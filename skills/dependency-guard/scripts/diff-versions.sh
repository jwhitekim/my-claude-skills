#!/usr/bin/env bash
# 변경된 lockfile에서 버전이 바뀐 패키지를 찾고, major 버전이 오른 것을 강조한다.
# 네트워크를 쓰지 않는다 — lockfile diff만 본다.
# 사용법: diff-versions.sh [staged|last]  (기본 staged)
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
  *)      echo "[dependency-guard] 알 수 없는 모드: $MODE (staged|last)"; exit 1 ;;
esac

LOCKFILES=$(echo "$CHANGED" | grep -E '(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml)$')
[ -z "$LOCKFILES" ] && exit 0

old_content() {
  git show "HEAD:$1" 2>/dev/null
}
new_content() {
  if [ "$MODE" = "staged" ]; then
    git show ":$1" 2>/dev/null
  else
    cat "$1" 2>/dev/null
  fi
}

MAJOR_BUMPS=""
TOTAL=0

while IFS= read -r file; do
  [ -z "$file" ] && continue
  base="$(basename "$file")"

  old_versions=$(old_content "$file" | "$PY_BIN" "$_DIR/extract-versions.py" "$base" | sort -u)
  new_versions=$(new_content "$file" | "$PY_BIN" "$_DIR/extract-versions.py" "$base" | sort -u)

  [ -z "$old_versions" ] && [ -z "$new_versions" ] && continue

  while IFS=$'\t' read -r name new_ver; do
    [ -z "$name" ] && continue
    old_ver=$(echo "$old_versions" | awk -F'\t' -v n="$name" '$1==n{print $2; exit}')
    [ -z "$old_ver" ] && continue   # 신규 설치된 패키지는 비교 대상 아님
    [ "$old_ver" = "$new_ver" ] && continue

    old_major="${old_ver%%.*}"
    new_major="${new_ver%%.*}"
    TOTAL=$((TOTAL + 1))
    if [ "$old_major" != "$new_major" ]; then
      echo "  - [MAJOR] ${name}: ${old_ver} -> ${new_ver} (${file})"
      MAJOR_BUMPS="${MAJOR_BUMPS}${name}@${new_ver}
"
    else
      echo "  - ${name}: ${old_ver} -> ${new_ver} (${file})"
    fi
  done <<< "$new_versions"
done <<< "$LOCKFILES"

if [ "$TOTAL" -gt 0 ]; then
  echo "[dependency-guard] 의존성 버전 변경 ${TOTAL}건"
fi
if [ -n "$MAJOR_BUMPS" ]; then
  echo "[dependency-guard] major 업그레이드 패키지:"
  echo "$MAJOR_BUMPS" | sed '/^$/d' | sed 's/^/  /'
fi
