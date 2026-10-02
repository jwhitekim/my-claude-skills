#!/usr/bin/env bash
# diff를 영향 범위별로 분류하고, 해당하는 가드 스크립트만 실행한다.
# 아무것도 막지 않는다 — 각 가드의 결과를 모아 보여줄 뿐이다.
# 사용법: impact.sh [staged|last]  (기본 staged)
set -u

MODE="${1:-staged}"
SKILLS="$HOME/.claude/skills"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[change-impact] git 저장소가 아닙니다."
  exit 0
fi
# git diff 경로가 저장소 루트 기준이라, 하위 폴더에서 불러도 루트에서 돌린다.
cd "$(git rev-parse --show-toplevel)" || exit 1

case "$MODE" in
  staged) CHANGED=$(git diff --cached --name-only --diff-filter=ACMR) ;;
  last)   CHANGED=$(git diff --name-only --diff-filter=ACMR HEAD~1 HEAD 2>/dev/null) ;;
  *)      echo "[change-impact] 알 수 없는 모드: $MODE (staged|last)"; exit 1 ;;
esac

if [ -z "$CHANGED" ]; then
  if [ "$MODE" = "staged" ]; then
    echo "[change-impact] staged 변경이 없습니다. git add 후 다시 실행하거나 'last'로 마지막 커밋을 보세요."
  else
    echo "[change-impact] 마지막 커밋에 변경이 없습니다."
  fi
  exit 0
fi

has() { echo "$CHANGED" | grep -qE "$1"; }

SRC='\.(py|js|jsx|ts|tsx|go|rb|java)$'
LOCK='(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml)$'
SPEC='(openapi|swagger)[^/]*\.(ya?ml|json)$'
MIGRATION='(^|/)migrations/[^/]+\.sql$'
DOCS_SPEC='(^|/)specs/[^/]+/spec\.md$'
CONFIG='(^|/)\.env[^/]*$|^\.github/workflows/'

AREAS=""
has "$SRC"       && AREAS="$AREAS 소스"
has "$LOCK"      && AREAS="$AREAS 의존성"
has "$SPEC"      && AREAS="$AREAS API스펙"
has "$MIGRATION" && AREAS="$AREAS DB마이그레이션"
has "$DOCS_SPEC" && AREAS="$AREAS 문서스펙"
has "$CONFIG"    && AREAS="$AREAS 설정/CI"

COUNT=$(echo "$CHANGED" | wc -l | tr -d ' ')
echo "[change-impact] 변경 파일 ${COUNT}개 — 영향 범위:${AREAS:- 해당 가드 없음}"

run() {
  local title="$1"; shift
  local out
  out=$("$@" 2>&1)
  if [ -n "$out" ]; then
    echo
    echo "== ${title} =="
    echo "$out"
  fi
}

has "$SRC"       && run "테스트 누락 (test-gap-finder)"     bash "$SKILLS/test-gap-finder/scripts/find-gaps.sh" "$MODE"
has "$LOCK"      && run "의존성 변경 (dependency-guard)"    bash "$SKILLS/dependency-guard/scripts/diff-versions.sh" "$MODE"
has "$SPEC"      && run "API 스펙 (api-contract-guard)"     bash "$SKILLS/api-contract-guard/scripts/check.sh" "$MODE"
has "$MIGRATION" && run "DB 마이그레이션 (migration-guard)" bash "$SKILLS/migration-guard/scripts/check.sh" "$MODE"

if has "$DOCS_SPEC"; then
  while IFS= read -r f; do
    [ -f "$f" ] && run "문서 스펙 형식 (docs-compliance): $f" bash "$SKILLS/docs-compliance/scripts/check-spec.sh" "$f"
  done < <(echo "$CHANGED" | grep -E "$DOCS_SPEC")
fi

# config-drift-guard는 diff가 아니라 현재 파일 상태 전체를 비교한다.
has "$CONFIG" && run "설정 불일치 (config-drift-guard)" bash "$SKILLS/config-drift-guard/scripts/scan.sh" detail

if echo "$CHANGED" | grep -qE '^\.github/workflows/'; then
  echo
  echo "[change-impact] CI 워크플로가 바뀌었습니다 — 푸시 후 deploy-status로 배포 결과를 확인하세요."
fi
