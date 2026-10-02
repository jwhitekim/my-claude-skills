#!/usr/bin/env bash
# dirname 을 띄우지 않는다. 윈도우에서 프로세스 하나가 0.5초씩 걸린다.
#   경로에 역슬래시가 섞이면 이 방식이 엉뚱한 곳을 가리키므로, 찾지 못하면
#   설치 경로로 물러선다. 역슬래시를 직접 다루지 않아 인용 사고가 없다
_TG_DIR="${BASH_SOURCE[0]%/*}"
[ -f "$_TG_DIR/_root.sh" ] || _TG_DIR="$HOME/.claude/skills/todo-guard/scripts"
. "$_TG_DIR/_root.sh"
# TODO.md 장부를 모델 대신 정리한다.
#
# 왜 있나
#   모델이 TODO.md 를 Read · Edit 하면 호출 한 번이 대화 전체를 다시 읽는다.
#   이 명령은 마지막 확인 명령(테스트 · 빌드 · 실행) 뒤에 && 로 붙여 쓴다.
#   따로 부르지 않으니 호출이 늘지 않고, TODO.md 를 읽을 필요도 없다.
#
# 사용
#   todo.sh done 12 [13.2 …]      완료. 하위 항목은 끝낸 것만 번호로 적는다
#   todo.sh done 12 --why "사유"   파일을 바꾸지 않고 끝난 일(빌드 · 테스트 · 조사 · 답변),
#                                  한 번에 여러 항목을 고친 경우. 사유가 항목 옆에 남는다
#   todo.sh hold 12 "사유"         보류 - 사용자 판단 대기. 턴 종료를 막지 않는다
#   todo.sh add "할 일" [...]      지시에 없던 일을 더 적는다 (새 번호)
#   todo.sh list                   열린 항목 · 보류 항목
#   todo.sh archive [남길 개수]     완료 항목을 TODO-완료.md 로 옮긴다 (기본 10개 남김)
#
# 번호는 # 를 붙여도 된다 (#12). 항목 글자로는 고르지 않는다. 한글 따옴표가
#   셸을 거치며 깨지는 일이 잦아, 번호만 받는다

S="bash \"\$HOME/.claude/skills/todo-guard/scripts/todo.sh\""
usage() { sed -n '/^# 사용/,/^# 번호는/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 2; }

[ -f "$TG_TODO" ] || { echo "[todo-guard] TODO.md 가 없습니다: $TG_TODO" >&2; exit 1; }

open_ids() {
  local l out=""
  for l in "${TG_L[@]}"; do
    [[ "$l" =~ $TG_RX_ITEM ]] || continue
    [ "${BASH_REMATCH[1]}" = " " ] && out+=" #${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
  done
  printf '%s' "${out:- (없음)}"
}

# 열렸거나 보류된 항목이면서 번호가 맞는가
openish_has_id() {
  case "${1#"${1%%[![:space:]]*}"}" in "- [ ] "*|"- [?] "*) ;; *) return 1 ;; esac
  tg_has_id "$1" "$2"
}

