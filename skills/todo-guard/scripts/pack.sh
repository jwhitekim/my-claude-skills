#!/usr/bin/env bash
# 배포용 zip 을 만든다. 받은 사람은 ~/.claude/skills/ 에 풀면 끝난다.
#
#   bash scripts/pack.sh              ~/todo-guard_<날짜>.zip
#   bash scripts/pack.sh <낼 경로>
#
# zip 안에 todo-guard/ 폴더가 들어가도록 담는다. 그래야 푸는 자리가 헷갈리지 않는다.
# 파이썬으로 담는다. 윈도우·macOS·리눅스에서 같은 것이 나오고, zip 명령이
# 깔려 있지 않아도 된다
# dirname 을 띄우지 않는다. 윈도우에서 프로세스 하나가 0.5초씩 걸린다.
#   경로에 역슬래시가 섞이면 이 방식이 엉뚱한 곳을 가리키므로, 찾지 못하면
#   설치 경로로 물러선다. 역슬래시를 직접 다루지 않아 인용 사고가 없다
_TG_DIR="${BASH_SOURCE[0]%/*}"
[ -f "$_TG_DIR/_root.sh" ] || _TG_DIR="$HOME/.claude/skills/todo-guard/scripts"
. "$_TG_DIR/_root.sh"
export PYTHONIOENCODING=utf-8
SKILL="$(cd "$_TG_DIR/.." && pwd)"
OUT="${1:-$HOME/todo-guard_$(date +%Y%m%d).zip}"

PY="$(find_python)"
[ -n "$PY" ] || { echo "파이썬 3 이 필요합니다." >&2; exit 1; }

"$PY" - "$SKILL" "$OUT" <<'PY'
import os, sys, zipfile

skill, out = sys.argv[1], sys.argv[2]
# 배포본에 넣지 않는 것 - 저장소 살림과 시험 부산물
SKIP_DIR = {".git", "__pycache__", ".claude"}
SKIP_EXT = (".pyc", ".old", ".bak", ".zip")
SKIP_NAME = {".gitattributes", ".gitignore"}

# 줄끝을 LF 로 맞춰 담는다.
#   윈도우에서 git 이 CRLF 로 꺼내 놓은 스크립트를 그대로 담으면, 받은 사람이
#   macOS·리눅스에서 풀었을 때 첫 줄 #!/usr/bin/env bash 부터 깨진다.
#   담는 시점에 맞추면 개발 기계가 어떻든 배포본은 항상 옳다
TEXT_EXT = (".sh", ".py", ".md", ".txt", ".json")


def read_for_zip(path):
    data = open(path, "rb").read()
    if path.lower().endswith(TEXT_EXT):
        data = data.replace(b"\r\n", b"\n")
    return data

os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
n = 0
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, names in os.walk(skill):
        dirs[:] = [d for d in dirs if d not in SKIP_DIR]
        for nm in sorted(names):
            if nm.lower().endswith(SKIP_EXT) or nm in SKIP_NAME:
                continue
            full = os.path.join(root, nm)
            rel = os.path.relpath(full, skill).replace(os.sep, "/")
            z.writestr("todo-guard/" + rel, read_for_zip(full))
            n += 1
print("만듦: %s  (파일 %d개)" % (out, n))
print("받는 사람은 ~/.claude/skills/ 에 풀면 됩니다.")
PY
