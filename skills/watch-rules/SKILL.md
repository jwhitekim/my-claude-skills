---
name: watch-rules
description: "Use when asked to set up automatic length checks for a project's rule files (CLAUDE.md, .claude/rules/*.md) — \"규칙 파일 길이 체크 훅 설치해줘\", \"이 프로젝트에도 watch-rules 깔아줘\" — or when trim-rules never seems to run on its own."
---

# watch-rules

`trim-rules` 같은 정리 스킬은 Claude가 능동적으로 줄 수를 세어봐야 트리거되는데,
그럴 이유가 없어서 실제로는 거의 안 돈다. 이 스킬은 세션 시작 시 자동으로 규칙 파일
줄 수를 체크하는 훅을 설치해서, Claude의 판단력에 의존하지 않고 기계적으로 알린다.

## 설치

```bash
cd <대상 프로젝트 루트>
bash ~/.claude/skills/watch-rules/scripts/setup.sh
```

- `.claude/hooks/watch-rules.sh` 껍데기를 깐다 (본체는 `scripts/check.sh` 한 벌 —
  고치면 설치된 모든 프로젝트에 바로 적용된다).
- `.claude/settings.json`의 `hooks.SessionStart` 배열에 이 스킬의 항목만 추가/갱신한다.
  다른 훅(권한 설정, 다른 스킬이 넣은 훅)은 건드리지 않는다.
- 세션을 재시작(`/exit` 후 재진입)해야 적용된다.

## 용어

이 문서에서 **"규칙 파일"**은 `CLAUDE.md`와 `.claude/rules/*.md`를 통칭한다 — 이름은
다르지만 둘 다 Claude Code가 세션 시작 시 자동으로 읽어들이는 컨텍스트라는 점에서
같은 범주로 다룬다.

## 판단 로직

`.claude/rules/`(공식 관례 — 세션 시작 시 자동 로드되는 디렉터리)가 있으면 그 안의
파일 각각을 개별로 검사한다(주제별로 쪼개 쓰는 곳이라 파일 하나하나가 짧아야 함).

없으면 단일 파일 위치를 우선순위로 확인한다: 루트 `CLAUDE.md` → `.claude/CLAUDE.md` →
`.claude/RULES.md`. **`.claude/RULES.md`는 이름이 비슷해도 Claude Code가 자동 로드하는
파일명이 아니다** — 발견되면 줄수와 별개로 그 사실도 경고한다(자동 로드가 안 되고 있을
가능성이 높으므로).

임계값 기본값은 200줄. 프로젝트마다 다르게 하려면 `.claude/settings.json`의 훅 명령에
환경변수를 붙인다:

```json
{ "hooks": [ { "type": "command", "command": "RULES_LENGTH_THRESHOLD=150 bash .claude/hooks/watch-rules.sh" } ] }
```

## 걷어내기

`.claude/hooks/watch-rules.sh` 파일과 `.claude/settings.json`의 해당 SessionStart
항목을 지운다. 이 스킬은 파일을 직접 고치지 않고 알리기만 하므로, 걷어내도 되돌릴 상태가
없다.
