# -*- coding: utf-8 -*-
"""repo-health 훅을 갱신하고 이전 config-drift-guard 훅을 통합한다.

다른 훅 명령과 설정은 그대로 둔다.

사용: python3 merge-settings.py <settings.json 경로>
"""
import json
import sys

MARKS = ("repo-health.sh", "config-drift-guard.sh")


def main():
    path = sys.argv[1]
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read().strip()
        data = json.loads(content) if content else {}
    except FileNotFoundError:
        data = {}

    hooks = data.setdefault("hooks", {})
    session_start = hooks.setdefault("SessionStart", [])

    kept = []
    for entry in session_start:
        original = entry.get("hooks", [])
        remaining = [
            hook for hook in original
            if not any(mark in hook.get("command", "") for mark in MARKS)
        ]
        if len(remaining) != len(original):
            if not remaining:
                continue
            entry = {**entry, "hooks": remaining}
        kept.append(entry)
    session_start[:] = kept
    session_start.append({
        "hooks": [
            {"type": "command", "command": "bash .claude/hooks/repo-health.sh"}
        ]
    })

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print("[repo-health] settings.json 갱신 완료")


if __name__ == "__main__":
    main()
