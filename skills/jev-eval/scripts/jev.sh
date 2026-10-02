#!/usr/bin/env bash
set -euo pipefail

SECRETS="$HOME/.config/my-claude-skills/secrets.env"
if [ -z "${AI_GATEWAY_API_KEY:-}" ] && [ -f "$SECRETS" ]; then
  . "$SECRETS"
fi
if [ -z "${AI_GATEWAY_API_KEY:-}" ]; then
  echo "Error: AI_GATEWAY_API_KEY가 없습니다. my-claude-skills 레포에서 ./install.sh를 실행해 키를 입력하세요." >&2
  exit 1
fi

# 사용법: jev.sh "<state, 평가 대상 텍스트/JSON>" '<questions JSON, TypeSafe systemone 형식>'
# questions 예시: {"approve": {"type": "noul", "instructions": "Is this safe to run?"}}
#               {"route": {"type": "choice", "instructions": "...", "criteria": {"cheap": "...", "claude": "..."}}}
#               {"risk": {"type": "score", "instructions": "...", "scale": {"min": 0, "max": 10}}}
STATE="${1:?사용법: jev.sh \"<state>\" '<questions JSON>'}"
QUESTIONS="${2:?questions JSON이 필요합니다. 예: '{\"approve\": {\"type\": \"noul\", \"instructions\": \"...\"}}'}"

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

HTTP_CODE=$(curl -sS --max-time 30 -o "$TMPFILE" -w "%{http_code}" \
  https://ai-gateway.vercel.sh/typesafe/v1/systemone \
  -H "Authorization: Bearer $AI_GATEWAY_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg state "$STATE" --argjson questions "$QUESTIONS" \
      '{model: "typesafe-ai/jev", state: $state, questions: $questions}')")

RESPONSE=$(cat "$TMPFILE")

if [ "$HTTP_CODE" -ge 400 ]; then
  ERR_MSG=$(echo "$RESPONSE" | jq -r '.message // empty' 2>/dev/null || true)
  echo "Error: jev 호출 실패 (HTTP $HTTP_CODE): ${ERR_MSG:-$RESPONSE}" >&2
  exit 1
fi

echo "$RESPONSE" | jq '.answers'
