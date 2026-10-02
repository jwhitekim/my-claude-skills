#!/usr/bin/env bash
# dirname 을 띄우지 않는다. 윈도우에서 프로세스 하나가 0.5초씩 걸린다.
#   경로에 역슬래시가 섞이면 이 방식이 엉뚱한 곳을 가리키므로, 찾지 못하면
#   설치 경로로 물러선다. 역슬래시를 직접 다루지 않아 인용 사고가 없다
_TG_DIR="${BASH_SOURCE[0]%/*}"
[ -f "$_TG_DIR/_root.sh" ] || _TG_DIR="$HOME/.claude/skills/todo-guard/scripts"
. "$_TG_DIR/_root.sh"
# UserPromptSubmit 훅: 지시를 받는 순간 TODO.md 「진행 중」에 적는다.
#
# 왜 훅이 적나
#   전에는 모델이 TODO.md 를 읽고 Edit 로 적었다. 지시 한 번에 읽기 · 등록 · 완료 표시로
#   3~8회를 불렀고, 호출마다 대화 전체를 다시 읽는다. 긴 세션에서는 한 번에 50만 토큰,
#   실제 세션에서 투두가드 몫이 토큰의 9~12% 였다.
#   훅은 모델 밖에서 돌아 토큰을 쓰지 않는다.
#
# 적는 방식
#   - [ ] #14 지시 첫머리                    지시 하나
#   - [ ] #15.1 …  - [ ] #15.2 …            「1. 2. 3.」 번호 매긴 지시는 항목마다
#   「응 · 진행해 · 계속」 같은 맞장구는 새 지시가 아니다. 적지 않는다
#   배경 알림 · 시스템 알림도 지시가 아니다. 적지 않고 기준점도 건드리지 않는다
#
# 질문이었으면
#   문구로 지시(w)와 질문 · 의견(q)을 가른다. 질문도 일단 적는다 - 답하다 파일을 고치게 되면 그대로 남는다.
#   질문은 파일을 바꾸지 않은 채 턴이 끝나면 check-todo 가 지운다. 지시는 지우지 않는다
#
# 남기는 것
#   TODO.md                           항목
#   .claude/todo-guard/s/<세션>.turn  도장 · TODO.md 지문 · 적은 번호 · 종류 · 지시 첫머리
#   .claude/todo-guard/reg.tsv        적은 번호 · 세션 · 그때까지 파일을 바꾼 횟수
#   stdout                            「#14 등록」 한 줄 - 모델이 번호를 알게 한다

INPUT=""
IFS= read -r -d '' INPUT || true

# TODO.md 가 없는 프로젝트는 세팅 전이다. 건드리지 않는다
[ -f "$TG_TODO" ] || exit 0
[ -d "$TG_SD" ] || mkdir -p "$TG_SD" 2>/dev/null || exit 0
tg_sid_from "$INPUT"
tg_mark_start

RAW=""
tg_json_raw_to RAW prompt "$INPUT"
PROMPT=""
tg_json_unescape_to PROMPT "$RAW"

# 배경 알림 · 시스템 알림은 사용자 지시가 아니다.
#   이것을 지시로 읽으면 하던 작업을 이어 하려는데 새 항목이 생기고 기준점이 바뀐다
case "${PROMPT#"${PROMPT%%[![:space:]]*}"}" in
  ""|"<task-notification>"*|"<system-reminder>"*|"[SYSTEM NOTIFICATION"*|"<local-command-stdout>"*|"Caveat:"*|"<command-name>"*|"<command-message>"*)
    exit 0 ;;
esac

