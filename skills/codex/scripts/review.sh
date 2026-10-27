#!/usr/bin/env bash
# Codex 내장 코드 리뷰(codex exec review)를 읽기 전용으로 돌리고 리뷰 결과만 stdout으로 낸다.
#
# 사용: review.sh [--uncommitted | --base <브랜치> | --commit <SHA>] [--cd <DIR>] [--effort <LEVEL>] ["<추가 지시>"]
#   범위를 안 주면 --uncommitted로 본다. 옵션은 추가 지시보다 앞에 둔다.
#   리뷰 결과를 두고 더 묻고 싶으면 ask.sh로 새로 묻는다(리뷰 세션은 이어 묻지 않는다).
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

WORKDIR="$PWD"
EFFORT=""
SCOPE=()
SCOPE_TEXT=""
set_scope() {
  if [ ${#SCOPE[@]} -gt 0 ]; then
    echo "[codex] 리뷰 범위는 하나만 지정하세요" >&2
    exit 1
  fi
  SCOPE=("$@")
}

while [ $# -gt 0 ]; do
  case "$1" in
    --uncommitted) set_scope --uncommitted; SCOPE_TEXT="커밋하지 않은 변경(staged, unstaged, untracked 모두)"; shift ;;
    --base) set_scope --base "${2:?--base에 브랜치가 필요합니다}"; SCOPE_TEXT="$2 브랜치와의 merge-base 대비 현재 작업 트리의 변경(git diff \$(git merge-base HEAD $2)). 커밋하지 않은 추적 파일 변경도 포함"; shift 2 ;;
    --commit) set_scope --commit "${2:?--commit에 SHA가 필요합니다}"; SCOPE_TEXT="커밋 $2가 도입한 변경(git show $2)"; shift 2 ;;
    --cd) WORKDIR="${2:?--cd에 디렉터리가 필요합니다}"; shift 2 ;;
    --effort) EFFORT="${2:?--effort에 값이 필요합니다}"; shift 2 ;;
    --) shift; break ;;
    -*) echo "[codex] 알 수 없는 옵션: $1" >&2; exit 1 ;;
    *) break ;;
  esac
done
if [ ${#SCOPE[@]} -eq 0 ]; then
  SCOPE=(--uncommitted)
  SCOPE_TEXT="커밋하지 않은 변경(staged, unstaged, untracked 모두)"
fi
if [ $# -gt 1 ]; then
  echo "[codex] 추가 지시는 따옴표로 묶어 하나로 넘기세요" >&2
  exit 1
fi

require_codex

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OPTS=(-o "$TMP/last.txt" -c 'sandbox_mode="read-only"')
[ -n "$EFFORT" ] && OPTS+=(-c "model_reasoning_effort=\"$EFFORT\"")

cd "$WORKDIR"
set +e
if [ $# -eq 1 ]; then
  # CLI는 범위 옵션과 프롬프트를 함께 받지 않는다. 추가 지시가 있으면 범위를 프롬프트에 적는다.
  printf '리뷰 대상: %s\n\n%s' "$SCOPE_TEXT" "$1" \
    | codex exec review "${OPTS[@]}" - >"$TMP/out.txt" 2>"$TMP/err.txt"
else
  codex exec review "${SCOPE[@]}" "${OPTS[@]}" </dev/null >"$TMP/out.txt" 2>"$TMP/err.txt"
fi
RC=$?
set -e

if [ $RC -ne 0 ] || [ ! -s "$TMP/last.txt" ]; then
  echo "[codex] 리뷰 실패 (exit $RC)" >&2
  tail -20 "$TMP/err.txt" >&2
  exit 1
fi

cat "$TMP/last.txt"; echo
