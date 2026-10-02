#!/usr/bin/env bash
# 전체 검사를 돌려서 요약 또는 상세를 출력한다.
# 설치된 프로젝트는 이 파일을 복사하지 않고 껍데기로 불러온다 — 고치면 즉시 전체 반영.
_DIR="${BASH_SOURCE[0]%/*}"
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

TITLES=$(echo "$RESULTS" | grep '^\[config-drift-guard\]')
COUNT=$(echo "$TITLES" | grep -c '^\[config-drift-guard\]')
echo "[config-drift-guard] 점검 결과 ${COUNT}건 — 상세: bash ~/.claude/skills/config-drift-guard/scripts/scan.sh detail"
echo "$TITLES" | sed 's/^/  /'
