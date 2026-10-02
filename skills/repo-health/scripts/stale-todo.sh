#!/usr/bin/env bash
# TODO/FIXME 주석 중 일정 기간 이상 건드리지 않은 것을 찾는다.
# git blame 기준이라 git 저장소가 아니면 조용히 건너뛴다.
DAYS="${REPO_HEALTH_STALE_DAYS:-90}"

command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

NOW=$(date +%s)
FOUND=0

while IFS=: read -r file line _; do
  [ -z "$file" ] && continue
  blame_date=$(git log -1 --format=%at -L "${line},${line}:${file}" -- "$file" 2>/dev/null | tail -1)
  [ -z "$blame_date" ] && continue
  age_days=$(( (NOW - blame_date) / 86400 ))
  if [ "$age_days" -ge "$DAYS" ]; then
    echo "  - ${file}:${line} (${age_days}일 전)"
    FOUND=$((FOUND + 1))
  fi
done < <(git grep -n -E 'TODO|FIXME' -- . ':!*.lock' ':!node_modules' 2>/dev/null | head -50)

if [ "$FOUND" -gt 0 ]; then
  echo "[repo-health] 오래된 TODO/FIXME ${FOUND}건 (${DAYS}일 이상 방치)"
fi
