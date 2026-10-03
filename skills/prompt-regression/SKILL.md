---
name: prompt-regression
description: "Use before or after changing an LLM prompt or agent instruction when you need to know whether outputs got worse — \"프롬프트 고쳤는데 나빠진 거 없나 봐줘\", \"프롬프트 회귀 테스트\", \"프롬프트 기준선 저장해줘\"."
---

# prompt-regression

프롬프트는 출력이 매번 조금씩 달라서 일반 테스트로 회귀를 잡기 어렵다. 이 스킬은 대표 입력에
대한 **기준선 출력**을 저장해 두고, 프롬프트를 바꾼 뒤의 출력과 비교해 채점한다.

git의 이전 커밋을 체크아웃해서 돌리는 방식은 쓰지 않는다 — `node_modules`/`.venv` 같은
실행 환경이 없어 깨지기 쉽다. 대신 **고치기 전에 snapshot을 먼저 떠 둔다.**

## 프로젝트에 둘 것

`prompt-evals/<묶음이름>/` 아래에:

| 파일 | 내용 |
|---|---|
| `cases.jsonl` | 한 줄에 케이스 하나: `{"id": "...", "input": "...", "criteria": "출력이 갖춰야 할 기준"}` |
| `cmd` | 입력을 stdin으로 받아 결과를 stdout으로 내는 명령 한 줄. 프로젝트 루트에서 실행된다 (예: `python tools/run_prompt.py`) |
| `baseline/` | 기준선 출력 — 커밋해 둔다 |
| `latest/` | 최근 비교 출력 — `.gitignore`에 넣어도 된다 |

`cmd`용 실행 스크립트가 없으면 프로젝트의 LLM 호출 함수를 감싸는 얇은 스크립트를 만든다
(stdin 읽기 → 프롬프트 함수 호출 → 결과 출력). `criteria`는 "정확히 무엇이 들어 있어야
하는지"처럼 구체적으로 쓴다 — 모호하면 채점도 흔들린다.

## 실행

```bash
R=~/.claude/skills/prompt-regression/scripts/regress.py
python3 $R prompt-evals/<묶음> snapshot   # 프롬프트 고치기 전: 기준선 저장
python3 $R prompt-evals/<묶음> compare    # 고친 뒤: 새 출력 생성 + 채점 + 비교
python3 $R prompt-evals/<묶음> accept     # 새 출력이 더 낫거나 의도한 변화면 기준선으로 확정
```

## 판정

`compare`는 기준선과 새 출력을 각각 `jev-eval`로 0(fails)~2(fully_meets) 점수로 채점한다.

| 결과 | 조건 |
|---|---|
| `[회귀]` | 새 점수가 기준선보다 0.3 이상 낮음 |
| `[확인 필요]` | 0.1 이상 낮지만 회귀 기준 미만, 또는 채점 확신도가 0.5 미만, 또는 채점/실행 실패 |
| `[통과]` | 그 외 |

**`[확인 필요]` 케이스는 Claude가 `baseline/<id>.txt`와 `latest/<id>.txt`를 직접 읽고
`criteria`에 비춰 판정한다.** `[회귀]`도 사용자에게 보여줄 때 두 출력의 실제 차이를 함께
짚는다.

## jev-eval을 못 쓸 때

`jev-eval`이 실패하면(키 없음, 크레딧 부족 등) 모든 케이스가 `[확인 필요]`로 나온다. 이때는
Claude가 전부 직접 비교한다 — 케이스가 많으면 토큰이 많이 드니, 사용자에게 알리고 케이스를
줄일지 묻는다.

## 하지 않는 것

- **프롬프트를 고치지 않는다.** 회귀를 찾을 뿐이다.
- **자동으로 기준선을 바꾸지 않는다.** `accept`는 사용자가 새 출력을 받아들이기로 한 뒤에만
  실행한다.
- **한 번 돌린 결과를 절대적으로 믿지 않는다.** LLM 출력은 흔들리므로, 회귀가 1~2건뿐이면
  해당 케이스만 한 번 더 돌려 재현되는지 확인한다.