# 지시를 항목으로 나눈다.
#   사용자는 한 메시지에 「3번 제목 바꾸고, 5번은 그림 넣고, 7번…」처럼 여러 슬라이드 수정을 몰아 준다.
#   전에는 줄 맨 앞 「1. 2.」만 나눠서 이런 지시가 통째로 항목 하나가 됐다. 모델이 1~2번만 하고
#   done 해도 투두가드는 몰랐다. 여러 줄 지시는 첫 두 줄만 적혀 나머지가 TODO 에서 아예 빠졌다.
#
#   나누는 자리
#     - 줄 머리 목록 표시     1.  1)  1:  -  *  •  ·  ①~⑮
#     - 슬라이드를 가리키는 말 3번 · 3장 · 3페이지 · 슬라이드 3 · 페이지 3 · ①~⑮  (한 줄 안에서도 끊는다)
#     - 첫 항목 뒤에 오는 줄은 모두 항목이다 (끝에 덧붙인 「그리고 다 끝나면 ~」도 빠지지 않게)
#   첫 항목 앞의 줄은 머리말로 본다 (「슬라이드 수정사항」)
#   <태그> 로 시작하는 줄과 코드 울타리는 지시 문장이 아니다
RX_CIRC='①|②|③|④|⑤|⑥|⑦|⑧|⑨|⑩|⑪|⑫|⑬|⑭|⑮'
RX_REF="(슬라이드|페이지)[[:space:]]*[0-9]{1,3}|[0-9]{1,3}[[:space:]]*(번|장|페이지)|$RX_CIRC"
RX_REFHEAD="^((슬라이드|페이지)[[:space:]]*[0-9]{1,3}|[0-9]{1,3}[[:space:]]*(번|장|페이지)|$RX_CIRC)"
RX_MARK='^([0-9]{1,2}[.):][[:space:]]*|[-*•·][[:space:]]+)'

# 동사꼴 · 물음 판정에 쓰는 말 (아래 「지시인가 질문인가」가 쓴다)
RX_ANS='(알려|설명해|말해|보여|보고해|요약해|정리해|비교해|분석해|검토해|점검해|평가해|판단해|추천해|답해|대답해|조사해|확인해)[[:space:]]*(줘|주세요|줄래|봐|주라)?'
RX_ACT='바꿔|바꾸|바꿀|고쳐|고치|고칠|넣어|넣고|넣을|넣자|넣기|지워|지우|빼|만들|옮겨|옮기|올려|늘려|줄여|키워|맞춰|채워|붙여|나눠|합쳐|돌려|띄워|찍어|그려|써줘|써 줘|써|쓰고|적어|적고|수정해|수정하|추가해|추가하|삭제해|삭제하|제거해|제거하|작성해|작성하|이동해|이동시|교체해|교체하|변경해|변경하|적용해|적용하|반영해|반영하|배포해|배포하|커밋해|커밋하|푸시해|푸시하|설치해|설치하|실행해|실행하|실행시|저장해|저장하|복사해|복사하|생성해|생성하|구현해|구현하|개선해|개선하|조정해|조정하|정렬해|정렬하|준비해|준비하|진행해|진행하|처리해|처리하|끝내|마무리해|마무리하|해줘|해 줘|해주|해봐|해 봐|해라|하자|줄래|주세요|해야|다시 해|다시해|please|fix|commit|push|deploy'
RX_ASK='[?？]|뭐|뭔|무엇|무슨|어디|어떻게|어떤|어때|왜|언제|누가|누구|몇|얼마|있나|없나|됐나|되나|했나|인가|인지|는지|을까|할까|일까|맞지|맞나|아냐|아니야|않아|거지|건가|궁금'
RX_SAY='(다|네|죠|지|냐|니|나|까|는데|인데|은데|던데|잖아|잔아|거든|같아|듯)$'

