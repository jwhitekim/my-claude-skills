# -*- coding: utf-8 -*-
"""예전 프로젝트 껍데기 SessionStart 훅(repo-health.sh, config-drift-guard.sh)을 settings.json에서 걷어낸다.
추가는 하지 않는다.

command에 해당 이름이 들어간 hook만 지우고, 그 결과 hooks가 빈 entry만 지운다.
다른 훅과 설정은 그대로 둔다. 바뀐 게 있을 때만 파일을 다시 쓴다.

사용: python3 merge-settings.py <settings.json 경로>
"""
import json
import sys

MARKS = ("repo-health.sh", "config-drift-guard.sh")


def main():
    path = sys.argv[1]
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
    except FileNotFoundError:
        return
    data = json.loads(content) if content.strip() else {}

    hooks = data.get("hooks")
    session_start = hooks.get("SessionStart") if isinstance(hooks, dict) else None
    if not isinstance(session_start, list):
        return

    kept = []
    removed = 0
    for entry in session_start:
        original = entry.get("hooks", [])
        remaining = [
            hook for hook in original
            if not any(mark in hook.get("command", "") for mark in MARKS)
        ]
        removed += len(original) - len(remaining)
        if len(remaining) != len(original):
            if not remaining:
                continue
            entry = {**entry, "hooks": remaining}
        kept.append(entry)

    if not removed:
        return
    session_start[:] = kept

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"[repo-health] settings.json에서 예전 훅 {removed}개 제거")


if __name__ == "__main__":
    main()
