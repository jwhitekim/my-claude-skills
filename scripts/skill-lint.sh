#!/usr/bin/env bash
# my-claude-skills 레포의 스킬(skills/<이름>/SKILL.md) 구성을 검사한다. 경고만 하고 아무것도 고치지 않는다.
# 검사: SKILL.md 존재, frontmatter name과 폴더명 일치, description 비어있음 여부,
# SKILL.md의 scripts/*.sh·py 참조 경로 존재(${CLAUDE_SKILL_DIR}, ${CLAUDE_PLUGIN_ROOT}/skills/<다른스킬>, 중첩 경로 포함),
# SKILL.md에 남은 예전 설치 경로(~/.claude/skills) 참조, scripts/*.sh 실행 권한, README 스킬 등재.
# 전체 검사에서는 스킬이 하나도 없는지와 description 완전 중복도 확인한다.
# 스킬은 플러그인 jw로 배포되므로(호출명 jw:<이름>) 폴더명이 곧 스킬 이름이다.
# 사용법: bash scripts/skill-lint.sh            전체 스킬 검사
#        bash scripts/skill-lint.sh <스킬명>    해당 스킬만 검사
set -u

_DIR="${BASH_SOURCE[0]%/*}"
# 호출한 작업 디렉터리와 무관하게 실제 스크립트 경로에서 플러그인 매니페스트(.claude-plugin/plugin.json)가 있는 곳까지 올라간다.
REPO_DIR="$(cd "$_DIR" && pwd -P)"
while [ "$REPO_DIR" != "/" ] && [ ! -f "$REPO_DIR/.claude-plugin/plugin.json" ]; do
  REPO_DIR="$(dirname "$REPO_DIR")"
done
if [ ! -f "$REPO_DIR/.claude-plugin/plugin.json" ]; then
  echo "[skill-lint] .claude-plugin/plugin.json을 찾지 못해 레포 루트를 정할 수 없음"
  exit 1
fi

# 스킬 폴더 목록. skills/ 바로 아래(깊이 1)의 */SKILL.md 가 있는 폴더를 찾는다.
skill_dirs() {
  [ -d "$REPO_DIR/skills" ] || return 0
  find "$REPO_DIR/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | sed 's#/SKILL.md$##' | sort
}
# 이름으로 스킬 폴더를 찾는다. 없으면 빈 문자열.
skill_dir_of() {
  skill_dirs | awk -v n="$1" -F/ '$NF == n { print; exit }'
}
README="$REPO_DIR/README.md"

TARGET="${1:-}"
ISSUES=0

warn() {
  echo "[skill-lint] $1"
  ISSUES=$((ISSUES + 1))
}

# README에 등장하는 스킬명을 모아둔다. 백틱으로 감싼 `이름` 또는 `jw:이름`, 그리고 본문의 jw:이름 표기를 모두 인식하고 jw: 접두어는 뗀다.
README_NAMES=""
if [ -f "$README" ]; then
  README_NAMES=$( {
    grep -oE '`(jw:)?[a-z][a-z0-9_-]*`' "$README" | tr -d '`'
    grep -oE 'jw:[a-z][a-z0-9_-]*' "$README"
  } | sed 's/^jw://' | sort -u )
fi

