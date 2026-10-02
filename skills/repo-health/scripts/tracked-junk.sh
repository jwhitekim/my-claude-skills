#!/usr/bin/env bash
# .DS_Store, *.log, node_modules 등 커밋되면 안 될 흔적이 git에 이미 추적되고 있는지 확인한다.
# .gitignore 추가를 대신 해주지 않는다 — 발견된 사실만 알린다.
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

PATTERNS='(^|/)\.DS_Store$|\.log$|(^|/)node_modules/|(^|/)__pycache__/|\.pyc$|(^|/)\.env$'

MATCHES=$(git ls-files | grep -E "$PATTERNS")
[ -z "$MATCHES" ] && exit 0

COUNT=$(echo "$MATCHES" | wc -l | tr -d ' ')
echo "[repo-health] git에 추적되고 있는 흔적 파일 ${COUNT}개 (.gitignore 검토 권장)"
echo "$MATCHES" | sed 's/^/  - /' | head -10
