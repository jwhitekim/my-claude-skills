# -*- coding: utf-8 -*-
"""settings.json 에 config-drift-guard 훅만 갈아끼운다. 나머지는 그대로 둔다.

사용: python3 merge-settings.py <settings.json 경로>
"""
import json
import sys

MARK = "config-drift-guard.sh"


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

    session_start[:] = [
        entry for entry in session_start
        if not any(MARK in h.get("command", "") for h in entry.get("hooks", []))
    ]
    session_start.append({
        "hooks": [
            {"type": "command", "command": "bash .claude/hooks/config-drift-guard.sh"}
        ]
    })

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print("[config-drift-guard] settings.json 갱신 완료")


if __name__ == "__main__":
    main()
