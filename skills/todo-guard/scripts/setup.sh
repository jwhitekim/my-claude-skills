#!/usr/bin/env bash
# 「투두가드로 이 프로젝트 세팅해줘」 한 마디로 도는 세팅.
#
# 하는 일
#   1. 전역 ~/.claude/CLAUDE.md 에 「세션 밖 폴더」 규칙이 있는지 보고, 없으면 넣는다
#   2. TODO.md 를 만든다
#   3. 훅 네 개의 껍데기를 프로젝트에 깐다 (session-start · prompt-mark · pre-tool · check-todo)
#   4. .claude/settings.json 에 훅을 등록한다
#   5. 프로젝트 CLAUDE.md 에 운영 규칙을 병합한다
#   6. 투두가드설명서.md 를 둔다
#
# 문서 문체 검사는 글검수(geulgeomsu) 스킬로 옮겼다. 옛 세팅의 문서 검사 껍데기가 있으면 걷어낸다.
#
# 이미 있는 것은 건드리지 않는다.
set -u
# 윈도우 콘솔은 cp949 라 파이썬이 찍는 한글이 깨진다. UTF-8 로 맞춘다
export PYTHONIOENCODING=utf-8
# dirname 을 띄우지 않는다. 윈도우에서 프로세스 하나가 0.5초씩 걸린다.
#   경로에 역슬래시가 섞이면 이 방식이 엉뚱한 곳을 가리키므로, 찾지 못하면
#   설치 경로로 물러선다. 역슬래시를 직접 다루지 않아 인용 사고가 없다
_TG_DIR="${BASH_SOURCE[0]%/*}"
[ -f "$_TG_DIR/_root.sh" ] || _TG_DIR="$HOME/.claude/skills/todo-guard/scripts"
SKILL="$(cd "$_TG_DIR/.." && pwd)"
S="$SKILL/scripts"
. "$S/_root.sh"
PY_BIN="$(find_python)"

say() { echo "  $*"; }

echo "[todo-guard] 세팅 시작 - $(pwd)"

# ── 1. 전역 규칙 ────────────────────────────────────────────────
bash "$S/ensure-global-rule.sh" install

# ── 1-1. bash.exe 속도 점검 (윈도우만) ─────────────────────────
# 재고 알리기만 한다. 셸은 바꾸지 않는다 - Claude Code 는 bash.exe 를 요구해서
#   sh.exe 로 돌리면 「No suitable shell found」 로 막힌다 (2026-09-25). 자세한 것은 pick-shell.py
if [ "$IS_WIN" = "1" ] && [ -n "$PY_BIN" ] && command -v cygpath >/dev/null 2>&1; then
  "$PY_BIN" "$S/pick-shell.py" "$(cygpath -w /usr/bin/sh.exe)" "$(cygpath -w /usr/bin/bash.exe)" \
    || say "셸 고르기 실패 - 훅은 bash.exe 로 돈다"
fi

# ── 2. TODO.md ─────────────────────────────────────────────────
if [ -f TODO.md ]; then
  say "TODO.md 이미 있음"
else
  cat > TODO.md <<'MD'
# TODO

## 항상 지킬 것

<!-- 사용자가 한 번 말한 금지·필수 사항. 매 턴 읽는다. 지우지 않는다 -->

## 진행 중

## 완료

## 보류 (사용자 확인 필요)
MD
  say "TODO.md 생성"
fi

# ── 3. 훅 복사 ─────────────────────────────────────────────────
mkdir -p .claude/hooks
# 내용을 복사하지 않고 스킬 본체를 부르는 껍데기만 깐다.
#   복사하면 규칙을 고쳐도 이미 세팅한 프로젝트는 옛 사본으로 돈다.
#   강의자료에서 검사기 사본이 폴더마다 23개씩 생겨 같은 문제를 겪었다.
for f in session-start.sh check-todo.sh pre-tool.sh prompt-mark.sh; do
  cat > ".claude/hooks/$f" <<SHIM
#!/usr/bin/env bash
# 껍데기. 내용은 ~/.claude/skills/todo-guard/scripts/$f 에 한 벌만 둔다.
#   exec 가 아니라 source 로 부른다. exec 는 bash 를 한 번 더 띄우는데
#   윈도우에서 그 한 번이 0.6초다. 도구를 부를 때마다 붙는 시간이다
. "\$HOME/.claude/skills/todo-guard/scripts/$f"
SHIM
done
say "훅 4개 등록 (껍데기) - .claude/hooks/"

