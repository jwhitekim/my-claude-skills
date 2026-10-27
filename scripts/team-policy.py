# -*- coding: utf-8 -*-
"""팀장(메인 Claude)·직원(하위 에이전트) 운영 방식을 전역 설정에 적용한다.

1. ~/.claude/settings.json 의 env 에 직원 모델을 haiku 로 고정한다.
   CLAUDE_CODE_SUBAGENT_MODEL=haiku        직원 기본 모델
   CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1      Agent 도구의 model 옵션과 에이전트 정의의 모델 지정을 무시
2. ~/.claude/CLAUDE.md 에 policies/team-policy.md 내용을 표시선 블록으로 넣는다.
   블록 밖의 내용은 건드리지 않고, 다시 실행하면 블록만 새 내용으로 바꾼다.

사용: python3 team-policy.py <settings.json> <CLAUDE.md> <team-policy.md>
      python3 team-policy.py --remove <settings.json> <CLAUDE.md>   적용한 것만 되돌린다
두 파일 모두 바꾸기 전에 .bak 으로 남긴다.
"""
import json
import os
import re
import shutil
import sys

ENV = {
    "CLAUDE_CODE_SUBAGENT_MODEL": "haiku",
    "CLAUDE_CODE_SUBAGENT_MODEL_FORCE": "1",
}
START = "<!-- my-claude-skills:team-policy:start (install.sh가 관리하는 블록, 직접 고치지 마세요) -->"
END = "<!-- my-claude-skills:team-policy:end -->"
BLOCK_RE = re.compile(
    r"\n*<!-- my-claude-skills:team-policy:start[^>]*-->.*?<!-- my-claude-skills:team-policy:end -->\n*",
    re.S,
)


def read(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        return None


def write(path, content):
    if os.path.exists(path):
        shutil.copyfile(path, path + ".bak")
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def update_settings(path, remove):
    content = (read(path) or "").strip()
    data = json.loads(content) if content else {}
    env = data.setdefault("env", {})
    if remove:
        for key, value in ENV.items():
            # 사용자가 다른 값으로 바꿔 둔 키는 지우지 않는다.
            if env.get(key) == value:
                del env[key]
        if not env:
            del data["env"]
    else:
        env.update(ENV)
    write(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    for key in ENV:
        print("team-policy: %s %s" % ("removed" if remove else "set", key))


def update_claude_md(path, policy_path, remove):
    content = read(path) or ""
    stripped = BLOCK_RE.sub("\n\n", content).strip("\n")
    if remove:
        new = stripped + "\n" if stripped else ""
    else:
        policy = read(policy_path)
        if not policy or not policy.strip():
            sys.exit("team-policy: %s 가 비어 있거나 없습니다" % policy_path)
        block = "%s\n%s\n%s" % (START, policy.strip("\n"), END)
        new = (stripped + "\n\n" if stripped else "") + block + "\n"
    if new != content:
        write(path, new)
    print("team-policy: %s CLAUDE.md block" % ("removed" if remove else "updated"))


def main():
    args = sys.argv[1:]
    remove = bool(args) and args[0] == "--remove"
    if remove:
        args = args[1:]
    if len(args) != (2 if remove else 3):
        sys.exit(__doc__)
    update_settings(args[0], remove)
    update_claude_md(args[1], args[2] if not remove else None, remove)


if __name__ == "__main__":
    main()
