# my-claude-skills

개인용 Claude Code 스킬 11개와 전역 훅·운영 정책을 관리하고 설치하는 저장소입니다.

## 설치

Git, Claude Code, Bash, Python 3, curl이 필요합니다. `agent-browser` 설치에는 npm·Homebrew·Cargo 중 하나가 필요합니다.

```sh
git clone https://github.com/jwhitekim/my-claude-skills   # 이미 받았다면 생략
cd my-claude-skills
./install.sh
```

[설치 스크립트](install.sh)는 다음을 적용합니다.

- 스킬을 `~/.claude/skills/`에 심볼릭 링크로 연결합니다. **같은 이름의 기존 항목은 삭제하고 교체합니다.**
- 전역 `SessionStart` 훅으로 `repo-health`를 등록합니다. 저장소 정리 대상과 설정 불일치를 검사합니다.
- [팀 운영 정책](policies/team-policy.md)을 `~/.claude/CLAUDE.md`의 관리 블록에 넣습니다. 하위 에이전트 모델을 Haiku로 고정합니다. 커밋·PR의 Claude 서명을 끕니다.
- `agent-browser`와 전용 Chrome, Codex CLI를 설치합니다. 지원 환경에서는 Lightpanda도 설치합니다.
- API 키를 `~/.config/my-claude-skills/secrets.env`에 권한 600으로 저장합니다.

바꾸는 전역 설정 파일은 수정 직전 상태를 `.bak`으로 남깁니다(실행할 때마다 덮어씀). CLI 설치가 실패해도 나머지는 계속합니다. 링크 방식이라 설치 후에도 저장소를 지우면 안 되고, 스킬을 추가하면 설치를 다시 실행합니다.

팀 운영 정책을 지우려면 저장소 루트에서 실행합니다. 설치 전에 있던 설정값을 복원하지는 않습니다.

```sh
python3 scripts/team-policy.py --remove ~/.claude/settings.json ~/.claude/CLAUDE.md
```

### API 키

`gemini-rewrite`에는 `jq`가 필요합니다. 기본 호출에는 `GEMINI_API_KEY`를 쓰고, `AI_GATEWAY_API_KEY`는 402·429 응답 때 대체 호출용으로 선택 사항입니다. `GEMINI_PROVIDER=gateway`로 실행하면 `AI_GATEWAY_API_KEY`만 필요합니다.
키는 [환경변수 예제](.env.example)를 복사해 입력합니다. 호출 경로는 [한국어 문장 다듬기 안내](skills/gemini-rewrite/SKILL.md)를 따릅니다.

```sh
cp .env.example .env
# .env에 키를 채운 뒤 실행합니다.
./install.sh
```

저장할 키는 `.env` → 기존 저장값 → 셸 환경변수 → 터미널 입력 순으로 정합니다.
터미널 입력은 Enter로 건너뜁니다. 비대화형 실행에서는 묻지 않고 건너뜁니다.
`.env`는 Git에서 제외합니다. 값을 바꾸면 설치를 다시 실행합니다. `.env` 없이 키를 바꾸려면 `~/.config/my-claude-skills/secrets.env`에서 해당 줄을 지우고 다시 실행합니다(저장된 값이 셸 환경변수보다 먼저입니다).
스킬 실행 시에는 환경변수가 저장 파일보다 우선합니다.

### Codex 로그인

Codex CLI는 npm이나 Homebrew로 설치합니다. 둘 다 없으면 nvm으로 Node.js LTS부터 설치합니다.
터미널에서 설치하면 필요한 로그인도 진행합니다. 직접 로그인할 때는 아래 방법 중 하나를 선택합니다.

```sh
codex login                                          # ChatGPT 계정
codex login --device-auth                            # 브라우저 없는 서버
printenv OPENAI_API_KEY | codex login --with-api-key  # API 키를 표준입력으로 전달
```

자세한 준비 절차는 [Codex 사용 안내](skills/codex/SKILL.md)를 따릅니다.

## 사용법

설치 후 새 Claude Code 세션에서 작업을 요청합니다.

```text
저장소 건강검진해줘
```

`repo-health`가 저장소 정리 대상과 설정 불일치를 확인합니다.

배포 상태 확인의 전제조건은 [배포 상태 안내](skills/deploy-status/SKILL.md)를 따릅니다.
[릴리스 점검 훅](skills/release-guard/SKILL.md)은 프로젝트마다 따로 설치합니다.

## 구성 목록

### 소프트웨어 개발

| 스킬 | 용도 |
| --- | --- |
| [`api-contract-guard`](skills/api-contract-guard/SKILL.md) | OpenAPI·Swagger 변경의 하위 호환성 점검 |
| [`change-impact`](skills/change-impact/SKILL.md) | 변경 영향 범위·테스트 누락·SQL 마이그레이션 위험 점검 |
| [`commit-and-push`](skills/commit-and-push/SKILL.md) | 변경 검증과 커밋, 사용자 확인 후 푸시 |
| [`dependency-guard`](skills/dependency-guard/SKILL.md) | 의존성 잠금 파일 변경의 안전성 점검 |
| [`deploy-status`](skills/deploy-status/SKILL.md) | GitHub Actions 배포 상태 확인·실패 진단·장애 회고 작성 |
| [`release-guard`](skills/release-guard/SKILL.md) | 릴리스·버전 태그 준비와 태그 푸시 전 점검 |
| [`repo-health`](skills/repo-health/SKILL.md) | 저장소 정리 대상과 환경·CI 설정 불일치 점검 |

### 그 외

| 스킬 | 용도 |
| --- | --- |
| [`agent-browser`](skills/agent-browser/SKILL.md) | 실제 브라우저로 웹 탐색·조작·화면 확인 |
| [`codex`](skills/codex/SKILL.md) | Codex 의견 요청·교차 검증·리뷰·문서 초안 작성 |
| [`gemini-rewrite`](skills/gemini-rewrite/SKILL.md) | 의미를 유지하며 한국어 문장 다듬기 |
| [`readme-writer`](skills/readme-writer/SKILL.md) | README 작성·축약·양식 정리 |

## 스킬 수정 후 확인

저장소에서 스킬을 고친 뒤 구성 검사 도구를 실행합니다.

```sh
bash scripts/skill-lint.sh
```

새 Claude Code 세션에서 해당 스킬의 `description`에 맞는 요청으로 호출과 동작을 확인합니다.

## 라이선스

LICENSE 파일이 없어 라이선스 확인이 필요합니다.
