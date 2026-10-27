#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.claude/skills"

# 이름이 바뀌어 레포에는 더 이상 없는 옛 스킬. 새 이름: 옛 이름
# (macOS 기본 bash 3.2는 연관 배열을 지원하지 않아 함수로 대체)
old_name_for() {
  case "$1" in
    gemini-rewrite) echo "gemini" ;;
    deploy-status) echo "deploy-status-guard" ;;
  esac
}

mkdir -p "$TARGET_DIR"

# 스킬은 skills/<분류>/<이름>/ 에 있다(평평한 skills/<이름>/ 도 지원). 설치 위치는 분류 없이 ~/.claude/skills/<이름>/.
skill_dirs() {
  find "$REPO_DIR/skills" -mindepth 2 -maxdepth 3 -name SKILL.md | sed 's#/SKILL.md$##' | sort
}
skill_dir_of() {
  skill_dirs | awk -v n="$1" -F/ '$NF == n { print; exit }'
}

# 설치 전 레포 구성 점검 (경고만 하고 설치는 계속 진행)
LINT="$(skill_dir_of skill-lint)/scripts/lint.sh"
if [ -x "$LINT" ]; then
  bash "$LINT"
fi

while IFS= read -r d; do
  d="$d/"
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
done < <(skill_dirs)

# 레포에서 지운 스킬의 링크가 남지 않게 정리한다. 이 레포를 가리키는 링크만 대상이다.
for link in "$TARGET_DIR"/*; do
  [ -L "$link" ] || continue
  dest="$(readlink "$link")"
  case "$dest" in
    "$REPO_DIR"/skills/*) [ -e "$dest" ] || { rm -f "$link"; echo "removed stale link: $(basename "$link")"; } ;;
  esac
done

# 세션 시작 점검(repo-health, config-drift-guard)을 전역 설정에 등록한다.
# 프로젝트마다 따로 깔지 않아도 모든 프로젝트에서 돈다. 기존 설정은 settings.json.bak에 남긴다.
PY_BIN="python3"
command -v python3 >/dev/null 2>&1 || PY_BIN="python"
"$PY_BIN" "$REPO_DIR/scripts/global-hooks.py" "$HOME/.claude/settings.json"

# 팀장(메인)·직원(하위 에이전트) 운영 방식. 직원 모델을 haiku로 고정하고
# policies/team-policy.md를 ~/.claude/CLAUDE.md에 표시선 블록으로 넣는다.
# 되돌리기: python3 scripts/team-policy.py --remove ~/.claude/settings.json ~/.claude/CLAUDE.md
"$PY_BIN" "$REPO_DIR/scripts/team-policy.py" "$HOME/.claude/settings.json" "$HOME/.claude/CLAUDE.md" "$REPO_DIR/policies/team-policy.md"

# agent-browser 스킬이 쓰는 CLI와 전용 Chrome. 실패해도 나머지 설치는 계속한다.
bash "$(skill_dir_of agent-browser)/scripts/setup.sh" || echo "[agent-browser] 설치 실패 — 나중에 다시 실행하세요"

# codex 스킬이 쓰는 Codex CLI. 터미널에서 실행하면 로그인까지 진행한다.
bash "$(skill_dir_of codex)/scripts/setup.sh" || echo "[codex] 설치 실패 — 나중에 다시 실행하세요"

# API 키는 레포 밖 비밀 파일에 둔다. gemini-rewrite 스크립트가 환경변수가 없을 때 여기서 읽는다.
SECRETS_DIR="$HOME/.config/my-claude-skills"
SECRETS="$SECRETS_DIR/secrets.env"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"
touch "$SECRETS"
chmod 600 "$SECRETS"

# 레포 루트 .env에 키가 있으면 그 값을 우선 저장한다. 실행(source)하지 않고 해당 키 줄만 읽는다.
DOTENV="$REPO_DIR/.env"
dotenv_value() {
  [ -f "$DOTENV" ] || return 0
  local line
  line="$(grep -E "^[[:space:]]*(export[[:space:]]+)?$1=" "$DOTENV" | tail -1 | tr -d '\r')" || true
  line="${line#*=}"
  case "$line" in
    \"*\") line="${line#\"}"; line="${line%\"}" ;;
    \'*\') line="${line#\'}"; line="${line%\'}" ;;
  esac
  printf '%s' "$line"
}

for key in AI_GATEWAY_API_KEY GEMINI_API_KEY; do
  value="$(dotenv_value "$key")"
  if [ -n "$value" ]; then
    # 환경변수를 저장값으로 오인하지 않게 subshell에서 먼저 지운 뒤 파일만 읽는다.
    saved="$( unset "$key"; . "$SECRETS" 2>/dev/null; printf '%s' "${!key:-}" )"
    if [ "$saved" = "$value" ]; then
      echo "key: ${key} 이미 저장됨 (.env와 같음)"
      continue
    fi
    # 키가 든 임시 파일이 잠깐이라도 넓은 권한으로 생기지 않게 umask를 좁혀 만든다.
    ( umask 077; grep -v "^${key}=" "$SECRETS" > "$SECRETS.tmp" || true )
    printf '%s=%q\n' "$key" "$value" >> "$SECRETS.tmp"
    mv "$SECRETS.tmp" "$SECRETS"
    chmod 600 "$SECRETS"
    echo "key: ${key} .env 값으로 저장"
    continue
  fi
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
    echo "key: ${key} 건너뜀 — 레포 루트 .env에 넣거나 나중에 ./install.sh를 다시 실행하면 입력할 수 있습니다"
  fi
done
