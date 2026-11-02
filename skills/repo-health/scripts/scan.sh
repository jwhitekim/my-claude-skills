#!/usr/bin/env bash
# 전체 검사를 돌려서 요약 또는 상세를 출력한다.
# jw 플러그인의 SessionStart 훅이 summary 모드로 부른다.
_DIR="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
MODE="${1:-summary}"
# 세션 시작 자동 점검만 끈다. 직접 부른 detail은 그대로 돈다.
[ "$MODE" = "summary" ] && [ "${REPO_HEALTH_DISABLE:-0}" = "1" ] && exit 0

RESULTS=$(
  bash "$_DIR/stale-todo.sh"
  bash "$_DIR/big-files.sh"
  bash "$_DIR/tracked-junk.sh"
  bash "$_DIR/dead-symbols.sh"
)

if [ -n "$RESULTS" ]; then
  if [ "$MODE" = "detail" ]; then
    echo "$RESULTS"
  else
    # summary 모드: "[repo-health] ..." 제목 줄만 모아서 한 줄 알림으로 압축
    TITLES=$(echo "$RESULTS" | grep '^\[repo-health\]')
    COUNT=$(echo "$TITLES" | grep -c '^\[repo-health\]')
    echo "[repo-health] 점검 결과 ${COUNT}건 — 상세: bash \"$_DIR/scan.sh\" detail"
    echo "$TITLES" | sed 's/^/  /'
  fi
fi

# 독립된 검사이므로 위 검사에 결과가 없거나 실패해도 drift 검사를 실행한다.
bash "$_DIR/drift/scan.sh" "$MODE"
