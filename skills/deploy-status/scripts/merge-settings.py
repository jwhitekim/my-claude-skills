# -*- coding: utf-8 -*-
"""예전 deploy-status 껍데기 PostToolUse 훅을 settings.json에서 걷어낸다. 추가는 하지 않는다.

command에 deploy-status-hook.sh가 들어간 hook만 지우고, 그 결과 hooks가 빈 entry만 지운다.
다른 훅과 설정은 그대로 둔다. 바뀐 게 있을 때만 파일을 다시 쓴다.

사용: python3 merge-settings.py <settings.json 경로>
"""
import json
import sys

MARK = "deploy-status-hook.sh"


def main():
    path = sys.argv[1]
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
    except FileNotFoundError:
        return
    data = json.loads(content) if content.strip() else {}

    hooks = data.get("hooks")
    post_tool_use = hooks.get("PostToolUse") if isinstance(hooks, dict) else None
    if not isinstance(post_tool_use, list):
        return

    kept = []
    removed = 0
    for entry in post_tool_use:
        original = entry.get("hooks", [])
        remaining = [h for h in original if MARK not in h.get("command", "")]
        removed += len(original) - len(remaining)
        if len(remaining) != len(original):
            if not remaining:
                continue
            entry = {**entry, "hooks": remaining}
        kept.append(entry)

    if not removed:
        return
    post_tool_use[:] = kept

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"[deploy-status] settings.json에서 예전 훅 {removed}개 제거")


if __name__ == "__main__":
    main()
