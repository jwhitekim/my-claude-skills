#!/usr/bin/env bash
set -euo pipefail

# 사용법: rewrite.sh "<원문 텍스트>"  또는  rewrite.sh < file.md
if [ $# -ge 1 ]; then
  TEXT="$1"
else
  TEXT="$(cat)"
fi

PROMPT="다음은 Claude가 작성한 한국어 텍스트입니다. 내용과 정보(맥락)는 절대 추가하거나 빼지 마세요. 단순히 문장 끝맺음(어조)만 바꾸지 말고, 번역체/어색한 표현이나 부자연스러운 단어 선택 자체를 한국어 원어민이 실제로 쓰는 자연스러운 단어와 표현으로 바꿔주세요(예: 지나치게 직역투인 명사구, 어색한 조사 사용, 영어식 어순 등을 한국어답게). 문단이나 항목 순서가 지금보다 더 명확하게 읽히는 구성이 있다면 재구성해도 됩니다 — 단, 마크다운 문법(제목 레벨, 코드블록, 링크)은 깨지지 않게 유지하세요. 결과는 다듬어진 전체 텍스트만 출력하세요.

---
${TEXT}
---"

bash "$HOME/.claude/skills/gemini-rewrite/scripts/call.sh" "$PROMPT"
