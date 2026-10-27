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

`compare`는 파일 존재와 실행 성공을 먼저 확인한다. 출력이 같으면 채점을 생략한다.
다르면 `jev-eval`로 0(fails)~2(fully_meets) 점수를 받는다. 점수와 확신도는 **모델 추정치**다.
`latest/`는 매 실행 전에 비운다. 출력이 빠진 실행은 `accept`할 수 없다.

| 결과 | 조건 |
|---|---|
| `[확인 필요]` | 실행·채점 실패, 낮거나 누락된 확신도, 임계값 경계, 또는 중간 점수 하락 |
| `[회귀]` | 위 조건이 없고 하락이 회귀 임계값을 넘음(모델 추정) |
| `[통과]` | 같은 출력, 또는 위 조건에 해당하지 않음 |

환경변수 `PROMPT_REGRESSION_DROP=0.3`, `PROMPT_AMBIGUOUS_DROP=0.1`,
`PROMPT_LOW_CONFIDENCE=0.5`, `PROMPT_BOUNDARY_MARGIN=0.02`로 설정한다. 기본값은 초기
경험값이다. 하락 임계값의 ±경계 폭, 또는 확신도 ≤ 최소 확신도+경계 폭이면 확인이 우선이다.
설정값은 실행 결과에 나온다. 확인 하락값은 회귀 하락값보다 작아야 한다.

**`[확인 필요]` 케이스는 Claude가 두 출력과 `criteria`를 대조해 근거를 정리하고 사람에게
확인을 넘긴다.** `[회귀]`도 사용자에게 보여줄 때 두 출력의 실제 차이를 함께
짚는다.

## jev-eval을 못 쓸 때

`jev-eval`이 실패하면(키 없음, 크레딧 부족 등) 채점이 필요한 케이스는 `[확인 필요]`로 나온다. 이때는
Claude가 전부 직접 비교한다 — 케이스가 많으면 토큰이 많이 드니, 사용자에게 알리고 케이스를
줄일지 묻는다.

## 하지 않는 것

- **프롬프트를 고치지 않는다.** 회귀를 찾을 뿐이다.
- **자동으로 기준선을 바꾸지 않는다.** `accept`는 사용자가 새 출력을 받아들이기로 한 뒤에만
  실행한다.
- **한 번 돌린 결과를 절대적으로 믿지 않는다.** LLM 출력은 흔들리므로, 회귀가 1~2건뿐이면
  해당 케이스만 한 번 더 돌려 재현되는지 확인한다.
