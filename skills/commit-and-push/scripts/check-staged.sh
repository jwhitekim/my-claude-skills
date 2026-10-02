#!/usr/bin/env bash
# staged 파일 목록을 정리하고, 그 중 시크릿/민감 파일로 보이는 패턴을 기계적으로
# 골라낸다. "의도한 범위와 맞는지" 같은 의미 판단은 하지 않는다 — 그건 이 목록을
# 받아서 Claude가 한다.
set -u

FILES=$(git diff --cached --name-only)
if [ -z "$FILES" ]; then
  echo "staged 파일 없음"
  exit 0
fi

echo "## staged 파일"
echo "$FILES"

FLAGGED=$(echo "$FILES" | grep -E '(^|/)\.env(\..*)?$|(^|/)secrets/|\.pem$|id_rsa$|\.key$' || true)
if [ -n "$FLAGGED" ]; then
  echo ""
  echo "## 경고: 민감 파일로 보이는 항목"
  echo "$FLAGGED"
fi
