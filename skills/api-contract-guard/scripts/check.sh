#!/usr/bin/env bash
# 변경된 OpenAPI/Swagger 스펙 파일을 찾아 old/new를 비교한다.
# 사용법: check.sh [staged|last]  (기본 staged)
set -u

_DIR="${BASH_SOURCE[0]%/*}"
PY_BIN="python3"
command -v python3 >/dev/null 2>&1 || PY_BIN="python"

MODE="${1:-staged}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

case "$MODE" in
  staged) CHANGED=$(git diff --cached --name-only --diff-filter=M) ;;
  last)   CHANGED=$(git diff --name-only --diff-filter=M HEAD~1 HEAD 2>/dev/null) ;;
  *)      echo "[api-contract-guard] 알 수 없는 모드: $MODE (staged|last)"; exit 1 ;;
esac

SPECS=$(echo "$CHANGED" | grep -iE '(openapi|swagger)[^/]*\.(ya?ml|json)$')
[ -z "$SPECS" ] && exit 0

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

while IFS= read -r file; do
  [ -z "$file" ] && continue
  old="$TMPDIR/old_$(basename "$file")"
  new="$TMPDIR/new_$(basename "$file")"

  git show "HEAD:$file" > "$old" 2>/dev/null || : > "$old"
  if [ "$MODE" = "staged" ]; then
    git show ":$file" > "$new" 2>/dev/null || : > "$new"
  else
    cat "$file" > "$new" 2>/dev/null || : > "$new"
  fi

  "$PY_BIN" "$_DIR/compare-openapi.py" "$old" "$new"
done <<< "$SPECS"
