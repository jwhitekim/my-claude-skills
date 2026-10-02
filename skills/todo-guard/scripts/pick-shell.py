# -*- coding: utf-8 -*-
"""윈도우에서 Git 의 bash.exe 가 느린지 재고 알린다. 셸은 바꾸지 않는다.

왜 셸을 바꾸지 않나 (2026-09-25)
  전에는 bash.exe 가 느리면 ~/.claude/settings.json 의 env.CLAUDE_CODE_GIT_BASH_PATH 를
  같은 프로그램인 sh.exe 로 돌렸다. 훅은 빨라졌지만, **Claude Code 는 bash.exe 를 요구한다.**
  그 설정이 있는 채로 세션을 열면 「No suitable shell found」 로 Bash 도구가 통째로 막힌다
  (헤드리스 시험에서는 드러나지 않았고, 다른 세션에서 터졌다).
  그래서 이 스크립트는 재고 알리기만 하고, 예전에 넣어 둔 sh.exe 설정이 있으면 걷어낸다.

  느린 것은 셸을 바꿔 피하지 않고 원인을 고친다 - scripts/fix-slow-bash.sh
  (Git 의 bash.exe 파일 하나에 윈도우가 붙여 둔 상태 때문이다. 같은 내용의 새 파일로 바꾸면 537 → 55ms)

사용: python pick-shell.py <sh.exe 윈도우 경로> <bash.exe 윈도우 경로>
      (setup.sh 가 cygpath -w 로 넘긴다)
"""
import io
import json
import os
import subprocess
import sys
import time

try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

KEY = "CLAUDE_CODE_GIT_BASH_PATH"
RUNS = 7
SLOW_MS = 300


def launch_ms(exe):
    t = []
    for _ in range(RUNS):
        s = time.perf_counter()
        subprocess.run([exe, "-c", ":"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        t.append((time.perf_counter() - s) * 1000)
    t.sort()
    return t[len(t) // 2]


def drop_old_setting():
    """전 판이 넣어 둔 sh.exe 설정을 걷어낸다. 사용자가 손수 적은 다른 셸은 건드리지 않는다."""
    path = os.path.join(os.path.expanduser("~"), ".claude", "settings.json")
    if not os.path.exists(path):
        return
    try:
        data = json.load(io.open(path, encoding="utf-8"))
    except ValueError:
        return
    env = data.get("env")
    if not isinstance(env, dict):
        return
    cur = env.get(KEY, "")
    if not cur.lower().endswith(os.path.join("usr", "bin", "sh.exe").lower()):
        return
    io.open(path + ".todo-guard-백업_" + time.strftime("%Y%m%d-%H%M%S"), "w", encoding="utf-8").write(
        io.open(path, encoding="utf-8").read())
    env.pop(KEY, None)
    if env:
        data["env"] = env
    else:
        data.pop("env", None)
    io.open(path, "w", encoding="utf-8", newline=chr(10)).write(
        json.dumps(data, ensure_ascii=False, indent=2) + chr(10))
    print("  [고침] 전 판이 넣은 셸 설정(sh.exe)을 걷어냈습니다. 그대로 두면 새 세션이"
          " 「No suitable shell found」 로 막힙니다. 이미 열린 세션은 /exit 뒤 다시 여십시오")


def main(sh, bash):
    if os.name != "nt":
        return 0
    drop_old_setting()
    if not (os.path.isfile(sh) and os.path.isfile(bash)):
        return 0
    b = launch_ms(bash)
    s = launch_ms(sh)
    if b - s > SLOW_MS:
        print("  [알림] 이 PC 는 Git 의 bash.exe 만 유난히 느립니다 (bash.exe %.0fms · sh.exe %.0fms)."
              " Claude Code 의 모든 Bash 명령과 훅이 명령마다 그만큼 늦습니다." % (b, s))
        print("         사용자에게 알리고, 동의하면: bash ~/.claude/skills/todo-guard/scripts/fix-slow-bash.sh --apply"
              " (SKILL.md 「bash.exe 가 느린 PC」)")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("사용: python pick-shell.py <sh.exe> <bash.exe>")
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2]))
