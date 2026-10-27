---
name: jev-eval
description: Use to assist policy-based review before a risky tool call (delete, DB change, external API write), choose routing for an incoming task, triage items by urgency or category, or score items against a checklist/rubric — structured model estimates (probability, choice, or score), not execution authorization or free-text writing.
---

# jev

jev(typesafe-ai/jev)는 Vercel AI Gateway의 TypeSafe 호환 evaluation API로 호출하는 판별 전용 모델이다. 텍스트 대신 미리 정의한 타입드 질문(`questions`)에 대한 답을 반환한다. 지연 시간은 입력·모델·게이트웨이 상태에 따라 다르다. 속도 비교에는 같은 조건의 측정이 필요하다.

## 판정 순서

1. 사용자 권한, 파일 존재, 명령 종료 코드, 프로젝트의 명시된 허용·거부 목록을 먼저 확인한다.
2. 거부 조건이면 중단한다. 허용 목록의 모든 조건을 충족하면 그 정책을 따른다. 서로 충돌하면 사람에게 넘긴다.
3. 규칙으로 판정되지 않은 경우에만 jev를 보조로 쓴다. 점수·확률·확신도는 **모델 추정치**다.
4. 위험 작업에서 미확정인 권한·정책은 사람이 확인한다. jev 점수로 승인하거나 거부 규칙을 덮어쓰지 않는다.

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

### (A) 가드레일 / 규칙으로 미확정인 위험 작업의 검토 보조

```bash
bash ~/.claude/skills/jev-eval/scripts/jev.sh \
  "<실행할 명령, 대상 경로, 확인한 권한과 허용·거부 정책, 미확정 조건>" \
  '{"needs_review": {"type": "noul", "instructions": "Do the supplied unresolved policy conditions require human review?"}}'
```

예: 삭제는 승인된 경로·대상 목록·복구 조건을 모두 확인하고, DB/API 쓰기는 명시된 허용
작업·환경·권한을 확인한다. 목록 밖이거나 조건이 없으면 실행하지 않고 사람에게 넘긴다.
`needs_review.noul`은 검토 우선순위를 정하는 모델 추정치이며, 낮아도 실행 허가가 아니다.

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

`score`가 낮은 항목은 기준과 원문을 대조한다. 임계값·최소 확신도·경계 폭은 호출 측의
설정으로 받고 사용값을 보고한다. 기본값을 두면 초기 경험값임을 밝힌다. jev.sh는 원시
응답만 반환한다. 확신도 누락·저확신·경계 범위·응답 오류는 사람 확인으로 넘긴다.
모델 추정치만으로 통과를 확정하지 않는다.

## 키 설정

my-claude-skills 레포의 `./install.sh`를 실행하면 키가 없을 때 입력받아
`~/.config/my-claude-skills/secrets.env`(권한 600, 레포 밖)에 저장한다. `jev.sh`는 환경변수가
없으면 이 파일에서 읽는다. 키를 바꾸려면 그 파일에서 해당 줄을 지우고 `./install.sh`를 다시
실행한다. 키 값은 어디에도 문서화하지 않는다.

크레딧은 **직접 구매한 AI Gateway 크레딧**이어야 한다. 무료 플랜의 월 $5 크레딧으로는
`typesafe-ai/jev`를 쓸 수 없어서 403("Free tier users do not have access to this model")이 난다.
