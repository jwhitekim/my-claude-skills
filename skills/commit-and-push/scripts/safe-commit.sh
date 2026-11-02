#!/usr/bin/env bash
# 지정한 파일만 add하고 커밋한다. 민감 파일 패턴이 섞여 있으면 무조건 거부한다 —
# check-staged.sh는 경고만 하고 판단을 Claude에게 넘기지만, 이 스크립트는
# 판단 없이 기계적으로 막는다(경고 vs 차단은 다른 안전 등급이다).
#
# 사용: safe-commit.sh "<message>" <file1> [file2 ...]
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "사용법: safe-commit.sh \"<message>\" <file1> [file2 ...]" >&2
  exit 1
fi

MSG="$1"; shift

is_sensitive() {
  local file="$1"
  if [[ "$file" =~ (^|/)secrets/|\.pem$|id_rsa$|\.key$ ]]; then
    return 0
  fi
  case "${file##*/}" in
    .env.example|.env.sample|.env.template) return 1 ;;
  esac
  [[ "$file" =~ (^|/)\.env(\..*)?$ ]]
}

for f in "$@"; do
  if is_sensitive "$f"; then
    echo "REFUSED: '$f'는 민감 파일 패턴(.env/secrets//.pem/.key/id_rsa)입니다. 커밋 대상에서 빼고 다시 실행하세요." >&2
    exit 1
  fi
done

# 경로별로 add한다. 경로 오타 등으로 하나라도 실패하면 커밋하지 않는다.
for f in "$@"; do
  git add -A -- "$f"
done

if git diff --cached --quiet; then
  echo "REFUSED: 커밋할 변경사항이 없습니다(staged가 비어 있음) — 경로를 확인하세요." >&2
  exit 1
fi

# Git이 경로 인자를 해석한 결과와 전체 staged 목록을 비교한다. 디렉터리·pathspec도
# 지원하고, rename은 이전/새 경로를 따로 검사해 범위 밖 삭제가 섞이지 않게 한다.
STAGED_FILES=()
EXPECTED_FILES=()
while IFS= read -r -d '' f; do
  STAGED_FILES+=("$f")
done < <(git diff --cached --name-only --no-renames -z)
while IFS= read -r -d '' f; do
  EXPECTED_FILES+=("$f")
done < <(git diff --cached --name-only --no-renames -z -- "$@")

if [ "${#STAGED_FILES[@]}" -ne "${#EXPECTED_FILES[@]}" ]; then
  echo "REFUSED: staged 목록이 지정한 파일 집합과 다릅니다. 커밋하지 않습니다." >&2
  echo "지정한 경로의 staged 파일:" >&2
  printf '  %q\n' "${EXPECTED_FILES[@]}" >&2
  echo "지정한 경로 밖의 staged 파일:" >&2
  for f in "${STAGED_FILES[@]}"; do
    found=0
    for expected in "${EXPECTED_FILES[@]}"; do
      if [ "$f" = "$expected" ]; then found=1; break; fi
    done
    if [ "$found" -eq 0 ]; then printf '  %q\n' "$f" >&2; fi
  done
  exit 1
fi

# 디렉터리 인자 안의 파일과 기존 staged 파일까지 실제 커밋 대상을 검사한다.
for f in "${STAGED_FILES[@]}"; do
  if is_sensitive "$f"; then
    echo "REFUSED: staged 파일 '$f'는 민감 파일 패턴입니다. 커밋 대상에서 빼세요." >&2
    exit 1
  fi
done

git commit -m "$MSG"
