# -*- coding: utf-8 -*-
"""이미 세팅한 프로젝트를 훑어 상태를 보고, 필요하면 다시 세팅한다.

왜 필요한가
  스킬을 고칠 때마다 세팅한 프로젝트를 하나씩 열어 다시 세팅하는 것은 못 할 일이다.
  대개는 그럴 필요도 없다 - 훅이 껍데기라 스킬 본체를 부르므로 고치면 바로 적용된다.
  다시 세팅해야 하는 것은 옛 세대(훅 내용을 통째로 복사하던 판)뿐이다.

  그것을 눈으로 가려내려면 프로젝트마다 파일을 열어 봐야 한다. 그래서 도구로 만든다.

사용
  python doctor.py <훑을 폴더> [...]          상태만 보여준다
  python doctor.py --fix <훑을 폴더> [...]     손봐야 할 것만 다시 세팅한다
"""
import json
import os
import shutil
import subprocess
import sys

# 윈도우 콘솔은 cp949 라 한글이 깨진다. 줄마다 바로 내보내야 setup.sh 출력과 순서가 맞는다
try:
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
except (AttributeError, ValueError):
    pass

SKILL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHIM_MARK = "skills/todo-guard/scripts"
EVENTS = ("SessionStart", "UserPromptSubmit", "PreToolUse", "Stop")


def git_bash():
    """Git Bash 를 찾는다.

    PATH 의 `bash` 를 그냥 쓰면 윈도우에서 `C:\\Windows\\System32\\bash.exe`(WSL 실행기)가
    잡힌다. 그 bash 는 이 스크립트 경로를 못 찾아 종료 코드 127 로 실패한다 (2026-09-26).
    Bash 도구에서 돌릴 때는 Git 의 bin 이 PATH 앞에 있어 우연히 통과했고, 그래서 늦게 드러났다.
    """
    if os.name != "nt":
        return "bash"
    cand = [os.environ.get("CLAUDE_CODE_GIT_BASH_PATH", "")]
    for base in (os.environ.get("ProgramFiles", r"C:\Program Files"),
                 os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)"),
                 os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs")):
        if base:
            cand += [os.path.join(base, "Git", "bin", "bash.exe"),
                     os.path.join(base, "Git", "usr", "bin", "bash.exe")]
    found = shutil.which("bash") or ""
    if found and "system32" not in found.lower():
        cand.append(found)
    for c in cand:
        if c and os.path.isfile(c):
            return c
    return "bash"


def posix_path(p):
    """C:\\Users\\… → /c/Users/… . Git Bash 는 이 꼴을 받는다."""
    p = p.replace(os.sep, "/")
    if os.name == "nt" and len(p) > 2 and p[1:3] == ":/":
        p = "/" + p[0].lower() + p[2:]
    return p


def find_projects(roots, depth=3):
    """훑을 폴더 아래에서 .claude/hooks 가 있는 곳을 모은다."""
    out = []
    for root in roots:
        root = os.path.abspath(root)
        if not os.path.isdir(root):
            continue
        base = root.rstrip(os.sep).count(os.sep)
        for cur, dirs, _ in os.walk(root):
            if cur.count(os.sep) - base >= depth:
                dirs[:] = []
                continue
            dirs[:] = [d for d in dirs
                       if d not in (".git", "node_modules", "__pycache__")]
            if os.path.isdir(os.path.join(cur, ".claude", "hooks")):
                out.append(cur)
                dirs[:] = []          # 프로젝트 안을 더 파고들지 않는다
    return sorted(out)