check_skill() {
  local dir="$1"
  local name
  name="$(basename "$dir")"

  local skill_md="$dir/SKILL.md"
  if [ ! -f "$skill_md" ]; then
    warn "$name: SKILL.md가 없음"
    return
  fi

  # frontmatter의 name: 필드
  local fm_name
  fm_name=$(awk -F': ' '/^name:/{print $2; exit}' "$skill_md" | tr -d '\r')
  if [ -z "$fm_name" ]; then
    warn "$name: SKILL.md frontmatter에 name: 필드가 없음"
  elif [ "$fm_name" != "$name" ]; then
    warn "$name: frontmatter name(${fm_name})이 폴더명과 다름"
  fi

  # frontmatter의 description: 필드
  local has_desc
  has_desc=$(awk -F': ' '/^description:/{print $2; exit}' "$skill_md")
  if [ -z "$has_desc" ]; then
    warn "$name: SKILL.md frontmatter에 description: 필드가 비어있음"
  fi

  # SKILL.md가 언급하는 scripts/*.sh|py 경로가 실제로 존재하는지.
  # 기준 폴더:
  #   skills/<다른스킬>/scripts/... (또는 ${CLAUDE_PLUGIN_ROOT}/skills/<다른스킬>/scripts/...) → 그 스킬 폴더
  #   ${CLAUDE_SKILL_DIR}/scripts/... 또는 scripts/... → 자기 스킬 폴더
  # 중첩 경로(scripts/migration/check.sh)도 잡는다.
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    case "$ref" in
      *skills/*/scripts/*)
        local rest="${ref#*skills/}"
        local ref_skill="${rest%%/*}"
        local ref_path="scripts/${ref#*scripts/}"
        local ref_dir
        ref_dir="$(skill_dir_of "$ref_skill")"
        if [ -z "$ref_dir" ] || [ ! -f "$ref_dir/$ref_path" ]; then
          warn "$name: SKILL.md가 참조하는 ${ref}가 존재하지 않음"
        fi
        ;;
      '${CLAUDE_PLUGIN_ROOT}/scripts/'*)
        # 플러그인 루트(레포 루트)의 공용 스크립트
        [ -f "$REPO_DIR/scripts/${ref#*scripts/}" ] || warn "$name: SKILL.md가 참조하는 ${ref}가 존재하지 않음"
        ;;
      *)
        local own_path="scripts/${ref#*scripts/}"
        [ -f "$dir/$own_path" ] || warn "$name: SKILL.md가 참조하는 ${ref}가 존재하지 않음"
        ;;
    esac
  done < <(grep -oE '(\$\{CLAUDE_SKILL_DIR\}/|\$\{CLAUDE_PLUGIN_ROOT\}/)?(skills/[A-Za-z0-9_-]+/)?scripts/[A-Za-z0-9_./-]+\.(sh|py)' "$skill_md" | sort -u)

  # 예전 설치 경로(~/.claude/skills) 참조가 남아 있는지. 플러그인 설치에서는 깨진 경로다.
  local legacy_lines
  legacy_lines=$(grep -nE '\.claude/skills/[A-Za-z0-9_-]+/scripts/' "$skill_md" | cut -d: -f1 | paste -sd, - || true)
  if [ -n "$legacy_lines" ]; then
    warn "$name: SKILL.md에 예전 설치 경로(~/.claude/skills) 참조가 남아 있음 (줄: ${legacy_lines})"
  fi

  # scripts/ 안의 .sh 파일이 실행 권한을 가지는지
  if [ -d "$dir/scripts" ]; then
    while IFS= read -r script; do
      [ -f "$script" ] || continue
      if [ ! -x "$script" ]; then
        warn "$name: $(basename "$script")에 실행 권한이 없음 (chmod +x 필요)"
      fi
    done < <(find "$dir/scripts" -maxdepth 1 -name '*.sh')
  fi

  # README에 이 스킬이 등장하는지
  if [ -n "$README_NAMES" ] && ! echo "$README_NAMES" | grep -qx "$name"; then
    warn "$name: README.md 스킬 목록에 없음"
  fi
}

if [ -n "$TARGET" ]; then
  target_dir="$(skill_dir_of "$TARGET")"
  if [ -n "$target_dir" ]; then
    check_skill "$target_dir"
  else
    echo "[skill-lint] 스킬을 찾을 수 없음: $TARGET"
    exit 1
  fi
else
  if [ -z "$(skill_dirs)" ]; then
    warn "skills/ 아래에 SKILL.md가 있는 스킬이 0개임. 레포 구조를 확인하세요."
  fi

  while IFS= read -r dir; do
    check_skill "$dir"
  done < <(skill_dirs)

  # 스킬 간 description 완전 중복(복붙 실수) 검사 — 전체 스캔일 때만 의미 있음
  DUP=$(skill_dirs | while IFS= read -r d; do f="$d/SKILL.md"
    [ -f "$f" ] || continue
    desc=$(awk -F': ' '/^description:/{print substr($0, index($0,$2)); exit}' "$f")
    [ -z "$desc" ] && continue
    echo "${desc}|||$(basename "$(dirname "$f")")"
  done | sort | awk -F'\\|\\|\\|' '{
    if ($1 == prev_desc) { print prev_name " / " $2 }
    prev_desc=$1; prev_name=$2
  }')
  if [ -n "$DUP" ]; then
    while IFS= read -r pair; do
      warn "description이 완전히 동일한 스킬: $pair"
    done <<< "$DUP"
  fi
fi

if [ "$ISSUES" -eq 0 ]; then
  echo "[skill-lint] 문제 없음"
fi
exit 0
