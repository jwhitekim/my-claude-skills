#!/usr/bin/env bash
# Codex에 한 번 묻고 마지막 답만 stdout으로 낸다. 세션 ID는 stderr로 낸다.
#
# 사용: ask.sh [옵션] "<프롬프트>"   또는   ask.sh [옵션] < prompt.txt
# 옵션은 프롬프트보다 앞에 둔다.
#   --write          파일 수정 허용(workspace-write). 작업 디렉터리와 /tmp 안에서만 쓸 수 있다.
#   --add-dir <DIR>  작업 디렉터리 밖에 쓰기를 허용할 디렉터리(반복 가능). --write를 포함한다.
#   --resume <ID>    이전 세션에 이어서 묻는다. ID는 이전 호출의 stderr에 나온다.
#   --cd <DIR>       Codex의 작업 디렉터리. 기본은 현재 디렉터리.
#   --effort <LEVEL> 추론 강도(low|medium|high|xhigh). 기본은 ~/.codex/config.toml 값.
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SANDBOX="read-only"
RESUME=""
WORKDIR="$PWD"
EFFORT=""
ADD_DIRS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --write) SANDBOX="workspace-write"; shift ;;
    --add-dir)
      dir="$(cd "${2:?--add-dir에 디렉터리가 필요합니다}" && pwd)" || exit 1
      # TOML 문자열에 그대로 넣으므로 따옴표·역슬래시·개행이 든 경로는 받지 않는다.
      case "$dir" in
        *'"'*|*'\'*|*$'\n'*) echo "[codex] --add-dir 경로에 따옴표·역슬래시·개행은 쓸 수 없습니다: $dir" >&2; exit 1 ;;
      esac
      ADD_DIRS+=("$dir"); SANDBOX="workspace-write"; shift 2 ;;
    --resume) RESUME="${2:?--resume에 세션 ID가 필요합니다}"; shift 2 ;;
    --cd) WORKDIR="${2:?--cd에 디렉터리가 필요합니다}"; shift 2 ;;
    --effort) EFFORT="${2:?--effort에 값이 필요합니다}"; shift 2 ;;
    --) shift; break ;;
    -*) echo "[codex] 알 수 없는 옵션: $1" >&2; exit 1 ;;
    *) break ;;
  esac
done

require_codex

if [ $# -gt 1 ]; then
  echo "[codex] 프롬프트는 따옴표로 묶어 하나로 넘기세요 (옵션은 프롬프트 앞에)" >&2
  exit 1
elif [ $# -eq 1 ]; then
  PROMPT="$1"
else
  PROMPT="$(cat)"
fi
if [ -z "$PROMPT" ]; then
  echo "[codex] 프롬프트가 비어 있습니다" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# resume에는 -s, --add-dir가 없어 설정값으로 넘긴다. 새 세션도 같은 방식으로 맞춘다.
OPTS=(--json --skip-git-repo-check -o "$TMP/last.txt" -c "sandbox_mode=\"$SANDBOX\"")
[ -n "$EFFORT" ] && OPTS+=(-c "model_reasoning_effort=\"$EFFORT\"")
if [ ${#ADD_DIRS[@]} -gt 0 ]; then
  roots=""
  for d in "${ADD_DIRS[@]}"; do roots+="${roots:+,}\"$d\""; done
  OPTS+=(-c "sandbox_workspace_write.writable_roots=[$roots]")
fi

# 프롬프트는 stdin으로 넘긴다. 인자로 넘기면 Codex가 빈 stdin을 기다리며 멈출 수 있다.
cd "$WORKDIR"
set +e
if [ -n "$RESUME" ]; then
  printf '%s' "$PROMPT" | codex exec resume "${OPTS[@]}" "$RESUME" - >"$TMP/events.jsonl" 2>"$TMP/err.txt"
else
  printf '%s' "$PROMPT" | codex exec "${OPTS[@]}" - >"$TMP/events.jsonl" 2>"$TMP/err.txt"
fi
RC=$?
set -e

SESSION="$(grep '"thread.started"' "$TMP/events.jsonl" | head -1 \
  | sed -n 's/.*"thread_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' || true)"
[ -z "$SESSION" ] && SESSION="$RESUME"

if [ $RC -ne 0 ] || [ ! -s "$TMP/last.txt" ]; then
  echo "[codex] 실패 (exit $RC)" >&2
  grep '"type":"error"\|"type":"turn.failed"' "$TMP/events.jsonl" >&2 || true
  tail -20 "$TMP/err.txt" >&2
  exit 1
fi

cat "$TMP/last.txt"; echo
if [ -n "$SESSION" ]; then
  echo "[codex] session: $SESSION (이어 묻기: --resume $SESSION)" >&2
else
  echo "[codex] session: 알 수 없음 (출력에서 세션 ID를 찾지 못해 이어 묻기 불가)" >&2
fi
