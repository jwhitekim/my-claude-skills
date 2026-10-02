#!/usr/bin/env bash
# fast-forward 푸시만 한다. force push 옵션 자체를 받지 않으므로 이 스크립트로는
# force push가 구조적으로 불가능하다 — 그건 이 스킬의 범위 밖(사람이 직접 위험을
# 인지하고 실행해야 하는 작업).
#
# 원격을 fetch해서 로컬이 뒤처지거나 갈라졌으면(diverged) push하지 않고 거부한다.
# 사용: safe-push.sh [remote] [branch]
set -euo pipefail

REMOTE="${1:-origin}"
BRANCH="${2:-$(git branch --show-current)}"

# 원격에 아직 이 브랜치가 없으면(첫 푸시) fetch할 것이 없다. ls-remote의 exit 2가 "없음"이고,
# 그 외 실패(네트워크 등)는 그대로 멈춘다.
RC=0
git ls-remote --exit-code --heads "$REMOTE" "$BRANCH" >/dev/null || RC=$?
if [ "$RC" -eq 0 ]; then
  git fetch "$REMOTE" "$BRANCH"
elif [ "$RC" -ne 2 ]; then
  echo "원격($REMOTE) 조회 실패 (exit $RC). 네트워크나 원격 주소를 확인하세요." >&2
  exit 1
fi

LOCAL=$(git rev-parse HEAD)
# --verify --quiet: 없으면 빈 값. (그냥 rev-parse는 없는 이름을 그대로 출력해버린다)
REMOTE_REF=$(git rev-parse --verify --quiet "refs/remotes/$REMOTE/$BRANCH" || true)

if [ -n "$REMOTE_REF" ] && [ "$REMOTE_REF" != "$LOCAL" ]; then
  # 공통 조상이 아예 없으면(기록이 따로 시작됨) 빈 값 → 아래에서 거부된다.
  BASE=$(git merge-base HEAD "$REMOTE_REF" || true)
  if [ "$BASE" != "$REMOTE_REF" ]; then
    echo "REFUSED: 원격($REMOTE/$BRANCH)이 로컬에 없는 커밋을 갖고 있습니다(뒤처짐/분기됨)." >&2
    echo "  local:  $LOCAL" >&2
    echo "  remote: $REMOTE_REF" >&2
    echo "  base:   $BASE" >&2
    echo "먼저 pull/rebase로 반영한 뒤 다시 시도하세요. force push는 이 스크립트로 할 수 없습니다." >&2
    exit 1
  fi
fi

git push "$REMOTE" "$BRANCH"
