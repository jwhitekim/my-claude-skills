#!/usr/bin/env bash
# dirname 을 띄우지 않는다. 윈도우에서 프로세스 하나가 0.5초씩 걸린다.
#   경로에 역슬래시가 섞이면 이 방식이 엉뚱한 곳을 가리키므로, 찾지 못하면
#   설치 경로로 물러선다. 역슬래시를 직접 다루지 않아 인용 사고가 없다
_TG_DIR="${BASH_SOURCE[0]%/*}"
[ -f "$_TG_DIR/_root.sh" ] || _TG_DIR="$HOME/.claude/skills/todo-guard/scripts"
. "$_TG_DIR/_root.sh"
. "$_TG_DIR/_shell.sh"
# PreToolUse 훅: 도구가 실제로 실행되기 전에 막는다.
#
# 막는 것
#   1. TODO.md 의 완료 이력을 지우는 것
#      Write 로 통째 쓰기 · Edit 로 - [x] 줄 줄이기 · cp/mv/rm/git checkout 으로 덮기 ·
#      파이썬 open('TODO.md','w') · PowerShell Set-Content/Remove-Item
#   2. 프로젝트 폴더 밖을 고치는 것 (allowOutside 에 적은 경로 · 임시 · 메모리 폴더는 통과)
#      Edit/Write 뿐 아니라 셸 명령의 쓰기 대상도 본다 (> · cp · mv · rm · sed -i · Set-Content …)
#   3. 열린 항목 없이 파일을 바꾸는 것
#      지시는 prompt-mark 훅이 받는 순간 등록하므로, 보통은 여기서 막히지 않는다.
#      배경 알림으로 깨어나 일을 이어 가거나, 다 끝낸 뒤 손을 더 대는 경우에 걸린다
#
# 적어 두는 것
#   파일을 바꾸는 작업이 지나가면
#     .claude/todo-guard/s/<세션>.worked 에 이번 지시의 도장을 찍는다.
#       턴이 끝날 때 도장이 없고 질문으로 적힌 지시면 check-todo 가 지운다
#     .claude/todo-guard/workn 을 1 올린다. todo.sh done 이 「적은 뒤 파일을 바꿨나」를 본다
#
# 보는 도구: Write · Edit · NotebookEdit · Bash · PowerShell
#   전에는 PowerShell 을 보지 않아, 윈도우 기본 셸로 한 일은 전부 검사를 건너뛰었다
#
# 종료 코드  0 통과 / 2 차단 (stderr 가 Claude 에게 전달된다)

IFS= read -r -d '' INPUT || true
CONF="$PROJ/.claude/todo-guard.json"
tg_sid_from "$INPUT"

