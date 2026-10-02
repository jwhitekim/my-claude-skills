#!/usr/bin/env bash
# dirname 을 띄우지 않는다. 윈도우에서 프로세스 하나가 0.5초씩 걸린다.
#   경로에 역슬래시가 섞이면 이 방식이 엉뚱한 곳을 가리키므로, 찾지 못하면
#   설치 경로로 물러선다. 역슬래시를 직접 다루지 않아 인용 사고가 없다
_TG_DIR="${BASH_SOURCE[0]%/*}"
[ -f "$_TG_DIR/_root.sh" ] || _TG_DIR="$HOME/.claude/skills/todo-guard/scripts"
. "$_TG_DIR/_root.sh"
# 사용자가 허가한 「프로젝트 밖 경로」를 설정에 적는다.
#   사용: allow-outside.sh <경로>
#         allow-outside.sh --list
#
# 사용자 허가 없이 이 스크립트를 부르지 않는다. 부르는 순간 차단이 풀린다.
CONF="$PROJ/.claude/todo-guard.json"

if [ "${1:-}" = "--list" ]; then
  # 여러 줄 JSON 도 읽히도록 한 줄로 이어 붙인 뒤 뽑는다
  [ -f "$CONF" ] && tr '\n' ' ' < "$CONF" | sed -n 's/.*"allowOutside"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p'
  exit 0
fi

TARGET="${1:-}"
[ -z "$TARGET" ] && { echo "사용: allow-outside.sh <경로>" >&2; exit 2; }

# 파일을 주면 그 폴더를 허용한다
[ -f "$TARGET" ] && TARGET=$(dirname "$TARGET")
TARGET=$(printf '%s' "$TARGET" | sed 's|\\|/|g')

PY="$(find_python)"
[ -n "$PY" ] || { echo "[todo-guard] 파이썬이 없어 설정을 고칠 수 없습니다." >&2; exit 1; }

mkdir -p "$PROJ/.claude"

# 통째로 다시 쓰지 않는다. allowOutside 만 더하고 나머지 키는 남긴다.
"$PY" - "$CONF" "$TARGET" <<'PY'
import io, json, os, sys
p, t = sys.argv[1], sys.argv[2]
d = {}
if os.path.exists(p):
    try:
        d = json.load(io.open(p, encoding="utf-8"))
        if not isinstance(d, dict):
            d = {}
    except Exception:
        d = {}
lst = d.setdefault("allowOutside", [])
if not isinstance(lst, list):
    lst = []
    d["allowOutside"] = lst
if t in lst:
    print("[todo-guard] 이미 허용된 경로 - " + t)
else:
    lst.append(t)
    print("[todo-guard] 허용 경로 추가 - " + t)
io.open(p, "w", encoding="utf-8", newline=chr(10)).write(
    json.dumps(d, ensure_ascii=False, indent=2) + chr(10))
PY
