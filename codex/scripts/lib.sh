#!/usr/bin/env bash
# ask.sh와 review.sh가 source하는 공용 함수.

# codex를 PATH에서 찾는다. setup.sh가 nvm으로 막 설치했다면 이 셸에는 아직 PATH가
# 잡혀 있지 않으므로 nvm을 불러와 한 번 더 찾는다.
require_codex() {
  command -v codex >/dev/null 2>&1 && return 0
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" >/dev/null 2>&1
  command -v codex >/dev/null 2>&1 && return 0
  echo "[codex] CLI가 없습니다 — bash ~/.claude/skills/codex/scripts/setup.sh 를 실행하세요" >&2
  exit 1
}
