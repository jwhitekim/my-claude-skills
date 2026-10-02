---
name: jev-eval
description: Use when approving a risky tool call before execution (delete, DB change, external API write), deciding which of several routing options an incoming task should take, triaging a batch of items by urgency or category, or scoring items against a checklist/rubric — situations needing a fast structured decision (probability, choice, or score), not free-text writing or explanation.
---

# jev

jev(typesafe-ai/jev)는 Vercel AI Gateway의 TypeSafe 호환 evaluation API로 호출하는 판별 전용 모델이다. 텍스트를 생성하지 않고, 미리 정의한 타입드 질문(`questions`)에 대한 답만 반환한다 — 그래서 일반 LLM보다 훨씬 빠르다.

## 호출법

```bash
bash ~/.claude/skills/jev-eval/scripts/jev.sh "<state, 평가 대상 텍스트/JSON>" '<questions JSON>'
```

- `AI_GATEWAY_API_KEY`가 필요하다. 환경변수에 없으면 `~/.config/my-claude-skills/secrets.env`에서 읽는다(아래 "키 설정").
- `state`: 평가 대상이 되는 상황/텍스트(자유 문자열).
- `questions`: 질문 이름을 키로 하는 객체. 각 질문은 세 타입 중 하나:
  - `"type": "noul"` — 예/아니오를 0~1 확률로 반환. `instructions`만 필요.
  - `"type": "choice"` — 여러 선택지 중 하나를 고름. `instructions` + `criteria`(선택지 이름: 설명)로 정의.
  - `"type": "score"` — 순서형 등급으로 평가. `instructions` + `criteria`(등급 라벨 배열, 낮은 것부터 높은 것 순서 — 예: `["low", "medium", "high"]`)로 정의한다. **`scale`은 무시된다 — `criteria` 배열이 없으면 400 에러.** 응답의 `score`는 0~1이 아니라 **`criteria` 배열 인덱스의 확률 가중 기댓값**이다(예: 3개 라벨이면 0~2 범위 — `probabilities`를 인덱스에 곱해 합산한 값). `confidence`, `legend`(인덱스→라벨), `probabilities`(라벨별 확률)도 함께 온다.
- 출력은 `{"질문이름": {"type": "...", "noul"|"choice"|"score": 값}}` 형태 JSON.

## 유스케이스별 예시

### (A) 가드레일 / 위험한 도구 호출 사전 차단

```bash
bash ~/.claude/skills/jev-eval/scripts/jev.sh \
  "<실행하려는 명령/도구 호출 설명>" \
  '{"approve": {"type": "noul", "instructions": "Is this action safe to auto-approve without asking the user?"}}'
```

`approve.noul`이 낮으면(예: 0.5 미만) 실행을 중단하고 사용자에게 확인을 구한다.

### (B) 동적 라우팅

```bash
bash ~/.claude/skills/jev-eval/scripts/jev.sh \
  "<작업 내용>" \
  '{"route": {"type": "choice", "instructions": "Which handler should process this task?", "criteria": {"cheap": "simple query", "claude": "needs deep reasoning or design", "gemini_ko_docs": "Korean README/doc writing"}}}'
```

`gemini_ko_docs`가 나와도 jev는 판정만 한 것이다 — Gemini API를 자동으로 호출하지 않는다. 사용자에게 확인하거나 `gemini-rewrite` 스킬로 넘긴다.

### (C) 트리아지 / 분류

```bash
bash ~/.claude/skills/jev-eval/scripts/jev.sh \
  "<항목 내용>" \
  '{"urgency": {"type": "choice", "instructions": "How urgent is this?", "criteria": {"low": "...", "medium": "...", "high": "..."}}, "spam": {"type": "noul", "instructions": "Is this spam?"}}'
```

여러 질문을 한 번에 물을 수 있다. 스크립트는 단건 호출이므로 여러 항목은 반복 호출한다.

### (D) 루브릭 평가

```bash
bash ~/.claude/skills/jev-eval/scripts/jev.sh \
  "<대상 코드/문서>" \
  '{"passes_rule": {"type": "score", "instructions": "How well does this satisfy the rule: <rule text>", "criteria": ["fails", "partially_meets", "fully_meets"]}}'
```

`criteria` 배열 순서가 곧 등급 순서다(낮은 것 → 높은 것). 응답 예(실제 호출로 검증됨):

```json
{"passes_rule": {"type": "score", "score": 1.28, "confidence": 0.48,
  "legend": {"0": "fails", "1": "partially_meets", "2": "fully_meets"},
  "probabilities": {"0": 0.04, "1": 0.65, "2": 0.31}}}
```

`score` 1.28은 "fails=0, partially_meets=1, fully_meets=2" 인덱스의 확률 가중 평균이다 — 세 번째 라벨(`fully_meets`)에 가까울수록 배열 길이-1에 가까운 값이 나온다.

`score`가 낮은 항목은 Claude가 직접 재검토한다.

## 키 설정

my-claude-skills 레포의 `./install.sh`를 실행하면 키가 없을 때 입력받아
`~/.config/my-claude-skills/secrets.env`(권한 600, 레포 밖)에 저장한다. `jev.sh`는 환경변수가
없으면 이 파일에서 읽는다. 키를 바꾸려면 그 파일에서 해당 줄을 지우고 `./install.sh`를 다시
실행한다. 키 값은 어디에도 문서화하지 않는다.

크레딧은 **직접 구매한 AI Gateway 크레딧**이어야 한다. 무료 플랜의 월 $5 크레딧으로는
`typesafe-ai/jev`를 쓸 수 없어서 403("Free tier users do not have access to this model")이 난다.
