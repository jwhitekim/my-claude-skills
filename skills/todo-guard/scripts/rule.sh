#!/usr/bin/env bash
# dirname 을 띄우지 않는다. 윈도우에서 프로세스 하나가 0.5초씩 걸린다.
#   경로에 역슬래시가 섞이면 이 방식이 엉뚱한 곳을 가리키므로, 찾지 못하면
#   설치 경로로 물러선다. 역슬래시를 직접 다루지 않아 인용 사고가 없다
_TG_DIR="${BASH_SOURCE[0]%/*}"
[ -f "$_TG_DIR/_root.sh" ] || _TG_DIR="$HOME/.claude/skills/todo-guard/scripts"
. "$_TG_DIR/_root.sh"
# 「항상 지킬 것」을 TODO.md 맨 위에 적어 둔다.
#
# 왜 TODO.md 인가
#   사용자가 한 번 말한 금지 사항이 몇 턴 지나면 잊힌다. CLAUDE.md 에 적어도
#   세션 중간에는 다시 읽지 않는다. TODO.md 는 훅이 매 턴 읽고, 항목을 적으려고
#   나도 매 턴 연다. 그래서 잊을 수 없는 자리다.
#
#   글로 적는 것만으로는 모자란다. 그래서 확장자가 적힌 규칙은 pre-tool 훅이
#   실제로 도구를 막는다. 「pptx 를 만들지 마라」는 pptx 를 쓰려는 순간 걸린다.
#
# 사용
#   rule.sh add "PDF·PPTX 는 사용자가 만들라고 할 때까지 만들지 않는다"
#   rule.sh list
#   rule.sh remove <번호>
#   rule.sh tidy [--apply]   규칙 자리에 섞인 끝난 일 · 보류를 완료 · 보류 절로 옮긴다
#
# 규칙 자리에는 규칙만 둔다
#   실제 프로젝트에서 「항상 지킬 것」에 끝난 작업(- [x] …)이 33줄까지 쌓였다. 훅은 체크박스 줄을
#   규칙으로 보지 않지만(그래서 출력에는 안 나온다), 파일이 지저분해지고 사람이 읽기 어렵다.
#   tidy 로 옮긴다. 지우지 않는다

TODO="$PROJ/TODO.md"
HEAD="## 항상 지킬 것"

ensure() {
  [ -f "$TODO" ] || printf '# TODO\n\n## 진행 중\n\n## 완료\n\n## 보류 (사용자 확인 필요)\n' > "$TODO"
  grep -qF "$HEAD" "$TODO" && return 0
  PY="$(find_python)"
  [ -n "$PY" ] || { echo "파이썬 3 이 필요합니다." >&2; exit 1; }
  "$PY" - "$TODO" "$HEAD" <<'PYEOF'
# -*- coding: utf-8 -*-
import io, sys
p, head = sys.argv[1], sys.argv[2]
t = io.open(p, encoding="utf-8").read()
NL = chr(10)
block = (head + NL + NL +
         "<!-- 사용자가 한 번 말한 금지·필수 사항. 매 턴 읽는다. 지우지 않는다 -->" + NL + NL)
i = t.find("## ")
t = (t[:i] + block + t[i:]) if i >= 0 else (t.rstrip() + NL * 2 + block)
io.open(p, "w", encoding="utf-8", newline=NL).write(t)
PYEOF
}

list_rules() {
  [ -f "$TODO" ] || { echo "TODO.md 가 없습니다."; exit 0; }
  awk -v h="$HEAD" '
    $0 == h { on = 1; next }
    on && /^## / { on = 0 }
    on && /^- \[/ { next }                       # 체크박스 줄은 규칙이 아니다 (rule.sh tidy 로 옮긴다)
    on && /^- / { n++; print "  " n ". " substr($0, 3) }
  ' "$TODO"
}

case "${1:-list}" in
  add)
    [ -z "${2:-}" ] && { echo "사용: rule.sh add \"규칙 문장\"" >&2; exit 2; }
    ensure
    PY="$(find_python)"
    "$PY" - "$TODO" "$HEAD" "$2" <<'PYEOF'
# -*- coding: utf-8 -*-
import io, sys
p, head, text = sys.argv[1], sys.argv[2], sys.argv[3].strip()
NL = chr(10)
L = io.open(p, encoding="utf-8").read().split(NL)
i = L.index(head)
j = i + 1
while j < len(L) and not L[j].startswith("## "):
    j += 1
body = [x for x in L[i+1:j] if x.strip().startswith("- ") and not x.strip().startswith("- [")]
if any(x.strip()[2:].strip() == text for x in body):
    print("[todo-guard] 이미 있는 규칙입니다 - " + text)
    sys.exit(0)
k = j
while k > i and not L[k-1].strip():
    k -= 1
