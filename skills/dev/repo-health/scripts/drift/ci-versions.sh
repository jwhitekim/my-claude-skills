#!/usr/bin/env bash
# .github/workflows/*.yml 사이에서 node-version/python-version 핀이 서로 다른지 확인한다.
set -u

[ -d .github/workflows ] || exit 0

shopt -s nullglob
WORKFLOWS=(.github/workflows/*.yml .github/workflows/*.yaml)
shopt -u nullglob
[ "${#WORKFLOWS[@]}" -lt 2 ] && exit 0

check_version_key() {
  local key="$1"
  local pairs
  pairs=$(grep -H -oE "${key}:[[:space:]]*['\"]?[0-9][A-Za-z0-9.]*" "${WORKFLOWS[@]}" 2>/dev/null \
          | sed -E "s/:${key}:[[:space:]]*/: /" | sed -E "s/['\"]//g")
  if [ -z "$pairs" ]; then
    return 1
  fi

  local distinct
  distinct=$(echo "$pairs" | sed -E 's/^[^:]+: //' | sort -u | wc -l | tr -d ' ')
  if [ "$distinct" -gt 1 ]; then
    echo "  - ${key} 버전이 워크플로마다 다름:"
    echo "$pairs" | sed 's/^/      /'
    return 0
  fi
  return 1
}

FOUND=0
check_version_key "node-version" && FOUND=$((FOUND + 1))
check_version_key "python-version" && FOUND=$((FOUND + 1))

if [ "$FOUND" -gt 0 ]; then
  echo "[config-drift-guard] CI 워크플로 간 버전 핀 불일치 ${FOUND}개"
fi
