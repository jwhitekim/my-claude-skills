#!/usr/bin/env bash
# 전체 검사를 돌려서 요약 또는 상세를 출력한다.
# jw 플러그인의 SessionStart 훅이 summary 모드로 부른다.
_DIR="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
MODE="${1:-summary}"

RESULTS=$(
  bash "$_DIR/env-keys.sh"
  bash "$_DIR/ci-versions.sh"
)

[ -z "$RESULTS" ] && exit 0

if [ "$MODE" = "detail" ]; then
  echo "$RESULTS"
  exit 0
fi

TITLES=$(echo "$RESULTS" | grep '^\[repo-health:drift\]')
COUNT=$(echo "$TITLES" | grep -c '^\[repo-health:drift\]')
echo "[repo-health:drift] 점검 결과 ${COUNT}건 — 상세: bash \"$_DIR/scan.sh\" detail"
echo "$TITLES" | sed 's/^/  /'
