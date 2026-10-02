# -*- coding: utf-8 -*-
"""settings.json 에 이 스킬의 훅만 갈아끼운다. 나머지는 그대로 둔다.

왜 필요한가
  처음에는 setup.sh 가 settings.json 을 통째로 새로 썼다. 그 파일에는
  permissions 같은 프로젝트 설정이 함께 들어 있어서, 세팅 한 번에 권한 목록이
  날아가고 「직접 병합하십시오」라는 말만 남았다.

  그다음 판은 hooks 키를 통째로 갈아끼웠다. permissions 는 살아남았지만,
  사용자가 따로 걸어 둔 훅(상태줄·포매터·다른 플러그인)이 조용히 사라졌다.
  그래서 이번에는 훅 배열 안에서 「이 스킬이 넣은 항목」만 골라 바꾼다.

하는 일
  1) 기존 훅 중 todo-guard 것(경로에 todo-guard/hooks 또는 옛 이름)만 걷어낸다
  2) 그 자리에 지금 판의 훅을 넣는다
  3) 남의 훅과 나머지 키(permissions, env, model …)는 손대지 않는다

사용: python merge-settings.py <settings.json 경로> <훅 폴더 절대경로>
"""
import io
import json
import os
import sys

# 윈도우 콘솔은 cp949 라 한글 출력이 깨진다 (「settings.json �� ��」). UTF-8 로 낸다
try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

MATCHER = "Write|Edit|NotebookEdit|Bash|PowerShell"

# 이 스킬이 등록하는 훅
HOOKS = [
    ("SessionStart", None, ["session-start.sh"]),
    # 지시가 온 시점을 적어 둔다. 턴 끝에 등록 여부를 판정하려면 이것이 있어야 한다
    ("UserPromptSubmit", None, ["prompt-mark.sh"]),
    # PowerShell 도 본다. 윈도우 기본 셸이라 빼면 그쪽으로 한 일은 검사를 통째로 건너뛴다
    ("PreToolUse", MATCHER, ["pre-tool.sh"]),
    ("Stop", None, ["check-todo.sh"]),
]

# 이 스킬의 훅임을 알아보는 표시. 옛 세대가 쓰던 이름도 함께 본다.
#   doc-check.sh 는 글검수로 옮기기 전의 문서 검사 훅이다. 알아보고 걷어낸다
MINE = ("session-start.sh", "pre-tool.sh", "check-todo.sh", "doc-check.sh",
        "prompt-mark.sh",
        "todo-check.sh", "todo-session-start.sh", "todo-guard")


def is_mine(entry):
    """훅 항목이 이 스킬이 넣은 것인지 본다."""
    try:
        blob = json.dumps(entry, ensure_ascii=False)
    except (TypeError, ValueError):
        return False
    return any(m in blob for m in MINE)


# 훅 명령의 꼴.
#   윈도우에서 Claude Code 는 훅 명령을 Git Bash 로 돌린다. 명령이 bash "…" 이면 그 bash 가
#   bash 를 한 번 더 띄운다. 이 PC 에서 bash 한 번이 0.4~0.6초라 훅마다 그만큼 늦었다
#   (메시지 받을 때 887ms → . "…" 로 417ms). 그래서 윈도우에서는 지금 셸에서 바로 읽는다.
#   macOS · 리눅스는 훅 명령을 sh 로 돌릴 수 있다(리눅스 sh 는 dash). 거기서 bash 문법을 읽으면
#   깨지므로 bash "…" 를 그대로 쓴다. 그쪽은 프로세스 띄우는 값이 싸다
WIN = os.name == "nt" or sys.platform.startswith(("win", "msys", "cygwin"))
RUN = '. "%s/%s"' if WIN else 'bash "%s/%s"'


def build(hook_dir):
    out = {}
    for event, matcher, names in HOOKS:
        entry = {"hooks": [{"type": "command",
                            "command": RUN % (hook_dir, n)}
                           for n in names]}
        if matcher:
            entry["matcher"] = matcher
        out[event] = entry
    return out


def main(path, hook_dir):
    data = {}
    raw = ""
    if os.path.exists(path):
        raw = io.open(path, encoding="utf-8").read().strip()
        if raw:
            try:
                data = json.loads(raw)
            except ValueError:
                print("  [경고] settings.json 을 읽지 못했습니다. 손대지 않습니다.")
                return 1
            if not isinstance(data, dict):
                print("  [경고] settings.json 이 객체가 아닙니다. 손대지 않습니다.")
                return 1
        # 되돌릴 수단부터
        io.open(path + ".bak", "w", encoding="utf-8").write(raw)

    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        hooks = {}

    mine = build(hook_dir)
    had_old = False
    kept_foreign = 0

    for event, entry in mine.items():
        existing = hooks.get(event)
        existing = existing if isinstance(existing, list) else []
        foreign = []
        for e in existing:
            if is_mine(e):
                if "todo-check.sh" in json.dumps(e, ensure_ascii=False) \
                        or "todo-session-start.sh" in json.dumps(e, ensure_ascii=False):
                    had_old = True
            else:
                foreign.append(e)
        kept_foreign += len(foreign)
        hooks[event] = foreign + [entry]

    # 이 스킬이 더는 쓰지 않는 이벤트에 옛 훅이 남아 있으면 거기서도 걷어낸다
    for event in list(hooks):
        if event in mine or not isinstance(hooks[event], list):
            continue
        left = [e for e in hooks[event] if not is_mine(e)]
        if len(left) != len(hooks[event]):
            had_old = True
        if left:
            hooks[event] = left
        else:
            del hooks[event]

    data["hooks"] = hooks

    parent = os.path.dirname(os.path.abspath(path))
    if parent:
        try:
            os.makedirs(parent)
        except OSError:
            pass
    io.open(path, "w", encoding="utf-8", newline=chr(10)).write(
        json.dumps(data, ensure_ascii=False, indent=2) + chr(10))

    if had_old:
        print("  옛 세대 훅 등록(todo-check.sh 등)을 걷어냈습니다")
    if kept_foreign:
        print("  이 스킬 것이 아닌 훅 %d개는 그대로 두었습니다" % kept_foreign)
    other = sorted(k for k in data if k != "hooks")
    if other:
        print("  기존 설정 유지: %s" % " ".join(other))
    print("  settings.json 에 훅 등록 (SessionStart 1 · UserPromptSubmit 1 · PreToolUse 1 · Stop 1)")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("사용: python merge-settings.py <settings.json> <훅 폴더>")
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2]))
