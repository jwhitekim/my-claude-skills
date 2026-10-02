#!/usr/bin/env bash
# 이미 세팅한 프로젝트를 훑어 상태를 보고, 필요하면 다시 세팅한다.
#   bash doctor.sh <프로젝트 상위 폴더> [...]          상태만
#   bash doctor.sh --fix <프로젝트 상위 폴더> [...]    손봐야 할 것만 다시 세팅
# dirname 을 띄우지 않는다. 윈도우에서 프로세스 하나가 0.5초씩 걸린다.
#   경로에 역슬래시가 섞이면 이 방식이 엉뚱한 곳을 가리키므로, 찾지 못하면
#   설치 경로로 물러선다. 역슬래시를 직접 다루지 않아 인용 사고가 없다
_TG_DIR="${BASH_SOURCE[0]%/*}"
[ -f "$_TG_DIR/_root.sh" ] || _TG_DIR="$HOME/.claude/skills/todo-guard/scripts"
. "$_TG_DIR/_root.sh"
export PYTHONIOENCODING=utf-8
PY="$(find_python)"
[ -n "$PY" ] || { echo "파이썬 3 이 필요합니다." >&2; exit 1; }
exec "$PY" "$_TG_DIR/doctor.py" "$@"
