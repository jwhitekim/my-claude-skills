#!/usr/bin/env bash
# 전역 ~/.claude/CLAUDE.md 에 「세션 밖 폴더」 규칙이 있는지 보고, 없으면 넣는다.
#
# 왜 스킬이 챙기나
#   배너 규칙은 세팅하지 않은 새 폴더에서도 지켜져야 한다. 그래서 스킬 안이 아니라
#   전역 CLAUDE.md 에 둔다. 다만 새 PC·새 계정에서는 그 파일이 비어 있으므로,
#   「투두가드 세팅해줘」 한 마디에 전역 규칙까지 갖춰지게 한다.
#
# 넣을 때 표시를 남기는 이유
#   전에는 표시 없이 본문만 덧붙였다. 그래서 나중에 「스킬이 넣은 것」과
#   「사용자가 직접 쓴 것」을 구분할 수 없었다. 구분 없이 지우면 사용자가 쓴 글을
#   날린다. 그래서 넣은 대목만 표시로 감싸고, 뺄 때는 그 안쪽만 잘라낸다.
#   표시가 없는 규칙은 사용자가 쓴 것으로 보고 손대지 않는다.
#
# 프로젝트 세팅을 걷어낼 때는 이 규칙을 빼지 않는다
#   전역 규칙은 모든 프로젝트가 같이 쓴다. 게다가 동작을 바꾸지 않고 경고만 한다.
#   프로젝트 하나를 걷어낸다고 빼면 다른 프로젝트의 경고까지 사라진다.
#   뺄 때는 사용자가 「전역 규칙 빼줘」 라고 따로 말해야 한다.
#
# 사용: ensure-global-rule.sh [check|install|remove]
#   check    있으면 0, 없으면 1
#   install  없을 때만 덧붙임 (이미 있으면 건드리지 않음)
#   remove   이 스킬이 넣은 대목만 뺌 (표시가 없으면 손대지 않음)

# dirname 을 띄우지 않는다. 윈도우에서 프로세스 하나가 0.5초씩 걸린다.
#   경로에 역슬래시가 섞이면 이 방식이 엉뚱한 곳을 가리키므로, 찾지 못하면
#   설치 경로로 물러선다. 역슬래시를 직접 다루지 않아 인용 사고가 없다
_TG_DIR="${BASH_SOURCE[0]%/*}"
[ -f "$_TG_DIR/_root.sh" ] || _TG_DIR="$HOME/.claude/skills/todo-guard/scripts"
SKILL_DIR="$(cd "$_TG_DIR/.." && pwd)"
SRC="$SKILL_DIR/rules/outside-rule.md"
DST="$HOME/.claude/CLAUDE.md"
MARK="세션 밖 폴더에서 작업중"
BEGIN="<!-- todo-guard:outside-rule:begin -->"
END="<!-- todo-guard:outside-rule:end -->"

has_rule() {
  [ -f "$DST" ] && grep -q "$MARK" "$DST"
}

case "${1:-check}" in
  check)
    if has_rule; then
      echo "[todo-guard] 전역 규칙 있음 - ~/.claude/CLAUDE.md"
      exit 0
    fi
    echo "[todo-guard] 전역 규칙 없음. ensure-global-rule.sh install 로 넣으십시오."
    exit 1
    ;;
  install)
    if has_rule; then
      echo "[todo-guard] 전역 규칙이 이미 있음. 건드리지 않음."
      exit 0
    fi
    [ -f "$SRC" ] || { echo "[todo-guard] 규칙 원본 없음: $SRC" >&2; exit 1; }
    mkdir -p "$(dirname "$DST")"
    # 되돌릴 수단부터 만든다
    HAD=0
    if [ -f "$DST" ]; then
      HAD=1
      cp "$DST" "$DST.bak-$(date +%Y%m%d-%H%M%S)"
      printf '\n' >> "$DST"
    else
      printf '# 전역 규칙\n\n' > "$DST"
    fi
    # 넣은 대목을 표시로 감싼다. 나중에 이 안쪽만 잘라내면 된다
    {
      echo "$BEGIN"
      cat "$SRC"
      echo "$END"
    } >> "$DST"
    echo "[todo-guard] 전역 규칙을 넣었습니다 - $DST"
    [ "$HAD" = "1" ] && echo "  (기존 파일은 .bak-날짜 로 남겨 두었습니다)"
    exit 0
    ;;
  remove)
    if ! grep -qF "$BEGIN" "$DST" 2>/dev/null; then
      if has_rule; then
        echo "[todo-guard] 전역 규칙이 있지만 이 스킬이 넣은 표시가 없습니다."
        echo "  사용자가 직접 쓴 것으로 보고 손대지 않습니다 - $DST"
        exit 1
      fi
      echo "[todo-guard] 전역 규칙이 없습니다. 뺄 것이 없습니다."
      exit 0
    fi
    # 백업 이름을 붙잡아 둔다. .bak-* 로 훑으면 예전 백업까지 함께 읽는다
    BAK="$DST.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$DST" "$BAK"
    # 표시 사이만 잘라낸다
    awk -v b="$BEGIN" -v e="$END" '
      index($0, b) { skip = 1; next }
      index($0, e) { skip = 0; next }
      !skip { print }
    ' "$BAK" > "$DST.new" 2>/dev/null || {
      echo "[todo-guard] 잘라내기 실패. 손대지 않았습니다." >&2; rm -f "$DST.new"; exit 1; }
    mv "$DST.new" "$DST"
    echo "[todo-guard] 전역 규칙을 뺐습니다 - $DST"
    echo "  (빼기 전 파일: $BAK)"
    exit 0
    ;;
  *)
    echo "사용: ensure-global-rule.sh [check|install|remove]" >&2
    exit 2
    ;;
esac
