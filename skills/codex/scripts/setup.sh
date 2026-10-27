#!/usr/bin/env bash
# Codex CLI를 처음부터 설치하고 로그인까지 안내한다. 이미 된 단계는 건너뛴다.
# install.sh가 부르고, 스킬이 CLI를 못 찾았을 때도 직접 부른다.
#
# 순서: Node.js(npm) 확인 → 없으면 nvm으로 설치(sudo 불필요) → @openai/codex 설치 → 로그인
# 사용: setup.sh            설치 + 터미널이면 로그인까지 진행
#       setup.sh --no-login 설치만 하고 로그인은 안내만
set -u

NO_LOGIN=0
[ "${1:-}" = "--no-login" ] && NO_LOGIN=1
NVM_VERSION="v0.40.3"

load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
}

if ! command -v codex >/dev/null 2>&1; then
  load_nvm
fi

if ! command -v codex >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1 && ! command -v npm >/dev/null 2>&1; then
    echo "[codex] Homebrew로 설치"
    brew install codex || { echo "[codex] brew 설치 실패"; exit 1; }
  else
    if ! command -v npm >/dev/null 2>&1; then
      echo "[codex] npm이 없어 nvm으로 Node.js LTS를 설치합니다 (~/.nvm, sudo 불필요)"
      if ! command -v curl >/dev/null 2>&1; then
        echo "[codex] curl이 필요합니다 — curl 설치 후 다시 실행하세요"
        exit 1
      fi
      # curl | bash로 이으면 다운로드 실패가 묻히므로 받아 둔 뒤 실행한다.
      nvm_installer="$(mktemp)"
      curl -fsSL -o "$nvm_installer" "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" \
        || { echo "[codex] nvm 설치 스크립트 다운로드 실패"; rm -f "$nvm_installer"; exit 1; }
      bash "$nvm_installer" || { echo "[codex] nvm 설치 실패"; rm -f "$nvm_installer"; exit 1; }
      rm -f "$nvm_installer"
      load_nvm
      nvm install --lts || { echo "[codex] Node.js 설치 실패"; exit 1; }
    fi
    echo "[codex] npm으로 @openai/codex 설치"
    npm install -g @openai/codex || { echo "[codex] npm 설치 실패"; exit 1; }
  fi
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "[codex] 설치했지만 PATH에서 찾지 못했습니다 — 새 터미널을 열고 다시 실행하세요"
  exit 1
fi
if ! version="$(codex --version 2>&1)"; then
  echo "[codex] codex가 있지만 실행되지 않습니다: $version"
  exit 1
fi
echo "[codex] $version 설치됨 ($(command -v codex))"

if codex login status >/dev/null 2>&1; then
  echo "[codex] $(codex login status 2>&1 | head -1)"
  exit 0
fi

# 로그인은 사람이 브라우저에서 승인해야 한다. 터미널이 아니면 안내만 한다.
# 브라우저가 없는 원격 서버면 --device-auth(코드 입력 방식)를 쓴다.
if [ $NO_LOGIN -eq 0 ] && [ -t 0 ]; then
  if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || [ "$(uname -s)" = "Darwin" ]; then
    codex login
  else
    codex login --device-auth
  fi
else
  # 방금 nvm으로 설치했다면 호출한 셸의 PATH에는 아직 codex가 없으므로 절대 경로로 안내한다.
  bin="$(command -v codex)"
  echo "[codex] 로그인 필요: $bin login  (브라우저 없는 서버면 $bin login --device-auth)"
  echo "[codex] Claude Code 안에서는 프롬프트에 '! $bin login --device-auth'를 입력하세요"
fi