# 한 줄을 슬라이드 언급마다 끊는다 → CLAUSES
#   앞 토막에 언급만 있고 할 일이 없으면 끊지 않는다 (「② 2장 그림 교체」는 한 토막)
split_clauses() {
  local rest="$1" cur="" m pre body j
  CLAUSES=()
  while [[ "$rest" =~ $RX_REF ]]; do
    m="${BASH_REMATCH[0]}"
    pre="${rest%%"$m"*}"
    rest="${rest#*"$m"}"
    body="$cur$pre"
    while [[ "$body" =~ $RX_REF ]]; do body="${body/"${BASH_REMATCH[0]}"/}"; done
    body="${body//[[:space:],.:·]/}"
    # 번호 사이가 이음말뿐이면 한 지시다 (「7번이랑 8번 순서 바꿔」 · 「3번부터 5번까지」)
    j="${pre//[[:space:],.:·~-]/}"
    case "$j" in 이랑|랑|와|과|하고|및|또는|이나|나|부터|에서|도|이며) body="" ;; esac
    if [ -n "$cur" ] && [ -n "$body" ]; then
      CLAUSES+=("$cur$pre"); cur="$m"
    else
      cur="$cur$pre$m"
    fi
  done
  cur="$cur$rest"
  [ -n "${cur//[[:space:]]/}" ] && CLAUSES+=("$cur")
}

# 토막 앞뒤의 공백 · 쉼표 · 이음말을 걷는다
tidy_to() {
  local __v="$1" s="$2"
  s="${s#"${s%%[![:space:],]*}"}"
  s="${s%"${s##*[![:space:],]}"}"
  case "$s" in "그리고 "*) s="${s#그리고 }" ;; "및 "*) s="${s#및 }" ;; esac
  printf -v "$__v" '%s' "$s"
}

FIRST=""; SECOND=""; ITEMS=(); started=0
rest="$PROMPT"
while [ -n "$rest" ]; do
  line="${rest%%$'\n'*}"
  if [ "$line" = "$rest" ]; then rest=""; else rest="${rest#*$'\n'}"; fi
  line="${line//$'\t'/ }"; line="${line%$'\r'}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [ -n "$line" ] || continue
  # 화면을 붙여넣은 줄은 지시가 아니다. 사용자는 화면을 붙이고 한 줄로 시킨다
  #   («이것 좀 정리해줘» + 로그 30줄). 전에는 로그 줄마다 항목으로 쪼개 8개가 등록됐다
  case "$line" in
    "<"*|'```'*) continue ;;
    "●"*|"⎿"*|"✻"*|"✢"*|"❯"*|"│"*|"├"*|"└"*|"┌"*|"─"*|"⏵"*|"[todo-guard]"*|"[글검수]"*) continue ;;
    "★"*|"·"*|"- [ ]"*|"- [x]"*|"- [X]"*|"- [?]"*) continue ;;   # 붙여넣은 TODO.md · 규칙 줄
    "Stop hook"*|"Ran "*|"Searched for "*|"Baked for "*|"Read "*|"Wrote "*|"Listed "*|"Bash("*|"Read("*|"Edit("*|"Write("*|"Update("*) continue ;;
    *" says: "*) continue ;;
  esac
  if [ -z "$FIRST" ]; then FIRST="$line"
  elif [ -z "$SECOND" ]; then SECOND="$line"
  fi
  body="$line"; isitem=0
  if [[ "$line" =~ $RX_MARK ]]; then
    isitem=1; body="${line:${#BASH_REMATCH[0]}}"
  elif [[ "$line" =~ $RX_REFHEAD ]]; then
    isitem=1
  fi
  split_clauses "$body"
  if [ "$isitem" = 1 ] || [ "$started" = 1 ] || [ "${#CLAUSES[@]}" -ge 2 ]; then
    started=1
    for c in "${CLAUSES[@]}"; do
      tidy_to c "$c"
      [ -n "$c" ] && ITEMS+=("$c")
    done
  fi
done

# 맞장구 - 새 지시가 아니다. 앞 지시를 이어 간다
ACK=0
if [ "${#ITEMS[@]}" -lt 2 ] && [ -z "$SECOND" ]; then
  a="${FIRST//[[:space:].!~?,]/}"
  tg_lower_to a "$a"
  case "$a" in
    ""|응|네|넵|예|ㅇㅇ|ㅇㅋ|ok|okay|오케이|좋아|좋아요|좋습니다|그래|그래요|고|ㄱ|ㄱㄱ|고고|진행|진행해|진행해줘|진행해주세요|진행하자|계속|계속해|계속해줘|계속진행|해줘|해|부탁해|맞아|맞아요|됐어|알았어|알겠어|확인|yes|y|go|continue)
      ACK=1 ;;
  esac
