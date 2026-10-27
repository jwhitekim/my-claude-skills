#!/usr/bin/env bash
# my-claude-skills 레포의 스킬(skills/<이름>/ 또는 skills/<분류>/<이름>/) 구성을 검사한다. 경고만 하고 아무것도 고치지 않는다.
# 검사: SKILL.md 존재, frontmatter name과 폴더명 일치, description 비어있음 여부,
# SKILL.md의 scripts/*.sh·py 참조 경로 존재, scripts/*.sh 실행 권한, README 스킬 등재.
# 전체 검사에서는 스킬명 중복과 description 완전 중복도 확인한다.
# 사용법: bash scripts/skill-lint.sh            전체 스킬 검사
#        bash scripts/skill-lint.sh <스킬명>    해당 스킬만 검사
set -u

_DIR="${BASH_SOURCE[0]%/*}"
# 호출한 작업 디렉터리와 무관하게 실제 스크립트 경로에서 install.sh가 있는 곳까지 올라간다.
REPO_DIR="$(cd "$_DIR" && pwd -P)"
while [ "$REPO_DIR" != "/" ] && [ ! -f "$REPO_DIR/install.sh" ]; do
  REPO_DIR="$(dirname "$REPO_DIR")"
done
SKILLS_DIR="$REPO_DIR/skills"

# 스킬 폴더 목록. 분류 폴더(skills/<분류>/<이름>/)와 평평한 구조(skills/<이름>/)를 모두 찾는다.
skill_dirs() {
  find "$SKILLS_DIR" -mindepth 2 -maxdepth 3 -name SKILL.md | sed 's#/SKILL.md$##' | sort
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

# README에 등장하는 스킬명(백틱으로 감싼 `이름` 패턴)을 모아둔다 — 항목 5에서 재사용.
README_NAMES=""
if [ -f "$README" ]; then
  README_NAMES=$(grep -oE '`[a-z][a-z0-9_-]*`' "$README" | tr -d '`')
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
  # "skills/<다른스킬>/scripts/X" 형태면 그 스킬 기준으로, 아니면 자기 폴더 기준으로 본다.
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    case "$ref" in
      skills/*/scripts/*)
        local ref_skill="${ref#skills/}"
        ref_skill="${ref_skill%%/*}"
        local ref_path="scripts/${ref##*/scripts/}"
        local ref_dir
        ref_dir="$(skill_dir_of "$ref_skill")"
        [ -n "$ref_dir" ] && [ -f "$ref_dir/$ref_path" ] || warn "$name: SKILL.md가 참조하는 ${ref}가 존재하지 않음"
        ;;
      *)
        [ -f "$dir/$ref" ] || warn "$name: SKILL.md가 참조하는 ${ref}가 존재하지 않음"
        ;;
    esac
  done < <(grep -oE '(skills/[A-Za-z0-9_-]+/)?scripts/[A-Za-z0-9_.-]+\.(sh|py)' "$skill_md" | sort -u)

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
  while IFS= read -r dir; do
    check_skill "$dir"
  done < <(skill_dirs)

  # 분류 폴더가 달라도 설치 위치(~/.claude/skills/<이름>)는 하나라 이름이 겹치면 안 된다.
  while IFS= read -r dup_name; do
    warn "같은 이름의 스킬이 두 곳 이상에 있음: $dup_name"
  done < <(skill_dirs | awk -F/ '{print $NF}' | sort | uniq -d)

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
