---
name: change-impact
description: "Use when asked what a change affects — \"이 변경이 뭘 건드리는지 봐줘\", \"영향 범위 확인해줘\", \"change-impact 돌려줘\" — or when you want the relevant guard checks on a staged diff or the last commit without naming each guard."
---

# change-impact

가드 스킬들을 묶는 오케스트레이터. 사용자가 가드 이름을 일일이 기억하지 않아도 되게
한다. 직접 판단하는 건 없고, diff 경로로 분류해서 해당 가드 스크립트를 부를 뿐이다.

## 실행

```bash
bash ~/.claude/skills/change-impact/scripts/impact.sh          # staged 기준 (기본)
bash ~/.claude/skills/change-impact/scripts/impact.sh last     # 마지막 커밋 기준
```

저장소 하위 폴더에서 불러도 루트 기준으로 돈다. staged 변경이 없으면 `git add` 하거나
`last`를 쓰라고 안내만 하고 끝난다.

## 분류와 호출 대상

| 영향 범위 | 판단 기준(변경 경로) | 호출하는 가드 |
|---|---|---|
| 소스 | `.py/.js/.jsx/.ts/.tsx/.go/.rb/.java` | `test-gap-finder` — 대응 테스트 파일 없음 |
| 의존성 | `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` | `dependency-guard` — 버전 변경, major 업그레이드 |
| API 스펙 | 파일명에 `openapi`/`swagger`가 든 `.yaml/.yml/.json` | `api-contract-guard` — breaking change |
| DB 마이그레이션 | `*/migrations/*.sql` | `migration-guard` — destructive/lock 위험, 기존 파일 수정 |
| 문서 스펙 | `specs/<capability>/spec.md` | `docs-compliance`의 `check-spec.sh` — Requirement/Scenario 형식 |
| 설정/CI | `.env*`, `.github/workflows/*` | `config-drift-guard` — `.env` 키·CI 버전 핀 불일치 (현재 상태 전체 비교) |

CI 워크플로가 바뀌었으면 푸시 후 `deploy-status`로 배포 결과를 확인하라고 한 줄 덧붙인다.

각 가드는 문제가 없으면 아무것도 출력하지 않으므로, 결과에는 실제로 걸린 항목만 남는다.

## 결과를 보여줄 때

1. 첫 줄의 영향 범위 요약을 그대로 보여준다.
2. 가드별로 걸린 항목이 있으면 섹션별로 정리한다. 없으면 "걸린 항목 없음"으로 끝낸다.
3. 후속 조치는 각 가드 스킬의 "처리할 때" 지침을 따른다 — 예: 테스트 누락이면
   `test-gap-finder` 지침대로 테스트 작성 여부를 묻고, major 업그레이드면
   `dependency-guard`의 라이선스 확인을 제안한다.

## 하지 않는 것

- **커밋·푸시를 막거나 대신하지 않는다.** `commit-and-push`와 연결되어 있지 않다 — 필요할
  때 따로 부르는 도구다.
- **세션 시작 훅을 설치하지 않는다.** `repo-health`, `config-drift-guard`, `watch-rules`의
  자동 감지는 각자 설치한다.
- **`release-guard`는 부르지 않는다.** 태그 푸시 시점의 pre-push 훅이라 diff 분석과는 시점이
  다르다.
