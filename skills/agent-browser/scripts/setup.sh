#!/usr/bin/env bash
# agent-browser CLI와 전용 Chrome을 설치한다. 이미 있으면 건너뛴다.
# install.sh가 부르고, 스킬이 CLI를 못 찾았을 때도 직접 부른다.
set -u

if ! command -v agent-browser >/dev/null 2>&1; then
  if command -v npm >/dev/null 2>&1; then
    npm install -g agent-browser
  elif command -v brew >/dev/null 2>&1; then
    brew install agent-browser
  elif command -v cargo >/dev/null 2>&1; then
    cargo install agent-browser
  else
    echo "[agent-browser] npm/brew/cargo 중 하나가 필요합니다 — 설치를 건너뜁니다"
    exit 0
  fi
fi

if [ -d "$HOME/.agent-browser/browsers" ] && [ -n "$(ls -A "$HOME/.agent-browser/browsers" 2>/dev/null)" ]; then
  echo "[agent-browser] $(agent-browser --version) 이미 설치됨"
else
  agent-browser install
  # Linux에서 공유 라이브러리가 없으면 sudo가 필요하므로 자동으로 하지 않고 안내만 한다.
  [ "$(uname -s)" = "Linux" ] && echo "[agent-browser] 'shared library' 오류가 나면: agent-browser install --with-deps"
fi

# 가벼운 읽기 작업용 lightpanda. Linux·macOS만 바이너리가 있다.
LIGHTPANDA_VERSION="1.0.0"
if command -v lightpanda >/dev/null 2>&1; then
  echo "[agent-browser] lightpanda $(lightpanda version 2>/dev/null) 이미 설치됨"
else
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) asset="lightpanda-x86_64-linux" ;;
    Linux-aarch64) asset="lightpanda-aarch64-linux" ;;
    Darwin-x86_64) asset="lightpanda-x86_64-macos" ;;
    Darwin-arm64) asset="lightpanda-aarch64-macos" ;;
    *) asset="" ;;
  esac
  if [ -z "$asset" ]; then
    echo "[agent-browser] 이 OS에는 lightpanda가 없음 — Chrome만 씁니다"
  else
    mkdir -p "$HOME/.local/bin"
    curl -fsSL -o "$HOME/.local/bin/lightpanda" \
      "https://github.com/lightpanda-io/browser/releases/download/${LIGHTPANDA_VERSION}/${asset}" \
      && chmod +x "$HOME/.local/bin/lightpanda" \
      && echo "[agent-browser] lightpanda ${LIGHTPANDA_VERSION} 설치: ~/.local/bin/lightpanda"
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) ;;
      *) echo "[agent-browser] ~/.local/bin을 PATH에 추가해야 lightpanda를 찾습니다" ;;
    esac
  fi
fi
