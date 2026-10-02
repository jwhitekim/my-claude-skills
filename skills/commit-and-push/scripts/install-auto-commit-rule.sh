#!/usr/bin/env bash
# 커밋 자동화 규칙을 프로젝트의 규칙 파일에 마커와 함께 추가한다.
# 이미 마커가 있으면 아무것도 하지 않는다(중복 삽입 방지) — Claude가 임의로
# 문구를 손으로 고치는 대신, 정해진 문구를 스크립트가 결정적으로 넣는다.
set -euo pipefail

BEGIN="<!-- commit-and-push:auto-commit-rule:begin -->"
END="<!-- commit-and-push:auto-commit-rule:end -->"

BLOCK() {
  echo ""
  echo "$BEGIN"
  echo "## 커밋 자동화"
  echo ""
  echo "기능 추가·버그 수정 작업이 검증(빌드/테스트/구문 확인 등, 프로젝트에 검증 수단이 있는"
  echo "경우)을 통과하면, 사용자의 별도 요청 없이도 로컬 커밋까지는 자동으로 실행한다"
  echo "(commit-and-push 스킬의 커밋 단계). 원격 푸시는 이 자동화에 포함되지 않으며 항상 사람"
  echo "확인을 받는다."
  echo "$END"
}

# .claude/rules/ (공식 관례 — 자동 로드되는 디렉터리)가 있으면 그 안에 이
# 규칙만 담은 파일을 새로 만든다. 기존 파일에 끼워 넣지 않는 이유: rules/는
# 주제별로 파일을 나눠 쓰라고 있는 곳이라, 커밋 자동화라는 독립된 주제는
# 자기 파일을 갖는 게 그 관례에 맞는다.
if [ -d .claude/rules ]; then
  if grep -qFl "$BEGIN" .claude/rules/*.md 2>/dev/null; then
    echo "[commit-and-push] 이미 설치되어 있습니다 - .claude/rules/"
    exit 0
  fi
  TARGET=".claude/rules/commit-automation.md"
  BLOCK > "$TARGET"
  echo "[commit-and-push] 커밋 자동화 규칙 추가 완료 - $TARGET"
  exit 0
fi

# rules/ 디렉터리가 없으면 표준 단일 파일 위치를 순서대로 확인한다.
if [ -f CLAUDE.md ]; then
  TARGET="CLAUDE.md"
elif [ -f .claude/CLAUDE.md ]; then
  TARGET=".claude/CLAUDE.md"
elif [ -f .claude/RULES.md ]; then
  TARGET=".claude/RULES.md"
else
  TARGET="CLAUDE.md"
  touch "$TARGET"
fi

if grep -qF "$BEGIN" "$TARGET" 2>/dev/null; then
  echo "[commit-and-push] 이미 설치되어 있습니다 - $TARGET"
  exit 0
fi

BLOCK >> "$TARGET"
echo "[commit-and-push] 커밋 자동화 규칙 추가 완료 - $TARGET"
