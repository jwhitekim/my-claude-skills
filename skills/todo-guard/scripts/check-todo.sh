#!/usr/bin/env bash
# dirname 을 띄우지 않는다. 윈도우에서 프로세스 하나가 0.5초씩 걸린다.
#   경로에 역슬래시가 섞이면 이 방식이 엉뚱한 곳을 가리키므로, 찾지 못하면
#   설치 경로로 물러선다. 역슬래시를 직접 다루지 않아 인용 사고가 없다
_TG_DIR="${BASH_SOURCE[0]%/*}"
[ -f "$_TG_DIR/_root.sh" ] || _TG_DIR="$HOME/.claude/skills/todo-guard/scripts"
. "$_TG_DIR/_root.sh"
# Stop 훅: TODO.md 에 미완료 항목(- [ ])이 있으면 턴 종료를 막는다.
#   exit 0 = 종료 허용 / exit 2 = 종료 차단 (stderr 가 Claude 에게 전달된다)
#
# 1) 질문 턴을 정리한다
#   prompt-mark 가 질문 · 의견(q)으로 본 지시를 적었는데 이번 턴에 파일을 바꾸는 작업이 한 번도
#   없었으면(pre-tool 이 도장을 찍지 않았으면) 그 줄을 지운다. 지시(w)는 지우지 않는다.
#   전에는 종류를 가리지 않고 지워서, 「반영하겠습니다」만 하고 끝낸 지시가 사라졌다
#
# 2) 이 세션이 맡은 열린 항목만 본다
#   다른 세션이 적었고 그 세션이 아직 움직이고 있으면(이 세션을 연 뒤에 활동) 그 세션 몫이다.
#   그 세션이 이 세션을 열기 전에 멈췄으면(/clear · 새 세션) 남긴 일로 보고 이 세션이 맡는다
#
# 3) 남은 게 줄어드는 동안은 계속 막는다
#   전에는 stop_hook_active 면 무조건 통과시켜 한 번만 막았다. 3개 남은 채 한 개만 하고
#   다시 끝내려 하면 그대로 끝났다. 이제 막을 때 남은 수를 적어 두고, 줄었으면 또 막는다.
#   줄지 않았으면(진전 없음) 풀어 준다 - 무한 루프는 없다. 풀어 줄 때는 남은 항목을
#   사용자 화면에 띄운다(systemMessage). 조용히 끝나면 그게 바로 누락이다

IFS= read -r -d '' INPUT || true
[ -f "$TG_TODO" ] || exit 0
tg_sid_from "$INPUT"
ACTIVE=0
[[ "$INPUT" =~ \"stop_hook_active\"[[:space:]]*:[[:space:]]*true ]] && ACTIVE=1

tg_read_turn
tg_load
if [ "$TG_T_KIND" = q ] && [ -n "$TG_T_IDS" ] && ! tg_worked_this_turn; then
  tg_take tg_open_has_id "$TG_T_IDS"
  if [ "${#TG_TAKEN[@]}" -gt 0 ]; then
    tg_save
    # 지문을 새로 맞춘다. 지운 것을 「이번 턴에 정리했다」로 오해하지 않게 한다
    tg_fp_to FP
    tg_write_turn "$TG_T_STAMP" "$FP" "" q "$TG_T_PROMPT"
  fi
fi

# 이 세션이 맡은 열린 항목 (- [ ] 만. - [?] 는 사용자 판단 대기라 막지 않는다)
tg_reg_load
tg_start_to MYSTART "$TG_SID"
mine() {
  tg_reg_find "$1" || return 0
  local o="${TG_RSID[TG_R]}" a
  [ -z "$o" ] || [ "$o" = "$TG_SID" ] && return 0
  tg_last_act_to a "$o"
  [ "$a" -le "$MYSTART" ]
}
OPEN=(); OIDS=(); NOID=0
for l in "${TG_L[@]}"; do
  t="${l#"${l%%[![:space:]]*}"}"
  case "$t" in "- [ ]"*) ;; *) continue ;; esac
  if [[ "$t" =~ $TG_RX_ITEM ]]; then
    g="${BASH_REMATCH[2]}"; id="${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
    mine "$g" || continue
    OIDS+=("$id")
  else
    NOID=1
  fi
  OPEN+=("$t")
