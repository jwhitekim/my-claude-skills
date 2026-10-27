#!/usr/bin/env bash
# 변경된 소스 파일마다 대응 테스트 파일이 있는지 파일 존재만 검사한다.
# 테스트가 필요한지와 기존 테스트의 실제 커버 여부는 diff를 읽고 Claude가 판단한다.
# 사용법: find-gaps.sh [staged|last]
set -uo pipefail

MODE="${1:-staged}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[test-gap-finder] git 저장소가 아닙니다."
  exit 0
fi
case "$MODE" in
  staged) CHANGED=$(git diff --cached --name-only --diff-filter=ACMR) || exit 1 ;;
  last) CHANGED=$(git diff --name-only --diff-filter=ACMR HEAD~1 HEAD) || exit 1 ;;
  *) echo "[test-gap-finder] 알 수 없는 모드: $MODE (staged|last)"; exit 1 ;;
esac
[ -z "$CHANGED" ] && exit 0

SRC_EXT='\.(py|js|jsx|ts|tsx|go|rb|java)$'
TEST_MARK='(^|/)(test_|tests?/|__tests__/)|(_test|\.test|\.spec|_spec)\.'
ALL_FILES=$(git ls-files)
GAPS=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  [[ "$file" =~ $SRC_EXT ]] || continue
  [[ "$file" =~ $TEST_MARK ]] && continue
  base="${file##*/}"
  stem="${base%.*}"
  found=""
  # 정규식 대신 파일명 접두사를 비교해 '.' 등이 들어간 소스명도 문자 그대로 처리한다.
  while IFS= read -r candidate; do
    test_base="${candidate##*/}"
    case "$test_base" in
      "test_${stem}."*|"${stem}_test."*|"${stem}.test."*|"${stem}.spec."*|"${stem}_spec."*)
        found="$candidate"; break ;;
    esac
  done <<< "$ALL_FILES"
  if [ -n "$found" ]; then
    echo "  - ${file}: 대응 테스트 파일 있음: ${found} (커버 여부 미검증)"
    continue
  fi
  echo "  - ${file}: 대응 테스트 파일 없음 — 후보"
  GAPS=$((GAPS + 1))
done <<< "$CHANGED"

if [ "$GAPS" -gt 0 ]; then
  echo "[test-gap-finder] 대응 테스트 파일이 없는 검토 후보 ${GAPS}건"
fi
