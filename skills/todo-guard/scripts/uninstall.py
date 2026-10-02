# -*- coding: utf-8 -*-
"""이 프로젝트에서 todo-guard 세팅을 걷어낸다.

왜 필요한가
  세팅하는 길만 있고 되돌리는 길이 없었다. 그래서 한 번 켠 프로젝트는
  손으로 훅을 지우고 settings.json 을 열어 훅 등록을 골라내야 했다.
  그 과정에서 남의 훅이나 permissions 를 잘못 지우기 쉽다.

걷어내는 것
  .claude/hooks/    이 스킬이 깐 훅과 옛 문서 검사 훅 (남의 훅은 건드리지 않는다)
  settings.json     이 스킬이 넣은 훅 등록만. 나머지 키는 그대로 둔다
  .claude/todo-guard.json · .claude/todo-guard/   설정과 검사 기록
  .todoguarddocs · .todoguardskip · .todoguardignore  (글검수로 옮기기 전의 문서 목록)
  투두가드설명서.md
  CLAUDE.md 의 「작업 관리 규칙 (todo-guard)」 대목

남기는 것
  TODO.md · TODO-완료.md   사용자의 작업 기록이다. 스킬이 만든 것이라도 내용은
                       사용자 것이다. 함께 지우려면 --todo 를 붙인다.
  ~/.claude/CLAUDE.md  전역 「세션 밖 폴더」 규칙. 모든 프로젝트가 같이 쓰고,
                       동작을 바꾸지 않고 경고만 한다. 프로젝트 하나를 걷어낸다고
                       빼면 다른 프로젝트의 경고까지 사라진다.
                       빼려면 사용자가 따로 말해야 한다.
                         bash scripts/ensure-global-rule.sh remove

사용
  python uninstall.py [프로젝트 폴더] [--todo] [--dry]
"""
import json
import os
import shutil
import sys
import time

MY_HOOKS = ("session-start.sh", "check-todo.sh", "doc-check.sh", "pre-tool.sh",
            "prompt-mark.sh",
            "todo-check.sh", "todo-session-start.sh")
MINE = MY_HOOKS + ("todo-guard",)
CLAUDE_MD_HEAD = "# 작업 관리 규칙 (todo-guard)"


def is_mine(entry):
    try:
        blob = json.dumps(entry, ensure_ascii=False)
    except (TypeError, ValueError):
        return False
    return any(m in blob for m in MINE)


