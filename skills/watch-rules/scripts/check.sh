#!/usr/bin/env bash
# 규칙 파일 줄수를 확인해 정리 시점을 알린다.
# 설치된 프로젝트는 이 파일을 복사하지 않고 껍데기로 불러온다 — 고치면 즉시 전체 반영.
THRESHOLD="${RULES_LENGTH_THRESHOLD:-200}"

# .claude/rules/ (공식 관례 — 세션 시작 시 자동 로드되는 디렉터리)가 있으면
# 그 안의 각 파일을 개별로 검사한다. rules/는 원래 주제별로 쪼개 쓰라고 있는
# 곳이라, 파일 하나하나가 짧게 유지되는 게 핵심이다 — 합산해서 검사하면 이
# 목적과 어긋난다.
if [ -d ".claude/rules" ]; then
  FOUND=0
  for f in .claude/rules/*.md; do
    [ -f "$f" ] || continue
    LINES=$(wc -l < "$f" | tr -d ' ')
    if [ "$LINES" -ge "$THRESHOLD" ]; then
      echo "[watch-rules] ${f}가 ${LINES}줄입니다(권장 상한 ${THRESHOLD}줄) — 더 작은 주제로 쪼개는 정리를 검토하세요. (trim-rules 스킬 참고)"
      FOUND=1
    fi
  done
  exit 0
fi

# rules/ 디렉터리가 없으면 표준 단일 파일 위치를 순서대로 확인한다:
# 루트 CLAUDE.md → .claude/CLAUDE.md → .claude/RULES.md(비표준 관례, 일부
# 프로젝트가 이 이름을 씀 — 단, 이 이름은 Claude Code가 자동 로드하지 않으므로
# 발견되면 그 사실도 함께 알린다).
FILE=""
NONSTANDARD=0
if [ -f "CLAUDE.md" ]; then
  FILE="CLAUDE.md"
elif [ -f ".claude/CLAUDE.md" ]; then
  FILE=".claude/CLAUDE.md"
elif [ -f ".claude/RULES.md" ]; then
  FILE=".claude/RULES.md"
  NONSTANDARD=1
else
  exit 0
fi

LINES=$(wc -l < "$FILE" | tr -d ' ')
if [ "$NONSTANDARD" -eq 1 ]; then
  echo "[watch-rules] 경고: ${FILE}는 Claude Code가 자동 로드하는 파일명이 아닙니다(CLAUDE.md 또는 .claude/rules/*.md만 자동 로드됨). 이름을 바꾸거나 .claude/rules/로 옮기는 걸 검토하세요."
fi
if [ "$LINES" -ge "$THRESHOLD" ]; then
  echo "[watch-rules] ${FILE}가 ${LINES}줄입니다(권장 상한 ${THRESHOLD}줄) — 핵심 규칙만 남기고 나머지는 .claude/rules/로 주제별 분리하는 정리를 검토하세요. (trim-rules 스킬 참고)"
fi
exit 0
