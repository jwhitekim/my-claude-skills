#!/usr/bin/env bash
# 변경된 lockfile에서 버전이 바뀐 패키지를 찾고, major 버전이 오른 것을 강조한다.
# 네트워크를 쓰지 않는다 — lockfile diff만 본다.
# 사용법: diff-versions.sh [staged|last] [--packages major|all]
set -uo pipefail

_DIR="${BASH_SOURCE[0]%/*}"
PY_BIN="python3"
command -v python3 >/dev/null 2>&1 || PY_BIN="python"

MODE="${1:-staged}"
PACKAGES=""
if [ "$#" -gt 1 ]; then
  if [ "$#" -ne 3 ] || [ "$2" != "--packages" ] || { [ "$3" != major ] && [ "$3" != all ]; }; then
    echo "사용법: diff-versions.sh [staged|last] [--packages major|all]" >&2
    exit 1
  fi
  PACKAGES="$3"
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

case "$MODE" in
  staged) CHANGED=$(git diff --cached --name-only --diff-filter=M) || exit 1 ;;
  last)   CHANGED=$(git diff --name-only --diff-filter=M HEAD~1 HEAD) || exit 1 ;;
  *)      echo "[dependency-guard] 알 수 없는 모드: $MODE (staged|last)"; exit 1 ;;
esac

LOCKFILES=$(echo "$CHANGED" | grep -E '(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml)$')
[ -z "$LOCKFILES" ] && exit 0

TMP="$(mktemp -d)" || exit 1
trap 'rm -rf "$TMP"' EXIT

old_content() {
  if [ "$MODE" = staged ]; then
    git show "HEAD:$1" 2>/dev/null
  else
    git show "HEAD~1:$1" 2>/dev/null
  fi
}
new_content() {
  if [ "$MODE" = "staged" ]; then
    git show ":$1" 2>/dev/null
  else
    git show "HEAD:$1" 2>/dev/null
  fi
}

MAJOR_BUMPS=""
TOTAL=0

while IFS= read -r file; do
  [ -z "$file" ] && continue
  base="$(basename "$file")"

  old_content "$file" | "$PY_BIN" "$_DIR/extract-versions.py" "$base" | sort -u > "$TMP/old" || {
    echo "[dependency-guard] 이전 lockfile 읽기/추출 실패: $file" >&2; exit 1;
  }
  new_content "$file" | "$PY_BIN" "$_DIR/extract-versions.py" "$base" | sort -u > "$TMP/new" || {
    echo "[dependency-guard] 새 lockfile 읽기/추출 실패: $file" >&2; exit 1;
  }

  "$PY_BIN" - "$TMP/old" "$TMP/new" > "$TMP/changes" <<'PY'
import re
import sys

def load(path):
    versions = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            name, version = line.rstrip("\n").split("\t", 1)
            versions.setdefault(name, set()).add(version)
    return versions

def max_major(versions):
    matches = (re.match(r"^v?(\d+)(?:\.|$)", v) for v in versions)
    majors = [int(m.group(1)) for m in matches if m]
    return max(majors) if majors else None

old, new = (load(path) for path in sys.argv[1:])
for name in sorted(old.keys() | new.keys()):
    before, after = old.get(name, set()), new.get(name, set())
    removed, added = before - after, after - before
    if not removed and not added:
        continue
    kind = "NEW" if not before else "REMOVED" if not after else "CHANGED"
    old_major, new_major = max_major(removed), max_major(added)
    if old_major is not None and new_major is not None and old_major != new_major:
        kind = "MAJOR"
    print(name, ",".join(sorted(removed)) or "-", ",".join(sorted(added)) or "-", kind, sep="\t")
PY
  [ "$?" -eq 0 ] || exit 1

  while IFS=$'\t' read -r name old_ver new_ver kind; do
    [ -z "$name" ] && continue
    TOTAL=$((TOTAL + 1))
    IFS=',' read -r -a added_versions <<< "$new_ver"
    if [ -n "$PACKAGES" ]; then
      # 라이선스 조회는 기존 패키지에 추가된 버전만 넘긴다.
      if [ "$kind" != NEW ] && [ "$new_ver" != - ] && { [ "$PACKAGES" = all ] || [ "$kind" = MAJOR ]; }; then
        for version in "${added_versions[@]}"; do echo "${name}@${version}"; done
      fi
      continue
    fi
    if [ "$kind" != CHANGED ]; then
      echo "  - [${kind}] ${name}: ${old_ver} -> ${new_ver} (${file})"
      if [ "$kind" = MAJOR ]; then
        for version in "${added_versions[@]}"; do
          MAJOR_BUMPS="${MAJOR_BUMPS}${name}@${version}
"
        done
      fi
    else
      echo "  - ${name}: ${old_ver} -> ${new_ver} (${file})"
    fi
  done < "$TMP/changes"
done <<< "$LOCKFILES"

if [ -z "$PACKAGES" ] && [ "$TOTAL" -gt 0 ]; then
  echo "[dependency-guard] 의존성 버전 변경 ${TOTAL}건"
fi
if [ -n "$MAJOR_BUMPS" ]; then
  echo "[dependency-guard] major 업그레이드 패키지:"
  echo "$MAJOR_BUMPS" | sed '/^$/d' | sed 's/^/  /'
fi
