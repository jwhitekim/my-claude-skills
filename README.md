# my-claude-skills

저장소 점검, 변경 검증, 문서 작성과 브라우저 작업에 쓰는 개인용 Claude Code 스킬 12개와 전역 훅·운영 정책을 관리하고 설치하는 저장소입니다.

## 시작하기

Git, Bash, Python 3, curl과 사용 가능한 Claude Code가 필요합니다.

```sh
git clone https://github.com/jwhitekim/my-claude-skills
cd my-claude-skills
./install.sh
```

설치 후 점검할 저장소에서 새 Claude Code 세션을 열고 요청합니다.

```text
저장소 건강검진해줘
```

`repo-health`가 저장소 정리 대상과 설정 불일치를 확인합니다.

## 구성 목록

각 스킬의 상세 사용법과 준비 조건은 연결된 문서에서 확인합니다.

### 소프트웨어 개발

| 스킬 | 용도 |
| --- | --- |
| [`api-contract-guard`](skills/dev/api-contract-guard/SKILL.md) | OpenAPI·Swagger 변경의 하위 호환성 점검 |
| [`change-impact`](skills/dev/change-impact/SKILL.md) | 변경 영향 범위·테스트 누락·SQL 마이그레이션 위험 점검 |
| [`commit-and-push`](skills/dev/commit-and-push/SKILL.md) | 변경 검증과 커밋, 사용자 확인 후 푸시 |
| [`dependency-guard`](skills/dev/dependency-guard/SKILL.md) | 의존성 잠금 파일 변경의 안전성 점검 |
| [`deploy-status`](skills/dev/deploy-status/SKILL.md) | GitHub Actions 배포 상태 확인·실패 진단·장애 회고 작성 |
| [`release-guard`](skills/dev/release-guard/SKILL.md) | 릴리스·버전 태그 준비와 태그 푸시 전 점검 |
| [`repo-health`](skills/dev/repo-health/SKILL.md) | 저장소 정리 대상과 환경·CI 설정 불일치 점검 |
| [`spec-docs`](skills/dev/spec-docs/SKILL.md) | SDD 문서 구조 초기 세팅·요구사항과 작업 작성 형식·문서 배치 점검 |

### 그 외

| 스킬 | 용도 |
| --- | --- |
| [`agent-browser`](skills/general/agent-browser/SKILL.md) | 실제 브라우저로 웹 탐색·조작·화면 확인 |
| [`codex`](skills/general/codex/SKILL.md) | Codex 의견 요청·교차 검증·리뷰·문서 초안 작성 |
| [`gemini-rewrite`](skills/general/gemini-rewrite/SKILL.md) | 의미를 유지하며 한국어 문장 다듬기 |
| [`readme-writer`](skills/general/readme-writer/SKILL.md) | README 작성·축약·양식 정리 |

전역으로 적용하는 작업 분담 기준은 [팀 운영 정책](policies/team-policy.md)을 참고합니다.

## 라이선스

LICENSE 파일이 없어 라이선스 확인이 필요합니다.