# 문서 문체 검사는 글검수(geulgeomsu) 스킬로 옮겼다(2026-09-14). 옛 문서 검사 껍데기를 걷어낸다.
#   settings.json 의 등록은 아래 merge-settings.py 가 함께 걷어낸다.
#   검사할 문서 목록(.todoguarddocs)은 사용자가 적은 것이라 지우지 않고 알린다
if [ -f .claude/hooks/doc-check.sh ]; then
  rm -f .claude/hooks/doc-check.sh
  say "옛 문서 검사 훅(doc-check.sh)을 걷어냈습니다. 문서 검사는 글검수 스킬이 합니다"
fi
if [ -f .todoguarddocs ]; then
  say "[알림] 옛 문서 목록 .todoguarddocs 가 남아 있습니다. 투두가드는 더 이상 문서를 검사하지 않습니다."
  say "  문서 검사가 필요하면 「글검수 세팅해줘」 뒤 문서를 다시 등록하십시오. 목록 파일은 지워도 됩니다."
fi

# ── 4. settings.json 등록 ──────────────────────────────────────
# 통째로 새로 쓰지 않는다. 이 스킬이 넣은 훅만 갈아끼우고 나머지는 남긴다.
#   전에는 파일을 덮어써서 프로젝트 권한 목록이 날아갔다.
#   그다음 판은 hooks 키를 통째로 갈아끼워 남이 걸어 둔 훅이 조용히 사라졌다.

# 옛 세대(todo-enforcer) 훅 파일을 먼저 걷어낸다.
#   settings.json 을 손보기 전에 치워야 병합 결과와 파일 상태가 어긋나지 않는다
for old in todo-check.sh todo-session-start.sh; do
  if [ -f ".claude/hooks/$old" ]; then
    mv ".claude/hooks/$old" ".claude/hooks/$old.old"
    say "옛 훅 $old 를 .old 로 물렸습니다"
  fi
done

HOOK_DIR="$(cd .claude/hooks && pwd)"
if [ -n "$PY_BIN" ]; then
  "$PY_BIN" "$S/merge-settings.py" ".claude/settings.json" "$HOOK_DIR"     || say "settings.json 병합 실패. 직접 확인하십시오"
else
  say "[경고] 파이썬을 찾지 못해 settings.json 에 훅을 등록하지 못했습니다."
  say "  파이썬을 설치한 뒤 다시 세팅하십시오."
fi


# ── 5. 프로젝트 CLAUDE.md ──────────────────────────────────────
# 운영 규칙은 rules/claude-md-block.md 한 벌을 쓴다. 옛 판이면 그 대목만 바꾼다.
#   전에는 「todo-guard」 글자만 있으면 손대지 않아, 운영 방식이 바뀌어도
#   세팅한 프로젝트에 옛 규칙(모델이 직접 등록)이 남았다
if [ -n "$PY_BIN" ]; then
  "$PY_BIN" "$S/merge-claude-md.py" CLAUDE.md "$SKILL/rules/claude-md-block.md" || say "CLAUDE.md 병합 실패. 직접 확인하십시오"
else
  say "[경고] 파이썬을 찾지 못해 CLAUDE.md 에 운영 규칙을 넣지 못했습니다."
fi

# ── 6. 투두가드 설명서 ────────────────────────────────────────
# CLAUDE.md 에 넣지 않는다. 거기는 프로젝트 규칙을 적는 자리라 길어지면 묻힌다.
#   무엇이 자동으로 돌고 언제 막히는지는 따로 둔다
#   설명서는 스킬이 만드는 안내문이다. 옛 판이면 새로 쓴다 (옛 것은 .claude/ 에 백업)
DOC_SRC="$SKILL/rules/투두가드설명서.md"
if [ ! -f "$DOC_SRC" ]; then
  say "[경고] 설명서 원본을 찾지 못했습니다"
elif [ ! -f 투두가드설명서.md ]; then
  cp "$DOC_SRC" 투두가드설명서.md && say "투두가드설명서.md 생성"
elif cmp -s "$DOC_SRC" 투두가드설명서.md; then
  say "투두가드설명서.md 최신"
else
  cp 투두가드설명서.md ".claude/투두가드설명서.md.백업_$(date +%Y%m%d-%H%M%S)"
  cp "$DOC_SRC" 투두가드설명서.md && say "투두가드설명서.md 를 새 판으로 바꿈 (옛 것은 .claude/ 에 백업)"
fi

echo "[todo-guard] 세팅 완료"
echo "  훅은 세션을 열 때 한 번 읽힙니다. /exit 로 나갔다 다시 들어오면 적용됩니다."