def strip_hooks(path, log, dry):
    if not os.path.exists(path):
        return
    try:
        data = json.load(open(path, encoding="utf-8"))
    except (ValueError, OSError):
        log("settings.json 을 읽지 못했습니다. 손대지 않습니다.")
        return
    if not isinstance(data, dict):
        return
    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        return

    removed, kept = 0, 0
    for event in list(hooks):
        lst = hooks[event]
        if not isinstance(lst, list):
            continue
        left = [e for e in lst if not is_mine(e)]
        removed += len(lst) - len(left)
        kept += len(left)
        if left:
            hooks[event] = left
        else:
            del hooks[event]
    if not hooks:
        del data["hooks"]

    if not removed:
        log("settings.json 에서 걷어낼 훅 등록이 없습니다.")
        return
    if dry:
        log("settings.json 에서 훅 등록 %d개를 걷어냅니다 (남의 훅 %d개는 그대로)."
            % (removed, kept))
        return
    open(path, "w", encoding="utf-8", newline="\n").write(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    log("settings.json 에서 훅 등록 %d개를 걷어냈습니다 (남의 훅 %d개는 그대로)."
        % (removed, kept))


def strip_claude_md(path, log, dry):
    """setup.sh 가 덧붙인 대목만 잘라낸다. 사용자가 쓴 부분은 건드리지 않는다."""
    if not os.path.exists(path):
        return
    text = open(path, encoding="utf-8", errors="replace").read()
    i = text.find(CLAUDE_MD_HEAD)
    if i < 0:
        return
    # 다음 최상위 제목까지가 이 스킬이 넣은 대목이다
    j = text.find("\n# ", i + len(CLAUDE_MD_HEAD))
    cut = text[:i].rstrip() + ("\n" + text[j + 1:] if j > 0 else "\n")
    if dry:
        log("CLAUDE.md 에서 「작업 관리 규칙 (todo-guard)」 대목을 걷어냅니다.")
        return
    open(path, "w", encoding="utf-8", newline="\n").write(cut)
    log("CLAUDE.md 에서 「작업 관리 규칙 (todo-guard)」 대목을 걷어냈습니다.")


def main(argv):
    dry = "--dry" in argv
    with_todo = "--todo" in argv
    rest = [a for a in argv if not a.startswith("--")]
    proj = os.path.abspath(rest[0]) if rest else os.getcwd()

    hooks_dir = os.path.join(proj, ".claude", "hooks")
    conf = os.path.join(proj, ".claude", "todo-guard.json")
    if not os.path.isdir(hooks_dir) and not os.path.exists(conf):
        print("이 폴더에는 todo-guard 세팅이 없습니다: %s" % proj)
        return 0

    print("[todo-guard] 세팅을 걷어냅니다 - %s" % proj)
    if dry:
        print("  (--dry: 무엇을 지울지 보여만 줍니다. 실제로 지우지 않습니다)")

    def log(m):
        print("  " + m)

    # 되돌릴 수단부터 만든다
    if not dry:
        bak = os.path.join(proj, ".claude",
                           "todo-guard_걷어내기전_" + time.strftime("%Y%m%d-%H%M%S"))
        os.makedirs(bak)
        for rel in (os.path.join(".claude", "hooks"),
                    os.path.join(".claude", "settings.json"),
                    os.path.join(".claude", "todo-guard.json"),
                    "CLAUDE.md", ".todoguardignore", ".todoguardskip", ".todoguarddocs",
                "투두가드설명서.md"):
            src = os.path.join(proj, rel)
            if not os.path.exists(src):
                continue
            dst = os.path.join(bak, os.path.basename(rel.rstrip(os.sep)))
            (shutil.copytree if os.path.isdir(src) else shutil.copy2)(src, dst)
        log("백업: %s" % bak)

    # 훅 파일
    if os.path.isdir(hooks_dir):
        gone = 0
        for nm in sorted(os.listdir(hooks_dir)):
            base = nm[:-4] if nm.endswith(".old") else nm
            if base not in MY_HOOKS:
                continue
            if not dry:
                os.remove(os.path.join(hooks_dir, nm))
            gone += 1
        log("훅 파일 %d개를 %s" % (gone, "지웁니다." if dry else "지웠습니다."))
        if not dry and not os.listdir(hooks_dir):
            os.rmdir(hooks_dir)
            log("빈 .claude/hooks 폴더를 지웠습니다.")

    strip_hooks(os.path.join(proj, ".claude", "settings.json"), log, dry)

    for rel in (os.path.join(".claude", "todo-guard.json"),
                ".todoguardignore", ".todoguardskip", ".todoguarddocs",
                "투두가드설명서.md"):
        p = os.path.join(proj, rel)
        if os.path.exists(p):
            if not dry:
                os.remove(p)
            log("%s 를 %s" % (rel, "지웁니다." if dry else "지웠습니다."))

    cache = os.path.join(proj, ".claude", "todo-guard")
    if os.path.isdir(cache):
        if not dry:
            shutil.rmtree(cache)
        log(".claude/todo-guard (번호 · 턴 기록) 를 %s" % ("지웁니다." if dry else "지웠습니다."))

    strip_claude_md(os.path.join(proj, "CLAUDE.md"), log, dry)

    # TODO-완료.md 는 TODO.md 에서 옮겨 둔 완료 기록이다. TODO.md 와 같이 다룬다
    for name in ("TODO.md", "TODO-완료.md"):
        todo = os.path.join(proj, name)
        if not os.path.exists(todo):
            continue
        if with_todo:
            if not dry:
                os.remove(todo)
            log("%s 를 %s" % (name, "지웁니다." if dry else "지웠습니다."))
        else:
            log("%s 는 남겼습니다. 사용자의 작업 기록입니다 "
                "(함께 지우려면 --todo)." % name)

    # 전역 규칙은 프로젝트에 딸린 것이 아니다. 남긴다고 분명히 알린다
    gl = os.path.join(os.path.expanduser("~"), ".claude", "CLAUDE.md")
    if os.path.exists(gl):
        try:
            has = "세션 밖 폴더에서 작업중" in open(
                gl, encoding="utf-8", errors="replace").read()
        except OSError:
            has = False
        if has:
            log("전역 「세션 밖 폴더」 규칙은 남겼습니다 - ~/.claude/CLAUDE.md")
            log("  모든 프로젝트가 같이 쓰고, 동작을 바꾸지 않고 경고만 합니다.")
            log("  빼려면: bash ~/.claude/skills/todo-guard/scripts/"
                "ensure-global-rule.sh remove")

    if dry:
        print("[todo-guard] 여기까지가 지울 것입니다. 아직 아무것도 지우지 않았습니다.")
        return 0
    print("[todo-guard] 걷어내기 완료")
    print("  훅은 세션을 열 때 한 번 읽힙니다. /exit 로 나갔다 들어와야 풀립니다.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
