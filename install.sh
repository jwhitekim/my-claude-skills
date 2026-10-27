#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.claude/skills"

# 이름이 바뀌어 레포에는 더 이상 없는 옛 스킬. 새 이름: 옛 이름
# (macOS 기본 bash 3.2는 연관 배열을 지원하지 않아 함수로 대체)
old_name_for() {
  case "$1" in
    jev-eval) echo "jev" ;;
    gemini-rewrite) echo "gemini" ;;
    deploy-status) echo "deploy-status-guard" ;;
  esac
}

mkdir -p "$TARGET_DIR"

# 설치 전 레포 구성 점검 (경고만 하고 설치는 계속 진행)
if [ -x "$REPO_DIR/skills/skill-lint/scripts/lint.sh" ]; then
  bash "$REPO_DIR/skills/skill-lint/scripts/lint.sh"
fi

for d in "$REPO_DIR"/skills/*/; do
  name="$(basename "$d")"
  target="$TARGET_DIR/$name"

  # $target이 이미 존재하면(실제 디렉터리든 symlink든) 먼저 지운다.
  # 주의: $target이 "디렉터리를 가리키는 symlink"인 상태에서 `ln -sf`를 쓰면,
  # macOS ln이 그 symlink를 교체하는 대신 가리키는 디렉터리 "안쪽"에 새 symlink를
  # 만들어버린다 — $target이 레포 자신을 가리키므로 레포 안에 자기참조 symlink가
  # 생기는 버그가 실제로 있었다. 그래서 -f에 기대지 않고 명시적으로 먼저 지운다.
  rm -rf "$target"
  ln -s "$d" "$target"
  echo "linked: $name"

  # 이름이 바뀐 스킬이면 옛 이름 설치본도 정리
  old_name="$(old_name_for "$name")"
  if [ -n "$old_name" ] && [ -e "$TARGET_DIR/$old_name" ]; then
    rm -rf "$TARGET_DIR/$old_name"
    echo "removed stale: $old_name"
  fi
done

# 세션 시작 점검(repo-health, watch-rules, config-drift-guard)을 전역 설정에 등록한다.
# 프로젝트마다 따로 깔지 않아도 모든 프로젝트에서 돈다. 기존 설정은 settings.json.bak에 남긴다.
PY_BIN="python3"
command -v python3 >/dev/null 2>&1 || PY_BIN="python"
"$PY_BIN" "$REPO_DIR/scripts/global-hooks.py" "$HOME/.claude/settings.json"

# 팀장(메인)·직원(하위 에이전트) 운영 방식. 직원 모델을 haiku로 고정하고
# policies/team-policy.md를 ~/.claude/CLAUDE.md에 표시선 블록으로 넣는다.
# 되돌리기: python3 scripts/team-policy.py --remove ~/.claude/settings.json ~/.claude/CLAUDE.md
"$PY_BIN" "$REPO_DIR/scripts/team-policy.py" "$HOME/.claude/settings.json" "$HOME/.claude/CLAUDE.md" "$REPO_DIR/policies/team-policy.md"

# agent-browser 스킬이 쓰는 CLI와 전용 Chrome. 실패해도 나머지 설치는 계속한다.
bash "$REPO_DIR/skills/agent-browser/scripts/setup.sh" || echo "[agent-browser] 설치 실패 — 나중에 다시 실행하세요"

# codex 스킬이 쓰는 Codex CLI. 터미널에서 실행하면 로그인까지 진행한다.
bash "$REPO_DIR/skills/codex/scripts/setup.sh" || echo "[codex] 설치 실패 — 나중에 다시 실행하세요"

# API 키는 레포 밖 비밀 파일에 둔다. jev-eval/gemini-rewrite 스크립트가 환경변수가 없을 때 여기서 읽는다.
SECRETS_DIR="$HOME/.config/my-claude-skills"
SECRETS="$SECRETS_DIR/secrets.env"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"
touch "$SECRETS"
chmod 600 "$SECRETS"

for key in AI_GATEWAY_API_KEY GEMINI_API_KEY; do
  if grep -q "^${key}=" "$SECRETS"; then
    echo "key: ${key} 이미 저장됨"
    continue
  fi
  value="${!key:-}"
  if [ -n "$value" ]; then
    echo "key: ${key} 현재 환경변수 값을 저장"
  elif [ -t 0 ]; then
    printf "key: %s 입력 (건너뛰려면 Enter): " "$key"
    read -rs value || true
    echo
  fi
  if [ -n "$value" ]; then
    printf '%s=%q\n' "$key" "$value" >> "$SECRETS"
  else
    echo "key: ${key} 건너뜀 — 나중에 ./install.sh를 다시 실행하면 입력할 수 있습니다"
  fi
done
