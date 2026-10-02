#!/usr/bin/env bash
set -u
_DIR="${BASH_SOURCE[0]%/*}"
SKILL="$(cd "$_DIR/.." && pwd)"
S="$SKILL/scripts"

PY_BIN="python3"
command -v python3 >/dev/null 2>&1 || PY_BIN="python"

mkdir -p .claude/hooks
cat > .claude/hooks/repo-health.sh <<'SHIM'
#!/usr/bin/env bash
# 껍데기. 내용은 ~/.claude/skills/repo-health/scripts/scan.sh 에 한 벌만 둔다.
bash "$HOME/.claude/skills/repo-health/scripts/scan.sh" summary
SHIM
chmod +x .claude/hooks/repo-health.sh
echo "[repo-health] 훅 등록 (껍데기) - .claude/hooks/repo-health.sh"

mkdir -p .claude
[ -f .claude/settings.json ] || echo '{}' > .claude/settings.json

"$PY_BIN" "$S/merge-settings.py" .claude/settings.json

echo "[repo-health] 설치 완료. 세션을 재시작(/exit 후 재진입)해야 적용됩니다."
