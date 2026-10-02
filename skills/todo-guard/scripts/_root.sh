#!/usr/bin/env bash
# 훅과 명령이 같이 쓰는 도구 모음.
#
# 왜 한곳에 모으나
#   훅은 턴이 끝나는 시점의 작업 폴더에서 실행된다. 하위 폴더로 옮겨 다니며
#   작업하면 TODO.md 와 .claude/todo-guard.json 을 못 찾는다. 그래서 프로젝트
#   루트를 먼저 찾고, TODO.md 를 읽고 쓰는 방법도 한 벌로 둔다.
#
# 모두 bash 내장만 쓴다. 윈도우에서 외부 명령 하나가 0.35~0.43초,
#   서브셸 하나가 0.17초라 훅이 도구 호출마다 그만큼 늦어진다.
# macOS 기본 bash(3.2)에서도 돈다. mapfile · ${s,,} · printf '%(…)T' 는
#   bash 4 부터라 윈도우 쪽에서만 쓰거나 대신할 길을 둔다.
#
# 쓰는 법
#   _TG_DIR="${BASH_SOURCE[0]%/*}"; . "$_TG_DIR/_root.sh"   # PROJ 가 채워진다

# 프로젝트 루트를 변수에 담는다. 서브셸을 만들지 않는다.
#   find_proj_root_to PROJ  →  $PROJ 에 담긴다
find_proj_root_to() {
  local __var="$1" d home
  d="$PWD"
  home="$HOME"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    if [ "$d" != "$home" ]; then
      if [ -f "$d/.claude/todo-guard.json" ] || [ -d "$d/.claude/hooks" ]; then
        printf -v "$__var" '%s' "$d"
        return 0
      fi
    fi
    case "$d" in
      */*) d="${d%/*}" ;;
      *) break ;;
    esac
  done
  printf -v "$__var" '%s' "$PWD"
}

find_proj_root_to PROJ

# 쓸 수 있는 파이썬 3 을 찾는다. 없으면 빈 문자열.
#   윈도우에서는 python 을 먼저 본다. python3 은 마이크로소프트 스토어 껍데기라
#   부르면 스토어가 뜨며 멈춘다. macOS·리눅스에서는 python 이 없거나 2 라서
#   python3 을 먼저 본다
find_python() {
  local c
  local order="python3 python py"
  [ "$IS_WIN" = "1" ] && order="python py python3"
  for c in $order; do
    if command -v "$c" >/dev/null 2>&1 &&        "$c" -c "import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)" >/dev/null 2>&1; then
      echo "$c"; return 0
    fi
  done
  echo ""
}

# 여기가 윈도우인가. uname 을 띄우지 않는다
case "$OSTYPE" in
  msys*|cygwin*|win32*) IS_WIN=1 ;;
  *) IS_WIN=0 ;;
esac

# 글자를 바이트가 아니라 글자로 세게 한다.
#   훅은 로캘이 비어 있는 환경에서 돈다. 그대로 두면 ${s:0:80} 이 80바이트를 잘라
#   한글 한 글자가 가운데서 끊기고, TODO.md 에 깨진 글자가 남는다.
#   Git Bash 는 C.UTF-8, macOS 는 en_US.UTF-8 이 있다. 없는 이름은 조용히 넘긴다
tg_utf8() {
  local _k="가" _l
  [ "${#_k}" = 1 ] && return 0
  for _l in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
    { LC_ALL=$_l; } 2>/dev/null
    [ "${#_k}" = 1 ] && return 0
  done
  return 1
}
tg_utf8

# 파일을 통째로 읽는다. cat 을 띄우지 않는다
read_all() {
  [ -f "$1" ] || return 1
  local IFS=
  read -r -d '' REPLY < "$1"
  return 0
}

# 두 경로를 견줄 수 있게 표기를 맞춘다. 서브셸을 만들지 않는다.
#   norm_path_to NORM "$FP"  →  $NORM 에 담긴다
#
# 윈도우에서만 역슬래시를 / 로 바꾸고 드라이브 문자를 풀고 대소문자를 낮춘다.
#   PROJ 는 /d/work/... 이고 도구가 넘기는 경로는 D:\work\... 라 그대로는 어긋난다.
# macOS·리눅스에서는 손대지 않는다. \ 는 파일 이름 글자이고, 대소문자를 가린다
norm_path_to() {
  local __var="$1" s="$2"
  if [ "$IS_WIN" = "1" ]; then
    s="${s//\\//}"
    case "$s" in
      /?/*|/?) s="${s:1:1}:${s:2}" ;;
    esac
    while [[ "$s" == *//* ]]; do s="${s//\/\//\/}"; done
    printf -v "$__var" '%s' "${s,,}"
  else
    while [[ "$s" == *//* ]]; do s="${s//\/\//\/}"; done
    printf -v "$__var" '%s' "$s"
  fi
}

# 「항상 지킬 것」을 변수에 담는다.
#   standing_rules_to R  →  $R 에 줄바꿈으로 이어 담긴다
#   체크박스 줄(- [ ] · - [x] · - [?])은 규칙이 아니라 할 일이다. 그 절에 섞여 있어도 빼고 읽는다.
#   실제 프로젝트에서 끝난 작업 열몇 줄이 규칙 자리에 쌓여, 턴을 막을 때마다 통째로 딸려 나왔다
standing_rules_to() {
  local __var="$1" todo="$PROJ/TODO.md" _on=0 _l _out=""
  printf -v "$__var" '%s' ""
  [ -f "$todo" ] || return 0
  while IFS= read -r _l || [ -n "$_l" ]; do
    _l="${_l%$'\r'}"
    case "$_l" in
      "## 항상 지킬 것"*) _on=1; continue ;;
      "## "*) [ "$_on" = 1 ] && _on=0 ;;
    esac
    [ "$_on" = 1 ] || continue
    case "$_l" in
      "- ["*) ;;
      "- "*) _out="${_out:+$_out$'\n'}$_l" ;;
    esac
  done < "$todo"
  printf -v "$__var" '%s' "$_out"
}

# ── TODO.md 다루기 ─────────────────────────────────────────────
# 장부 정리는 훅과 todo.sh 가 한다. 모델이 TODO.md 를 열고 고치면 그 호출 하나가
#   대화 전체를 다시 읽는다. 긴 세션에서는 한 번에 50만 토큰이다.
#   훅은 모델 밖에서 돌아 토큰을 쓰지 않는다.
#
# 항목 모양
#   - [ ] #12 지시 첫머리          지시 하나
#   - [ ] #13.2 번호 매긴 지시의 둘째 항목
#   - [x] #12 …                    완료
#   - [?] #12 … (사유)             보류 - 사용자 판단 대기
# 번호가 없는 옛 항목도 그대로 둔다. 턴 종료 검사는 번호와 상관없이 - [ ] 를 본다

TG_TODO="$PROJ/TODO.md"
TG_DIR="$PROJ/.claude/todo-guard"
TG_RX_ITEM='^[[:space:]]*- \[([ x?])\] #([0-9]+)(\.([0-9]+))?([[:space:]]|$)'

# 줄 배열로 읽는다 → TG_L
#   윈도우 편집기로 저장한 TODO.md 는 줄끝이 CRLF 다. 읽을 때 CR 을 떼어 두고
#   (TG_CRLF=1) 쓸 때 되붙인다. 떼지 않으면 새로 넣은 줄만 LF 가 되어 줄끝이 섞인다
tg_load() {
  TG_L=(); TG_CRLF=0
  [ -f "$TG_TODO" ] || return 1
  if [ "${BASH_VERSINFO[0]:-3}" -ge 4 ]; then
    mapfile -t TG_L < "$TG_TODO"
  else
    local l
    while IFS= read -r l || [ -n "$l" ]; do TG_L+=("$l"); done < "$TG_TODO"
  fi
  [[ "${TG_L[0]:-}" == *$'\r' ]] && TG_CRLF=1
  local i n=${#TG_L[@]}
  for ((i=0; i<n; i++)); do TG_L[i]="${TG_L[i]%$'\r'}"; done
  return 0
}

# 줄 배열을 쓴다. 읽을 때의 줄끝을 따른다
tg_save() {
  if [ "${TG_CRLF:-0}" = 1 ]; then
    printf '%s\r\n' "${TG_L[@]}" > "$TG_TODO"
  else
    printf '%s\n' "${TG_L[@]}" > "$TG_TODO"
  fi
}

# 제목으로 시작하는 줄을 찾는다 → TG_I (없으면 -1)
tg_find_head() {
  local p="$1" i n=${#TG_L[@]}
  TG_I=-1
  for ((i=0; i<n; i++)); do
    [[ "${TG_L[i]}" == "$p"* ]] && { TG_I=$i; return 0; }
  done
  return 1
}

# 빈 줄인가 (공백 · CR 만 있어도 빈 줄)
tg_blank() {
  local s="${1//[[:space:]]/}"
  [ -z "${s//$'\r'/}" ]
}

# 절의 끝 - 다음 ## 직전에서 뒤쪽 빈 줄을 뺀 자리 → TG_E
tg_section_end() {
  local h=$1 n=${#TG_L[@]} e
  e=$((h+1))
  while [ "$e" -lt "$n" ] && [[ "${TG_L[e]}" != "## "* ]]; do e=$((e+1)); done
  while [ "$e" -gt $((h+1)) ] && tg_blank "${TG_L[e-1]}"; do e=$((e-1)); done
  TG_E=$e
}

# 절을 찾고, 없으면 파일 끝에 만든다 → TG_I
tg_ensure_head() {
  tg_find_head "$1" && return 0
  TG_L+=("" "$1")
  TG_I=$(( ${#TG_L[@]} - 1 ))
}

# 절 끝에 줄들을 넣는다
tg_append_to() {
  local head="$1"; shift
  tg_ensure_head "$head"
  tg_section_end "$TG_I"
  TG_L=("${TG_L[@]:0:TG_E}" "$@" "${TG_L[@]:TG_E}")
}

# 절 첫머리에 줄들을 넣는다. 완료는 최근 것이 위로 온다
tg_prepend_to() {
  local head="$1"; shift
  tg_ensure_head "$head"
  local k=$((TG_I+1))
  # 절 설명 주석(<!-- … -->)은 제목에 붙여 둔다
  while [ "$k" -lt "${#TG_L[@]}" ] && [[ "${TG_L[k]}" == "<!--"* ]]; do k=$((k+1)); done
  TG_L=("${TG_L[@]:0:k}" "$@" "${TG_L[@]:k}")
}

# 다음 번호 → TG_N. seq 파일이 없으면 TODO.md 에서 가장 큰 번호 다음으로 한다
tg_next_id() {
  local s=0 l
  if [ -f "$TG_DIR/seq" ]; then
    read -r s < "$TG_DIR/seq"
    [[ "$s" =~ ^[0-9]+$ ]] || s=0
  fi
  if [ "$s" = 0 ]; then
    for l in "${TG_L[@]}"; do
      [[ "$l" =~ $TG_RX_ITEM ]] && [ "${BASH_REMATCH[2]}" -gt "$s" ] && s="${BASH_REMATCH[2]}"
    done
  fi
  TG_N=$((s+1))
  [ -d "$TG_DIR" ] || mkdir -p "$TG_DIR" 2>/dev/null
  printf '%s\n' "$TG_N" > "$TG_DIR/seq"
}

# 줄이 번호 목록 중 하나에 해당하나. 「12」는 #12 와 #12.x 를 모두 뜻한다
#   tg_has_id "<줄>" "12 13.2"
tg_has_id() {
  local l="$1" id got
  [[ "$l" =~ $TG_RX_ITEM ]] || return 1
  got="${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
  for id in $2; do
    id="${id#\#}"
    [ "$got" = "$id" ] && return 0
    [[ "$got" == "$id".* ]] && return 0
  done
  return 1
}

# 열린 항목(- [ ])이면서 번호가 맞는가
tg_open_has_id() {
  case "${1#"${1%%[![:space:]]*}"}" in "- [ ] "*) ;; *) return 1 ;; esac
  tg_has_id "$1" "$2"
}

# 맨 앞(들여쓰기 없는) 완료 항목인가. 번호 없는 옛 항목도 포함
tg_is_done() {
  case "$1" in "- [x]"*|"- [X]"*) return 0 ;; esac
  return 1
}

# 항목 줄과 그 아래 들여쓴 줄을 한 덩어리로 뽑는다.
#   tg_take <조건 함수> <인자> [시작] [끝]  →  TG_TAKEN 에 뽑은 줄들, TG_L 에서는 뺀다
#   시작 · 끝을 주면 그 범위(줄 번호) 안에서만 뽑는다
tg_take() {
  local fn="$1" arg="$2" from="${3:-0}" to="${4:-${#TG_L[@]}}"
  local i n=${#TG_L[@]} on=0 l
  local keep=() took=()
  for ((i=0; i<n; i++)); do
    l="${TG_L[i]}"
    if [ "$i" -lt "$from" ] || [ "$i" -ge "$to" ]; then
      keep+=("$l"); on=0; continue
    fi
    if [ "$on" = 1 ] && [[ "$l" == [[:space:]]* ]] && ! tg_blank "$l"; then
      took+=("$l"); continue        # 위 항목의 하위 줄
    fi
    on=0
    if "$fn" "$l" "$arg"; then
      took+=("$l"); on=1; continue
    fi
    keep+=("$l")
  done
  TG_L=("${keep[@]}")
  TG_TAKEN=("${took[@]}")
}

# 지금 시각 (초). macOS 기본 bash 3.2 에는 EPOCHSECONDS · printf '%(…)T' 가 없어 date 를 부른다
tg_now_to() {
  local _tn_v="$1" _tn_t="${EPOCHSECONDS:-}"
  if [ -z "$_tn_t" ]; then
    printf -v _tn_t '%(%s)T' -1 2>/dev/null
    [[ "$_tn_t" =~ ^[0-9]+$ ]] || _tn_t="$(date +%s)"
  fi
  printf -v "$_tn_v" '%s' "$_tn_t"
}

# 이번 지시를 가리키는 도장. 시각 + 난수라 같은 초에 두 번 와도 겹치지 않는다
tg_stamp_to() {
  local _ts_v="$1" _ts_t
  tg_now_to _ts_t
  printf -v "$_ts_v" '%s-%s' "$_ts_t" "$RANDOM"
}

# 글자 수로 자른다. tg_cut_to VAR "문자열" 80
tg_cut_to() {
  local __v="$1" s="$2" n="$3"
  [ "${#s}" -gt "$n" ] && s="${s:0:n}…"
  printf -v "$__v" '%s' "$s"
}

# TODO.md 의 지문 - 줄 수 · 글자 수 · 열린 · 완료 · 보류 항목 수. 이번 턴에 바뀌었는지 볼 때 쓴다.
#   해시를 쓰면 명령을 하나 더 띄워야 한다. 쓰는 쪽과 보는 쪽이 같은 함수를 쓴다.
#   줄 수와 글자 수만 보면 done 을 놓친다. 「- [ ]」→「- [x]」는 한 글자만 바뀌고 줄을 옮겨도
#   줄 수 · 글자 수가 그대로라, 정리한 턴을 「안 바뀌었다」로 읽고 다음 작업을 막았다
tg_fp_to() {
  local __v="$1" l t n=0 c=0 o=0 x=0 h=0 _fl=()
  if [ -f "$TG_TODO" ]; then
    # while read 로 한 줄씩 읽으면 윈도우에서 파일 하나에 60ms 가 걸렸다(메시지마다 도는 훅의 대부분).
    #   mapfile 로 한 번에 읽는다. bash 3.2 에는 mapfile 이 없어 한 줄씩 읽는다
    if [ "${BASH_VERSINFO[0]:-3}" -ge 4 ]; then
      mapfile -t _fl < "$TG_TODO"
    else
      while IFS= read -r l || [ -n "$l" ]; do _fl+=("$l"); done < "$TG_TODO"
    fi
    for l in "${_fl[@]}"; do
      n=$((n+1)); c=$((c+${#l}+1))
      t="${l#"${l%%[![:space:]]*}"}"
      case "$t" in
        "- [ ]"*) o=$((o+1)) ;;
        "- [x]"*|"- [X]"*) x=$((x+1)) ;;
        "- [?]"*) h=$((h+1)) ;;
      esac
    done
  fi
  printf -v "$__v" '%s:%s:%s:%s:%s' "$n" "$c" "$o" "$x" "$h"
}

# ── 세션 ───────────────────────────────────────────────────────
# 한 프로젝트에서 세션 둘이 같이 돌 수 있다. 턴 기록은 세션마다 따로 둔다.
#   전에는 turn.txt 하나를 같이 써서, 한 세션의 지시가 다른 세션의 턴 판정을 덮었다.
#   TODO.md 는 하나다. 세션을 /clear 로 새로 열어도 남은 항목이 그대로 이어진다
#
#   .claude/todo-guard/s/<세션>.turn    이번 지시의 기록 (tg_read_turn)
#   .claude/todo-guard/s/<세션>.worked  파일을 바꾼 턴의 도장 \t 그 시각
#   .claude/todo-guard/s/<세션>.start   세션을 연 시각
#   .claude/todo-guard/s/<세션>.block   종료를 막을 때 남아 있던 항목 수
#   .claude/todo-guard/workn            파일을 바꾼 횟수 (프로젝트 전체)
#   .claude/todo-guard/reg.tsv          번호 \t 적은 세션 \t 적을 때의 workn (add 로 적은 것은 -)
TG_SD="$TG_DIR/s"
TG_SID="x"

# 훅 입력에서 세션 번호를 뽑는다 → TG_SID. 파일 이름에 쓰므로 영숫자 · - · _ 만 남긴다
tg_sid_from() {
  local s=""
  tg_json_raw_to s session_id "$1"
  s="${s//[^A-Za-z0-9_-]/}"
  TG_SID="${s:-x}"
}

# 이번 지시의 기록을 읽는다 → TG_T_STAMP · TG_T_FP · TG_T_IDS · TG_T_KIND · TG_T_PROMPT
#   한 줄: 도장 \t 지문 \t 적은 번호(없으면 -) \t 종류(w 지시 · q 질문) \t 지시 첫머리
#   빈 칸을 - 로 적는다. IFS 가 탭이면 빈 칸이 붙어 버려 뒤 칸이 앞으로 당겨진다
tg_read_turn() {
  TG_T_STAMP=""; TG_T_FP=""; TG_T_IDS=""; TG_T_KIND=""; TG_T_PROMPT=""
  [ -f "$TG_SD/$TG_SID.turn" ] || return 1
  IFS=$'\t' read -r TG_T_STAMP TG_T_FP TG_T_IDS TG_T_KIND TG_T_PROMPT < "$TG_SD/$TG_SID.turn"
  [ "$TG_T_IDS" = "-" ] && TG_T_IDS=""
  return 0
}

# tg_write_turn 도장 지문 번호들 종류 첫머리
tg_write_turn() {
  [ -d "$TG_SD" ] || mkdir -p "$TG_SD" 2>/dev/null || return 1
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "${3:--}" "${4:-w}" "$5" > "$TG_SD/$TG_SID.turn"
}

# 이번 턴에 파일을 바꾸는 작업을 했나 - pre-tool 이 도장을 찍어 둔다
tg_worked_this_turn() {
  local w="" e=""
  [ -f "$TG_SD/$TG_SID.worked" ] || return 1
  IFS=$'\t' read -r w e < "$TG_SD/$TG_SID.worked"
  [ -n "$TG_T_STAMP" ] && [ "$w" = "$TG_T_STAMP" ]
}

# 파일을 바꾼 횟수 → 변수
tg_workn_to() {
  local _tw_v="$1" _tw_n=0
  [ -f "$TG_DIR/workn" ] && read -r _tw_n < "$TG_DIR/workn"
  [[ "$_tw_n" =~ ^[0-9]+$ ]] || _tw_n=0
  printf -v "$_tw_v" '%s' "$_tw_n"
}

# 세션을 연 시각 → 변수 (기록이 없으면 0)
tg_start_to() {
  local _tst_v="$1" _tst_t=0
  [ -f "$TG_SD/$2.start" ] && read -r _tst_t < "$TG_SD/$2.start"
  [[ "$_tst_t" =~ ^[0-9]+$ ]] || _tst_t=0
  printf -v "$_tst_v" '%s' "$_tst_t"
}

# 세션을 연 시각을 적는다. 이미 있으면 두지 않는다 (compact 뒤에 다시 불려도 그대로)
tg_mark_start() {
  [ -f "$TG_SD/$TG_SID.start" ] && return 0
  [ -d "$TG_SD" ] || mkdir -p "$TG_SD" 2>/dev/null || return 1
  local _tm_t; tg_now_to _tm_t
  printf '%s\n' "$_tm_t" > "$TG_SD/$TG_SID.start"
}

# 세션이 마지막으로 움직인 시각 (지시를 받았거나 파일을 바꾼 때) → 변수
tg_last_act_to() {
  # 지역 변수 이름을 남과 겹치지 않게 둔다. 부르는 쪽이 a 에 받으려 하면 여기 a 에 담기고 만다
  local _tl_v="$1" _tl_sid="$2" _tl_a=0 _tl_s _tl_e
  if [ -f "$TG_SD/$_tl_sid.turn" ]; then
    IFS=$'\t' read -r _tl_s _tl_e < "$TG_SD/$_tl_sid.turn"
    _tl_s="${_tl_s%%-*}"; [[ "$_tl_s" =~ ^[0-9]+$ ]] && _tl_a=$_tl_s
  fi
  if [ -f "$TG_SD/$_tl_sid.worked" ]; then
    IFS=$'\t' read -r _tl_s _tl_e < "$TG_SD/$_tl_sid.worked"
    [[ "$_tl_e" =~ ^[0-9]+$ ]] && [ "$_tl_e" -gt "$_tl_a" ] && _tl_a=$_tl_e
  fi
  printf -v "$_tl_v" '%s' "$_tl_a"
}

# reg.tsv 를 읽는다 → TG_RID · TG_RSID · TG_RWN (bash 3.2 에 연관 배열이 없어 나란한 배열로 둔다)
tg_reg_load() {
  TG_RID=(); TG_RSID=(); TG_RWN=()
  [ -f "$TG_DIR/reg.tsv" ] || return 0
  local a b c
  while IFS=$'\t' read -r a b c || [ -n "$a" ]; do
    [ -n "$a" ] || continue
    TG_RID+=("$a"); TG_RSID+=("$b"); TG_RWN+=("${c%$'\r'}")
  done < "$TG_DIR/reg.tsv"
}

# 번호(묶음)의 기록을 찾는다 → TG_R (없으면 -1). 같은 번호가 여럿이면 마지막 것
tg_reg_find() {
  local i
  TG_R=-1
  for i in "${!TG_RID[@]}"; do [ "${TG_RID[i]}" = "$1" ] && TG_R=$i; done
  [ "$TG_R" -ge 0 ]
}

# tg_reg_add 번호 세션 workn
tg_reg_add() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$TG_DIR/reg.tsv"
}

# JSON 문자열 안에 넣을 수 있게 고친다 (\ " 줄바꿈)
tg_json_esc_to() {
  local __v="$1" s="$2" BS='\' DQ='"'
  s="${s//"$BS"/"$BS$BS"}"
  s="${s//"$DQ"/"$BS$DQ"}"
  s="${s//$'\r'/}"
  s="${s//$'\t'/ }"
  s="${s//$'\n'/"${BS}n"}"
  printf -v "$__v" '%s' "$s"
}

# 소문자로. ${s,,} 는 bash 4 부터라 macOS 기본 bash 에서는 tr 로 대신한다
tg_lower_to() {
  if [ "${BASH_VERSINFO[0]:-3}" -ge 4 ]; then
    printf -v "$1" '%s' "${2,,}"
  else
    printf -v "$1" '%s' "$(printf '%s' "$2" | tr 'A-Z' 'a-z')"
  fi
}

# Claude Code 메모리 폴더인가 (~/.claude/projects/<프로젝트>/memory/)
#   프로젝트 밖이지만 Claude Code 가 스스로 관리하는 저장소다. 막으면
#   「기억해 둬」가 매번 실패한다. .. 가 든 경로는 빠져나갈 수 있어 인정하지 않는다
tg_is_memory_path() {
  local s="$1"
  [ "$IS_WIN" = "1" ] && s="${s//\\//}"
  while [[ "$s" == *//* ]]; do s="${s//\/\//\/}"; done
  case "$s" in */../*|*/..) return 1 ;; esac
  case "$s" in */.claude/projects/*/memory/*) return 0 ;; esac
  return 1
}

# ── JSON 에서 문자열 값 뽑기 ───────────────────────────────────
# 훅 입력은 JSON 한 덩어리다. jq 를 띄우면 윈도우에서 0.4초라 셸 치환으로 뽑는다.
#   값 안의 \" 는 건너뛰고 닫는 따옴표에서 멈춘다. 이스케이프는 그대로 둔다
#   tg_json_raw_to VAR 키 "$INPUT"
tg_json_raw_to() {
  local __v="$1" key="$2" src="$3" rest chunk t val=""
  printf -v "$__v" '%s' ""
  case "$src" in *"\"$key\""*) ;; *) return 1 ;; esac
  rest="${src#*\"$key\"}"
  rest="${rest#"${rest%%[![:space:]]*}"}"
  [ "${rest:0:1}" = ":" ] || return 1
  rest="${rest:1}"
  rest="${rest#"${rest%%[![:space:]]*}"}"
  [ "${rest:0:1}" = '"' ] || return 1
  rest="${rest:1}"
  while :; do
    chunk="${rest%%\"*}"
    [ "$chunk" = "$rest" ] && break                 # 닫는 따옴표가 없다
    rest="${rest#*\"}"
    t="${chunk##*[!\\]}"                            # 끝에 붙은 역슬래시들
    if [ $(( ${#t} % 2 )) = 1 ]; then
      val+="$chunk\""                               # \" - 값 안의 따옴표
    else
      val+="$chunk"
      break
    fi
  done
  printf -v "$__v" '%s' "$val"
  return 0
}

# JSON 이스케이프를 푼다 (\\ \n \t \r \" \/). \uXXXX 는 그대로 둔다
tg_json_unescape_to() {
  local __v="$1" s="$2" BS='\' DQ='"' SOH=$'\001'
  case "$s" in
    *"$BS"*) ;;
    *) printf -v "$__v" '%s' "$s"; return 0 ;;
  esac
  s="${s//"$BS$BS"/$SOH}"
  s="${s//"${BS}n"/$'\n'}"
  s="${s//"${BS}t"/$'\t'}"
  s="${s//"${BS}r"/}"
  s="${s//"$BS$DQ"/$DQ}"
  s="${s//"$BS/"//}"
  # 따옴표 · 꺾쇠를 \u 로 적어 보내는 직렬화기도 있다. 판정에 쓰는 것만 푼다
  s="${s//"${BS}u0027"/\'}"
  s="${s//"${BS}u0022"/$DQ}"
  s="${s//"${BS}u003c"/<}"
  s="${s//"${BS}u003e"/>}"
  s="${s//"${BS}u0026"/&}"
  s="${s//$SOH/$BS}"
  printf -v "$__v" '%s' "$s"
}

# 경로를 절대 경로로 풀고 . · .. 를 정리한다. 풀 수 없으면(변수 · 와일드카드) 실패
#   tg_abs_to VAR 경로 기준폴더
tg_abs_to() {
  local __v="$1" p="$2" base="$3" prefix="" rest seg
  local stack=()
  case "$p" in
    '~') p="$HOME" ;;
    '~/'*) p="$HOME/${p#\~/}" ;;
    '$HOME'*) p="$HOME${p#\$HOME}" ;;
    '${HOME}'*) p="$HOME${p#\$\{HOME\}}" ;;
    '$env:USERPROFILE'*) p="$HOME${p#\$env:USERPROFILE}" ;;
    '$env:HOME'*) p="$HOME${p#\$env:HOME}" ;;
  esac
  case "$p" in *'$'*|*'`'*|*'*'*|*'?'*) return 1 ;; esac
  [ "$IS_WIN" = "1" ] && { p="${p//\\//}"; base="${base//\\//}"; }
  case "$p" in
    /*|[A-Za-z]:*) ;;
    *) p="$base/$p" ;;
  esac
  case "$p" in
    [A-Za-z]:/*) prefix="${p:0:3}"; rest="${p:3}" ;;
    [A-Za-z]:) prefix="${p}/"; rest="" ;;
    [A-Za-z]:*) prefix="${p:0:2}/"; rest="${p:2}" ;;
    /*) prefix="/"; rest="${p#/}" ;;
    *) rest="$p" ;;
  esac
  while [ -n "$rest" ]; do
    seg="${rest%%/*}"
    if [ "$seg" = "$rest" ]; then rest=""; else rest="${rest#*/}"; fi
    case "$seg" in
      ''|.) ;;
      ..) [ "${#stack[@]}" -gt 0 ] && stack=("${stack[@]:0:${#stack[@]}-1}") ;;
      *) stack+=("$seg") ;;
    esac
  done
  local IFS=/
  printf -v "$__v" '%s' "$prefix${stack[*]}"
}

