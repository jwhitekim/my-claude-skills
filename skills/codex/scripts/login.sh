#!/usr/bin/env bash
# Codex 로그인 상태를 보고, 로그인하거나 다른 계정으로 바꾼다.
# 브라우저 승인이나 코드 입력이 필요하므로 사람이 직접 실행한다.
# Claude Code 안에서는 프롬프트에 '! bash <이 파일 경로> [옵션]'으로 실행한다.
#
# 사용: login.sh             로그인 안 되어 있으면 로그인, 되어 있으면 상태만 출력
#       login.sh --status    상태만 출력(로그인 안 되어 있으면 종료 코드 1)
#       login.sh --switch    다른 계정으로 다시 로그인(사용량 한도에 걸렸을 때 등)
#       login.sh --device    브라우저 대신 코드 입력 방식(--device-auth)으로 로그인
#       login.sh --api-key   OPENAI_API_KEY 환경변수의 API 키로 로그인(사용량만큼 과금)
#       login.sh --restore   --switch 직전 계정으로 되돌린다(가장 최근 백업 사용)
# --switch는 --device, --api-key와 함께 쓸 수 있다.
# --switch는 기존 인증 파일을 auth.json.bak.* 로 남긴다. API 키는 로그인 때 검증되지 않으므로
# 잘못된 키였으면 --restore로 되돌린다.
set -u

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MODE="login"
SWITCH=0
DEVICE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --status) MODE="status"; shift ;;
    --switch) SWITCH=1; shift ;;
    --device) DEVICE=1; shift ;;
    --api-key) MODE="api-key"; shift ;;
    --restore) MODE="restore"; shift ;;
    *) echo "[codex] 알 수 없는 옵션: $1" >&2; exit 1 ;;
  esac
done

require_codex

CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
AUTH="$CODEX_DIR/auth.json"

# 상태 출력에는 경고 줄이 섞일 수 있어 WARNING 줄을 뺀 첫 줄만 쓴다.
status_line() { codex login status 2>&1 | grep -v '^WARNING' | head -1; }

if [ "$MODE" = "restore" ]; then
  latest="$(ls -t "$CODEX_DIR"/auth.json.bak.* 2>/dev/null | head -1)"
  if [ -z "$latest" ]; then
    echo "[codex] 되돌릴 백업이 없습니다 ($CODEX_DIR/auth.json.bak.*)" >&2
    exit 1
  fi
  mv -f "$latest" "$AUTH"
  echo "[codex] 되돌림: $(status_line)"
  exit 0
fi

if codex login status >/dev/null 2>&1; then
  echo "[codex] 현재: $(status_line)"
  if [ "$MODE" = "status" ] || [ $SWITCH -eq 0 ]; then
    exit 0
  fi
else
  echo "[codex] 현재: 로그인되어 있지 않음"
  [ "$MODE" = "status" ] && exit 1
fi

if [ "$MODE" = "api-key" ] && [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "[codex] OPENAI_API_KEY 환경변수가 비어 있습니다" >&2
  exit 1
fi

# 계정을 바꿀 때는 기존 인증 파일을 백업해 두고, 새 로그인이 실패하면 되돌린다.
BACKUP=""
if [ $SWITCH -eq 1 ] && [ -f "$AUTH" ]; then
  if ! BACKUP="$(mktemp "$CODEX_DIR/auth.json.bak.XXXXXX")" || ! cp -p "$AUTH" "$BACKUP"; then
    echo "[codex] 기존 인증을 백업하지 못해 계정 전환을 멈춥니다" >&2
    [ -n "$BACKUP" ] && rm -f "$BACKUP"
    exit 1
  fi
  codex logout >/dev/null 2>&1 || true
fi

if [ "$MODE" = "api-key" ]; then
  printenv OPENAI_API_KEY | codex login --with-api-key
elif [ $DEVICE -eq 1 ] || { [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && [ "$(uname -s)" != "Darwin" ]; }; then
  # 브라우저가 없는 서버로 보이면 코드 입력 방식을 쓴다.
  codex login --device-auth
else
  codex login
fi
RC=$?

if [ $RC -ne 0 ] || ! codex login status >/dev/null 2>&1; then
  echo "[codex] 로그인 실패 (exit $RC)" >&2
  if [ -n "$BACKUP" ]; then
    mv -f "$BACKUP" "$AUTH"
    echo "[codex] 이전 계정 인증을 되돌렸습니다: $(status_line)" >&2
  fi
  exit 1
fi

echo "[codex] 완료: $(status_line)"
[ -n "$BACKUP" ] && echo "[codex] 이전 계정 백업: $BACKUP (되돌리기: login.sh --restore)"
[ "$MODE" = "api-key" ] && echo "[codex] API 키는 첫 호출 때 검증됩니다. 실패하면 login.sh --restore로 되돌리세요"
exit 0
