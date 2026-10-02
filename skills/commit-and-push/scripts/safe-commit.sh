#!/usr/bin/env bash
# 지정한 파일만 add하고 커밋한다. 민감 파일 패턴이 섞여 있으면 무조건 거부한다 —
# check-staged.sh는 경고만 하고 판단을 Claude에게 넘기지만, 이 스크립트는
# 판단 없이 기계적으로 막는다(경고 vs 차단은 다른 안전 등급이다).
#
# 사용: safe-commit.sh "<message>" <file1> [file2 ...]
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "사용법: safe-commit.sh \"<message>\" <file1> [file2 ...]" >&2
  exit 1
fi

MSG="$1"; shift

for f in "$@"; do
  if echo "$f" | grep -Eq '(^|/)\.env(\..*)?$|(^|/)secrets/|\.pem$|id_rsa$|\.key$'; then
    echo "REFUSED: '$f'는 민감 파일 패턴(.env/secrets//.pem/.key/id_rsa)입니다. 커밋 대상에서 빼고 다시 실행하세요." >&2
    exit 1
  fi
done

# 경로별로 add한다. 이미 삭제가 완전히 스테이징된 경로(워킹트리·인덱스 양쪽에
# 더 이상 존재하지 않음)는 git이 "pathspec did not match any files"로 거부하는데,
# 이 경우는 이미 원하는 상태라 실패로 취급하지 않는다 — 진짜 실패(경로 오타 등)는
# 아래 "커밋할 게 없음" 체크가 잡아낸다.
for f in "$@"; do
  git add -A -- "$f" 2>/dev/null || true
done

if git diff --cached --quiet; then
  echo "REFUSED: 커밋할 변경사항이 없습니다(staged가 비어 있음) — 경로를 확인하세요." >&2
  exit 1
fi

git commit -m "$MSG"