# 설정으로 끌 수 있다
if read_all "$CONF" && [[ "$REPLY" =~ \"preGuard\"[[:space:]]*:[[:space:]]*false ]]; then
  exit 0
fi

TOOL=""
tg_json_raw_to TOOL tool_name "$INPUT"
TODO_CMD="bash \"\$HOME/.claude/skills/todo-guard/scripts/todo.sh\""

block() {
  printf '%s\n' "$@" >&2
  exit 2
}

# ── 도구별로 무엇을 바꾸는지 뽑는다 ─────────────────────────────
KIND=read
TGTS=(); TGT_CWDS=()
TODO_KILL=0; TODO_ADD=0
case "$TOOL" in
  Write|Edit|MultiEdit|NotebookEdit)
    FP=""
    tg_json_raw_to FP file_path "$INPUT" || tg_json_raw_to FP notebook_path "$INPUT"
    [ -n "$FP" ] || exit 0
    tg_json_unescape_to FP "$FP"
    if sh_is_todo_path "$FP"; then
      KIND=todo
      if [ "$TOOL" = "Write" ] && [ -f "$TG_TODO" ]; then
        block "[todo-guard] TODO.md 를 Write 로 통째로 쓰려 했습니다. 차단합니다." \
              "  완료 이력이 날아갑니다. 항목은 훅이 적고, 완료 표시는 이렇게 합니다:" \
              "    $TODO_CMD done <번호>"
      fi
      if [ "$TOOL" = "Edit" ]; then
        OLD=""; NEW=""
        tg_json_raw_to OLD old_string "$INPUT"
        tg_json_raw_to NEW new_string "$INPUT"
        X='- [x]'
        o="${OLD//"$X"/}"; n="${NEW//"$X"/}"
        oc=$(( (${#OLD} - ${#o}) / ${#X} )); nc=$(( (${#NEW} - ${#n}) / ${#X} ))
        if [ "$nc" -lt "$oc" ]; then
          block "[todo-guard] TODO.md 에서 완료 항목(- [x])을 지우려 했습니다. 차단합니다." \
                "  완료 이력은 지우지 않습니다. TODO.md 가 무거우면 옮깁니다:" \
                "    $TODO_CMD archive"
        fi
      fi
    elif tg_is_memory_path "$FP"; then
      exit 0
    else
      KIND=work; TGTS=("$FP"); TGT_CWDS=("$PWD")
    fi
    ;;
  Bash|PowerShell)
    RAW=""; CMD=""
    tg_json_raw_to RAW command "$INPUT"
    tg_json_unescape_to CMD "$RAW"
    mode=bash; [ "$TOOL" = "PowerShell" ] && mode=ps
    sh_classify "$CMD" "$mode"
    KIND="$SH_KIND"; TODO_KILL="$SH_TODO_KILL"; TODO_ADD="$SH_TODO_ADD"
    TGTS=("${SH_TGT[@]}"); TGT_CWDS=("${SH_TGT_CWD[@]}")
    # 번호를 반복문 · 변수로 통째로 돌려 done 하면 빠뜨린 지시까지 완료로 찍힌다.
    #   for n in 1 … 31; do todo.sh done $n; done - 몰아넣기 벤치마크에서 모델이 그렇게 했다
    RX_LOOPDONE='todo\.sh"?[[:space:]]+done[[:space:]]+"?\$'
    if [[ "$CMD" =~ $RX_LOOPDONE ]]; then
      block "[todo-guard] 번호를 반복문 · 변수로 돌려 한꺼번에 완료 처리하려 했습니다. 차단합니다." \
            "  빠뜨린 지시까지 완료로 찍힙니다. 실제로 끝낸 번호만 적으십시오: todo.sh done 3 5 7.2"
    fi
    # add 로 적는 항목은 이 세션 몫이다. todo.sh 는 세션 번호를 모르므로 여기서 남겨 둔다
    if [ "$TODO_ADD" = 1 ] && [ -d "$TG_DIR" ]; then
      printf '%s\n' "$TG_SID" > "$TG_DIR/add_owner"
    fi
    if [ "$TODO_KILL" = 1 ] && [ -f "$TG_TODO" ]; then
      block "[todo-guard] TODO.md 를 덮어쓰거나 지우려 했습니다. 차단합니다." \
            "  완료 이력이 날아갑니다. 항목 정리는 이것으로만 합니다:" \
            "    $TODO_CMD done <번호> · hold <번호> \"사유\" · add \"할 일\" · archive"
    fi
    ;;
  *) exit 0 ;;
esac

# ── 프로젝트 밖 ────────────────────────────────────────────────
# 현재 폴더가 아니라 프로젝트 루트로 견준다. 하위 폴더에서 불러도 같은 판정이 나온다
if [ "${#TGTS[@]}" -gt 0 ]; then
  norm_path_to ROOTN "$PROJ"
  ALLOW=()
  if read_all "$CONF" && [[ "$REPLY" =~ \"allowOutside\"[[:space:]]*:[[:space:]]*\[([^]]*)\] ]]; then
    A="${BASH_REMATCH[1]}"; A="${A//$'\n'/ }"
    OLDIFS="$IFS"; IFS=','
    for a in $A; do
      a="${a//\"/}"
      a="${a#"${a%%[![:space:]]*}"}"; a="${a%"${a##*[![:space:]]}"}"
      [ -z "$a" ] && continue
      tg_json_unescape_to a "$a"
      norm_path_to an "$a"; ALLOW+=("$an")
    done
    IFS="$OLDIFS"
  fi
  for i in "${!TGTS[@]}"; do
    t="${TGTS[i]}"
    # macOS · 리눅스에서 역슬래시는 파일 이름 글자다. 윈도우에서만 절대 경로로 본다
    if [ "$IS_WIN" != "1" ]; then case "$t" in *\\*) continue ;; esac; fi
    tg_abs_to ABS "$t" "${TGT_CWDS[i]}" || continue
    norm_path_to NORM "$ABS"
    case "$NORM" in "$ROOTN"/*|"$ROOTN") continue ;; esac
    # 시스템이 정해 준 임시·스크래치패드 폴더와 메모리 폴더는 막지 않는다
    case "$NORM" in
      */temp/claude/*|*/tmp/claude/*|/tmp/*|/tmp|*/appdata/local/temp/*|/private/tmp/*|/private/var/folders/*|/var/folders/*) continue ;;
    esac
    tg_is_memory_path "$NORM" && continue
    ok=0
    for an in "${ALLOW[@]}"; do
      case "$NORM" in "$an"/*|"$an") ok=1; break ;; esac
    done
    [ "$ok" = 1 ] && continue
    block "[todo-guard] 프로젝트 폴더 밖을 고치려 했습니다. 차단합니다." \
          "  고치려는 곳   : $t" \
          "  프로젝트 폴더 : $PROJ" \
          "  사용자에게 확인을 받고, 허가받았으면 아래를 실행한 뒤 다시 시도하십시오." \
          "    bash ~/.claude/skills/todo-guard/scripts/allow-outside.sh \"$ABS\"" \
          "  밖에서 작업하는 동안에는 매 응답 맨 위에 경고 배너를 붙이십시오."
  done
fi

[ "$KIND" = work ] || exit 0
[ -f "$TG_TODO" ] || exit 0

# ── 열린 항목 없이 작업 ────────────────────────────────────────
tg_read_turn                    # 기록이 없으면(TG_T_STAMP 가 비면) 판정하지 않는다

registered() {
  [ "$TODO_ADD" = 1 ] && return 0                   # 같은 명령에서 등록한다
  local l
  while IFS= read -r l || [ -n "$l" ]; do
    case "${l#"${l%%[![:space:]]*}"}" in "- [ ]"*) return 0 ;; esac
  done < "$TG_TODO"
  # 이번 지시 뒤로 TODO.md 가 바뀌었으면 정리한 것이다 (- [x] · - [?] 로 닫아 0 이 돼도 통과)
  local fp
  tg_fp_to fp
  [ "$fp" != "$TG_T_FP" ]
}

if [ -n "$TG_T_STAMP" ] && ! registered; then
  block "[todo-guard] 열린 항목이 없는데 파일을 바꾸려 했습니다. 차단합니다." \
        "  지금 하는 일을 먼저 적으십시오. 같은 명령 앞에 && 로 붙여도 됩니다." \
        "    $TODO_CMD add \"할 일\"" \
        "  질문이라 답만 하면 되는 것이면 파일을 바꾸지 말고 답하십시오."
fi

# 파일을 바꾸는 작업이 지나갔다는 기록
#   worked  이번 턴의 도장 - 턴이 끝날 때 질문이었는지 가른다
#   workn   바꾼 횟수 - done 할 때 「적은 뒤 파일을 바꿨나」를 본다.
#           세션 번호가 다르게 오는 경우(서브에이전트 등)에도 세도록 턴 기록과 상관없이 올린다
[ -d "$TG_DIR" ] || exit 0
tg_workn_to WN
printf '%s\n' "$((WN+1))" > "$TG_DIR/workn"
# 무엇을 바꿨나 - done 할 때 항목이 가리키는 파일 · 슬라이드를 바꿨는지 본다
for t in "${TGTS[@]}"; do
  printf '%s\t%s\n' "$((WN+1))" "$t" >> "$TG_DIR/changes.log"
done
if [ -n "$TG_T_STAMP" ]; then
  tg_now_to NOW
  printf '%s\t%s\n' "$TG_T_STAMP" "$NOW" > "$TG_SD/$TG_SID.worked"
fi
exit 0