L.insert(k, "- " + text)
io.open(p, "w", encoding="utf-8", newline=NL).write(NL.join(L))
print("[todo-guard] 항상 지킬 것에 추가 - " + text)
PYEOF
    ;;
  remove)
    [ -z "${2:-}" ] && { echo "사용: rule.sh remove <번호>" >&2; exit 2; }
    PY="$(find_python)"
    "$PY" - "$TODO" "$HEAD" "$2" <<'PYEOF'
# -*- coding: utf-8 -*-
import io, sys
p, head, no = sys.argv[1], sys.argv[2], int(sys.argv[3])
NL = chr(10)
L = io.open(p, encoding="utf-8").read().split(NL)
i = L.index(head); j = i + 1
while j < len(L) and not L[j].startswith("## "):
    j += 1
idx = [k for k in range(i+1, j) if L[k].strip().startswith("- ") and not L[k].strip().startswith("- [")]
if no < 1 or no > len(idx):
    print("그런 번호가 없습니다: %d" % no); sys.exit(2)
gone = L.pop(idx[no-1])
io.open(p, "w", encoding="utf-8", newline=NL).write(NL.join(L))
print("[todo-guard] 규칙을 뺐습니다 - " + gone.strip()[2:])
PYEOF
    ;;
  tidy)
    [ -f "$TODO" ] || { echo "TODO.md 가 없습니다."; exit 0; }
    PY="$(find_python)"
    [ -n "$PY" ] || { echo "파이썬 3 이 필요합니다." >&2; exit 1; }
    "$PY" - "$TODO" "$HEAD" "${2:-}" <<'PYEOF'
# -*- coding: utf-8 -*-
# 「항상 지킬 것」에 섞인 - [x] 는 「완료」 절 맨 위로, - [?] 는 「보류」 절로 옮긴다.
#   열린 항목(- [ ])은 그대로 둔다. 턴 종료를 막는 항목이라 건드리면 안 된다.
#   항목 아래 들여쓴 줄도 함께 옮긴다. 지우는 것은 없다
import io, shutil, sys, time
try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass
p, head, opt = sys.argv[1], sys.argv[2], sys.argv[3]
raw = io.open(p, encoding="utf-8", newline="").read()
crlf = "\r\n" in raw
NL = chr(10)
L = raw.replace("\r\n", NL).split(NL)


def find_head(name):
    for k, l in enumerate(L):
        if l.startswith(name):
            return k
    return -1


i = find_head(head)
if i < 0:
    print("[todo-guard] 「항상 지킬 것」 절이 없습니다."); sys.exit(0)
j = i + 1
while j < len(L) and not L[j].startswith("## "):
    j += 1

keep, done, hold, bucket = [], [], [], None
for l in L[i+1:j]:
    s = l.strip()
    if s.startswith("- [x]") or s.startswith("- [X]"):
        bucket = done; done.append(l); continue
    if s.startswith("- [?]"):
        bucket = hold; hold.append(l); continue
    if s.startswith("- [ ]"):
        bucket = None; keep.append(l); continue
    if bucket is not None and l[:1] in (" ", "\t") and s:
        bucket.append(l); continue
    bucket = None; keep.append(l)

if not done and not hold:
    print("[todo-guard] 「항상 지킬 것」에 옮길 것이 없습니다."); sys.exit(0)
print("[todo-guard] 옮길 것 - 완료 %d줄 · 보류 %d줄 (규칙 %d줄은 그대로)"
      % (len(done), len(hold), len([k for k in keep if k.strip().startswith("- ")])))
for l in (done + hold)[:10]:
    print("  " + l.strip()[:80])
if len(done) + len(hold) > 10:
    print("  … 외 %d줄" % (len(done) + len(hold) - 10))
if opt != "--apply":
    print("  옮기려면: rule.sh tidy --apply"); sys.exit(0)

while keep and not keep[-1].strip():
    keep.pop()
keep.append("")
shutil.copyfile(p, p + ".정리전백업_" + time.strftime("%Y%m%d-%H%M%S"))
L[i+1:j] = keep


def insert_top(name, block):
    if not block:
        return
    k = find_head(name)
    if k < 0:
        L.extend(["", name])
        k = len(L) - 1
    m = k + 1
    while m < len(L) and L[m].startswith("<!--"):
        m += 1
    if m < len(L) and not L[m].strip():
        m += 1
    L[m:m] = block


insert_top("## 완료", done)
insert_top("## 보류", hold)
out = NL.join(L)
if crlf:
    out = out.replace(NL, "\r\n")
io.open(p, "w", encoding="utf-8", newline="").write(out)
print("[todo-guard] 옮겼습니다. 옛 파일은 TODO.md.정리전백업_<시각> 에 있습니다.")
PYEOF
    ;;
  list|*) list_rules ;;
esac
