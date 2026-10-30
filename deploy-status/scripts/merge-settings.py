# -*- coding: utf-8 -*-
"""settings.json 에 deploy-status 훅만 갈아끼운다. 나머지는 그대로 둔다.

사용: python3 merge-settings.py <settings.json 경로>
"""
import json
import sys

MARK = "deploy-status-hook.sh"
MATCHER = "Bash"


def main():
    path = sys.argv[1]
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read().strip()
        data = json.loads(content) if content else {}
    except FileNotFoundError:
        data = {}

    hooks = data.setdefault("hooks", {})
    post_tool_use = hooks.setdefault("PostToolUse", [])

    post_tool_use[:] = [
        entry for entry in post_tool_use
        if not any(MARK in h.get("command", "") for h in entry.get("hooks", []))
    ]
    post_tool_use.append({
        "matcher": MATCHER,
        "hooks": [
            {"type": "command", "command": "bash .claude/hooks/deploy-status-hook.sh"}
        ]
    })

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print("[deploy-status] settings.json 갱신 완료")


if __name__ == "__main__":
    main()
