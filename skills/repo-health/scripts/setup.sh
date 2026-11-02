#!/usr/bin/env bash
# 예전 프로젝트 껍데기 정리. jw 플러그인의 SessionStart 훅이 모든 프로젝트에서 돌므로 설치는 필요 없다.
# 예전에 깐 .claude/hooks/repo-health.sh, config-drift-guard.sh 와 settings.json 등록만 걷어낸다.
set -u
_DIR="${BASH_SOURCE[0]%/*}"

PY_BIN="python3"
command -v python3 >/dev/null 2>&1 || PY_BIN="python"

CLEANED=0
for f in .claude/hooks/repo-health.sh .claude/hooks/config-drift-guard.sh; do
  if [ -f "$f" ]; then
    rm -f "$f"
    echo "[repo-health] 예전 껍데기 삭제: $f"
    CLEANED=$((CLEANED + 1))
  fi
done

if [ -f .claude/settings.json ]; then
  OUT="$("$PY_BIN" "$_DIR/merge-settings.py" .claude/settings.json)" || {
    echo "[repo-health] .claude/settings.json을 읽지 못했습니다 — 직접 확인하세요."
    exit 1
  }
  if [ -n "$OUT" ]; then
    echo "$OUT"
    CLEANED=$((CLEANED + 1))
  fi
fi

if [ "$CLEANED" -eq 0 ]; then
  echo "[repo-health] 정리할 예전 설치 없음"
fi
