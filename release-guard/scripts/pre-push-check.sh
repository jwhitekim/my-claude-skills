#!/usr/bin/env bash
# git pre-push 훅 본체. 태그를 푸시할 때만 체크리스트를 돌리고, 실패하면 푸시를 막는다.
# 태그가 아닌 일반 브랜치 푸시는 아무 것도 하지 않고 즉시 통과한다.
# 설치된 프로젝트는 이 파일을 복사하지 않고 껍데기로 불러온다 — 고치면 즉시 전체 반영.
set -u

FAIL=0

version_from_file() {
  local commit="$1"
  if git cat-file -e "${commit}:package.json" 2>/dev/null; then
    git show "${commit}:package.json" | grep -m1 '"version"' | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
  elif git cat-file -e "${commit}:VERSION" 2>/dev/null; then
    git show "${commit}:VERSION" | tr -d '[:space:]'
  elif git cat-file -e "${commit}:pyproject.toml" 2>/dev/null; then
    git show "${commit}:pyproject.toml" | grep -m1 '^version' | sed -E 's/version[[:space:]]*=[[:space:]]*"([^"]+)"/\1/'
  fi
}

check_tag() {
  local tag="$1"
  local sha="$2"
  local ver="${tag#v}"

  local commit
  if ! commit="$(git rev-parse --verify "${sha}^{commit}" 2>/dev/null)"; then
    echo "[release-guard] 태그(${tag})의 커밋을 읽을 수 없습니다."
    FAIL=1
    return
  fi

  local file_ver
  file_ver="$(version_from_file "$commit")"
  if [ -n "$file_ver" ] && [ "$file_ver" != "$ver" ]; then
    echo "[release-guard] 버전 파일(${file_ver})과 태그(${tag})가 다릅니다."
    FAIL=1
  fi

  if git cat-file -e "${commit}:CHANGELOG.md" 2>/dev/null; then
    if ! git show "${commit}:CHANGELOG.md" | grep -qE "(^|[^0-9])${ver//./\\.}([^0-9]|$)"; then
      echo "[release-guard] CHANGELOG.md에 ${ver} 항목이 없습니다."
      FAIL=1
    fi
  fi
}

# 작업 트리 대신 푸시하는 각 태그의 커밋 트리를 검사한다. 삭제 푸시는 건너뛴다.
while read -r local_ref local_sha remote_ref remote_sha; do
  [[ "$local_sha" =~ ^0+$ ]] && continue
  case "$local_ref" in
    refs/tags/*) check_tag "${local_ref#refs/tags/}" "$local_sha" ;;
  esac
done

if [ "$FAIL" -eq 1 ]; then
  echo "[release-guard] 체크리스트 실패 — 푸시를 차단합니다. (bypass: git push --no-verify)"
  exit 1
fi

exit 0
