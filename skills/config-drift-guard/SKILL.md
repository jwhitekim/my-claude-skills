---
name: config-drift-guard
description: dev/staging/prod용 .env* 파일 사이의 키 불일치(값은 비교하지 않음, 비밀값 노출 방지)와 .github/workflows/*.yml 사이의 Node/Python 버전 핀 불일치를 세션 시작 시 자동으로 점검하는 훅을 설치한다. "환경 설정 어긋나는 거 없나 봐줘", "config-drift-guard 깔아줘", ".env 파일들 키 맞는지 확인해줘" 같은 요청에 사용한다.
---

# config-drift-guard

`repo-health`와 같은 패턴 — 세션 시작 시 자동으로 돌아서 기계적으로 알린다. 아무것도
자동으로 고치지 않는다.

## 설치

```bash
cd <대상 프로젝트 루트>
bash ~/.claude/skills/config-drift-guard/scripts/setup.sh
```

- `.claude/hooks/config-drift-guard.sh` 껍데기를 깐다 (본체는 `scripts/scan.sh` 한 벌).
- `.claude/settings.json`의 `hooks.SessionStart` 배열에 이 스킬의 항목만 추가/갱신한다.
- 세션을 재시작(`/exit` 후 재진입)해야 적용된다.

## 검사 항목

| 스크립트 | 하는 일 | 한계 |
|---|---|---|
| `env-keys.sh` | `.env*` 파일들의 **키 집합만** 비교 (`.env.example` 기준, 없으면 사전순 첫 파일). 값은 절대 읽거나 출력하지 않는다 | 키 이름이 같은데 의미가 다른 경우는 못 잡음 |
| `ci-versions.sh` | `.github/workflows/*.yml` 사이에서 `node-version`/`python-version` 핀이 서로 다른지 | 워크플로가 2개 미만이면 비교할 게 없어 건너뜀, matrix 버전 전략은 "여러 버전 테스트"가 의도일 수 있어 오탐 가능 — 발견되면 의도한 matrix인지부터 확인 |

**비밀값은 절대 다루지 않는다.** `env-keys.sh`는 `KEY=` 패턴만 추출하고 `=` 뒤의 값은
읽지 않는다 — 출력에 비밀값이 섞일 가능성 자체를 구조적으로 차단한다.

## 출력

```
[config-drift-guard] 점검 결과 2건 — 상세: bash ~/.claude/skills/config-drift-guard/scripts/scan.sh detail
  [config-drift-guard] .env 파일 간 키 불일치 1개 (기준: .env.example)
  [config-drift-guard] CI 워크플로 간 버전 핀 불일치 1개
```

상세는 직접 실행:

```bash
bash ~/.claude/skills/config-drift-guard/scripts/scan.sh detail
```

## 발견된 항목을 처리할 때

1. **`.env` 키 불일치** — 새 환경변수를 추가했는데 다른 환경 파일에 빠뜨렸을 가능성이
   크다. 어느 쪽이 맞는지(새로 추가해야 하는지, 그 환경엔 원래 필요 없는지) 사용자에게
   확인한 뒤 추가한다. **값은 절대 추측해서 채우지 않는다** — 플레이스홀더만 넣거나
   사용자에게 직접 받는다.
2. **CI 버전 핀 불일치** — matrix 테스트처럼 의도된 것인지 먼저 확인한다. 의도치 않은
   불일치면 어느 버전으로 통일할지 물어보고 고친다.

## 걷어내기

`.claude/hooks/config-drift-guard.sh` 파일과 `.claude/settings.json`의 해당
SessionStart 항목을 지운다. 되돌릴 상태가 없다.
