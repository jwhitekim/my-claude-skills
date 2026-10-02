#!/usr/bin/env bash
# my-claude-skills 레포의 skills/*/ 구성을 검사한다. 경고만 하고 아무것도 고치지 않는다.
# 사용법: lint.sh            전체 스킬 검사
#        lint.sh <스킬명>    해당 스킬만 검사
set -u

_DIR="${BASH_SOURCE[0]%/*}"
REPO_DIR="$(cd "$_DIR/../../.." && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
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
        [ -f "$SKILLS_DIR/$ref_skill/$ref_path" ] || warn "$name: SKILL.md가 참조하는 ${ref}가 존재하지 않음"
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
  if [ -d "$SKILLS_DIR/$TARGET" ]; then
    check_skill "$SKILLS_DIR/$TARGET"
  else
    echo "[skill-lint] 스킬을 찾을 수 없음: $TARGET"
    exit 1
  fi
else
  for dir in "$SKILLS_DIR"/*/; do
    check_skill "$dir"
  done

  # 스킬 간 description 완전 중복(복붙 실수) 검사 — 전체 스캔일 때만 의미 있음
  DUP=$(for f in "$SKILLS_DIR"/*/SKILL.md; do
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
