#!/usr/bin/env bash
# PostToolUse 훅(Bash 매처). push 뒤 워크플로별 상태를 확인한다.
# 실패 원인 진단(로그 읽고 수정안 제시)은 deploy-status 스킬로 넘긴다.
set -u

_DIR="${BASH_SOURCE[0]%/*}"
python3 "$_DIR/post-push-status.py"
