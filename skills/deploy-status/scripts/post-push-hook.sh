#!/usr/bin/env bash
# PostToolUse 훅(Bash 매처). push 뒤 워크플로별 상태를 확인한다.
# jw 플러그인이 설치되면 모든 프로젝트에서 이 훅이 돈다. 프로젝트가 .claude/deploy-status.enabled 파일을
# 둔 경우에만 실제 확인을 하므로, 파일이 없으면 아무 출력 없이 끝난다(setup.sh가 이 파일을 만든다).
# 실패 원인 진단(로그 읽고 수정안 제시)은 deploy-status 스킬로 넘긴다.
set -u

[ -f "${CLAUDE_PROJECT_DIR:-.}/.claude/deploy-status.enabled" ] || exit 0

_DIR="${BASH_SOURCE[0]%/*}"
python3 "$_DIR/post-push-status.py"
