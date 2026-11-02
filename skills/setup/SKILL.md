---
name: setup
description: "Use when finishing jw plugin setup or when the session-start notice says items are not ready — applying the lead/worker team policy, installing the agent-browser and Codex CLIs, registering API keys, or cleaning up the old symlink install — \"jw 설정해줘\", \"/jw:setup\", \"준비 안 된 항목 마무리해줘\", \"API 키 등록해줘\"."
---

# setup

플러그인이 직접 할 수 없는 마무리 설정을 한다. 세션 시작 점검 훅은 상태만 알리고, 실제 변경은 이 스킬이 사용자 요청을 받았을 때만 한다.

## 먼저 상태 확인

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-check.sh" --report
```

빠진 항목만 처리한다. 무엇을 바꾸는지 사용자에게 먼저 알린다. 특히 팀 정책은 모든 프로젝트에 적용되는 전역 설정을 바꾼다.

## 실행

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh"                       # 전체
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" --skip-cli            # CLI 설치 없이
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" --env-file <.env 경로> # 키를 .env에서 가져오기
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" --clean-legacy        # 예전 심볼릭 링크 정리 포함
```

- **팀 정책:** `~/.claude/settings.json`에 직원 모델(haiku 고정)과 커밋 서명 끄기를 넣고, `~/.claude/CLAUDE.md`에 정책 블록을 넣는다. 처음 적용할 때 원래 값을 남긴다. 사용자가 되돌리길 원하면 `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/team-policy.py" --remove ~/.claude/settings.json ~/.claude/CLAUDE.md`를 실행한다. env 변경은 Claude Code를 다시 시작해야 확실히 반영된다고 알린다.
- **CLI:** npm 전역 설치, 브라우저 다운로드처럼 시간이 걸리고 시스템을 바꾸는 작업이다. 사용자가 원하지 않으면 `--skip-cli`를 쓴다. 출력에 codex 로그인 안내가 나오면 그 명령을 사용자에게 `! <명령>` 형태로 전한다. 로그인은 사람이 해야 한다.
- **API 키:** Claude 안에서는 키를 입력받지 않는다. 사용자에게 키 값을 채팅에 붙여 넣으라고 하지 않는다. 키가 든 `.env` 파일이 있으면 `--env-file`로 가져오고, 없으면 `~/.config/my-claude-skills/secrets.env`에 `KEY=값` 줄을 직접 추가하라고 안내한다. 필수 키는 `GEMINI_API_KEY`(gemini-rewrite), `NAVER_CLIENT_ID`·`NAVER_CLIENT_SECRET`(naver-search)이다.
- **예전 설치:** 예전 `install.sh`가 만든 `~/.claude/skills/<이름>` 링크가 남으면 같은 스킬이 두 번 뜨거나 끊긴 링크가 된다. `~/.claude/settings.json`의 옛 repo-health 전역 훅은 세션마다 없는 파일을 부른다. 사용자 확인 후 `--clean-legacy`로 둘 다 정리한다. 실제 폴더와 다른 훅은 지우지 않는다.

## 프로젝트에 남은 예전 껍데기

예전 방식으로 설치한 프로젝트에는 지금은 없는 경로를 부르는 껍데기가 남을 수 있다. 그 프로젝트에서 각 스킬의 `setup.sh`를 다시 실행하면 정리되거나 새 방식으로 바뀐다.

| 껍데기 | 다시 실행할 것 |
| --- | --- |
| `.claude/hooks/repo-health.sh` | `bash "${CLAUDE_PLUGIN_ROOT}/skills/repo-health/scripts/setup.sh"` |
| `.claude/hooks/deploy-status-hook.sh` | `bash "${CLAUDE_PLUGIN_ROOT}/skills/deploy-status/scripts/setup.sh"` |
| git `pre-push`에 `~/.claude/skills/release-guard` 경로 | `bash "${CLAUDE_PLUGIN_ROOT}/skills/release-guard/scripts/setup.sh"` |
