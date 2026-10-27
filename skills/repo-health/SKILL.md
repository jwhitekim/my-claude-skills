---
name: repo-health
description: "Use when asked to check a repository for accumulated clutter or configuration drift across .env* files and GitHub Actions workflows — \"저장소 건강검진해줘\", \"이 프로젝트 정리할 거 없나 봐줘\", \"환경 설정 어긋나는 거 없나 봐줘\", \".env 파일들 키 맞는지 확인해줘\" — or to install repo-health in a project (\"repo-health 깔아줘\")."
---

# repo-health

세션 시작 시 저장소 정리 후보와 환경 설정 drift를 함께 검사해 기계적으로 알린다.
문제를 자동으로 고치지 않는다. 알리기만 한다.

## 설치

```bash
cd <대상 프로젝트 루트>
bash ~/.claude/skills/repo-health/scripts/setup.sh
```

- `.claude/hooks/repo-health.sh` 껍데기를 깐다 (본체는 `scripts/scan.sh` 한 벌 —
  저장소 정리 검사와 `scripts/drift/scan.sh`를 함께 실행하며, 고치면 설치된 모든
  프로젝트에 바로 적용된다).
- `.claude/settings.json`의 `hooks.SessionStart` 배열에 repo-health 훅 하나만
  추가/갱신한다. 기존 config-drift-guard 훅 등록과
  `.claude/hooks/config-drift-guard.sh` 파일은 제거한다. 다른 훅과 설정은 보존한다.
- 세션을 재시작(`/exit` 후 재진입)해야 적용된다.
- git 저장소가 아니면 저장소 정리 검사는 건너뛴다. drift 검사는 현재 디렉터리의
  `.env*`와 `.github/workflows/`를 기준으로 실행한다.

## 검사 항목

| 스크립트 | 하는 일 | 한계 |
|---|---|---|
| `stale-todo.sh` | `TODO`/`FIXME` 주석 중 `git blame` 기준 90일(기본) 이상 안 건드려진 것 | git 이력 기반이라 날짜 조작된 커밋엔 못 속아 넘어가지 않음(=속음) |
| `big-files.sh` | 추적 중인 파일 중 800줄(기본) 넘는 것 | 바이너리는 제외 |
| `tracked-junk.sh` | `.DS_Store`, `*.log`, `node_modules/`, `__pycache__/`, `.env` 등이 git에 추적되고 있는지 | `.gitignore`를 대신 고쳐주지 않음, 발견만 함 |
| `dead-symbols.sh` | `function`/`def`/`func`/`fn` 키워드로 정의된 함수 중 저장소 전체에서 참조가 정의 한 줄뿐인 것 | **grep 기반 휴리스틱** — AST 아님. 리플렉션, 문자열로 조립한 호출, 외부 export, 템플릿 안 참조는 못 잡음. 오탐 가능성이 있으므로 **절대 자동으로 지우지 않는다** — 사람이 하나씩 확인 |
| `drift/env-keys.sh` | `.env*` 파일들의 **키 집합만** 비교 (`.env.example` 기준, 없으면 사전순 첫 파일) | 키 이름이 같은데 의미가 다른 경우는 못 잡음 |
| `drift/ci-versions.sh` | `.github/workflows/*.yml` 및 `*.yaml` 사이에서 `node-version`/`python-version` 핀이 서로 다른지 | 워크플로가 2개 미만이면 건너뜀. matrix 버전 전략은 의도된 것일 수 있어 먼저 확인 |

파일 수가 3000개를 넘는 저장소는 `dead-symbols.sh` 검사를 건너뛴다(시간이 너무 오래 걸림).

**비밀값은 다루지 않는다.** `drift/env-keys.sh`는 `KEY=` 패턴에서 키만 추출해
비교한다. 환경변수 값은 출력하지 않는다.

## 출력

세션 시작 시에는 요약만 한 줄~몇 줄로 보여준다:

```
[repo-health] 점검 결과 2건 — 상세: bash ~/.claude/skills/repo-health/scripts/scan.sh detail
  [repo-health] 오래된 TODO/FIXME 2건 (90일 이상 방치)
  [repo-health] 참조 없는 함수 후보 4개 이상 (오탐 가능 — 삭제 전 직접 확인)
[config-drift-guard] 점검 결과 2건 — 상세: bash ~/.claude/skills/repo-health/scripts/drift/scan.sh detail
  [config-drift-guard] .env 파일 간 키 불일치 1개 (기준: .env.example)
  [config-drift-guard] CI 워크플로 간 버전 핀 불일치 1개
```

사용자가 상세를 요청하면 직접 실행한다:

```bash
bash ~/.claude/skills/repo-health/scripts/scan.sh detail
```

환경 설정 drift만 요청하면 다음 진입점을 사용한다. `summary`와 `detail`을 지원하며
기존 출력 표지(`[config-drift-guard]`)를 유지한다:

```bash
bash ~/.claude/skills/repo-health/scripts/drift/scan.sh detail
```

저장소 정리 검사와 drift 검사는 독립적으로 실행해 한쪽이 실패해도 다른 쪽은 계속 돈다.
문제가 없으면 아무 출력도 없다 — 조용히 통과한다.

## 임계값 조정

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command",
        "command": "REPO_HEALTH_STALE_DAYS=30 REPO_HEALTH_BIGFILE_LINES=500 bash .claude/hooks/repo-health.sh" }] }
    ]
  }
}
```

- `REPO_HEALTH_STALE_DAYS` (기본 90)
- `REPO_HEALTH_BIGFILE_LINES` (기본 800)

## 발견된 항목을 처리할 때

1. **dead-symbols 결과는 바로 지우지 않는다.** grep 매칭이라 오탐이 섞여 있다 — 실제로
   해당 파일을 열어 호출부가 정말 없는지 확인한 뒤에만 삭제를 제안한다.
2. **tracked-junk 결과는 `.gitignore` 추가 + `git rm --cached`를 제안**하되, 실행은
   사용자 확인 후에 한다 (git 히스토리에서 완전히 지우는 건 별개 작업이라 범위 밖).
3. **stale-todo, big-files는 정보 제공용.** 실제 조치(TODO 해소, 파일 분리)는 사용자
   판단에 맡긴다.
4. **`.env` 키 불일치** — 새 환경변수를 다른 환경 파일에 빠뜨렸을 가능성이 크다.
   추가해야 하는지, 그 환경엔 원래 필요 없는지 사용자에게 확인한 뒤 추가한다.
   **값은 절대 추측해서 채우지 않는다** — 플레이스홀더만 넣거나 사용자에게 직접 받는다.
5. **CI 버전 핀 불일치** — matrix 테스트처럼 의도된 것인지 먼저 확인한다.
   의도치 않은 불일치면 어느 버전으로 통일할지 물어보고 고친다.

## 걷어내기

`.claude/hooks/repo-health.sh` 파일과 `.claude/settings.json`의 해당 SessionStart
항목을 지운다. 이 스킬은 파일을 직접 고치지 않고 알리기만 하므로, 걷어내도 되돌릴 상태가
없다.
