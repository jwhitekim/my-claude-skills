#!/bin/bash
# API 키를 ~/.config/my-claude-skills/secrets.env(권한 600)에 저장하거나 상태를 확인한다.
# gemini-rewrite·paper-search·naver-search 스크립트가 환경변수가 없을 때 이 파일에서 읽는다.
#
# 사용: keys.sh                  환경변수에 있는 값 저장, 터미널이면 빠진 키를 입력받음
#       keys.sh --from <.env>    .env 파일의 값을 우선 저장(실행하지 않고 해당 키 줄만 읽음)
#       keys.sh --check          저장하지 않고 빠진 필수 키만 출력(모두 있으면 종료 코드 0)
set -euo pipefail

KEYS="AI_GATEWAY_API_KEY GEMINI_API_KEY S2_API_KEY OPENALEX_API_KEY NAVER_CLIENT_ID NAVER_CLIENT_SECRET"
# 없으면 해당 스킬이 동작하지 않는 키. 나머지는 선택(없어도 동작).
REQUIRED="GEMINI_API_KEY NAVER_CLIENT_ID NAVER_CLIENT_SECRET"

SECRETS_DIR="$HOME/.config/my-claude-skills"
SECRETS="$SECRETS_DIR/secrets.env"
DOTENV=""
CHECK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --from) DOTENV="${2:-}"; shift 2 ;;
    --check) CHECK=1; shift ;;
    *) echo "사용법: keys.sh [--from <.env>] [--check]" >&2; exit 2 ;;
  esac
done

# 환경변수를 저장값으로 오인하지 않게 subshell에서 먼저 지운 뒤 파일만 읽는다.
saved_value() {
  [ -f "$SECRETS" ] || return 0
  ( unset "$1"; . "$SECRETS" 2>/dev/null; printf '%s' "${!1:-}" )
}

if [ $CHECK -eq 1 ]; then
  missing=""
  for key in $REQUIRED; do
    [ -n "${!key:-}" ] && continue
    [ -n "$(saved_value "$key")" ] && continue
    missing="$missing $key"
  done
  if [ -n "$missing" ]; then
    echo "${missing# }"
    exit 1
  fi
  exit 0
fi

mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"
touch "$SECRETS"
chmod 600 "$SECRETS"

dotenv_value() {
  [ -n "$DOTENV" ] && [ -f "$DOTENV" ] || return 0
  local line
  line="$(grep -E "^[[:space:]]*(export[[:space:]]+)?$1=" "$DOTENV" | tail -1 | tr -d '\r')" || true
  line="${line#*=}"
  case "$line" in
    \"*\") line="${line#\"}"; line="${line%\"}" ;;
    \'*\') line="${line#\'}"; line="${line%\'}" ;;
  esac
  printf '%s' "$line"
}

store() {
  # 키가 든 임시 파일이 잠깐이라도 넓은 권한으로 생기지 않게 umask를 좁혀 만든다.
  ( umask 077; grep -v "^$1=" "$SECRETS" > "$SECRETS.tmp" || true )
  printf '%s=%q\n' "$1" "$2" >> "$SECRETS.tmp"
  mv "$SECRETS.tmp" "$SECRETS"
  chmod 600 "$SECRETS"
}

for key in $KEYS; do
  value="$(dotenv_value "$key")"
  if [ -n "$value" ]; then
    if [ "$(saved_value "$key")" = "$value" ]; then
      echo "key: ${key} 이미 저장됨 (.env와 같음)"
    else
      store "$key" "$value"
      echo "key: ${key} .env 값으로 저장"
    fi
    continue
  fi
  if grep -q "^${key}=" "$SECRETS"; then
    echo "key: ${key} 이미 저장됨"
    continue
  fi
  value="${!key:-}"
  if [ -n "$value" ]; then
    echo "key: ${key} 현재 환경변수 값을 저장"
  elif [ -t 0 ]; then
    printf "key: %s 입력 (건너뛰려면 Enter): " "$key"
    read -rs value || true
    echo
  fi
  if [ -n "$value" ]; then
    store "$key" "$value"
  else
    echo "key: ${key} 건너뜀 — $SECRETS 에 ${key}=값 줄을 추가하면 됩니다"
  fi
done
