#!/usr/bin/env bash
set -u

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[release-guard] git 저장소가 아닙니다."
  exit 1
fi

_DIR="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
SRC="$_DIR/pre-push-check.sh"
MARK="release-guard/scripts/pre-push-check.sh"
HOOK_DIR="$(git rev-parse --git-path hooks)"
HOOK="$HOOK_DIR/pre-push"

mkdir -p "$HOOK_DIR"

if [ -f "$HOOK" ] && ! grep -q "$MARK" "$HOOK"; then
  echo "[release-guard] 이미 다른 내용의 pre-push 훅이 있습니다: $HOOK"
  echo "[release-guard] 덮어쓰지 않습니다. 이 스크립트 내용을 기존 훅에 합치세요: $SRC"
  exit 1
fi

{
  echo "#!/usr/bin/env bash"
  echo "# release-guard/scripts/pre-push-check.sh 복사본 (jw 플러그인)"
  echo "# 원본을 고쳤으면 setup.sh를 다시 실행해야 반영됩니다."
  tail -n +2 "$SRC"
} > "$HOOK"
chmod +x "$HOOK"

echo "[release-guard] pre-push 훅 설치 완료: $HOOK"
echo "[release-guard] 태그를 푸시할 때만 체크리스트가 돌고, 일반 브랜치 푸시는 영향 없습니다."
echo "[release-guard] 플러그인의 pre-push-check.sh를 업데이트했다면 setup.sh를 다시 실행하세요."
