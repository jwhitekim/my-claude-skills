#!/usr/bin/env bash
# PostToolUse 훅(Bash 매처). 방금 실행된 명령이 push였는지 기계적으로 확인하고,
# 배포 워크플로가 있으면 완료까지 상태를 폴링해 결과만 알린다.
# 실패 원인 진단(로그 읽고 수정안 제시)은 스크립트로 못 하는 판단 영역이라
# deploy-status 스킬로 넘긴다 — 이 훅은 "확인이 필요하다"는 사실만 알린다.
set -u

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("command", ""))
except Exception:
    print("")
' 2>/dev/null)

case "$CMD" in
  *"safe-push.sh"*|*"git push"*) ;;
  *) exit 0 ;;
esac

[ -d .github/workflows ] || exit 0
command -v gh >/dev/null 2>&1 || { echo "[deploy-status] gh CLI가 없어 배포 상태를 자동 확인할 수 없습니다."; exit 0; }
gh auth status >/dev/null 2>&1 || { echo "[deploy-status] gh 인증이 안 되어 있어 배포 상태를 자동 확인할 수 없습니다."; exit 0; }

SHA=$(git rev-parse HEAD 2>/dev/null) || exit 0
BRANCH=$(git branch --show-current 2>/dev/null)

RUN_ID=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  RUN_ID=$(gh run list --branch "$BRANCH" --limit 5 --json databaseId,headSha \
    --jq ".[] | select(.headSha==\"$SHA\") | .databaseId" 2>/dev/null | head -1)
  [ -n "$RUN_ID" ] && break
  sleep 6
done

if [ -z "$RUN_ID" ]; then
  echo "[deploy-status] 커밋 ${SHA}에 대한 워크플로 실행을 못 찾았습니다(트리거 조건이 이 push와 안 맞을 수 있음)."
  exit 0
fi

echo "[deploy-status] 배포 실행 감지(run $RUN_ID). 최대 5분 대기합니다..."
# `timeout` 커맨드는 macOS 기본 셸에 없다(GNU coreutils 전용) — 직접 폴링 루프로
# 시간 제한을 구현한다. `gh run watch`에 기대는 대신 이 방식이 모든 플랫폼에서 돈다.
MAX=300
INTERVAL=15
ELAPSED=0
STATUS=""
CONCLUSION=""
while [ "$ELAPSED" -lt "$MAX" ]; do
  JSON=$(gh run view "$RUN_ID" --json status,conclusion 2>/dev/null)
  STATUS=$(printf '%s' "$JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))' 2>/dev/null)
  CONCLUSION=$(printf '%s' "$JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("conclusion") or "")' 2>/dev/null)
  [ "$STATUS" = "completed" ] && break
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

if [ "$STATUS" != "completed" ]; then
  echo "[deploy-status] ${MAX}초 안에 끝나지 않았습니다(run $RUN_ID, 상태: $STATUS). 나중에 deploy-status 스킬로 다시 확인하십시오."
  exit 0
elif [ "$CONCLUSION" = "success" ]; then
  echo "[deploy-status] 배포 성공 (run $RUN_ID)."
  exit 0
else
  echo "[deploy-status] 배포 실패 (run $RUN_ID, conclusion: $CONCLUSION). deploy-status 스킬로 원인을 진단하십시오: gh run view $RUN_ID --log-failed" >&2
  exit 2
fi
