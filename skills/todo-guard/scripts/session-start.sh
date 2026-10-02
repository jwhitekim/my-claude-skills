#!/usr/bin/env bash
# dirname 을 띄우지 않는다. 윈도우에서 프로세스 하나가 0.5초씩 걸린다.
#   경로에 역슬래시가 섞이면 이 방식이 엉뚱한 곳을 가리키므로, 찾지 못하면
#   설치 경로로 물러선다. 역슬래시를 직접 다루지 않아 인용 사고가 없다
_TG_DIR="${BASH_SOURCE[0]%/*}"
[ -f "$_TG_DIR/_root.sh" ] || _TG_DIR="$HOME/.claude/skills/todo-guard/scripts"
. "$_TG_DIR/_root.sh"
# SessionStart 훅: stdout 이 Claude 컨텍스트에 주입된다.
#   1) 「항상 지킬 것」을 맨 먼저 보여 준다
#   2) 완료 항목이 쌓였으면 TODO-완료.md 로 옮긴다 (TODO.md 를 가볍게)
#   3) 미완료 항목을 보고한다
#
# 짧게 쓴다. 여기 찍힌 글은 세션 내내 문맥에 남아 모든 호출이 다시 읽는다

INPUT=""
IFS= read -r -d '' INPUT || true

if [ ! -f "$TG_TODO" ]; then
  echo "[todo-guard] 이 프로젝트에 TODO.md 가 없습니다. todo-guard 스킬을 읽고 세팅하십시오."
  exit 0
fi

# 세션을 연 시각. 다른 세션이 남긴 항목을 이 세션이 맡을지 check-todo 가 이것으로 가른다
tg_sid_from "$INPUT"
tg_mark_start

# 일주일 넘게 움직이지 않은 세션의 기록은 지운다. rm 은 한 번만 띄운다
old=(); tg_now_to NOW
for f in "$TG_SD"/*.start; do
  [ -f "$f" ] || continue
  sid="${f##*/}"; sid="${sid%.start}"
  [ "$sid" = "$TG_SID" ] && continue
  tg_last_act_to act "$sid"; tg_start_to st "$sid"
  [ "$st" -gt "$act" ] && act=$st
  [ $((NOW - act)) -gt 604800 ] && old+=("$TG_SD/$sid.start" "$TG_SD/$sid.turn" "$TG_SD/$sid.worked" "$TG_SD/$sid.block")
done
[ "${#old[@]}" -gt 0 ] && rm -f "${old[@]}" 2>/dev/null
# 옛 판의 턴 기록 (세션을 나누기 전)
[ -f "$TG_DIR/turn.txt" ] && rm -f "$TG_DIR/turn.txt" "$TG_DIR/worked" 2>/dev/null

# 사용자가 한 번 말한 금지·필수 사항. 몇 턴 지나면 잊으므로 매 세션 맨 위에 둔다
standing_rules_to RULES
if [ -n "$RULES" ]; then
  echo "[todo-guard] ★ 항상 지킬 것 - 사용자가 정한 규칙입니다. 어기지 마십시오."
  # 이 글은 세션 내내 문맥에 남는다. 12개까지만, 줄마다 120자까지 보여 준다
  n=0
  while IFS= read -r _r || [ -n "$_r" ]; do n=$((n+1)); done <<< "$RULES"
  i=0
  while IFS= read -r _r || [ -n "$_r" ]; do
    i=$((i+1))
    [ "$i" -gt 12 ] && { echo "  … 외 $((n - 12))개 - 전부는 TODO.md 맨 위에 있습니다"; break; }
    _r="${_r#- }"; tg_cut_to _r "$_r" 120
    echo "  · $_r"
  done <<< "$RULES"
  echo
fi

