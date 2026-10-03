---
name: repo-health
description: "Use when asked to check a repository for accumulated clutter — \"저장소 건강검진해줘\", \"이 프로젝트 정리할 거 없나 봐줘\" — or to install it in a project (\"repo-health 깔아줘\"). Not for TODO.md task tracking (todo-guard) or rule-file length (trim-rules, watch-rules)."
---

# repo-health

`watch-rules`와 같은 패턴 — 세션 시작 시 자동으로 돌아서, Claude가 능동적으로 점검하길
기다리지 않고 기계적으로 알린다. 문제를 자동으로 고치지 않는다. 알리기만 한다.

## 설치

```bash
cd <대상 프로젝트 루트>
bash ~/.claude/skills/repo-health/scripts/setup.sh
```

- `.claude/hooks/repo-health.sh` 껍데기를 깐다 (본체는 `scripts/scan.sh` 한 벌 —
  고치면 설치된 모든 프로젝트에 바로 적용된다).
- `.claude/settings.json`의 `hooks.SessionStart` 배열에 이 스킬의 항목만 추가/갱신한다.
  다른 훅은 건드리지 않는다.
- 세션을 재시작(`/exit` 후 재진입)해야 적용된다.
- git 저장소가 아니면 모든 검사가 조용히 건너뛰어진다.

## 검사 항목

| 스크립트 | 하는 일 | 한계 |
|---|---|---|
| `stale-todo.sh` | `TODO`/`FIXME` 주석 중 `git blame` 기준 90일(기본) 이상 안 건드려진 것 | git 이력 기반이라 날짜 조작된 커밋엔 못 속아 넘어가지 않음(=속음) |
| `big-files.sh` | 추적 중인 파일 중 800줄(기본) 넘는 것 | 바이너리는 제외 |
| `tracked-junk.sh` | `.DS_Store`, `*.log`, `node_modules/`, `__pycache__/`, `.env` 등이 git에 추적되고 있는지 | `.gitignore`를 대신 고쳐주지 않음, 발견만 함 |
| `dead-symbols.sh` | `function`/`def`/`func`/`fn` 키워드로 정의된 함수 중 저장소 전체에서 참조가 정의 한 줄뿐인 것 | **grep 기반 휴리스틱** — AST 아님. 리플렉션, 문자열로 조립한 호출, 외부 export, 템플릿 안 참조는 못 잡음. 오탐 가능성이 있으므로 **절대 자동으로 지우지 않는다** — 사람이 하나씩 확인 |

파일 수가 3000개를 넘는 저장소는 `dead-symbols.sh` 검사를 건너뛴다(시간이 너무 오래 걸림).

## 출력

세션 시작 시에는 요약만 한 줄~몇 줄로 보여준다:

```
[repo-health] 점검 결과 3건 — 상세: bash ~/.claude/skills/repo-health/scripts/scan.sh detail
  [repo-health] 오래된 TODO/FIXME 2건 (90일 이상 방치)
  [repo-health] 참조 없는 함수 후보 4개 이상 (오탐 가능 — 삭제 전 직접 확인)
```

사용자가 상세를 요청하면 직접 실행한다:

```bash
bash ~/.claude/skills/repo-health/scripts/scan.sh detail
```

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

## 걷어내기

`.claude/hooks/repo-health.sh` 파일과 `.claude/settings.json`의 해당 SessionStart
항목을 지운다. 이 스킬은 파일을 직접 고치지 않고 알리기만 하므로, 걷어내도 되돌릴 상태가
없다.
