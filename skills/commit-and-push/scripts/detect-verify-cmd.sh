#!/usr/bin/env bash
# 현재 디렉토리(프로젝트 루트로 가정)에 있는 신호 파일을 보고 실행 가능한
# 검증 명령을 찾아 한 줄씩 stdout에 출력한다. 아무것도 못 찾으면 아무것도
# 출력하지 않는다 — 판단(그래도 커밋할지)은 Claude/사람 몫으로 남긴다.
set -u

emit() { echo "$1"; }

if [ -f package.json ]; then
  if command -v node >/dev/null 2>&1 && node -e '
    const s=require("./package.json").scripts||{};
    process.exit(s.build?0:1)' 2>/dev/null; then
    emit "npm run build"
  fi
  if command -v node >/dev/null 2>&1 && node -e '
    const s=require("./package.json").scripts||{};
    process.exit(s.test?0:1)' 2>/dev/null; then
    emit "npm test"
  fi
fi

if [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ]; then
  command -v pytest >/dev/null 2>&1 && emit "pytest -q"
  command -v ruff >/dev/null 2>&1 && emit "ruff check ."
  command -v mypy >/dev/null 2>&1 && emit "mypy ."
fi

if [ -f Cargo.toml ]; then
  emit "cargo build"
  emit "cargo test"
fi

if [ -f go.mod ]; then
  emit "go build ./..."
  emit "go vet ./..."
fi