# 완료 항목이 40개를 넘으면 최근 10개만 남기고 옮긴다
tg_load
DONE=0
for l in "${TG_L[@]}"; do tg_is_done "$l" && DONE=$((DONE+1)); done
if [ "$DONE" -gt 40 ]; then
  tg_archive 10 && [ "$TG_MOVED" -gt 0 ] &&     echo "[todo-guard] 완료 항목 ${TG_MOVED}개를 TODO-완료.md 로 옮겼습니다. 지우지 않았습니다."
  tg_load
fi

OPEN=(); HOLD=(); LIVE=" "
for l in "${TG_L[@]}"; do
  case "${l#"${l%%[![:space:]]*}"}" in
    "- [ ]"*) OPEN+=("${l#"${l%%[![:space:]]*}"}") ;;
    "- [?]"*) HOLD+=("${l#"${l%%[![:space:]]*}"}") ;;
    *) continue ;;
  esac
  [[ "$l" =~ $TG_RX_ITEM ]] && LIVE+="${BASH_REMATCH[2]} "
done

# reg.tsv 에서 다 끝난 번호를 걷는다. 남은 것만 다시 쓴다
if [ -f "$TG_DIR/reg.tsv" ]; then
  tg_reg_load; keep=()
  for i in "${!TG_RID[@]}"; do
    [[ "$LIVE" == *" ${TG_RID[i]} "* ]] && keep+=("${TG_RID[i]}"$'\t'"${TG_RSID[i]}"$'\t'"${TG_RWN[i]}")
  done
  if [ "${#keep[@]}" != "${#TG_RID[@]}" ]; then
    if [ "${#keep[@]}" -gt 0 ]; then printf '%s\n' "${keep[@]}" > "$TG_DIR/reg.tsv"; else : > "$TG_DIR/reg.tsv"; fi
  fi
fi

# changes.log 에서 남은 항목보다 앞선 기록을 걷는다 (done 대조에 더는 쓰이지 않는다)
if [ -s "$TG_DIR/changes.log" ]; then
  tg_reg_load; low=""
  for w in "${TG_RWN[@]}"; do
    [[ "$w" =~ ^[0-9]+$ ]] || continue
    { [ -z "$low" ] || [ "$w" -lt "$low" ]; } && low=$w
  done
  if [ -z "$low" ]; then
    : > "$TG_DIR/changes.log"
  else
    keep=()
    while IFS= read -r cl || [ -n "$cl" ]; do
      n="${cl%%$'\t'*}"
      [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -gt "$low" ] && keep+=("$cl")
    done < "$TG_DIR/changes.log"
    if [ "${#keep[@]}" -gt 0 ]; then printf '%s\n' "${keep[@]}" > "$TG_DIR/changes.log"; else : > "$TG_DIR/changes.log"; fi
  fi
fi

if [ "${#OPEN[@]}" -gt 0 ]; then
  echo "[todo-guard] 이전 세션의 미완료 항목 ${#OPEN[@]}개 - 사용자에게 보고하고 이어서 처리하십시오."
  i=0
  for l in "${OPEN[@]}"; do
    i=$((i+1)); [ "$i" -gt 15 ] && { echo "  … 외 $(( ${#OPEN[@]} - 15 ))개"; break; }
    tg_cut_to l "$l" 90; echo "  $l"
  done
fi
# 보류 항목도 알린다. 사용자 판단을 기다리는 것이라 안 보이면 그대로 묻힌다
if [ "${#HOLD[@]}" -gt 0 ]; then
  echo "[todo-guard] 사용자 판단을 기다리는 보류 항목 ${#HOLD[@]}개 - 사용자에게 다시 물으십시오."
  i=0
  for l in "${HOLD[@]}"; do
    i=$((i+1)); [ "$i" -gt 5 ] && { echo "  … 외 $(( ${#HOLD[@]} - 5 ))개"; break; }
    tg_cut_to l "$l" 90; echo "  $l"
  done
fi
# 사용법은 CLAUDE.md 운영 규칙에 있다. 여기서 되풀이하지 않는다
exit 0
