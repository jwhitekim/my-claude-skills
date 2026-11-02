# my-claude-skills

저장소 점검, 변경 검증, 문서 작성과 브라우저 작업에 쓰는 개인용 Claude Code 플러그인 `jw`입니다. 스킬 16개와 자동 점검 훅·운영 정책을 제공합니다.

## 시작하기

Git, Bash, Python 3, curl과 사용 가능한 Claude Code가 필요합니다.

Claude Code에서 사용자 범위로 설치한 뒤 마무리 설정을 실행합니다.

```text
/plugin marketplace add jwhitekim/my-claude-skills
/plugin install jw@jwhitekim-tools
/jw:setup
```

`/jw:setup`은 팀 정책 적용, agent-browser·Codex CLI 설치, API 키 등록을 돕습니다. 팀 정책은 모든 프로젝트에 적용되는 모델·서명 설정과 운영 규칙을 바꿉니다. 설정 후 Claude Code를 다시 시작합니다.

API 키 입력과 codex 로그인까지 터미널에서 한 번에 하려면 레포를 받아 직접 실행합니다.

```sh
git clone https://github.com/jwhitekim/my-claude-skills
bash my-claude-skills/scripts/setup.sh
```

예전 `install.sh`(심볼릭 링크 방식)로 설치했다면 `/jw:setup`에 예전 설치 정리를 요청합니다. `~/.claude/skills` 링크와 옛 전역 훅을 지웁니다. 프로젝트에 남은 예전 훅 정리는 [setup 안내](skills/setup/SKILL.md#프로젝트에-남은-예전-껍데기)를 참고합니다.

스킬은 `/jw:repo-health`처럼 `/jw:<이름>`으로 호출합니다. “저장소 건강검진해줘” 같은 자연어 요청으로도 자동 호출됩니다.

## 자동 점검

| 시점 | 하는 일 |
| --- | --- |
| 세션 시작 | 모든 프로젝트에서 repo-health가 저장소 정리 후보와 환경·CI 설정 불일치를 점검 |
| 새 세션 시작 | 팀 정책·CLI·필수 API 키·예전 설치의 준비 상태 알림. `JW_SKIP_SETUP_CHECK=1`로 알림 끄기 |
| Claude Code에서 push 직후 | 프로젝트에 `.claude/deploy-status.enabled`가 있을 때만 배포 상태 확인 |

세션 시작 훅은 상태만 확인합니다. 설정 변경과 CLI 설치는 `/jw:setup`에서 진행합니다. 배포 자동 확인은 [deploy-status](skills/deploy-status/SKILL.md#자동-확인-켜기)에서 프로젝트마다 켭니다.

## API 키

키는 `~/.config/my-claude-skills/secrets.env`에 권한 `600`으로 저장합니다. 스킬은 환경변수를 먼저 보고, 없으면 이 파일에서 읽습니다.

이 파일에 `KEY=값` 줄을 직접 넣거나, [.env.example](.env.example) 형식으로 채운 `.env`의 경로를 `/jw:setup`에 알려 주면 가져옵니다. Claude Code 안에서는 키를 대화형으로 입력받지 않습니다.

## 구성 목록

각 스킬의 상세 사용법과 준비 조건은 연결된 문서에서 확인합니다.

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
| [`spec-docs`](skills/spec-docs/SKILL.md) | SDD 문서 구조 초기 세팅·요구사항과 작업 작성 형식·문서 배치 점검 |

### 그 외

| 스킬 | 용도 |
| --- | --- |
| [`setup`](skills/setup/SKILL.md) | `/jw:setup`으로 팀 정책·CLI·API 키 준비와 예전 설치 정리 |
| [`agent-browser`](skills/agent-browser/SKILL.md) | 실제 브라우저로 웹 탐색·조작·화면 확인 |
| [`codex`](skills/codex/SKILL.md) | Codex 의견 요청·교차 검증·리뷰·문서 초안 작성 |
| [`gemini-rewrite`](skills/gemini-rewrite/SKILL.md) | 의미를 유지하며 한국어 문장 다듬기 |
| [`naver-search`](skills/naver-search/SKILL.md) | 네이버 블로그·뉴스·카페·지식iN·웹문서 검색 |
| [`paper-search`](skills/paper-search/SKILL.md) | 논문 검색, 오픈 액세스 원문 내려받기, GitHub 구현·Hugging Face 모델 찾기 |
| [`readme-writer`](skills/readme-writer/SKILL.md) | README 작성·축약·양식 정리 |
| [`seminar-slides`](skills/seminar-slides/SKILL.md) | 연구실 세미나 슬라이드를 마크다운 명세로 쓰고 템플릿 pptx로 만들기 |

전역으로 적용하는 작업 분담 기준은 [팀 운영 정책](team-policy.md)을 참고합니다.

## 업데이트

[plugin.json](.claude-plugin/plugin.json)에 `version`을 두지 않아 Git 커밋 SHA를 버전으로 사용합니다. 새 커밋은 업데이트 시 새 버전으로 구분됩니다. [공식 버전 규칙](https://code.claude.com/docs/en/plugins/publish#prepare-your-plugin-for-release)

Claude Code에서 마켓플레이스 목록을 갱신합니다.

```text
/plugin marketplace update jwhitekim-tools
```

설치된 `jw`는 `/plugin`의 Installed 탭에서 Update now로 갱신할 수 있습니다. 자동 업데이트는 Marketplaces 탭에서 `jwhitekim-tools`의 Enable auto-update를 켭니다. 업데이트 후 새 세션을 열거나 `/reload-plugins`로 반영합니다. [공식 업데이트 안내](https://code.claude.com/docs/en/discover-plugins#keep-plugins-updated)

## 팀 정책 되돌리기

`/jw:setup`에 팀 정책 되돌리기를 요청하거나, 레포 루트에서 실행합니다. 팀 정책 블록을 제거하고 모델·서명 설정을 되돌립니다.

```sh
python3 scripts/team-policy.py --remove ~/.claude/settings.json ~/.claude/CLAUDE.md
```

처음 적용 전 값이 기록돼 있으면 복원하고, 기록이 없으면 적용값과 같은 키만 지웁니다.

