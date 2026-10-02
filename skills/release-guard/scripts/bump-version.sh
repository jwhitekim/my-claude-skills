#!/usr/bin/env bash
# 버전 파일 갱신 + CHANGELOG.md 항목 추가 + git tag 생성을 기계적으로 실행한다.
# 어떤 버전으로 올릴지(patch/minor/major)는 이 스크립트가 판단하지 않는다 —
# 호출하는 쪽(Claude)이 git log를 보고 정한 버전 문자열을 인자로 넘긴다.
# 사용법: bump-version.sh <새버전, v 없이> ["변경 요약"]
set -euo pipefail

NEW_VER="${1:?버전을 인자로 넘기세요 (예: 1.3.0)}"
SUMMARY="${2:-}"

if [ -f package.json ]; then
  tmp=$(mktemp)
  sed -E "s/(\"version\"[[:space:]]*:[[:space:]]*\")[^\"]+(\")/\1${NEW_VER}\2/" package.json > "$tmp"
  mv "$tmp" package.json
  echo "[release-guard] package.json version -> ${NEW_VER}"
elif [ -f VERSION ]; then
  echo "$NEW_VER" > VERSION
  echo "[release-guard] VERSION -> ${NEW_VER}"
elif [ -f pyproject.toml ]; then
  tmp=$(mktemp)
  sed -E "s/^(version[[:space:]]*=[[:space:]]*\")[^\"]+(\")/\1${NEW_VER}\2/" pyproject.toml > "$tmp"
  mv "$tmp" pyproject.toml
  echo "[release-guard] pyproject.toml version -> ${NEW_VER}"
else
  echo "[release-guard] 버전 파일(package.json/VERSION/pyproject.toml)을 못 찾음 — 버전 파일 갱신은 건너뜀"
fi

if [ -f CHANGELOG.md ]; then
  tmp=$(mktemp)
  {
    echo "## ${NEW_VER} - $(date +%Y-%m-%d)"
    echo ""
    if [ -n "$SUMMARY" ]; then
      echo "$SUMMARY"
    else
      echo "- (내용 채우기)"
    fi
    echo ""
    cat CHANGELOG.md
  } > "$tmp"
  mv "$tmp" CHANGELOG.md
  echo "[release-guard] CHANGELOG.md에 ${NEW_VER} 항목 추가"
else
  echo "[release-guard] CHANGELOG.md가 없음 — 생성은 건너뜀 (원하면 직접 만든 뒤 다시 실행)"
fi

git add -A
git commit -m "release: v${NEW_VER}"
git tag -a "v${NEW_VER}" -m "v${NEW_VER}"
echo "[release-guard] 커밋 + 태그 v${NEW_VER} 생성 완료. 푸시는 사용자 확인 후: git push && git push --tags"
