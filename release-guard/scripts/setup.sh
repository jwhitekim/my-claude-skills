#!/usr/bin/env bash
set -u

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[release-guard] git 저장소가 아닙니다."
  exit 1
fi

HOOK_DIR="$(git rev-parse --git-dir)/hooks"
HOOK="$HOOK_DIR/pre-push"
MARK="release-guard/scripts/pre-push-check.sh"

mkdir -p "$HOOK_DIR"

if [ -f "$HOOK" ] && ! grep -q "$MARK" "$HOOK"; then
  echo "[release-guard] 이미 다른 내용의 pre-push 훅이 있습니다: $HOOK"
  echo "[release-guard] 덮어쓰지 않습니다 — 기존 훅 끝에 아래 줄을 수동으로 추가하세요:"
  echo "    bash \"\$HOME/.claude/skills/release-guard/scripts/pre-push-check.sh\""
  exit 1
fi

cat > "$HOOK" <<'SHIM'
#!/usr/bin/env bash
# 껍데기. 내용은 ~/.claude/skills/release-guard/scripts/pre-push-check.sh 에 한 벌만 둔다.
exec bash "$HOME/.claude/skills/release-guard/scripts/pre-push-check.sh"
SHIM
chmod +x "$HOOK"
echo "[release-guard] pre-push 훅 설치 완료: $HOOK"
echo "[release-guard] 태그를 푸시할 때만 체크리스트가 돌고, 일반 브랜치 푸시는 영향 없습니다."
