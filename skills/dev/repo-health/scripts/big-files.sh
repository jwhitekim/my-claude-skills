#!/usr/bin/env bash
# 라인 수가 임계치를 넘는 추적 파일을 찾는다. 바이너리는 제외.
THRESHOLD="${REPO_HEALTH_BIGFILE_LINES:-800}"

command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

FOUND=0
while IFS= read -r file; do
  [ -f "$file" ] || continue
  file --mime "$file" 2>/dev/null | grep -q "charset=binary" && continue
  lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
  [ -z "$lines" ] && continue
  if [ "$lines" -ge "$THRESHOLD" ]; then
    echo "  - ${file} (${lines}줄)"
    FOUND=$((FOUND + 1))
  fi
done < <(git ls-files)

if [ "$FOUND" -gt 0 ]; then
  echo "[repo-health] ${THRESHOLD}줄 넘는 큰 파일 ${FOUND}개"
fi
