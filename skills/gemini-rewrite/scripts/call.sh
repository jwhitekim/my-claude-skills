#!/usr/bin/env bash
# 공용 Gemini API 호출기. 프롬프트를 받아 텍스트 응답만 stdout으로 낸다.
# gemini-rewrite 및 그 이후 만들어질 다른 Gemini 기반 스킬(문서/영상 분석 등)이
# 이 한 벌을 공유한다 — API 호출/에러 처리 로직을 스킬마다 복사하지 않기 위함.
#
# 사용: call.sh "<프롬프트>"  또는  call.sh < prompt.txt
# 환경변수:
#   GEMINI_PROVIDER(선택) google | gateway. 기본 google.
#     google  — Google API 직접 호출(GEMINI_API_KEY). 크레딧 소진(402)·한도 초과(429)면
#               AI_GATEWAY_API_KEY가 있을 때 Vercel AI Gateway로 한 번 넘겨 다시 호출한다.
#     gateway — Vercel AI Gateway만 쓴다(AI_GATEWAY_API_KEY).
#   GEMINI_MODEL(선택, 기본 gemini-3.6-flash). Gateway에서는 google/ 접두사를 붙여 쓴다.
set -euo pipefail

SECRETS="$HOME/.config/my-claude-skills/secrets.env"
if { [ -z "${GEMINI_API_KEY:-}" ] || [ -z "${AI_GATEWAY_API_KEY:-}" ]; } && [ -f "$SECRETS" ]; then
  . "$SECRETS"
fi

PROVIDER="${GEMINI_PROVIDER:-google}"
MODEL="${GEMINI_MODEL:-gemini-3.6-flash}"

if [ $# -ge 1 ]; then
  PROMPT="$1"
else
  PROMPT="$(cat)"
fi

HTTP_CODE=""
RESPONSE=""

# 호출 결과는 HTTP_CODE, RESPONSE 전역 변수에 담는다.
call_google() {
  local resp_file
  resp_file=$(mktemp)
  HTTP_CODE=$(jq -n --arg p "$PROMPT" '{contents: [{parts: [{text: $p}]}]}' | curl -sS -o "$resp_file" -w "%{http_code}" \
    -X POST "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}" \
    -H "Content-Type: application/json" \
    --data-binary @-)
  RESPONSE=$(cat "$resp_file")
  rm -f "$resp_file"
}

call_gateway() {
  local resp_file gw_model
  resp_file=$(mktemp)
  case "$MODEL" in
    */*) gw_model="$MODEL" ;;
    *) gw_model="google/$MODEL" ;;
  esac
  HTTP_CODE=$(jq -n --arg m "$gw_model" --arg p "$PROMPT" '{model: $m, messages: [{role: "user", content: $p}]}' | curl -sS -o "$resp_file" -w "%{http_code}" \
    -X POST "https://ai-gateway.vercel.sh/v1/chat/completions" \
    -H "Authorization: Bearer $AI_GATEWAY_API_KEY" \
    -H "Content-Type: application/json" \
    --data-binary @-)
  RESPONSE=$(cat "$resp_file")
  rm -f "$resp_file"
}

require_key() {
  if [ -z "${!1:-}" ]; then
    echo "Error: $1가 없습니다. my-claude-skills 레포에서 ./install.sh를 실행해 키를 입력하세요." >&2
    exit 1
  fi
}

case "$PROVIDER" in
  google)
    require_key GEMINI_API_KEY
    call_google
    if { [ "$HTTP_CODE" = 402 ] || [ "$HTTP_CODE" = 429 ]; } && [ -n "${AI_GATEWAY_API_KEY:-}" ]; then
      echo "Note: Google API HTTP $HTTP_CODE — Vercel AI Gateway로 다시 호출합니다." >&2
      PROVIDER=gateway
      call_gateway
    fi
    ;;
  gateway)
    require_key AI_GATEWAY_API_KEY
    call_gateway
    ;;
  *)
    echo "Error: GEMINI_PROVIDER는 google 또는 gateway여야 합니다 (받은 값: $PROVIDER)" >&2
    exit 1
    ;;
esac

if [ "$HTTP_CODE" -ge 400 ]; then
  ERR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // empty' 2>/dev/null || true)
  echo "Error: Gemini 호출 실패 ($PROVIDER, HTTP $HTTP_CODE): ${ERR_MSG:-$RESPONSE}" >&2
  exit 1
fi

if [ "$PROVIDER" = gateway ]; then
  CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null || true)
else
  CONTENT=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null || true)
fi
if [ -n "$CONTENT" ]; then
  echo "$CONTENT"
else
  echo "Error: 응답에서 텍스트를 추출하지 못했습니다. 원문 응답:" >&2
  echo "$RESPONSE" >&2
  exit 1
fi
