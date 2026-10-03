---
name: gemini-rewrite
description: "Use when Korean text Claude just wrote (docs, README, commit messages) reads stiff, translated, or choppy, or the user asks to make it smoother, more natural, or easier to read without changing its meaning."
---

# gemini

Gemini(`gemini-3.6-flash`) API를 쓰는 작업들을 한 스킬 안에 모아둔다. API 호출 공용
로직(`scripts/call.sh`)과 작업별 스크립트(`scripts/rewrite.sh` 등)를 분리해서, 새 작업이
추가돼도 호출 로직은 한 곳에서만 관리한다.

## 한국어 문장 다듬기 (rewrite)

정보는 유지하되, 문장 끝맺음(어조)뿐 아니라 번역투 단어 선택·어순까지 원어민이
실제로 쓰는 자연스러운 한국어로 바꾼다. 문단/섹션 구성이 더 명확해질 수 있다면 구조도
재구성한다 — 단, 정보를 추가·삭제하지는 않는다.

```bash
bash ~/.claude/skills/gemini-rewrite/scripts/rewrite.sh "<원문 텍스트>"
```

또는 파일을 stdin으로:

```bash
bash ~/.claude/skills/gemini-rewrite/scripts/rewrite.sh < README_KO.md
```

- `GEMINI_API_KEY`가 필요하다. 환경변수에 없으면 `~/.config/my-claude-skills/secrets.env`에서
  읽는다. 키가 없으면 my-claude-skills 레포의 `./install.sh`를 실행해 입력한다.
- 스크립트는 다듬어진 전체 텍스트만 stdout으로 출력한다.

### 결과를 사용자에게 보여줄 때

스크립트 출력을 그대로 붙여넣지 말고, 다음 두 섹션으로 정리해서 보여준다:

1. **바뀐 부분 요약** — 어떤 지점을 왜 고쳤는지 bullet로 짧게 (예: "번역투 명사구를 자연스러운 동사구로")
2. **다듬어진 전체 텍스트**

의미가 달라질 수 있는 지점(전문용어, 프로젝트 고유 표현을 임의로 바꾼 것으로 보이는 곳)이 있으면 `[확인 필요]`로 표시하고, 원문과 뭐가 다른지 짚어준다. 정보를 추가하거나 빼지 않았는지 원문과 대조해서 확인한 뒤 사용자에게 제시한다.

## 공용 호출 스크립트 (call.sh)

새 Gemini 작업을 이 스킬에 추가할 때는 API 호출을 새로 구현하지 않고 아래를 재사용한다:

```bash
bash ~/.claude/skills/gemini-rewrite/scripts/call.sh "<프롬프트>"
```

`GEMINI_MODEL` 환경변수로 모델을 바꿀 수 있다(기본값 `gemini-3.6-flash`). 응답 텍스트만
stdout으로 내고, 실패하면 에러 메시지와 함께 non-zero로 종료한다 — API 키 체크, HTTP
호출, 에러 파싱이 여기 다 들어있으므로 작업별 스크립트(`rewrite.sh`처럼)는 프롬프트
조립만 하면 된다.
