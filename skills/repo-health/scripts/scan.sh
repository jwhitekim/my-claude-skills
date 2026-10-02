#!/usr/bin/env bash
# 전체 검사를 돌려서 요약 또는 상세를 출력한다.
# 설치된 프로젝트는 이 파일을 복사하지 않고 껍데기로 불러온다 — 고치면 즉시 전체 반영.
_DIR="${BASH_SOURCE[0]%/*}"
MODE="${1:-summary}"

RESULTS=$(
  bash "$_DIR/stale-todo.sh"
  bash "$_DIR/big-files.sh"
  bash "$_DIR/tracked-junk.sh"
  bash "$_DIR/dead-symbols.sh"
)

[ -z "$RESULTS" ] && exit 0

if [ "$MODE" = "detail" ]; then
  echo "$RESULTS"
  exit 0
fi

# summary 모드: "[repo-health] ..." 제목 줄만 모아서 한 줄 알림으로 압축
TITLES=$(echo "$RESULTS" | grep '^\[repo-health\]')
COUNT=$(echo "$TITLES" | grep -c '^\[repo-health\]')
echo "[repo-health] 점검 결과 ${COUNT}건 — 상세: bash ~/.claude/skills/repo-health/scripts/scan.sh detail"
echo "$TITLES" | sed 's/^/  /'
