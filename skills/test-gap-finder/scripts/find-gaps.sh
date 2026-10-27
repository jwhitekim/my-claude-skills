#!/usr/bin/env bash
# 파일 존재 검사를 먼저 하고, 미대응 후보에만 jev 보조 판정을 쓴다.
# 기존 테스트의 실제 커버 여부는 diff와 테스트를 읽어 별도로 확인한다.
# 사용법: find-gaps.sh [staged|last]
set -uo pipefail

MODE="${1:-staged}"
JEV="$HOME/.claude/skills/jev-eval/scripts/jev.sh"
# 초기 경험값. 프로젝트 정책에 맞춰 호출 시 환경변수로 조정한다.
NEEDS_TEST_MIN="${TEST_GAP_NEEDS_TEST_MIN:-0.5}"
BOUNDARY_MARGIN="${TEST_GAP_BOUNDARY_MARGIN:-0.1}"
LOW_CONFIDENCE="${TEST_GAP_LOW_CONFIDENCE:-0.5}"
USE_JEV="${TEST_GAP_USE_JEV:-1}"
QUESTION='{"needs_test": {"type": "noul", "instructions": "Does this diff change logic in a way that warrants a test?"}}'
for value in "$NEEDS_TEST_MIN" "$BOUNDARY_MARGIN" "$LOW_CONFIDENCE"; do
  if ! awk -v n="$value" 'BEGIN {exit !(n ~ /^([0-9]+([.][0-9]*)?|[.][0-9]+)$/ && n >= 0 && n <= 1)}'; then
    echo "[test-gap-finder] 임계값은 0~1의 수여야 합니다: $value" >&2
    exit 1
  fi
done
case "$USE_JEV" in 0|1) ;; *) echo "TEST_GAP_USE_JEV는 0 또는 1이어야 합니다." >&2; exit 1 ;; esac

file_diff() {
  if [ "$MODE" = "staged" ]; then
    git diff --cached -- "$1"
  else
    git diff HEAD~1 HEAD -- "$1"
  fi
}

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

  reason="jev 판정 실패 — 후보 유지"
  excluded=0
  if [ "$USE_JEV" = 0 ]; then
    reason="jev 생략 — 후보 유지"
  elif [ -f "$JEV" ] && command -v jq >/dev/null 2>&1; then
    if diff=$(file_diff "$file"); then
      # 앞 20,000자까지만 보낸다. 잘린 입력으로는 후보를 제외하지 않는다.
      response=$(bash "$JEV" "${diff:0:20000}" "$QUESTION" 2>/dev/null) || response=""
      p=$(jq -er '.needs_test.noul | numbers | select(. >= 0 and . <= 1)' <<< "$response" 2>/dev/null) || p=""
      confidence=$(jq -er '.needs_test.confidence | numbers | select(. >= 0 and . <= 1)' <<< "$response" 2>/dev/null) || confidence=""
      if [ -n "$p" ]; then
        reason="모델 추정치 ${p}, 확신도 ${confidence:-없음} — 확인 필요, 후보 유지"
        if [ "${#diff}" -gt 20000 ]; then
          reason="모델 추정치 ${p}, 입력 잘림 — 확인 필요, 후보 유지"
        elif [ -n "$confidence" ] && awk -v p="$p" -v c="$confidence" -v m="$NEEDS_TEST_MIN" -v b="$BOUNDARY_MARGIN" -v l="$LOW_CONFIDENCE" 'BEGIN{exit !(p < m-b && c > l+b)}'; then
          reason="후보에서 제외된 이유: 모델 추정치 ${p} < ${NEEDS_TEST_MIN} (경계 폭 ${BOUNDARY_MARGIN}), 확신도 ${confidence}; 테스트 불필요 확정 아님"
          excluded=1
        fi
      fi
    else
      reason="diff 조회 실패 — 확인 필요, 후보 유지"
    fi
  fi
  echo "  - ${file}: 대응하는 테스트 파일 없음 (${reason})"
  [ "$excluded" -eq 1 ] || GAPS=$((GAPS + 1))
done <<< "$CHANGED"

if [ "$GAPS" -gt 0 ]; then
  echo "[test-gap-finder] 대응 테스트 파일이 없는 검토 후보 ${GAPS}건"
fi
