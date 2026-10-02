#!/usr/bin/env bash
set -u
_DIR="${BASH_SOURCE[0]%/*}"
SKILL="$(cd "$_DIR/.." && pwd)"
S="$SKILL/scripts"

PY_BIN="python3"
command -v python3 >/dev/null 2>&1 || PY_BIN="python"

if [ ! -d .github/workflows ]; then
  echo "[deploy-status] .github/workflows가 없습니다 — 이 프로젝트엔 설치할 대상이 없습니다."
  exit 0
fi

mkdir -p .claude/hooks
cat > .claude/hooks/deploy-status-hook.sh <<'SHIM'
#!/usr/bin/env bash
# 껍데기. 내용은 ~/.claude/skills/deploy-status/scripts/post-push-hook.sh 에 한 벌만 둔다.
. "$HOME/.claude/skills/deploy-status/scripts/post-push-hook.sh"
SHIM
chmod +x .claude/hooks/deploy-status-hook.sh
echo "[deploy-status] 훅 등록 (껍데기) - .claude/hooks/deploy-status-hook.sh"

mkdir -p .claude
[ -f .claude/settings.json ] || echo '{}' > .claude/settings.json

"$PY_BIN" "$S/merge-settings.py" .claude/settings.json

echo "[deploy-status] 설치 완료. 세션을 재시작(/exit 후 재진입)해야 적용됩니다."
echo "[deploy-status] push 직후 최대 5분간 배포 상태를 기다립니다 — 그동안 다음 턴이 지연될 수 있습니다."
