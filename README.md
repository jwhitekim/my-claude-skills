# my-claude-skills

개인용 Claude Code 스킬과 전역 훅·운영 정책을 한곳에서 관리하고 설치하는 저장소입니다.

## 설치

필요한 도구는 Git, Claude Code, Bash, Python 3, curl입니다. `agent-browser` 설치에는 npm·Homebrew·Cargo 중 하나가 필요합니다.

```sh
git clone https://github.com/jwhitekim/my-claude-skills   # 이미 받았다면 생략
cd my-claude-skills
./install.sh
```

[install.sh](install.sh)가 하는 일:

- `skills/`의 각 폴더를 `~/.claude/skills/`에 심볼릭 링크로 연결합니다. **같은 이름의 기존 항목은 지우고 교체합니다.**
- 전역 `SessionStart` 훅을 `~/.claude/settings.json`에 등록합니다.
- [팀 운영 정책](policies/team-policy.md)을 전역 설정에 적용합니다.
- `agent-browser`와 전용 Chrome, Codex CLI를 설치합니다. Lightpanda는 Linux·macOS(x86_64·arm64)에서만 설치합니다.
- API 키를 `~/.config/my-claude-skills/secrets.env`(권한 600)에 저장합니다.

바꾸는 전역 설정 파일은 수정 직전 상태를 `.bak`으로 남깁니다(실행할 때마다 덮어씀). CLI 설치가 실패해도 나머지는 계속합니다.

링크 방식이라 설치 후에도 저장소를 지우면 안 됩니다. 새 스킬을 추가했다면 `./install.sh`를 다시 실행합니다.

### 전역 훅

모든 프로젝트에서 세션을 시작할 때 다음을 점검합니다.

- `repo-health`: 저장소 정리 대상
- `config-drift-guard`: 환경 설정과 CI 설정의 차이

다시 설치해도 중복 등록되지 않습니다. 프로젝트에 `.claude/hooks/<스킬명>.sh`가 있으면 그 스킬의 전역 훅은 건너뜁니다.

### 팀 운영 정책

- 메인 Claude가 추론·판단을, 하위 에이전트가 반복 작업을 맡습니다.
- 하위 에이전트 모델을 Haiku로 고정합니다. 개별 모델 지정은 무시됩니다.
- 커밋·PR의 Claude 서명을 끕니다.
- 역할 분담 규칙을 `~/.claude/CLAUDE.md`의 관리 블록에 넣습니다. 다시 실행하면 블록만 갱신합니다.

새 Claude Code 세션부터 적용됩니다. 아래 명령은 정책 설정과 관리 블록을 지웁니다. 설치 전에 있던 설정값을 복원하지는 않습니다.

```sh
python3 scripts/team-policy.py --remove ~/.claude/settings.json ~/.claude/CLAUDE.md
```

### Codex 로그인

`codex` 스킬은 Codex CLI와 로그인이 필요합니다. CLI는 npm이나 Homebrew로 설치합니다. 둘 다 없으면 nvm으로 Node.js LTS부터 설치합니다. 로그인이 안 된 상태에서 터미널로 설치하면 로그인까지 진행합니다.

직접 로그인할 때는 하나를 고릅니다.

```sh
codex login                  # 개인 ChatGPT 계정
codex login --device-auth    # 브라우저 없는 서버
printenv OPENAI_API_KEY | codex login --with-api-key   # OpenAI API 키(표준입력으로 전달)
```

### API 키

| 변수 | 용도 |
| --- | --- |
| `AI_GATEWAY_API_KEY` | `gemini-rewrite`가 Google API 402·429 때 대체 호출 |
| `GEMINI_API_KEY` | `gemini-rewrite`의 Gemini API 호출 |

`gemini-rewrite`는 Google API가 402·429를 돌려줄 때만 AI Gateway로 대체 호출합니다.

`gemini-rewrite`를 실행하려면 `jq`도 필요합니다.

```sh
cp .env.example .env
# .env에 키를 채운 뒤 실행합니다
./install.sh
```

