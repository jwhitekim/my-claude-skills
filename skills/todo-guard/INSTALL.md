# todo-guard 설치

## 설치

`todo-guard` 폴더를 아래 위치에 통째로 넣는다.

```
Windows   C:\Users\<사용자>\.claude\skills\todo-guard\
macOS     ~/.claude/skills/todo-guard/
리눅스    ~/.claude/skills/todo-guard/
```

Claude Code 를 다시 열면 스킬 목록에 잡힌다.

## 쓰는 법

프로젝트 폴더에서 한 번만 실행.

```
투두가드로 프로젝트 세팅해줘
```

세팅이 끝나면 `/exit` 로 나갔다 다시 들어온다. 훅은 세션을 열 때 읽힌다.

## 무엇이 생기나

| 파일 | 하는 일 |
|---|---|
| `TODO.md` | 받은 지시를 적어 두는 곳 (훅이 적는다) |
| `TODO-완료.md` | 완료 항목이 40개를 넘으면 옮겨 두는 곳 (지우지 않는다) |
| `.claude/hooks/` 4개 | 스킬 본체를 부르는 껍데기 |
| `.claude/settings.json` | 훅 등록 (있던 설정은 그대로 둔다) |
| `투두가드설명서.md` | 무엇이 자동으로 돌고 언제 막히는지 |
| `CLAUDE.md` | 운영 규칙 병합 |

## 하는 일

**작업 누락 방지** — 지시가 오는 순간 훅이 TODO.md 에 `#번호` 로 적는다.
미완료 `- [ ]` 가 남으면 턴 종료를 막는다. Claude 는 TODO.md 를 열지 않고 번호로 완료만 알린다.
질문 · 의견으로 보이는 말은 파일을 바꾸지 않은 채 턴이 끝나면 훅이 지운다. 지시는 지우지 않는다.

**지키는 것** — TODO.md 완료 이력 삭제 · 프로젝트 밖 편집을 막는다.
Write · Edit · Bash · PowerShell 을 모두 본다.

문서 문체 검사는 하지 않는다. 슬라이드 · 보고서 검수는 글검수(geulgeomsu) 스킬이 한다.

## 명령

| 사용자가 말하면 | 하는 일 |
|---|---|
| 앞으로 ~하지 마 / 항상 ~해 | TODO.md 「항상 지킬 것」에 등록 |
| 투두가드 세팅된 프로젝트 훑어줘 | 세팅한 프로젝트 상태 점검 |
| TODO 정리해줘 | 완료 항목을 `TODO-완료.md` 로 옮김 |
| 투두가드 세팅 지워줘 | 이 프로젝트에서 세팅을 걷어냄 |

## 걷어내기

```
투두가드 세팅 지워줘
```

무엇을 지울지 먼저 보여준 뒤 지운다. 지우기 전에 백업한다.

**남기는 것** — `TODO.md` · `TODO-완료.md`(사용자의 작업 기록), 남이 걸어 둔 훅,
`settings.json` 의 다른 설정, 전역 `~/.claude/CLAUDE.md` 의 규칙.

## 옛 판에서 올릴 때

스크립트는 껍데기 훅이 불러오므로 폴더를 바꿔 넣으면 바로 적용된다.
프로젝트에 놓인 것(settings.json 훅 등록 · CLAUDE.md 운영 규칙 · 설명서)은 한 번 맞춘다.

```
투두가드 세팅된 프로젝트 훑어줘      → 옛 등록 · 옛 운영 규칙 · 옛 설명서 · 옛 문서 검사 훅을 알림
bash ~/.claude/skills/todo-guard/scripts/doctor.sh --fix <프로젝트 상위 폴더>
```

맞춘 뒤 그 프로젝트의 Claude Code 를 `/exit` 로 나갔다 다시 연다.

## 규칙을 고치려면

| 무엇 | 파일 | 고치면 |
|---|---|---|
| 세션 밖 편집 규칙 | `rules/outside-rule.md` | 전역 CLAUDE.md 에 설치 |
| 프로젝트 운영 규칙 | `rules/claude-md-block.md` | `doctor.sh --fix` 로 세팅한 곳에 반영 |

## 필요한 것

- Python 3 — 세팅(settings.json 병합) · 걷어내기 · 점검에 쓴다
- bash — 윈도우는 Claude Code 가 쓰는 Git Bash 를 그대로 쓴다. macOS 기본 bash 3.2 에서도 돈다

윈도우 · macOS · 리눅스에서 같이 돈다.
