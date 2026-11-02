#!/usr/bin/env bash
set -u
_DIR="${BASH_SOURCE[0]%/*}"

PY_BIN="python3"
command -v python3 >/dev/null 2>&1 || PY_BIN="python"

# 예전 설치(껍데기 훅 파일과 settings.json 등록)가 있으면 걷어낸다. 플러그인 훅으로 대체됐다.
rm -f .claude/hooks/deploy-status-hook.sh
if [ -f .claude/settings.json ]; then
  "$PY_BIN" "$_DIR/merge-settings.py" .claude/settings.json || {
    echo "[deploy-status] .claude/settings.json을 읽지 못했습니다 — 직접 확인하세요."
    exit 1
  }
fi

if [ ! -d .github/workflows ]; then
  echo "[deploy-status] .github/workflows가 없습니다 — 이 프로젝트엔 켤 대상이 없습니다."
  exit 0
fi

mkdir -p .claude
cat > .claude/deploy-status.enabled <<'MARKER'
# jw deploy-status: push 뒤 배포 상태를 자동 확인합니다. 끄려면 이 파일을 삭제하세요.
MARKER
echo "[deploy-status] 자동 확인 켜짐 — .claude/deploy-status.enabled 생성. 끄려면 이 파일을 삭제."
echo "[deploy-status] push 직후 기본 최대 300초간 상태를 기다립니다(DEPLOY_STATUS_WAIT_SECONDS로 조절) — 그동안 다음 턴이 지연될 수 있습니다."
