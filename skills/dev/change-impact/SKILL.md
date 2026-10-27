---
name: change-impact
description: "Use when asked to review the overall impact of staged changes or the last commit, check whether changed code lacks tests or covers new behavior, or inspect SQL migrations for destructive changes, lock risks, or edits to existing migrations."
---

# change-impact

변경 영향 범위를 분류하고 관련 검사를 실행한다. 테스트 누락 확인과 마이그레이션 위험
확인은 이 스킬에 포함되어 있으며, 각각 단독으로 실행할 수도 있다. 의존성·API·설정은
해당 외부 스킬의 스크립트를 호출한다. 스크립트는 후보와 위험 신호를 찾고, Claude는
diff와 기존 테스트를 읽어 실제 테스트 필요성과 커버 여부를 판단한다.

예시 요청: "이 변경이 뭘 건드리는지 봐줘", "영향 범위 확인해줘", "change-impact 돌려줘",
"테스트 누락 확인해줘", "이 변경 테스트 커버 되나 봐줘", "마이그레이션 파일 위험한 거 없나 봐줘".

## 실행

```bash
bash ~/.claude/skills/change-impact/scripts/impact.sh          # staged 기준 (기본)
bash ~/.claude/skills/change-impact/scripts/impact.sh staged   # staged 명시
bash ~/.claude/skills/change-impact/scripts/impact.sh last     # 마지막 커밋 기준
```

저장소 하위 폴더에서 불러도 루트 기준으로 돈다. staged 변경이 없으면 `git add` 하거나
`last`를 쓰라고 안내만 하고 끝난다.
삭제된 경로도 분류에 포함해 해당 가드를 호출한다. 실제 삭제 검사는 각 가드의 지원 범위에
따른다.

## 분류와 호출 대상

| 영향 범위 | 판단 기준(변경 경로) | 호출하는 가드 |
|---|---|---|
| 소스 | `.py/.js/.jsx/.ts/.tsx/.go/.rb/.java` | 내장 테스트 누락 검사 — 대응 테스트 파일 존재 여부 |
| 의존성 | `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` | `dependency-guard` — 버전 변경, major 업그레이드 |
| API 스펙 | 파일명에 `openapi`/`swagger`가 든 `.yaml/.yml/.json` | `api-contract-guard` — breaking change |
| DB 마이그레이션 | `*/migrations/*.sql` | 내장 마이그레이션 검사 — destructive/lock 위험, 기존 파일 수정 |
| 설정/CI | `.env*`, `.github/workflows/*` | `repo-health/scripts/drift/scan.sh detail` — `.env` 키·CI 버전 핀 불일치 (현재 상태 전체 비교) |

CI 워크플로가 바뀌었으면 푸시 후 `deploy-status`로 배포 결과를 확인하라고 한 줄 덧붙인다.

테스트 검사는 대응 테스트 파일이 있어도 경로와 "커버 여부 미검증"을 출력한다.
나머지 검사는 각 스크립트가 출력한 경고·정보를 보여준다.
하위 가드가 non-zero로 끝나도 나머지 검사를 계속하고, 끝에 `실패한 가드: ...`와 종료 코드를
모아 출력한 뒤 1로 끝난다. 모두 0이면 0으로 끝난다. 가드별 종료 코드에 문제 발견/실행 오류의
공통 구분 규약이 없어 non-zero는 모두 실패로 취급한다. 경고를 출력하고 0으로 끝내는 가드는
실패 요약에 포함하지 않는다.

## 테스트 누락 확인

테스트 관련 요청만 받으면 이 검사만 실행한다.

```bash
bash ~/.claude/skills/change-impact/scripts/test-gap/find-gaps.sh staged
bash ~/.claude/skills/change-impact/scripts/test-gap/find-gaps.sh last
```

[test-gap.md](test-gap.md)를 읽고 `[change-impact:test-gap]` 표지의 후보 목록을 받은 뒤 diff를 직접 검토한다.
파일 존재 여부와 실제 커버 여부를 구분하고, 테스트 작성이 요청되면 기존 테스트 스타일을
참고해 정상·분기·엣지케이스를 작성한 뒤 실제로 실행해 통과를 확인한다.

## 마이그레이션 위험 확인

마이그레이션 관련 요청만 받으면 이 검사만 실행한다.

```bash
bash ~/.claude/skills/change-impact/scripts/migration/check.sh staged
bash ~/.claude/skills/change-impact/scripts/migration/check.sh last
```

[migration.md](migration.md)의 위험 패턴과 휴리스틱 한계를 읽고 `[change-impact:migration]` 표지의 결과를 해석한다.
새 SQL의 destructive/lock 패턴과 기존 마이그레이션 수정을 알리며, 최종 판단은 사용자에게
맡긴다. DB 실행·롤백이나 스키마와 애플리케이션 코드의 정합성 검사는 수행하지 않는다.

## 결과를 보여줄 때

1. 첫 줄의 영향 범위 요약을 그대로 보여준다.
2. 가드별로 걸린 항목이 있으면 섹션별로 정리한다. 없으면 "걸린 항목 없음"으로 끝낸다.
3. 후속 조치는 위 하위 검사 문서와 외부 가드 스킬의 지침을 따른다 — 예: 테스트 누락이면
   [test-gap.md](test-gap.md)에 따라 diff를 검토하고, 테스트 작성 요청이 없으면 작성 여부를 묻는다.
   major 업그레이드면
   `dependency-guard`의 라이선스 확인을 제안한다.

## 하지 않는 것

- **커밋·푸시를 막거나 대신하지 않는다.** `commit-and-push`와 연결되어 있지 않다 — 필요할
  때 따로 부르는 도구다.
- **세션 시작 훅을 설치하지 않는다.** 저장소·설정 자동 감지는 `repo-health`가 담당한다.
- **`release-guard`는 부르지 않는다.** 태그 푸시 시점의 pre-push 훅이라 diff 분석과는 시점이
  다르다.
