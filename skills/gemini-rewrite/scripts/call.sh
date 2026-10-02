#!/usr/bin/env bash
# 공용 Gemini API 호출기. 프롬프트를 받아 텍스트 응답만 stdout으로 낸다.
# gemini-rewrite 및 그 이후 만들어질 다른 Gemini 기반 스킬(문서/영상 분석 등)이
# 이 한 벌을 공유한다 — API 호출/에러 처리 로직을 스킬마다 복사하지 않기 위함.
#
# 사용: call.sh "<프롬프트>"  또는  call.sh < prompt.txt
# 환경변수: GEMINI_API_KEY(필수), GEMINI_MODEL(선택, 기본 gemini-3.6-flash)
set -euo pipefail

SECRETS="$HOME/.config/my-claude-skills/secrets.env"
if [ -z "${GEMINI_API_KEY:-}" ] && [ -f "$SECRETS" ]; then
  . "$SECRETS"
fi
if [ -z "${GEMINI_API_KEY:-}" ]; then
  echo "Error: GEMINI_API_KEY가 없습니다. my-claude-skills 레포에서 ./install.sh를 실행해 키를 입력하세요." >&2
  exit 1
fi

MODEL="${GEMINI_MODEL:-gemini-3.6-flash}"

if [ $# -ge 1 ]; then
  PROMPT="$1"
else
  PROMPT="$(cat)"
fi

RESP_FILE=$(mktemp)
HTTP_CODE=$(curl -sS -o "$RESP_FILE" -w "%{http_code}" \
  -X POST "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg p "$PROMPT" '{contents: [{parts: [{text: $p}]}]}')")

RESPONSE=$(cat "$RESP_FILE")
rm -f "$RESP_FILE"

if [ "$HTTP_CODE" -ge 400 ]; then
  ERR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // empty' 2>/dev/null || true)
  echo "Error: Gemini 호출 실패 (HTTP $HTTP_CODE): ${ERR_MSG:-$RESPONSE}" >&2
  exit 1
fi

CONTENT=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null || true)
if [ -n "$CONTENT" ]; then
  echo "$CONTENT"
else
  echo "Error: 응답에서 텍스트를 추출하지 못했습니다. 원문 응답:" >&2
  echo "$RESPONSE" >&2
  exit 1
fi
