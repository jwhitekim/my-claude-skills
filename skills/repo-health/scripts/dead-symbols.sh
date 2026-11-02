#!/usr/bin/env bash
# 언어 무관 휴리스틱으로 "정의는 있는데 참조가 안 되는" 함수를 찾는다.
# grep 기반 심볼 매칭이라 리플렉션/동적 호출/export 재노출은 못 잡는다 — 오탐 가능.
# 자동 삭제는 하지 않는다. 결과는 사람이 확인할 후보 목록일 뿐이다.
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

FILE_COUNT=$(git ls-files | wc -l | tr -d ' ')
if [ "$FILE_COUNT" -gt 3000 ]; then
  echo "[repo-health] 파일 수가 많아(${FILE_COUNT}개) dead-symbol 검사를 건너뜁니다."
  exit 0
fi

EXTS='\.(js|jsx|ts|tsx|py|sh|go|rb|java|rs)$'
FILES=$(git ls-files | grep -E "$EXTS")
[ -z "$FILES" ] && exit 0

FOUND=0
MAX_HITS=15

while IFS= read -r file; do
  [ -f "$file" ] || continue
  # function NAME / def NAME / func NAME / fn NAME 형태의 정의부만 뽑는다.
  while IFS=: read -r lineno name; do
    [ -z "$name" ] && continue
    # 참조 횟수(정의 포함)가 1이면 정의 말고는 아무도 안 쓴다는 뜻.
    refs=$(git grep -ow -- "$name" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$refs" -le 1 ]; then
      echo "  - ${file}:${lineno} ${name}()"
      FOUND=$((FOUND + 1))
      [ "$FOUND" -ge "$MAX_HITS" ] && break 2
    fi
  done < <(grep -noE '(function|def|func|fn)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$file" 2>/dev/null \
            | sed -E 's/^([0-9]+):(function|def|func|fn)[[:space:]]+/\1:/')
done <<< "$FILES"

if [ "$FOUND" -gt 0 ]; then
  echo "[repo-health] 참조 없는 함수 후보 ${FOUND}개 이상 (오탐 가능 — 삭제 전 직접 확인)"
fi
