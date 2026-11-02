# -*- coding: utf-8 -*-
"""예전 방식(전역 settings.json에 심은 세션 시작 훅)의 흔적만 제거한다. 새로 등록하지 않는다.

사용: python3 legacy-cleanup.py <settings.json 경로>

제거 대상: hooks.SessionStart 의 command에 아래 경로가 들어간 hook 항목.
  /.claude/skills/repo-health/scripts/
  /.claude/skills/watch-rules/scripts/
  /.claude/skills/config-drift-guard/scripts/
다른 훅은 그대로 둔다. 제거로 hooks 목록이 빈 entry만 지운다.
내용이 바뀔 때만 <경로>.bak 을 남기고, 임시 파일에 쓴 뒤 os.replace 로 교체한다.
파일이 없으면 아무것도 하지 않는다.
"""
import json
import os
import shutil
import sys
import tempfile

LEGACY_SKILLS = ("repo-health", "watch-rules", "config-drift-guard")


def is_legacy(hook):
    command = hook.get("command", "")
    return any(("/.claude/skills/%s/scripts/" % name) in command for name in LEGACY_SKILLS)


def clean(data):
    """훅 목록에서 예전 항목을 빼고, 그 결과 빈 entry만 지운다. 제거한 훅 개수를 돌려준다."""
    removed = 0
    session_start = data.get("hooks", {}).get("SessionStart")
    if not isinstance(session_start, list):
        return 0

    kept_entries = []
    for entry in session_start:
        hooks = entry.get("hooks") if isinstance(entry, dict) else None
        if not isinstance(hooks, list):
            kept_entries.append(entry)
            continue
        kept_hooks = [h for h in hooks if not (isinstance(h, dict) and is_legacy(h))]
        removed += len(hooks) - len(kept_hooks)
        if hooks and not kept_hooks:
            # 이번 제거로 비게 된 entry만 지운다.
            continue
        entry["hooks"] = kept_hooks
        kept_entries.append(entry)

    if removed:
        data["hooks"]["SessionStart"] = kept_entries
    return removed


def main():
    if len(sys.argv) != 2:
        print("사용법: python3 legacy-cleanup.py <settings.json 경로>", file=sys.stderr)
        return 2
    path = sys.argv[1]
    if not os.path.exists(path):
        print("legacy: settings.json 없음, 건너뜀")
        return 0

    with open(path, "r", encoding="utf-8") as f:
        original = f.read()
    data = json.loads(original) if original.strip() else {}

    removed = clean(data)
    if removed == 0:
        print("legacy: 예전 세션 훅 없음")
        return 0

    new_text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    shutil.copyfile(path, path + ".bak")

    directory = os.path.dirname(os.path.abspath(path))
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".settings-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(new_text)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.remove(tmp)
        raise
    print("legacy: 예전 세션 훅 %d개 제거 (백업: %s.bak)" % (removed, path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