cmd="${1:-list}"; [ $# -gt 0 ] && shift
case "$cmd" in
  done)
    WHY=""; HASWHY=0; ARGS=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --why) HASWHY=1; WHY="${2:-}"; [ $# -ge 2 ] && shift; shift ;;
        --why=*) HASWHY=1; WHY="${1#--why=}"; shift ;;
        *) ARGS+=("$1"); shift ;;
      esac
    done
    [ "${#ARGS[@]}" -gt 0 ] || usage
    set -- "${ARGS[@]}"
    if [ "$HASWHY" = 1 ] && [ -z "${WHY//[[:space:]]/}" ]; then
      echo "[todo-guard] --why 뒤에 사유를 적으십시오: done $* --why \"빌드 성공\"" >&2
      exit 1
    fi
    # 끝낸 번호만 적는다. 여러 개면 한 번에 done 3 5 7.2 로 적어도 된다.
    #   편집은 몰아서 하고, 끝낸 번호만 정확히 적게 한다. 항목마다 따로 돌리게 하면
    #   20MB 슬라이드를 수십 번 열고 저장해 44% 느려졌다 (대화형 벤치마크).
    #   번호를 반복문으로 통째로 돌리는 것은 pre-tool 훅이 막는다 - 빠뜨린 지시까지 완료로 찍힌다
    tg_load
    # 하위 항목이 있는 번호를 통째로 주면 받지 않는다 (done 3 → #3.1~#3.5 전부).
    #   하위 항목을 하나씩 적게 한다: done 3.1 3.2 … - 끝낸 것만 골라 적으라는 뜻이다
    for a in "$@"; do
      a="${a#\#}"
      case "$a" in *.*) continue ;; esac
      subs=""
      for l in "${TG_L[@]}"; do
        case "${l#"${l%%[![:space:]]*}"}" in "- [ ] #$a."*|"- [?] #$a."*) ;; *) continue ;; esac
        [[ "$l" =~ $TG_RX_ITEM ]] && subs+=" ${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
      done
      if [ -n "$subs" ]; then
        echo "[todo-guard] #$a 에는 하위 항목이 있습니다. 끝낸 것만 번호로 적으십시오: done${subs}" >&2
        exit 1
      fi
    done
    # 적은 뒤로 파일을 바꾼 횟수보다 많이 끝냈다고 하면 받지 않는다.
    #   투두가드는 장부만 지키고 실제 파일은 보지 않는다. 그래서 슬라이드 8개 수정을 받고
    #   2개만 고친 뒤 done 3.1 … 3.8 을 적어도 그대로 완료가 됐다. 파일 내용까지 대조하지는
    #   못하지만, 「편집 2번으로 8개를 끝냈다」는 잡는다.
    #   파일을 바꾸지 않고 끝나는 일, 스크립트 하나로 여러 항목을 고친 경우는 --why 로 사유를 남긴다
    if [ "$HASWHY" = 0 ]; then
      tg_reg_load; tg_workn_to NOWN
      groups=" "
      for a in "$@"; do a="${a#\#}"; g="${a%%.*}"; [[ "$groups" == *" $g "* ]] || groups+="$g "; done
      for g in $groups; do
        tg_reg_find "$g" || continue
        wn="${TG_RWN[TG_R]}"
        [[ "$wn" =~ ^[0-9]+$ ]] || continue          # add 로 적은 항목은 보지 않는다
        ev=$((NOWN - wn)); cnt=0
        for l in "${TG_L[@]}"; do
          [[ "$l" =~ $TG_RX_ITEM ]] || continue
          [ "${BASH_REMATCH[2]}" = "$g" ] || continue
          st="${BASH_REMATCH[1]}"; id="${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
          if [ "$st" = x ]; then cnt=$((cnt+1)); continue; fi
          for a in "$@"; do a="${a#\#}"; [ "$a" = "$id" ] && { cnt=$((cnt+1)); break; }; done
        done
        [ "$cnt" -le "$ev" ] && continue
        if [ "$ev" = 0 ]; then
          echo "[todo-guard] #$g 는 적힌 뒤 바꾼 파일이 없습니다. 하지 않은 일은 done 하지 않습니다." >&2
        else
          echo "[todo-guard] #$g 에서 ${cnt}개를 끝냈다고 했지만, 적힌 뒤 파일을 바꾼 것은 ${ev}번입니다. 실제로 끝낸 번호만 적으십시오." >&2
        fi
        echo "  파일을 바꾸지 않는 일이었거나 한 번에 여러 개를 고쳤으면 사유를 붙이십시오: done $* --why \"사유\"" >&2
        exit 1
      done
    fi
    tg_take openish_has_id "$*"
    if [ "${#TG_TAKEN[@]}" = 0 ]; then
      echo "[todo-guard] 그 번호의 열린 항목이 없습니다: $*" >&2
      echo "  열린 항목:$(open_ids)" >&2
      exit 1
    fi
    # 항목이 가리키는 파일 · 슬라이드를 적힌 뒤 바꿨나.
    #   횟수만 세면 엉뚱한 파일을 고치고도 done 이 됐다. 그래서 항목 글을 본다
    #   - 파일 이름(c.txt · Deck.tsx에서 · 리드미.md로)이 있으면 적힌 뒤 그 파일들을 모두 바꿨어야 한다.
    #     「c.txt · d.txt · e.txt 에 써」는 항목 하나로 적힌다(한 번에 2~3개는 나누지 않는다). 셋 중 하나만
    #     하고 done 하는 것을 여기서 잡는다. 드라이브 · / · ~ 로 시작하는 경로는 가져다 쓸 원본(넣을 이미지)으로
    #     보고 따지지 않는다
    #   - 파일 이름이 없고 슬라이드 번호(3번 · 슬라이드 3)가 있으면, 적힌 뒤 바꾼 파일 가운데
    #     슬라이드마다 따로 둔 파일(slide03.tsx · 03.html · page-3.md)이 있을 때만 그 번호 파일을 찾는다.
    #     덱 파일 하나(deck.pptx · index.html)를 고치는 구조에서는 파일 이름으로 가릴 수 없어 넘어간다
    #   번호와 파일이 어긋나는 게 맞으면(다른 파일에 있었다 등) --why 로 사유를 남긴다
    if [ "$HASWHY" = 0 ] && [ -f "$TG_DIR/changes.log" ]; then
      RX_FTOK='^(["'"'"'(<\[]*)(([a-z]:)?[^[:space:]]*[\\/])?([^\\/[:space:]]+)\.(txt|md|mdx|tsx|ts|jsx|js|mjs|cjs|json|html|htm|css|scss|sass|less|py|ipynb|sh|ps1|bat|png|jpg|jpeg|gif|svg|webp|ico|mp4|mov|webm|mp3|wav|pptx|docx|xlsx|hwp|hwpx|pdf|csv|tsv|yml|yaml|toml|ini|xml|vue|svelte|java|kt|go|rs|cs|rb|php|sql)([^a-z0-9].*)?$'
      RX_SREF='(슬라이드|페이지)[[:space:]]*([0-9]{1,3})|([0-9]{1,3})[[:space:]]*(번|장|페이지)'
      RX_SFILE='^(slide|page|scene|슬라이드)?[-_ ]?0*([0-9]{1,3})([-_. ]|$)'
      CL_N=(); CL_B=()
      while IFS=$'\t' read -r cn cpath || [ -n "$cn" ]; do
        [[ "$cn" =~ ^[0-9]+$ ]] || continue
        cpath="${cpath%$'\r'}"; cpath="${cpath%/}"; cpath="${cpath//\\//}"; cpath="${cpath##*/}"
        tg_lower_to cpath "$cpath"
        CL_N+=("$cn"); CL_B+=("$cpath")
      done < "$TG_DIR/changes.log"
      for l in "${TG_TAKEN[@]}"; do
        [[ "$l" =~ $TG_RX_ITEM ]] || continue
        g="${BASH_REMATCH[2]}"; id="$g${BASH_REMATCH[3]}"
        tg_reg_find "$g" || continue
        wn="${TG_RWN[TG_R]}"; [[ "$wn" =~ ^[0-9]+$ ]] || continue
        text="${l#*"#$id"}"; tg_lower_to text "$text"
        chg=" "; slides=" "
        for i in "${!CL_N[@]}"; do
          [ "${CL_N[i]}" -gt "$wn" ] || continue
          chg+="${CL_B[i]} "
          [[ "${CL_B[i]}" =~ $RX_SFILE ]] && slides+="$((10#${BASH_REMATCH[2]})) "
        done
        # 파일 이름
        want=""; miss=""
        IFS=$' \t' read -r -a toks <<< "$text"      # 낱말로 - 따옴표 없는 $text 는 * 를 파일 이름으로 푼다
        for tok in "${toks[@]}"; do
          [[ "$tok" =~ $RX_FTOK ]] || continue
          d="${BASH_REMATCH[2]}"; f="${BASH_REMATCH[4]}.${BASH_REMATCH[5]}"
          case "$d" in [a-z]:*|/*|"~"*|\\*) continue ;; esac
          case "$f" in node.js|vue.js|next.js|nuxt.js|three.js|d3.js|chart.js|express.js|react.js) continue ;; esac
          want+=" $f"
          [[ "$chg" == *" $f "* ]] || miss+=" $f"
        done
        if [ -n "$want" ]; then
          [ -z "$miss" ] && continue
          tg_cut_to show "${l#*"#$id "}" 40
          echo "[todo-guard] #$id 「$show」 -$miss 를 적힌 뒤 바꾼 기록이 없습니다. 실제로 끝낸 번호만 적으십시오." >&2
          echo "  바꾼 파일:${chg% }" >&2
          echo "  다른 파일로 처리했으면 사유를 붙이십시오: done $* --why \"사유\"" >&2
          exit 1
        fi
        # 슬라이드 번호 - 슬라이드마다 파일이 따로 있는 구조일 때만
        [ "$slides" = " " ] && continue
        nums=""; t="$text"
        while [[ "$t" =~ $RX_SREF ]]; do
          n="${BASH_REMATCH[2]}${BASH_REMATCH[3]}"; nums+=" $((10#$n))"
          t="${t#*"${BASH_REMATCH[0]}"}"
        done
        [ -n "$nums" ] || continue
        hit=0
        for n in $nums; do [[ "$slides" == *" $n "* ]] && hit=1; done
        [ "$hit" = 1 ] && continue
        tg_cut_to show "${l#*"#$id "}" 40
        echo "[todo-guard] #$id 「$show」 - 슬라이드${nums// / #} 파일을 적힌 뒤 바꾼 기록이 없습니다. 실제로 끝낸 번호만 적으십시오." >&2
        echo "  바꾼 슬라이드 파일:${slides% }" >&2
        echo "  다른 파일로 처리했으면 사유를 붙이십시오: done $* --why \"사유\"" >&2
        exit 1
      done
    fi
    # 출력은 한 줄로 한다. 여기 찍힌 글은 문맥에 남아 그 뒤 모든 호출이 다시 읽는다.
    #   전에는 항목마다 한 줄씩 찍어, 긴 세션에서 done 17번이 수백 줄로 쌓였다
    n=0; ids=""
    for i in "${!TG_TAKEN[@]}"; do
      l="${TG_TAKEN[i]}"
      case "$l" in
        "- [ ] "*|"- [?] "*)
          l="- [x] ${l:6}"
          if [ -n "$WHY" ]; then w="${WHY//$'\n'/ }"; tg_cut_to w "$w" 60; l+=" (사유: $w)"; fi
          TG_TAKEN[i]="$l"; n=$((n+1))
          [[ "$l" =~ $TG_RX_ITEM ]] && ids+=" #${BASH_REMATCH[2]}${BASH_REMATCH[3]}" ;;
      esac
    done
    tg_prepend_to "## 완료" "${TG_TAKEN[@]}"
    tg_save
    tg_cut_to ids "${ids# }" 60
    echo "[todo-guard] 완료 ${n}개: $ids" ;;

  hold)
    [ $# -ge 1 ] || usage
    id="$1"; why="${2:-사용자 판단 필요}"
    tg_load
    tg_take tg_open_has_id "$id"
    if [ "${#TG_TAKEN[@]}" = 0 ]; then
      echo "[todo-guard] 그 번호의 열린 항목이 없습니다: $id" >&2
      echo "  열린 항목:$(open_ids)" >&2
      exit 1
    fi
    for i in "${!TG_TAKEN[@]}"; do
      l="${TG_TAKEN[i]}"
      case "$l" in "- [ ] "*) TG_TAKEN[i]="- [?] ${l:6} ($why)"; echo "  보류 ${l:6}" ;; esac
    done
    tg_find_head "## 보류" || TG_L+=("" "## 보류 (사용자 확인 필요)")
    tg_append_to "## 보류" "${TG_TAKEN[@]}"
    tg_save
    echo "[todo-guard] 보류로 옮겼습니다. 사용자에게 사유를 알리십시오." ;;

  add)
    [ $# -gt 0 ] || usage
    tg_load
    # 어느 세션이 적었나 - 같은 명령을 본 pre-tool 훅이 남겨 둔다
    owner=""
    [ -f "$TG_DIR/add_owner" ] && read -r owner < "$TG_DIR/add_owner"
    lines=(); nids=()
    for t in "$@"; do
      t="${t//$'\t'/ }"; t="${t//$'\n'/ }"
      [ -n "${t//[[:space:]]/}" ] || continue
      tg_next_id
      tg_cut_to t "$t" 80
      lines+=("- [ ] #$TG_N $t"); nids+=("$TG_N")
      echo "  등록 #$TG_N $t"
    done
    [ "${#lines[@]}" -gt 0 ] || usage
    tg_append_to "## 진행 중" "${lines[@]}"
    tg_save
    # 모델이 스스로 적은 일은 done 때 파일 변경 횟수를 보지 않는다 (-)
    for id in "${nids[@]}"; do tg_reg_add "$id" "${owner:-x}" "-"; done ;;

  list)
    tg_load
    no=0; nh=0
    for l in "${TG_L[@]}"; do
      case "${l#"${l%%[![:space:]]*}"}" in
        "- [ ]"*) echo "  ${l#"${l%%[![:space:]]*}"}"; no=$((no+1)) ;;
        "- [?]"*) nh=$((nh+1)) ;;
      esac
    done
    echo "[todo-guard] 열린 항목 ${no}개 · 보류 ${nh}개" ;;

  archive)
    keep="${1:-10}"
    [[ "$keep" =~ ^[0-9]+$ ]] || usage
    tg_archive "$keep"
    if [ "${TG_MOVED:-0}" -gt 0 ]; then
      echo "[todo-guard] 완료 ${TG_MOVED}개를 TODO-완료.md 로 옮겼습니다 (최근 ${keep}개는 남김)."
    else
      echo "[todo-guard] 옮길 완료 항목이 없습니다."
    fi ;;

  -h|--help|help) usage ;;
  *) echo "[todo-guard] 모르는 명령: $cmd" >&2; usage ;;
esac
