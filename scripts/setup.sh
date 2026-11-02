#!/bin/bash
# jw 플러그인 설치 뒤 마무리 설정. /jw:setup 스킬이 부르고, 레포에서 터미널로 직접 실행해도 된다
# (터미널이면 API 키 입력과 codex 로그인까지 진행한다).
# 이미 된 단계는 건너뛰므로 여러 번 실행해도 된다.
#
# 사용: setup.sh [--env-file <.env>] [--clean-legacy] [--skip-cli]
#   --env-file      API 키를 이 .env에서 가져온다
#   --clean-legacy  예전 install.sh 설치를 정리한다: ~/.claude/skills/<jw 스킬 이름> 심볼릭 링크와
#                   ~/.claude/settings.json의 옛 전역 세션 훅
#   --skip-cli      agent-browser·codex CLI 설치를 건너뛴다
#
# 하는 일
#   1. 팀 정책: ~/.claude/settings.json env·attribution, ~/.claude/CLAUDE.md 표시선 블록
#      되돌리기: python3 <플러그인>/scripts/team-policy.py --remove ~/.claude/settings.json ~/.claude/CLAUDE.md
#   2. CLI: agent-browser(+전용 Chrome), codex. 터미널이 아니면 codex 로그인은 안내만 한다.
#   3. API 키: secrets.env에 저장. 터미널이 아니면 입력받지 않고 빠진 키만 알린다.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE=""
CLEAN_LEGACY=0
SKIP_CLI=0
while [ $# -gt 0 ]; do
  case "$1" in
    --env-file) ENV_FILE="${2:-}"; shift 2 ;;
    --clean-legacy) CLEAN_LEGACY=1; shift ;;
    --skip-cli) SKIP_CLI=1; shift ;;
    *) echo "사용법: setup.sh [--env-file <.env>] [--clean-legacy] [--skip-cli]" >&2; exit 2 ;;
  esac
done

PY_BIN="python3"
command -v python3 >/dev/null 2>&1 || PY_BIN="python"

echo "== 팀 정책"
"$PY_BIN" "$ROOT/scripts/team-policy.py" "$HOME/.claude/settings.json" "$HOME/.claude/CLAUDE.md" "$ROOT/team-policy.md" \
  || echo "[jw] 팀 정책 적용 실패"

if [ $SKIP_CLI -eq 0 ]; then
  echo "== CLI"
  bash "$ROOT/skills/agent-browser/scripts/setup.sh" || echo "[agent-browser] 설치 실패 — 나중에 다시 실행하세요"
  if [ -t 0 ]; then
    bash "$ROOT/skills/codex/scripts/setup.sh" || echo "[codex] 설치 실패 — 나중에 다시 실행하세요"
  else
    bash "$ROOT/skills/codex/scripts/setup.sh" --no-login || echo "[codex] 설치 실패 — 나중에 다시 실행하세요"
  fi
fi

echo "== API 키"
if [ -n "$ENV_FILE" ]; then
  bash "$ROOT/scripts/keys.sh" --from "$ENV_FILE" </dev/null || true
  [ -t 0 ] && bash "$ROOT/scripts/keys.sh"
else
  bash "$ROOT/scripts/keys.sh" || true
fi

if [ $CLEAN_LEGACY -eq 1 ]; then
  echo "== 예전 설치 정리"
  for d in "$ROOT"/skills/*/; do
    name="$(basename "$d")"
    link="$HOME/.claude/skills/$name"
    # 링크만 지운다. 사용자가 직접 만든 실제 폴더는 건드리지 않는다.
    if [ -L "$link" ]; then
      rm -f "$link"
      echo "removed link: $link"
    fi
  done
  # 예전 install.sh가 ~/.claude/settings.json에 넣은 전역 세션 훅. 다른 훅은 보존한다.
  "$PY_BIN" "$ROOT/scripts/legacy-cleanup.py" "$HOME/.claude/settings.json"
fi

echo "== 상태"
bash "$ROOT/scripts/session-check.sh" --report
echo "팀 정책의 env 설정은 Claude Code를 다시 시작해야 확실히 반영됩니다."
