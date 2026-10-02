#!/usr/bin/env bash
# 변경된 소스 파일 중 대응하는 테스트 파일이 아예 없는 것을 찾고, jev-eval로 그 변경이
# 테스트가 필요한 로직 변경인지 판정해 사소한 변경(포맷팅·주석 등)은 뺀다.
# "기존 테스트가 이번 변경을 커버하는가"는 여기서 보지 않는다 — Claude가 직접 판단한다.
# 사용법: find-gaps.sh [staged|last]  (기본 staged)
set -u

MODE="${1:-staged}"
JEV="$HOME/.claude/skills/jev-eval/scripts/jev.sh"
NEEDS_TEST_MIN=0.5
QUESTION='{"needs_test": {"type": "noul", "instructions": "Does this diff change logic in a way that warrants a test?"}}'

file_diff() {
  if [ "$MODE" = "staged" ]; then
    git diff --cached -- "$1"
  else
    git diff HEAD~1 HEAD -- "$1"
  fi
}

# 출력: 0~1 확률. jev를 못 쓰면 빈 문자열.
needs_test() {
  [ -f "$JEV" ] || return 0
  # jev 입력 한도(32k 토큰)를 넘지 않게 diff를 자른다.
  local diff
  diff="$(file_diff "$1" | head -c 20000)"
  bash "$JEV" "$diff" "$QUESTION" 2>/dev/null | jq -r '.needs_test.noul // empty' 2>/dev/null
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[test-gap-finder] git 저장소가 아닙니다."
  exit 0
fi

case "$MODE" in
  staged) CHANGED=$(git diff --cached --name-only --diff-filter=ACMR) ;;
  last)   CHANGED=$(git diff --name-only --diff-filter=ACMR HEAD~1 HEAD 2>/dev/null) ;;
  *)      echo "[test-gap-finder] 알 수 없는 모드: $MODE (staged|last)"; exit 1 ;;
esac

[ -z "$CHANGED" ] && exit 0

SRC_EXT='\.(py|js|jsx|ts|tsx|go|rb|java)$'
TEST_MARK='(^|/)(test_|tests?/|__tests__/)|(_test|\.test|\.spec|_spec)\.'

ALL_FILES_CACHE=""
all_files() {
  [ -z "$ALL_FILES_CACHE" ] && ALL_FILES_CACHE="$(git ls-files)"
  echo "$ALL_FILES_CACHE"
}

GAPS=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  echo "$file" | grep -qE "$SRC_EXT" || continue
  echo "$file" | grep -qE "$TEST_MARK" && continue  # 이미 테스트 파일 자체면 건너뜀

  base="$(basename "$file")"
  stem="${base%.*}"

  found=$(all_files | grep -E "(^|/)(test_${stem}|${stem}_test|${stem}\.test|${stem}\.spec)\." || true)
  [ -n "$found" ] && continue

  p="$(needs_test "$file")"
  if [ -z "$p" ]; then
    echo "  - ${file}: 대응하는 테스트 파일 없음 (jev 판정 실패 — 거르지 않음)"
    GAPS=$((GAPS + 1))
  elif awk -v p="$p" -v m="$NEEDS_TEST_MIN" 'BEGIN{exit !(p < m)}'; then
    echo "  - ${file}: 사소한 변경으로 판단해 제외 (테스트 필요 확률 ${p})"
  else
    echo "  - ${file}: 대응하는 테스트 파일 없음 (테스트 필요 확률 ${p})"
    GAPS=$((GAPS + 1))
  fi
done <<< "$CHANGED"

if [ "$GAPS" -gt 0 ]; then
  echo "[test-gap-finder] 테스트가 필요한데 테스트 파일이 없는 변경 ${GAPS}건"
fi
