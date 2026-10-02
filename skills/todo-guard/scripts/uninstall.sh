#!/usr/bin/env bash
# 이 프로젝트에서 todo-guard 세팅을 걷어낸다.
#   bash uninstall.sh              지금 폴더에서 걷어낸다 (TODO.md 는 남긴다)
#   bash uninstall.sh --dry        무엇을 지울지 보여만 준다
#   bash uninstall.sh --todo       TODO.md 까지 지운다
# dirname 을 띄우지 않는다. 윈도우에서 프로세스 하나가 0.5초씩 걸린다.
#   경로에 역슬래시가 섞이면 이 방식이 엉뚱한 곳을 가리키므로, 찾지 못하면
#   설치 경로로 물러선다. 역슬래시를 직접 다루지 않아 인용 사고가 없다
_TG_DIR="${BASH_SOURCE[0]%/*}"
[ -f "$_TG_DIR/_root.sh" ] || _TG_DIR="$HOME/.claude/skills/todo-guard/scripts"
. "$_TG_DIR/_root.sh"
export PYTHONIOENCODING=utf-8
PY="$(find_python)"
[ -n "$PY" ] || { echo "파이썬 3 이 필요합니다." >&2; exit 1; }
exec "$PY" "$_TG_DIR/uninstall.py" "$PROJ" "$@"
