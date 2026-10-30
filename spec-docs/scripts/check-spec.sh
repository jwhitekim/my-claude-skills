#!/usr/bin/env bash
set -uo pipefail

# 사용법: check-spec.sh <spec.md 파일 경로 또는 docs/ 디렉터리>
TARGET="${1:?사용법: check-spec.sh <spec.md 파일 또는 docs/ 디렉터리>}"
FAIL=0

check_spec_file() {
  local f="$1"
  # Requirement 제목 형식
  if grep -n '^### Requirement:' "$f" >/dev/null 2>&1; then
    while IFS=: read -r lineno _; do
      # 해당 Requirement 아래 첫 비어있지 않은 문장이 SHALL로 끝나는지 대략 확인
      sentence=$(sed -n "$((lineno+1)),$((lineno+5))p" "$f" | grep -v '^#' | grep -v '^\s*$' | head -1)
      if [ -n "$sentence" ] && ! echo "$sentence" | grep -q 'SHALL'; then
        echo "[$f:$lineno] Requirement 문장에 SHALL이 없습니다: $sentence"
        FAIL=1
      fi
    done < <(grep -n '^### Requirement:' "$f")
  fi

  # Scenario 형식: GIVEN/WHEN/THEN 3개 모두 있는지, 볼드(**) 사용 여부
  if grep -n '^#### Scenario:' "$f" >/dev/null 2>&1; then
    while IFS=: read -r lineno _; do
      block=$(sed -n "$((lineno+1)),$((lineno+6))p" "$f")
      for kw in GIVEN WHEN THEN; do
        if ! echo "$block" | grep -q -- "- $kw "; then
          echo "[$f:$lineno] Scenario에 $kw 항목이 없습니다(형식: - $kw <내용>, 볼드 금지)"
          FAIL=1
        fi
      done
      if echo "$block" | grep -qE '\*\*(GIVEN|WHEN|THEN)\*\*'; then
        echo "[$f:$lineno] Scenario에 볼드체(**GIVEN** 등)가 사용됐습니다 — plain text만 허용"
        FAIL=1
      fi
    done < <(grep -n '^#### Scenario:' "$f")
  fi
}

check_docs_tree() {
  local root="$1"
  # 금지 파일/폴더 이름
  local forbidden
  forbidden=$(find "$root" \( -name 'openspec' -o -name 'AGENTS.md' -o -regex '.*-v[0-9][0-9.]*\.md' \) 2>/dev/null)
  if [ -n "$forbidden" ]; then
    echo "금지된 이름의 파일/폴더 발견:"
    echo "$forbidden"
    FAIL=1
  fi

  # capability별 design.md/tasks.md 중복
  local dup
  dup=$(find "$root/specs" -mindepth 2 \( -name 'design.md' -o -name 'tasks.md' \) 2>/dev/null)
  if [ -n "$dup" ]; then
    echo "capability별로 별도 design.md/tasks.md가 있습니다(프로젝트에 1개씩만 허용):"
    echo "$dup"
    FAIL=1
  fi

  # contract.md 최근 변경 경고(git 저장소인 경우만)
  if [ -f "$root/contract.md" ] && git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$root" diff --name-only HEAD~5 2>/dev/null | grep -q "$(basename "$root")/contract.md\|^contract.md$"; then
      echo "경고: contract.md가 최근 커밋에서 수정된 이력이 있습니다 — FROZEN 원칙 확인 필요"
    fi
  fi
}

if [ -f "$TARGET" ]; then
  check_spec_file "$TARGET"
elif [ -d "$TARGET" ]; then
  check_docs_tree "$TARGET"
  while IFS= read -r f; do
    check_spec_file "$f"
  done < <(find "$TARGET" -path '*/specs/*/spec.md')
else
  echo "Error: $TARGET 를 찾을 수 없습니다" >&2
  exit 1
fi

if [ "$FAIL" -eq 0 ]; then
  echo "OK: 위반 사항 없음"
fi
exit "$FAIL"
