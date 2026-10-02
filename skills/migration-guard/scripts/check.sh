#!/usr/bin/env bash
# */migrations/*.sql 파일의 변경을 검사한다.
# - 새로 추가된 마이그레이션: destructive/lock 위험 패턴 검사
# - 이미 있던 마이그레이션을 수정: 그 자체로 경고 (적용된 환경엔 반영 안 됨)
# 사용법: check.sh [staged|last]  (기본 staged)
set -u

_DIR="${BASH_SOURCE[0]%/*}"

MODE="${1:-staged}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

case "$MODE" in
  staged)
    ADDED=$(git diff --cached --name-only --diff-filter=A)
    MODIFIED=$(git diff --cached --name-only --diff-filter=M)
    ;;
  last)
    ADDED=$(git diff --name-only --diff-filter=A HEAD~1 HEAD 2>/dev/null)
    MODIFIED=$(git diff --name-only --diff-filter=M HEAD~1 HEAD 2>/dev/null)
    ;;
  *)
    echo "[migration-guard] 알 수 없는 모드: $MODE (staged|last)"; exit 1 ;;
esac

PATTERN='(^|/)migrations/[^/]+\.sql$'

ADDED_MIGRATIONS=$(echo "$ADDED" | grep -E "$PATTERN")
MODIFIED_MIGRATIONS=$(echo "$MODIFIED" | grep -E "$PATTERN")

[ -z "$ADDED_MIGRATIONS" ] && [ -z "$MODIFIED_MIGRATIONS" ] && exit 0

TOTAL=0

while IFS= read -r file; do
  [ -z "$file" ] && continue
  out=$(bash "$_DIR/check-sql.sh" "$file")
  if [ -n "$out" ]; then
    echo "[migration-guard] ${file}:"
    echo "$out"
    TOTAL=$((TOTAL + 1))
  fi
done <<< "$ADDED_MIGRATIONS"

while IFS= read -r file; do
  [ -z "$file" ] && continue
  echo "[migration-guard] ${file}: 이미 존재하던 마이그레이션 파일을 수정 중입니다 — 이미 적용된 환경(로컬/스테이징/운영)에는 반영되지 않습니다. 새 마이그레이션 파일을 추가하는 걸 권장합니다."
  TOTAL=$((TOTAL + 1))
done <<< "$MODIFIED_MIGRATIONS"

exit 0
