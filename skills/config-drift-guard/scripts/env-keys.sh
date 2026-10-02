#!/usr/bin/env bash
# .env* 파일들의 "키 집합"만 비교한다 (값은 절대 읽거나 출력하지 않음).
# .env.example이 있으면 그걸 기준으로, 없으면 파일명 사전순 첫 파일을 기준으로 삼는다.
set -u

shopt -s nullglob
FILES=(.env .env.*)
shopt -u nullglob

[ "${#FILES[@]}" -lt 2 ] && exit 0

keys_of() {
  grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$1" 2>/dev/null | sed 's/=$//'
}

BASELINE=".env.example"
if [ ! -f "$BASELINE" ]; then
  BASELINE="$(printf '%s\n' "${FILES[@]}" | sort | head -1)"
fi
BASE_KEYS="$(keys_of "$BASELINE")"
[ -z "$BASE_KEYS" ] && exit 0

FOUND=0
for f in "${FILES[@]}"; do
  [ "$f" = "$BASELINE" ] && continue
  [ -f "$f" ] || continue
  cur_keys="$(keys_of "$f")"
  missing=$(comm -23 <(echo "$BASE_KEYS" | sort) <(echo "$cur_keys" | sort))
  if [ -n "$missing" ]; then
    echo "  - ${f}: ${BASELINE}에는 있는데 없는 키 -> $(echo "$missing" | tr '\n' ' ')"
    FOUND=$((FOUND + 1))
  fi
done

if [ "$FOUND" -gt 0 ]; then
  echo "[config-drift-guard] .env 파일 간 키 불일치 ${FOUND}개 (기준: ${BASELINE})"
fi
