# my-claude-skills

개인용 Claude Code 스킬 모음. 버전관리는 이 레포에서 하고, 실제 사용은 symlink로 `~/.claude/skills/`에 연결해서 씁니다.

## 설치

```bash
./install.sh
```

`skills/` 아래의 각 폴더를 `~/.claude/skills/`에 symlink로 연결합니다. 레포 파일을 고치면 바로 반영되고, 새 스킬을 `skills/`에 추가한 뒤 다시 실행하면 그것도 자동으로 링크됩니다.

다른 머신에서 처음 세팅할 때:

```bash
git clone <repo-url> ~/CODINGPROJECT/my-claude-skills
~/CODINGPROJECT/my-claude-skills/install.sh
```

### 전역 훅

`install.sh`는 세션 시작 점검 3개(`repo-health`, `watch-rules`, `config-drift-guard`)를 `~/.claude/settings.json`의 `SessionStart`에 등록합니다. 그래서 프로젝트마다 따로 깔지 않아도 모든 프로젝트에서 돕니다. 다시 실행해도 중복으로 쌓이지 않고, 기존 설정은 `settings.json.bak`에 남습니다. 프로젝트에 같은 스킬의 훅이 이미 깔려 있으면 전역 훅은 건너뜁니다.

### 팀장·직원 운영 방식

`install.sh`는 메인 Claude(팀장)가 추론·판단을 맡고 잡일은 하위 에이전트(직원)에게 맡기는 방식을 전역 설정에 적용합니다(`scripts/team-policy.py`).

- `~/.claude/settings.json`의 `env`에 `CLAUDE_CODE_SUBAGENT_MODEL=haiku`, `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`을 넣어 직원 모델을 항상 Haiku로 고정합니다. FORCE가 켜지면 Agent 도구의 `model` 옵션과 에이전트 정의의 모델 지정이 무시됩니다.
- 같은 파일에 `"attribution": {"commit": "", "pr": ""}`를 넣어 커밋·PR에 Claude 서명(`Co-Authored-By` 등)을 붙이지 않습니다.
- `policies/team-policy.md`의 역할 분담 규칙을 `~/.claude/CLAUDE.md`에 표시선 블록으로 넣습니다. 블록 밖 내용은 그대로 두고, 다시 실행하면 블록만 갱신합니다.
- 바꾸기 전 파일은 `.bak`으로 남깁니다. 되돌리려면 `python3 scripts/team-policy.py --remove ~/.claude/settings.json ~/.claude/CLAUDE.md`를 실행하세요.
- 새 Claude Code 세션부터 적용됩니다.

### Codex

`codex` 스킬은 Codex CLI와 로그인이 필요합니다. `install.sh`가 CLI를 설치하고(npm이 없고 Homebrew가 있으면 Homebrew로, 둘 다 없으면 nvm으로 Node.js부터), 터미널에서 실행하면 로그인까지 진행합니다. 로그인은 개인 ChatGPT 계정(`codex login`, 브라우저 없는 서버는 `codex login --device-auth`)이나 OpenAI API 키(`codex login --with-api-key`) 중 하나로 합니다.

### API 키

`jev-eval`(`AI_GATEWAY_API_KEY`)과 `gemini-rewrite`(`GEMINI_API_KEY`)는 API 키가 필요합니다. `install.sh`가 키를 `~/.config/my-claude-skills/secrets.env`(권한 600, 레포 밖)에 저장하고, 스크립트들은 환경변수가 없으면 이 파일에서 읽습니다.

키를 넣는 방법은 세 가지이고, 위에 있는 것이 우선합니다.

1. 레포 루트 `.env`: `cp .env.example .env`로 복사해 값을 채운 뒤 `./install.sh`를 실행합니다. 저장된 값과 다르면 새 값으로 바꿉니다. `.env`는 git에 올라가지 않습니다.
2. 지금 셸의 환경변수: 아직 저장된 키가 없을 때 그 값을 저장합니다.
3. 직접 입력: 둘 다 없으면 터미널에서 입력받습니다. 건너뛰었다면 나중에 `./install.sh`를 다시 실행하면 됩니다.

`.env`를 쓰지 않을 때 키를 바꾸려면 secrets 파일에서 해당 줄을 지우고 다시 실행하세요.

`jev-eval`은 직접 구매한 AI Gateway 크레딧이 있어야 동작합니다(무료 플랜 월 $5 크레딧으로는 사용 불가).

## 테스트 방법

1. 레포에서 스킬 수정 (symlink라 `~/.claude/skills/`에 즉시 반영됨)
2. 새 Claude Code 세션을 연다 (같은 세션은 스킬 목록이 캐시돼 있어 변경이 안 잡힐 수 있음)
3. 해당 스킬의 description에 맞는 요청을 실제로 던져서 의도대로 호출/동작하는지 확인
4. 문제 있으면 수정 → 새 세션에서 재확인 반복