# ── 완료 항목 정리 ─────────────────────────────────────────────
# 완료 항목이 쌓이면 TODO.md 를 읽을 때마다 비싸다 (실제로 94KB · 완료 342개까지 쌓였다).
#   「진행 중」에 남은 완료 항목과, 「완료」에서 최근 몇 개를 뺀 나머지를
#   TODO-완료.md 로 옮긴다. 지우지 않는다. 하위 줄도 함께 옮긴다
#   tg_archive 남길개수  →  TG_MOVED 에 옮긴 항목 수
_tg_arc_keep=10
_tg_arc_seen=0
_tg_arc_pred() {
  tg_is_done "$1" || return 1
  _tg_arc_seen=$((_tg_arc_seen+1))
  [ "$_tg_arc_seen" -gt "$_tg_arc_keep" ]
}
tg_archive() {
  _tg_arc_keep="${1:-10}"
  TG_MOVED=0
  tg_load || return 1
  local moved=() e
  # 1) 「진행 중」에 남은 완료 항목 - 전부 옮긴다
  if tg_find_head "## 진행 중"; then
    tg_section_end "$TG_I"
    _tg_arc_seen=0; local saved="$_tg_arc_keep"; _tg_arc_keep=0
    tg_take _tg_arc_pred "" "$((TG_I+1))" "$TG_E"
    _tg_arc_keep="$saved"
    moved+=("${TG_TAKEN[@]}")
  fi
  # 2) 「완료」 - 위에서 _tg_arc_keep 개만 남긴다
  if tg_find_head "## 완료"; then
    e=$((TG_I+1))
    while [ "$e" -lt "${#TG_L[@]}" ] && [[ "${TG_L[e]}" != "## "* ]]; do e=$((e+1)); done
    _tg_arc_seen=0
    tg_take _tg_arc_pred "" "$((TG_I+1))" "$e"
    moved+=("${TG_TAKEN[@]}")
  fi
  local x
  for x in "${moved[@]}"; do tg_is_done "$x" && TG_MOVED=$((TG_MOVED+1)); done
  [ "$TG_MOVED" -gt 0 ] || return 0
  local arc="$PROJ/TODO-완료.md" day=""
  printf -v day '%(%Y-%m-%d)T' -1 2>/dev/null || day="$(date +%Y-%m-%d)"
  local eol='%s\n'
  [ "${TG_CRLF:-0}" = 1 ] && eol='%s\r\n'
  if [ ! -f "$arc" ]; then
    printf "$eol" "# TODO 완료 기록" "" "TODO.md 에서 옮겨 온 완료 항목. 투두가드가 TODO.md 를 가볍게 두려고 옮긴다." > "$arc"
  fi
  printf "$eol" "" "## $day 정리 (${TG_MOVED}개)" "" "${moved[@]}" >> "$arc"
  tg_save
}
