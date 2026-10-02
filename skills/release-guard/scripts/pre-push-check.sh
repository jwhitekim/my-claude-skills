#!/usr/bin/env bash
# git pre-push 훅 본체. 태그를 푸시할 때만 체크리스트를 돌리고, 실패하면 푸시를 막는다.
# 태그가 아닌 일반 브랜치 푸시는 아무 것도 하지 않고 즉시 통과한다.
# 설치된 프로젝트는 이 파일을 복사하지 않고 껍데기로 불러온다 — 고치면 즉시 전체 반영.
set -u

FAIL=0

read_tags() {
  while read -r local_ref local_sha remote_ref remote_sha; do
    case "$local_ref" in
      refs/tags/*)
        echo "${local_ref#refs/tags/}"
        ;;
    esac
  done
}

version_from_file() {
  if [ -f package.json ]; then
    grep -m1 '"version"' package.json | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
  elif [ -f VERSION ]; then
    tr -d '[:space:]' < VERSION
  elif [ -f pyproject.toml ]; then
    grep -m1 '^version' pyproject.toml | sed -E 's/version[[:space:]]*=[[:space:]]*"([^"]+)"/\1/'
  fi
}

check_tag() {
  local tag="$1"
  local ver="${tag#v}"

  local file_ver
  file_ver="$(version_from_file)"
  if [ -n "$file_ver" ] && [ "$file_ver" != "$ver" ]; then
    echo "[release-guard] 버전 파일(${file_ver})과 태그(${tag})가 다릅니다."
    FAIL=1
  fi

  if [ -f CHANGELOG.md ]; then
    if ! grep -qE "(^|[^0-9])${ver//./\\.}([^0-9]|$)" CHANGELOG.md; then
      echo "[release-guard] CHANGELOG.md에 ${ver} 항목이 없습니다."
      FAIL=1
    fi
  fi

  if [ -n "$(git status --porcelain)" ]; then
    echo "[release-guard] working tree가 깨끗하지 않습니다 (커밋 안 된 변경 있음)."
    FAIL=1
  fi
}

TAGS="$(read_tags)"
[ -z "$TAGS" ] && exit 0

while IFS= read -r tag; do
  [ -z "$tag" ] && continue
  check_tag "$tag"
done <<< "$TAGS"

if [ "$FAIL" -eq 1 ]; then
  echo "[release-guard] 체크리스트 실패 — 푸시를 차단합니다. (bypass: git push --no-verify)"
  exit 1
fi

exit 0