## 스킬 목록

| 스킬 | 설명 |
|---|---|
| `agent-browser` | 크롬 확장 대신 Vercel `agent-browser` CLI로 웹 페이지 열기·클릭·입력·스크린샷. Linux·Mac·Windows 공통, 로그인 상태는 전용 프로필에 유지. 로그인 없는 읽기는 가벼운 lightpanda, 나머지는 Chrome. `install.sh`가 CLI·전용 Chrome·lightpanda를 설치. |
| `api-contract-guard` | OpenAPI/Swagger 스펙 변경에서 엔드포인트 삭제·필드 required화·타입 변경 같은 breaking change 감지. change-impact가 호출. |
| `change-impact` | diff를 소스/의존성/API 스펙/마이그레이션/문서 스펙/설정·CI로 분류하고 해당하는 가드만 골라 실행. 가드들을 한 번에 부르는 진입점. |
| `codex` | Codex CLI를 불러 의견을 주고받고(세션 이어 묻기), 교차검증·문서 검증·프로젝트 리뷰를 맡기고, CLAUDE.md 같은 규칙 문서를 쓰게 함. 기본은 읽기 전용. `install.sh`가 CLI를 설치(Node 없으면 nvm부터). |
| `commit-and-push` | 코드 변경을 커밋하고 원격에 푸시할 때 사용. 커밋 전 빌드/린트/테스트 검증, 푸시는 사람 확인 후에만. |
| `config-drift-guard` | `.env*` 파일 간 키 불일치(값은 안 봄)와 CI 워크플로 간 Node/Python 버전 핀 불일치를 세션 시작 시 자동 점검. |
| `dependency-guard` | lockfile 변경 시 패키지 버전 변경 요약, major 업그레이드 강조, npm 라이선스 위험 확인. change-impact가 호출. |
| `deploy-status` | 푸시 후 GitHub Actions 배포가 정상적으로 끝났는지 확인하고, 실패 시 로그를 읽고 원인을 진단. |
| `docs-compliance` | `specs/<capability>/spec.md`의 Requirement/Scenario 작성이나 `tasks.md` 항목 추가, 기존 `docs/` 구조 감사 시 사용. |
| `docs-init` | 프로젝트에 spec/design 문서가 아직 없을 때 `docs/` 구조(contract/proposal/design/tasks)를 처음 세팅. |
| `gemini-rewrite` | Claude가 쓴 한국어 문장이 번역투이거나 어색할 때 의미/정보는 유지하고 구조는 더 명확하게 재구성. |
| `incident-review` | 장애 시각 전후 커밋·GitHub Actions 실행·실패 로그를 모아 타임라인/원인 분석/액션 아이템으로 정리한 회고 문서를 `docs/incidents/`에 작성. |
| `jev-eval` | 위험한 툴 호출 승인, 여러 옵션 중 라우팅 결정, 항목 우선순위/점수 매기기 등 빠른 구조적 판단이 필요할 때. |
| `migration-guard` | `*/migrations/*.sql` 변경에서 destructive/lock 위험 패턴과 기존 마이그레이션 수정을 감지. change-impact가 호출. |
| `prompt-regression` | 프롬프트 수정 전 출력을 기준선으로 저장하고, 수정 후 같은 입력으로 돌려 jev-eval 채점으로 회귀를 찾음. 애매한 케이스는 Claude가 직접 판정. |
| `readme-writer` | 개발자 표준 양식(standard-readme, Make a README, GitHub Docs, Google 가이드)의 공통 뼈대로 README를 새로 쓰거나 간단하게 줄임. 명령·경로는 저장소에서 확인한 것만 쓰고, 유형별 뼈대 4종(`templates.md`) 제공. |
| `release-guard` | git tag push 시에만 동작하는 pre-push 훅. 버전/CHANGELOG/working tree를 확인하고 실패하면 푸시 차단. 버전 올리기+태그 생성 스크립트도 제공. |
| `repo-health` | 오래된 TODO, 참조 없는 함수 후보, 큰 파일, git에 잘못 추적된 흔적 파일을 세션 시작 시 자동 점검. |
| `skill-lint` | 이 레포의 `skills/*/` 구성(SKILL.md, 경로 참조, 실행 권한, README 등재)을 검사하는 메타 스킬. |
| `test-gap-finder` | 변경된 코드에 대응하는 테스트 파일이 없는지 확인하고(사소한 변경은 jev로 자동 제외), 없으면 테스트 케이스를 제안·작성. change-impact가 호출. |
| `todo-guard` | TODO.md 기반 작업 추적과 Stop hook 검증으로 지시를 드랍하지 않게 함. |
| `trim-rules` | CLAUDE.md나 `.claude/rules/*.md`가 너무 길어졌을 때(200줄 안팎 초과) 정리. |
| `watch-rules` | 규칙 파일이 길어지는 걸 세션 시작 시 자동 감지하는 훅을 설치. |
