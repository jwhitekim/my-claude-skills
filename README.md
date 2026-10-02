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

### API 키

`jev-eval`(`AI_GATEWAY_API_KEY`)과 `gemini-rewrite`(`GEMINI_API_KEY`)는 API 키가 필요합니다. `install.sh`가 키가 없으면 입력받아 `~/.config/my-claude-skills/secrets.env`(권한 600, 레포 밖)에 저장하고, 스크립트들은 환경변수가 없으면 이 파일에서 읽습니다. 지금 셸에 환경변수로 키가 있으면 그 값을 그대로 저장합니다. 입력을 건너뛰었다면 나중에 `./install.sh`를 다시 실행하면 됩니다. 키를 바꾸려면 파일에서 해당 줄을 지우고 다시 실행하세요.

`jev-eval`은 직접 구매한 AI Gateway 크레딧이 있어야 동작합니다(무료 플랜 월 $5 크레딧으로는 사용 불가).

## 테스트 방법

1. 레포에서 스킬 수정 (symlink라 `~/.claude/skills/`에 즉시 반영됨)
2. 새 Claude Code 세션을 연다 (같은 세션은 스킬 목록이 캐시돼 있어 변경이 안 잡힐 수 있음)
3. 해당 스킬의 description에 맞는 요청을 실제로 던져서 의도대로 호출/동작하는지 확인
4. 문제 있으면 수정 → 새 세션에서 재확인 반복

## 스킬 목록

| 스킬 | 설명 |
|---|---|
| `api-contract-guard` | OpenAPI/Swagger 스펙 변경에서 엔드포인트 삭제·필드 required화·타입 변경 같은 breaking change 감지. change-impact가 호출. |
| `change-impact` | diff를 소스/의존성/API 스펙/마이그레이션/문서 스펙/설정·CI로 분류하고 해당하는 가드만 골라 실행. 가드들을 한 번에 부르는 진입점. |
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
| `release-guard` | git tag push 시에만 동작하는 pre-push 훅. 버전/CHANGELOG/working tree를 확인하고 실패하면 푸시 차단. 버전 올리기+태그 생성 스크립트도 제공. |
| `repo-health` | 오래된 TODO, 참조 없는 함수 후보, 큰 파일, git에 잘못 추적된 흔적 파일을 세션 시작 시 자동 점검. |
| `skill-lint` | 이 레포의 `skills/*/` 구성(SKILL.md, 경로 참조, 실행 권한, README 등재)을 검사하는 메타 스킬. |
| `test-gap-finder` | 변경된 코드에 대응하는 테스트 파일이 없는지 확인하고(사소한 변경은 jev로 자동 제외), 없으면 테스트 케이스를 제안·작성. change-impact가 호출. |
| `todo-guard` | TODO.md 기반 작업 추적과 Stop hook 검증으로 지시를 드랍하지 않게 함. |
| `trim-rules` | CLAUDE.md나 `.claude/rules/*.md`가 너무 길어졌을 때(200줄 안팎 초과) 정리. |
| `watch-rules` | 규칙 파일이 길어지는 걸 세션 시작 시 자동 감지하는 훅을 설치. |