done

BF="$TG_SD/$TG_SID.block"
if [ "${#OPEN[@]}" = 0 ]; then
  [ -s "$BF" ] && : > "$BF"
  exit 0
fi

if [ "$ACTIVE" = 1 ]; then
  prev=""
  [ -f "$BF" ] && read -r prev < "$BF"
  if [[ "$prev" =~ ^[0-9]+$ ]] && [ "${#OPEN[@]}" -ge "$prev" ]; then
    # 막아도 진전이 없다. 풀어 주고 남은 것을 사용자에게 보인다
    : > "$BF"
    msg="[todo-guard] 끝나지 않은 항목 ${#OPEN[@]}개가 남은 채 턴이 끝났습니다"
    i=0
    for l in "${OPEN[@]}"; do
      i=$((i+1)); [ "$i" -gt 6 ] && { msg+=$'\n'"  … 외 $(( ${#OPEN[@]} - 6 ))개"; break; }
      l="${l#- \[ \] }"; tg_cut_to l "$l" 50
      msg+=$'\n'"  $l"
    done
    tg_json_esc_to msg "$msg"
    printf '{"systemMessage":"%s"}\n' "$msg"
    exit 0
  fi
fi
[ -d "$TG_SD" ] || mkdir -p "$TG_SD" 2>/dev/null
printf '%s\n' "${#OPEN[@]}" > "$BF"

# 막는 글. 짧게 쓴다 - 이 글도 문맥에 남는다. 명령 경로는 CLAUDE.md 운영 규칙에 있다
MSG="[todo-guard] 끝나지 않은 항목 - 끝냈으면 todo.sh done 번호, 파일을 바꾸지 않는 일이었으면 done 번호 --why \"사유\", 판단이 필요하면 hold"
i=0
for l in "${OPEN[@]}"; do
  i=$((i+1))
  [ "$i" -gt 8 ] && { MSG+=$'\n'"  … 외 $(( ${#OPEN[@]} - 8 ))개"; break; }
  tg_cut_to l "$l" 70
  MSG+=$'\n'"  $l"
done
# 이번 지시에 손도 안 댄 채 끝내려 한다 - 「반영하겠습니다」만 하고 끝내는 경우
if [ "$TG_T_KIND" = w ] && [ -n "$TG_T_IDS" ] && ! tg_worked_this_turn; then
  for id in "${OIDS[@]}"; do
    if [ "${id%%.*}" = "$TG_T_IDS" ]; then
      MSG+=$'\n'"  이번 지시 #$TG_T_IDS 에 파일을 하나도 바꾸지 않았습니다. 하겠다고만 하고 끝내지 마십시오"
      break
    fi
  done
fi
[ "$NOID" = 1 ] && MSG+=$'\n'"  번호 없는 옛 항목은 Edit 로 - [x] 나 - [?] 로 바꾼다"
# 「항상 지킬 것」은 여기서 찍지 않는다 (2026-09-26).
#   막을 때마다 딸려 나와 사용자 화면에서 답변을 밀어 올렸고, 그 글이 문맥에도 그대로 쌓였다.
#   규칙은 세션을 열 때 한 번 보여 주고, TODO.md 맨 위에 그대로 있다

# 종료 코드 2 대신 JSON 으로 막는다 (2026-09-27).
#   2 로 끝내면 Claude Code 가 「Stop hook error」로 적어 사용자에게 고장처럼 보인다.
#   decision=block 은 같은 일을 하면서 오류가 아니라 「막음」으로 표시된다.
#   JSON 을 못 읽는 판을 만나면 stderr + 2 로 물러선다
tg_json_esc_to RS "$MSG"
printf '{"decision":"block","reason":"%s"}\n' "$RS"
exit 0