설치할 때 키는 다음 순서로 정합니다.

1. `.env`에 값이 있으면 그 값으로 저장합니다.
2. 없으면 기존 저장값을 유지합니다.
3. 저장값도 없으면 현재 셸의 환경변수를 저장합니다.
4. 그것도 없으면 터미널에서 입력받습니다. Enter로 건너뛸 수 있고, 터미널이 아니면 묻지 않고 건너뜁니다.

`.env`는 git에 올라가지 않습니다. `.env`를 바꿨거나 입력을 건너뛰었다면 설치를 다시 실행합니다.

`.env` 없이 키를 바꾸려면 저장 파일에서 해당 줄을 지우고 설치를 다시 실행합니다.

스킬을 실행할 때는 환경변수가 저장 파일보다 우선합니다.

## 사용법

설치 후 Claude Code에서 스킬이 맡는 작업을 요청합니다. 예: `저장소 건강검진해줘` → `repo-health`.

프로젝트별로 준비가 필요한 스킬도 있습니다.

- [배포 상태 확인](skills/deploy-status/SKILL.md): GitHub Actions가 있어야 합니다.
- [릴리스 점검 훅](skills/release-guard/SKILL.md): 프로젝트마다 따로 설치합니다.

### 스킬 수정 후 확인

1. 저장소에서 스킬을 고칩니다. 심볼릭 링크라 바로 반영됩니다.
2. 새 Claude Code 세션을 엽니다. 기존 세션은 스킬 목록이 캐시돼 있을 수 있습니다.
3. 스킬의 `description`에 맞는 요청으로 호출과 동작을 확인합니다.

## 구성 목록

| 스킬 | 용도 |
| --- | --- |
| [`agent-browser`](skills/agent-browser/SKILL.md) | 실제 브라우저로 웹 탐색·조작·화면 확인 |
| [`api-contract-guard`](skills/api-contract-guard/SKILL.md) | OpenAPI·Swagger 변경의 호환성 점검 |
| [`change-impact`](skills/change-impact/SKILL.md) | 변경 영향 범위와 관련 점검 확인 |
| [`codex`](skills/codex/SKILL.md) | Codex 의견 요청, 교차 검증·리뷰·문서 초안 작성 |
| [`commit-and-push`](skills/commit-and-push/SKILL.md) | 변경 검증과 커밋, 사용자 확인 후 푸시 |
| [`config-drift-guard`](skills/config-drift-guard/SKILL.md) | 환경별 설정과 GitHub Actions의 차이 점검 |
| [`dependency-guard`](skills/dependency-guard/SKILL.md) | 의존성 잠금 파일 변경의 안전성 점검 |
| [`deploy-status`](skills/deploy-status/SKILL.md) | 푸시 후 GitHub Actions 배포 상태 확인·실패 진단 |
| [`gemini-rewrite`](skills/gemini-rewrite/SKILL.md) | 의미를 유지하며 한국어 문장 다듬기 |
| [`incident-review`](skills/incident-review/SKILL.md) | 장애·배포 실패 회고 작성 |
| [`migration-guard`](skills/migration-guard/SKILL.md) | SQL 마이그레이션의 파괴적 변경·잠금 위험 점검 |
| [`readme-writer`](skills/readme-writer/SKILL.md) | README 작성·축약·양식 정리 |
| [`release-guard`](skills/release-guard/SKILL.md) | 릴리스·버전 태그 준비와 사전 점검 |
| [`repo-health`](skills/repo-health/SKILL.md) | 저장소에 쌓인 불필요한 파일·정리 대상 점검 |
| [`skill-lint`](skills/skill-lint/SKILL.md) | 스킬 생성·수정 후 저장소 구성 점검 |
| [`test-gap-finder`](skills/test-gap-finder/SKILL.md) | 변경 코드의 테스트 누락 후보 확인 |

## 라이선스

LICENSE 파일이 없어 라이선스 확인이 필요합니다.
