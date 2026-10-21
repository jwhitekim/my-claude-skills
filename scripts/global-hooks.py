# -*- coding: utf-8 -*-
"""~/.claude/settings.json 에 세션 시작 점검 훅을 전역으로 등록한다. 다른 항목은 그대로 둔다.

사용: python3 global-hooks.py <settings.json 경로>

프로젝트에 이미 같은 스킬의 껍데기(.claude/hooks/<스킬>.sh)가 깔려 있으면
프로젝트 훅이 돌기 때문에 전역 훅은 건너뛴다 (두 번 출력 방지).
"""
import json
import shutil
import sys

# 스킬 이름: 스킬 폴더 기준 실행 스크립트
HOOKS = {
    "repo-health": "scripts/scan.sh summary",
    "watch-rules": "scripts/check.sh",
    "config-drift-guard": "scripts/scan.sh summary",
}


def marker(name):
    return "/.claude/skills/%s/scripts/" % name


def command(name, script):
    return (
        '[ -f .claude/hooks/{n}.sh ] || bash "$HOME/.claude/skills/{n}/{s}"'
    ).format(n=name, s=script)


def main():
    path = sys.argv[1]
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read().strip()
        data = json.loads(content) if content else {}
        shutil.copyfile(path, path + ".bak")
    except FileNotFoundError:
        data = {}

    session_start = data.setdefault("hooks", {}).setdefault("SessionStart", [])

    for name, script in HOOKS.items():
        session_start[:] = [
            entry for entry in session_start
            if not any(marker(name) in h.get("command", "") for h in entry.get("hooks", []))
        ]
        session_start.append({
            "hooks": [{"type": "command", "command": command(name, script)}]
        })
        print("global hook: %s" % name)

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