fi

# 지시인가 질문 · 의견인가 → KIND (w · q)
#   전에는 문구를 보지 않고 「파일을 안 바꾼 턴 = 질문」으로 보고 지웠다. 그러면 「반영하겠습니다」라고만
#   하고 끝낸 지시, 일하는 도중에 들어와 흐름에 묻힌 지시까지 지워졌다 - 막으려던 누락을 투두가드가
#   통과시켰다. 이제 지우는 것은 질문 · 의견으로 보이는 것뿐이다.
#   애매하면 지시로 본다. 잘못 남은 질문은 done --why 한 번으로 닫히지만, 지워진 지시는 되살릴 수 없다
#     1) 여러 항목으로 나뉜 지시                        → w
#     2) 「알려줘 · 설명해 · 정리해 · 보고해」 같은 답을 달라는 말을 걷어 내고도
#        「바꿔 · 넣어 · 고쳐 · 빼 · 줄래 · 해줘 · 수정해 …」가 남으면 → w  (「색 바꿔줄래?」는 지시)
#        명사만으로는 보지 않는다. 「저장소」 「변경사항 뭐야?」가 지시로 잡히지 않게 동사꼴만 둔다.
#        「3번 배경 삭제」처럼 명사로 끝난 지시는 물음이 없으니 4) 에서 지시가 된다
#     3) 답을 달라는 말 · 물음 · 「~다 · ~는데 · ~잖아」로 끝나는 말 → q  (「이거 맞아?」)
#     4) 나머지                                           → w
KIND=w
if [ "$ACK" = 0 ] && [ "${#ITEMS[@]}" -lt 2 ]; then
  t="$PROMPT"; tg_lower_to t "$t"
  ans=0
  while [[ "$t" =~ $RX_ANS ]]; do t="${t/"${BASH_REMATCH[0]}"/ }"; ans=1; done
  tail="${t%"${t##*[![:space:].!~…]}"}"
  if [[ "$t" =~ $RX_ACT ]]; then KIND=w
  elif [ "$ans" = 1 ] || [[ "$t" =~ $RX_ASK ]] || [[ "$tail" =~ $RX_SAY ]]; then KIND=q
  fi
fi

tg_load
LINES=(); IDS=""
if [ "$ACK" = 0 ]; then
  tg_next_id
  if [ "${#ITEMS[@]}" -ge 2 ]; then
    k=0
    for it in "${ITEMS[@]}"; do
      k=$((k+1))
      [ "$k" -gt 30 ] && break
      tg_cut_to it "$it" 70
      LINES+=("- [ ] #$TG_N.$k $it")
    done
  else
    text="$FIRST"
    # 첫 줄이 「추가 작업이야.」처럼 짧으면 다음 줄까지 잇는다
    [ "${#text}" -lt 12 ] && [ -n "$SECOND" ] && text="$text $SECOND"
    tg_cut_to text "$text" 80
    LINES+=("- [ ] #$TG_N $text")
  fi
  IDS="$TG_N"
  tg_append_to "## 진행 중" "${LINES[@]}"
  tg_save
  # 누가 · 언제 적었나. done 할 때 「적은 뒤 파일을 바꿨나」를 이것으로 본다
  tg_workn_to WN
  tg_reg_add "$TG_N" "$TG_SID" "$WN"
fi

# 기준점 - 이 지시 뒤로 TODO.md 가 바뀌었는지 볼 때 쓴다
tg_stamp_to STAMP
tg_fp_to FP
head="$FIRST"; head="${head//$'\t'/ }"; tg_cut_to head "$head" 60
tg_write_turn "$STAMP" "$FP" "$IDS" "$KIND" "$head"

# 모델에게 번호를 알리고(additionalContext), 사용자 화면에 「받음」을 띄운다(systemMessage).
#   모델 쪽은 짧게 쓴다. 이 글은 지시마다 문맥에 쌓이고 그 뒤 모든 호출이 다시 읽는다.
#   완료 명령의 전체 경로는 CLAUDE.md 운영 규칙에 있다.
#
#   사용자 쪽 「받음」 - 창이 입력을 받을 준비가 안 됐을 때(막 띄운 직후) · 선택 창이 떠 있을 때 친 메시지는
#   Claude Code 에 닿지 않는다. 그러면 이 훅도 돌지 않아 투두가드는 모른다(벤치마크 m2pa 에서 첫 메시지가
#   그렇게 사라졌다). 메시지마다 「받음」이 뜨면, 안 뜬 것은 도착하지 않은 것이다. 다시 보내면 된다
#
#   질문으로 본 것에는 done 을 시키지 않는다. 답만 하면 check-todo 가 지운다. 전에는 질문에도
#   「끝나면 done」이라고 알려, 모델이 답한 뒤 done 명령을 한 번 더 불렀다
#   「받음」을 얼마나 띄울까 - .claude/todo-guard.json 의 "receipt"
#     multi (기본) 여러 항목으로 나뉠 때만 · always 메시지마다 · off 안 띄움
#   앱에서는 이 알림이 빨간 경고로 보인다. 메시지마다 띄우면 답변이 밀려 올라간다.
#   나뉜 항목은 눈으로 확인할 값이 있어 그때만 띄운다
RECEIPT=multi
if read_all "$PROJ/.claude/todo-guard.json" &&
   [[ "$REPLY" =~ \"receipt\"[[:space:]]*:[[:space:]]*\"(always|off|multi)\" ]]; then
  RECEIPT="${BASH_REMATCH[1]}"
fi

CTX=""; SEEN=""
tg_cut_to brief "$FIRST" 30
if [ -n "$IDS" ]; then
  if [ "${#LINES[@]}" -gt 1 ]; then
    # 나눈 항목은 목록으로 보여 준다. 몰아 준 지시에서 1~2번만 하고 끝내는 일을 막으려면
    #   해야 할 것이 눈앞에 있어야 한다
    CTX="[todo-guard] #$IDS.1~#$IDS.${#LINES[@]} 등록 → 하나씩 끝낼 때마다 todo.sh done $IDS.1 … (전부 해야 턴이 끝난다)"
    for l in "${LINES[@]}"; do
      l="${l#- \[ \] \#}"; tg_cut_to l "$l" 60; CTX+=$'\n'"  $l"
    done
    SEEN="[todo-guard] 받음 #$IDS.1~#$IDS.${#LINES[@]} (${#LINES[@]}개) · $brief"
  elif [ "$KIND" = q ]; then
    CTX="[todo-guard] #$IDS 질문으로 적음 - 답만 하면 훅이 지운다. 파일을 고치게 되면 끝나고 done $IDS"
    SEEN="[todo-guard] 받음 #$IDS (질문) · $brief"
  else
    CTX="[todo-guard] #$IDS 등록 → 끝나면 todo.sh done $IDS"
    SEEN="[todo-guard] 받음 #$IDS · $brief"
  fi
else
  SEEN="[todo-guard] 받음 (새 지시 아님 - 이어서 진행) · $brief"
fi
case "$RECEIPT" in
  always) ;;
  multi) [ "${#LINES[@]}" -gt 1 ] || SEEN="" ;;
  *) SEEN="" ;;
esac

if [ -n "$CTX" ] && [ -n "$SEEN" ]; then
  tg_json_esc_to SEEN "$SEEN"; tg_json_esc_to CTX "$CTX"
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$SEEN" "$CTX"
elif [ -n "$CTX" ]; then
  printf '%s\n' "$CTX"          # 모델에게만 알린다. 그냥 찍으면 문맥으로 들어간다
elif [ -n "$SEEN" ]; then
  tg_json_esc_to SEEN "$SEEN"
  printf '{"systemMessage":"%s"}\n' "$SEEN"
fi
exit 0
