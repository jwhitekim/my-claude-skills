# -*- coding: utf-8 -*-
"""팀장(메인 Claude)·직원(하위 에이전트) 운영 방식을 전역 설정에 적용한다.

1. ~/.claude/settings.json 의 env 에 직원 모델을 haiku 로 고정하고, 커밋·PR 서명을 끈다.
   CLAUDE_CODE_SUBAGENT_MODEL=haiku        직원 기본 모델
   CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1      Agent 도구의 model 옵션과 에이전트 정의의 모델 지정을 무시
   attribution.commit/pr = ""             직원(과 팀장)이 만드는 커밋·PR에 Claude 서명을 붙이지 않는다
2. ~/.claude/CLAUDE.md 에 team-policy.md 내용을 표시선 블록으로 넣는다.
   블록 밖의 내용은 건드리지 않고, 다시 실행하면 블록만 새 내용으로 바꾼다.

사용: python3 team-policy.py <settings.json> <CLAUDE.md> <team-policy.md>
      python3 team-policy.py --check <settings.json> <CLAUDE.md> <team-policy.md>   적용 상태만 확인(맞으면 종료 코드 0)
      python3 team-policy.py --remove <settings.json> <CLAUDE.md>   적용한 것만 되돌린다
두 파일 모두 바꾸기 전에 .bak 으로 남긴다. 내용이 같으면 쓰지 않는다.
처음 적용할 때 원래 값을 ~/.config/my-claude-skills/team-policy-prior.json 에 남기고,
--remove 는 그 값으로 되돌린다(기록이 없으면 적용값과 같은 키만 지운다).
"""
import json
import os
import re
import shutil
import sys
import tempfile

ENV = {
    "CLAUDE_CODE_SUBAGENT_MODEL": "haiku",
    "CLAUDE_CODE_SUBAGENT_MODEL_FORCE": "1",
}
# 빈 문자열이면 Claude Code가 커밋·PR에 서명(Co-Authored-By 등)을 넣지 않는다.
ATTRIBUTION = {"commit": "", "pr": ""}
PRIOR = os.path.expanduser("~/.config/my-claude-skills/team-policy-prior.json")
MISSING = "__missing__"
START = "<!-- my-claude-skills:team-policy:start (jw 플러그인 /jw:setup이 관리하는 블록, 직접 고치지 마세요) -->"
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
    if read(path) == content:
        return
    if os.path.exists(path):
        shutil.copyfile(path, path + ".bak")
    directory = os.path.dirname(path) or "."
    os.makedirs(directory, exist_ok=True)
    # 다른 프로세스가 반쯤 쓴 파일을 읽지 않도록 임시 파일에 쓴 뒤 한 번에 바꾼다.
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".team-policy.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(content)
    if os.path.exists(path):
        shutil.copymode(path, tmp)
    os.replace(tmp, path)


def save_prior(data):
    """처음 적용할 때만 원래 값을 기록한다. 이미 기록이 있으면 덮어쓰지 않는다."""
    if os.path.exists(PRIOR):
        return
    env = data.get("env", {}) if isinstance(data.get("env"), dict) else {}
    attribution = data.get("attribution")
    prior = {
        "env": {k: env.get(k, MISSING) for k in ENV},
        "attribution": ({k: attribution.get(k, MISSING) for k in ATTRIBUTION}
                        if isinstance(attribution, dict) else
                        (MISSING if attribution is None else attribution)),
    }
    os.makedirs(os.path.dirname(PRIOR), exist_ok=True)
    with open(PRIOR, "w", encoding="utf-8") as f:
        json.dump(prior, f, ensure_ascii=False, indent=2)


def load_prior():
    try:
        with open(PRIOR, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, ValueError):
        return None


def restore(target, key, value):
    if value == MISSING:
        target.pop(key, None)
    else:
        target[key] = value


def update_settings(path, remove):
    content = (read(path) or "").strip()
    data = json.loads(content) if content else {}
    if not remove:
        save_prior(data)
    env = data.setdefault("env", {})
    prior = load_prior() if remove else None
    if remove:
        for key, value in ENV.items():
            # 사용자가 다른 값으로 바꿔 둔 키는 지우지 않는다.
            if env.get(key) == value:
                if prior:
                    restore(env, key, prior["env"].get(key, MISSING))
                else:
                    del env[key]
        if not env:
            del data["env"]
        attribution = data.get("attribution")
        prior_attr = prior.get("attribution") if prior else None
        if isinstance(attribution, dict):
            for key, value in ATTRIBUTION.items():
                if attribution.get(key) == value:
                    if isinstance(prior_attr, dict):
                        restore(attribution, key, prior_attr.get(key, MISSING))
                    else:
                        del attribution[key]
            if not attribution:
                del data["attribution"]
        if prior and not isinstance(prior_attr, dict) and prior_attr != MISSING and "attribution" not in data:
            data["attribution"] = prior_attr
        if prior:
            os.remove(PRIOR)
    else:
        env.update(ENV)
        # attribution: false 처럼 불리언으로 둔 경우는 사용자가 이미 정한 것이므로 건드리지 않는다.
        attribution = data.setdefault("attribution", {})
        if isinstance(attribution, dict):
            attribution.update(ATTRIBUTION)
    write(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    for key in list(ENV) + ["attribution.commit", "attribution.pr"]:
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


def check(settings_path, claude_md_path, policy_path):
    """정책이 지금 내용 그대로 적용돼 있으면 True."""
    content = (read(settings_path) or "").strip()
    try:
        data = json.loads(content) if content else {}
    except ValueError:
        return False
    env = data.get("env") if isinstance(data.get("env"), dict) else {}
    if any(env.get(k) != v for k, v in ENV.items()):
        return False
    attribution = data.get("attribution")
    # 불리언 false 등 사용자가 이미 정한 서명 설정은 적용된 것으로 본다.
    if isinstance(attribution, dict) and any(attribution.get(k) != v for k, v in ATTRIBUTION.items()):
        return False
    if attribution is None:
        return False
    # 표시선 주석 문구는 판마다 다를 수 있으므로 블록 본문만 비교한다.
    policy = (read(policy_path) or "").strip("\n")
    match = re.search(
        r"<!-- my-claude-skills:team-policy:start[^>]*-->\n(.*?)\n<!-- my-claude-skills:team-policy:end -->",
        read(claude_md_path) or "", re.S)
    return bool(policy) and bool(match) and match.group(1).strip("\n") == policy


def main():
    args = sys.argv[1:]
    if args and args[0] == "--check":
        if len(args) != 4:
            sys.exit(__doc__)
        sys.exit(0 if check(*args[1:]) else 1)
    remove = bool(args) and args[0] == "--remove"
    if remove:
        args = args[1:]
    if len(args) != (2 if remove else 3):
        sys.exit(__doc__)
    update_settings(args[0], remove)
    update_claude_md(args[1], args[2] if not remove else None, remove)


if __name__ == "__main__":
    main()