def inspect(proj):
    """이 프로젝트가 지금 판으로 도는지 본다."""
    hooks = os.path.join(proj, ".claude", "hooks")
    files = sorted(os.listdir(hooks))
    ss = os.path.join(hooks, "session-start.sh")

    problems = []
    if os.path.exists(ss):
        try:
            text = open(ss, encoding="utf-8", errors="replace").read()
        except OSError:
            text = ""
        if SHIM_MARK not in text:
            problems.append("훅이 사본이다 - 고친 내용이 반영되지 않는다")
    else:
        problems.append("옛 이름의 훅만 있다")

    sj = os.path.join(proj, ".claude", "settings.json")
    registered = []
    if os.path.exists(sj):
        try:
            registered = [e for e in EVENTS
                          if e in (json.load(open(sj, encoding="utf-8"))
                                   .get("hooks") or {})]
        except (ValueError, OSError):
            problems.append("settings.json 을 읽지 못했다")
    else:
        problems.append("settings.json 이 없다")
    for e in EVENTS:
        if e not in registered:
            problems.append("%s 훅이 등록돼 있지 않다" % e)

    if any(f.endswith(".sh") and f.startswith("todo-") for f in files):
        problems.append("옛 세대 훅 파일이 남아 있다")

    # PowerShell 을 훅 대상에서 뺀 옛 등록 - 윈도우 기본 셸로 한 일은 검사를 건너뛴다
    try:
        pre = (json.load(open(sj, encoding="utf-8")).get("hooks") or {}).get("PreToolUse") or []
        mine = [e for e in pre if "pre-tool.sh" in json.dumps(e, ensure_ascii=False)]
        if mine and not any("PowerShell" in (e.get("matcher") or "") for e in mine):
            problems.append("PreToolUse 가 PowerShell 도구를 보지 않는다 (옛 등록)")
        # 전역 셸 설정이 sh.exe 면 새 세션이 「No suitable shell found」 로 막힌다.
        #   옛 판(2026-09-23~24)이 훅을 빠르게 하려고 넣었다. setup 이 걷어낸다
        if os.name == "nt":
            try:
                genv = (json.load(open(os.path.join(os.path.expanduser("~"), ".claude", "settings.json"),
                                       encoding="utf-8")).get("env") or {})
                if str(genv.get("CLAUDE_CODE_GIT_BASH_PATH", "")).lower().endswith("sh.exe") and \
                        not str(genv.get("CLAUDE_CODE_GIT_BASH_PATH", "")).lower().endswith("bash.exe"):
                    problems.append("전역 설정의 셸이 sh.exe 다 (새 세션이 「No suitable shell found」 로 막힌다)")
            except (ValueError, OSError):
                pass

        # 윈도우에서 bash "…" 로 등록하면 훅마다 bash 를 한 번 더 띄워 0.4~0.6초씩 늦다
        if os.name == "nt":
            for evs in (json.load(open(sj, encoding="utf-8")).get("hooks") or {}).values():
                cmds = [h.get("command", "") for e in (evs or []) for h in (e.get("hooks") or [])]
                if any(c.startswith("bash ") and "/.claude/hooks/" in c and
                       any(n in c for n in ("session-start.sh", "prompt-mark.sh", "pre-tool.sh", "check-todo.sh"))
                       for c in cmds):
                    problems.append("훅 등록이 bash 꼴이다 (윈도우에서 훅마다 bash 를 한 번 더 띄운다)")
                    break
    except (ValueError, OSError, AttributeError):
        pass

    # CLAUDE.md 운영 규칙 판 - 옛 판은 모델에게 TODO.md 를 직접 열고 고치라고 한다
    cm = os.path.join(proj, "CLAUDE.md")
    try:
        ctext = open(cm, encoding="utf-8", errors="replace").read()
    except OSError:
        ctext = ""
    if "# 작업 관리 규칙 (todo-guard)" in ctext and "todo-guard 운영 규칙 v6" not in ctext:
        problems.append("CLAUDE.md 운영 규칙이 옛 판이다")

    doc = os.path.join(proj, "투두가드설명서.md")
    src = os.path.join(SKILL, "rules", "투두가드설명서.md")
    try:
        if os.path.exists(doc) and open(doc, "rb").read() != open(src, "rb").read():
            problems.append("투두가드설명서.md 가 옛 판이다")
    except OSError:
        pass

    # 문서 문체 검사는 글검수(geulgeomsu) 스킬로 옮겼다. 옛 문서 검사 훅이 남았으면 걷어내야 한다
    try:
        doc_hook = "doc-check.sh" in open(sj, encoding="utf-8").read()
    except OSError:
        doc_hook = False
    if "doc-check.sh" in files or doc_hook:
        problems.append("옛 문서 검사 훅(doc-check.sh)이 남아 있다 - 문서 검사는 글검수 스킬로 옮겼다")

    return files, registered, problems


def main(argv):
    fix = "--fix" in argv
    roots = [a for a in argv if not a.startswith("--")]
    if not roots:
        print(__doc__.strip())
        return 2

    projects = find_projects(roots)
    if not projects:
        print("세팅된 프로젝트를 찾지 못했습니다.")
        return 0

    need = []
    for p in projects:
        _, registered, problems = inspect(p)
        if problems:
            need.append(p)
            print("[손봐야 함] %s" % p)
            for m in problems:
                print("    - %s" % m)
        else:
            print("[그대로 좋음] %s   (%s)" % (p, "+".join(registered)))

    print()
    print("모두 %d곳 - 그대로 좋음 %d · 손봐야 함 %d"
          % (len(projects), len(projects) - len(need), len(need)))

    if not need:
        print("훅이 껍데기라 스킬을 고치면 바로 적용됩니다. 다시 세팅할 것이 없습니다.")
        return 0

    if not fix:
        print("다시 세팅하려면 --fix 를 붙여 다시 실행하십시오.")
        return 1

    print()
    for p in need:
        print("=== 다시 세팅: %s" % p)
        r = subprocess.run([git_bash(), posix_path(os.path.join(SKILL, "scripts", "setup.sh"))],
                           cwd=p)
        if r.returncode != 0:
            print("    실패 (종료 코드 %d)" % r.returncode)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
