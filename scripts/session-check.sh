#!/bin/bash
# jw 플러그인 준비 상태를 점검한다. 아무것도 고치지 않는다.
# 플러그인 SessionStart(startup) 훅이 부르고, 빠진 것이 있을 때만 한 줄 알린다.
#
# 사용: session-check.sh            빠진 항목만 한 줄로 출력(없으면 출력 없음)
#       session-check.sh --report   항목별 상태를 모두 출력
# 끄기: 환경변수 JW_SKIP_SETUP_CHECK=1
set -u

[ "${JW_SKIP_SETUP_CHECK:-0}" = "1" ] && [ "${1:-}" != "--report" ] && exit 0

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY_BIN="python3"
command -v python3 >/dev/null 2>&1 || PY_BIN="python"
REPORT=0
[ "${1:-}" = "--report" ] && REPORT=1

missing=()
line() { [ $REPORT -eq 1 ] && printf '  %-14s %s\n' "$1" "$2"; return 0; }

if "$PY_BIN" "$ROOT/scripts/team-policy.py" --check \
    "$HOME/.claude/settings.json" "$HOME/.claude/CLAUDE.md" "$ROOT/team-policy.md" 2>/dev/null; then
  line "팀 정책" "적용됨"
else
  line "팀 정책" "미적용 또는 내용이 바뀜"
  missing+=("팀 정책")
fi

for cli in agent-browser codex; do
  found=0
  command -v "$cli" >/dev/null 2>&1 && found=1
  # codex는 nvm으로 설치돼 PATH에 아직 없을 수 있다.
  if [ $found -eq 0 ] && [ "$cli" = codex ] && [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
    ( . "${NVM_DIR:-$HOME/.nvm}/nvm.sh" >/dev/null 2>&1; command -v codex >/dev/null 2>&1 ) && found=1
  fi
  if [ $found -eq 1 ]; then
    line "$cli" "설치됨"
  else
    line "$cli" "없음"
    missing+=("$cli")
  fi
done

if keys="$(bash "$ROOT/scripts/keys.sh" --check 2>/dev/null)"; then
  line "API 키" "필수 키 모두 있음"
else
  line "API 키" "없음: $keys"
  missing+=("API 키($keys)")
fi

# 예전 install.sh가 만든 심볼릭 링크가 남으면 같은 스킬이 두 번 뜬다.
legacy=0
for d in "$ROOT"/skills/*/; do
  name="$(basename "$d")"
  [ -L "$HOME/.claude/skills/$name" ] && legacy=1 && break
done
grep -q '/\.claude/skills/repo-health/scripts/' "$HOME/.claude/settings.json" 2>/dev/null && legacy=1
if [ $legacy -eq 1 ]; then
  line "예전 설치" "~/.claude/skills 링크 또는 옛 전역 훅이 남아 있음 (/jw:setup 예전 설치 정리)"
  missing+=("예전 설치 정리")
else
  line "예전 설치" "없음"
fi

if [ $REPORT -eq 0 ] && [ ${#missing[@]} -gt 0 ]; then
  joined="$(printf '%s, ' "${missing[@]}")"
  echo "[jw] 준비 안 된 항목: ${joined%, } — /jw:setup 으로 마무리하세요 (알림 끄기: JW_SKIP_SETUP_CHECK=1)"
fi
exit 0
