#!/usr/bin/env bash
# 셸 명령을 읽어 「무엇을 바꾸나」를 뽑는다. pre-tool.sh 가 쓴다.
#
# 왜 필요한가
#   전에는 명령 글자에 「TODO.md」가 들어 있나, 첫 낱말이 읽기 명령인가만 봤다.
#   그래서 `python build.py && cat TODO.md` 가 등록 검사를 빠져나가고,
#   `cp 빈파일 TODO.md` · `rm -rf /d/다른프로젝트` 가 그대로 지나갔다.
#   PowerShell 명령은 아예 보지 않았다.
#   따옴표를 가려 토막 내고, 명령마다 쓰기 대상을 뽑아야 막을 수 있다.
#
# 결과
#   SH_KIND       read | todo | work     (읽기만 · 장부 정리만 · 파일을 바꾸는 작업)
#   SH_TGT        쓰기 대상 경로 배열 (명령에 적힌 그대로)
#   SH_TGT_CWD    대상마다 그 시점의 작업 폴더 (cd 를 따라간다)
#   SH_TODO_KILL  TODO.md 를 덮어쓰거나 지우는 명령이면 1
#   SH_TODO_ADD   todo.sh add 가 들어 있으면 1 (같은 명령에서 등록한다)
#
# 쓰는 법
#   sh_classify "<명령>" bash|ps

SH_MAX=20000     # 이보다 긴 명령은 뜯어보지 않고 작업으로 본다

sh_reset() {
  SH_KIND=read; SH_TGT=(); SH_TGT_CWD=(); SH_TODO_KILL=0; SH_TODO_ADD=0
  SH_CWD="$PWD"; SH_BODY=""
}

sh_work() { [ "$SH_KIND" = work ] || SH_KIND=work; }
sh_todo() { [ "$SH_KIND" = read ] && SH_KIND=todo; }

# 쓰는 명령인데 대상을 못 뽑았으면 작업으로 본다. 뽑았으면 대상이 판정한다
#   (TODO.md 에 덧붙이기 · 로그 · 메모리는 작업이 아니다)
sh_need_target() { [ "${#SH_TGT[@]}" -gt "${SH_SEG_T0:-0}" ] || sh_work; }

sh_is_todo_path() {
  local b="${1##*/}"; b="${b##*\\}"
  [ "$b" = "TODO.md" ]
}

# 로그 · 임시 파일로 보내는 것은 산출물을 바꾸는 것이 아니다.
#   배경 실행은 대개 로그로 돌린다. 그것까지 작업으로 보면 질문 턴이 작업 턴이 된다
sh_is_logpath() {
  local p="${1//\\//}"
  tg_lower_to p "$p"
  case "$p" in
    *.log|*.out) return 0 ;;
    /tmp/*|*/tmp/*|tmp/*|*/temp/*|*/log/*|log/*|*/logs/*|logs/*) return 0 ;;
  esac
  return 1
}

# 쓰기 대상 하나를 적는다. $2 = 덮어쓰는가(1) 덧붙이는가(0)
sh_target() {
  local t="$1" kill="${2:-1}"
  case "$t" in
    ''|/dev/null|/dev/stdout|/dev/stderr|/dev/tty|'$null'|'$Null'|NUL|nul|'&'*) return 0 ;;
  esac
  SH_TGT+=("$t"); SH_TGT_CWD+=("$SH_CWD")
  if sh_is_todo_path "$t"; then
    [ "$kill" = 1 ] && SH_TODO_KILL=1
    sh_todo                        # TODO.md 에 덧붙이는 것은 장부 정리다
    return 0
  fi
  # 메모리 기록은 작업이 아니다. 질문만 오간 턴에도 「기억해 둬」는 적을 수 있어야 한다
  tg_is_memory_path "$t" && return 0
  sh_is_logpath "$t" || sh_work
}

# 따옴표를 가려 토막 낸다 → SH_T. 명령 구분(&& || ; | 줄바꿈)은 ";" 하나로 맞춘다
#   $2 = ps 이면 파워셸 규칙: 역슬래시는 보통 글자, 백틱이 이스케이프, & 는 호출 연산자
sh_tokenize() {
  local s="$1" mode="$2"
  local LC_ALL=C
  local n=${#s} i=0 c d q="" cur="" has=0 depth=0 op
  SH_T=()
  while [ "$i" -lt "$n" ]; do
    c="${s:i:1}"
    if [ -n "$q" ]; then
      if [ "$c" = "$q" ]; then q=""; i=$((i+1)); continue; fi
      if [ "$q" = '"' ]; then
        if [ "$mode" != ps ] && [ "$c" = '\' ]; then
          d="${s:i+1:1}"
          case "$d" in '"'|'\'|'$'|'`') cur+="$d"; i=$((i+2)); continue ;; esac
        fi
        if [ "$mode" = ps ] && [ "$c" = '`' ]; then cur+="${s:i+1:1}"; i=$((i+2)); continue; fi
      fi
      cur+="$c"; i=$((i+1)); continue
    fi
    # $( … ) 는 한 토막으로 둔다
    if [ "$depth" -gt 0 ]; then
      cur+="$c"
      case "$c" in '(') depth=$((depth+1)) ;; ')') depth=$((depth-1)) ;; esac
      i=$((i+1)); continue
    fi
    case "$c" in
      "'"|'"')
        q="$c"; has=1; i=$((i+1)); continue ;;
      '`')
        if [ "$mode" = ps ]; then cur+="${s:i+1:1}"; has=1; i=$((i+2)); continue; fi
        q='`'; has=1; i=$((i+1)); continue ;;
      ' '|$'\t'|$'\r')
        [ "$has" = 1 ] && { SH_T+=("$cur"); cur=""; has=0; }
        i=$((i+1)); continue ;;
      $'\n'|';')
        [ "$has" = 1 ] && { SH_T+=("$cur"); cur=""; has=0; }
        SH_T+=(";"); i=$((i+1)); continue ;;
      '&'|'|')
        d="${s:i+1:1}"
        if [ "$c" = '&' ] && [ "$d" = '>' ]; then        # &> · &>> 는 리다이렉트
          [ "$has" = 1 ] && { SH_T+=("$cur"); cur=""; has=0; }
          op='&>'; i=$((i+2))
          [ "${s:i:1}" = '>' ] && { op='&>>'; i=$((i+1)); }
          SH_T+=("$op"); continue
        fi
        if [ "$mode" = ps ] && [ "$c" = '&' ] && [ "$d" != '&' ]; then   # 파워셸 호출 연산자
          [ "$has" = 1 ] && { SH_T+=("$cur"); cur=""; has=0; }
          SH_T+=("&"); i=$((i+1)); continue
        fi
        [ "$has" = 1 ] && { SH_T+=("$cur"); cur=""; has=0; }
        SH_T+=(";")
        [ "$d" = "$c" ] && i=$((i+1))
        i=$((i+1)); continue ;;
      '>'|'<')
        op="$c"
        # 앞에 붙은 스트림 번호(2> · *>)는 리다이렉트의 일부다
        if [ "$has" = 1 ] && [[ "$cur" == [0-9*] ]]; then op="$cur$c"; cur=""; has=0; fi
        [ "$has" = 1 ] && { SH_T+=("$cur"); cur=""; has=0; }
        d="${s:i+1:1}"
        if [ "$c" = '>' ] && { [ "$d" = '>' ] || [ "$d" = '|' ]; }; then op+="$d"; i=$((i+1)); d="${s:i+1:1}"; fi
        if [ "$c" = '>' ] && [ "$d" = '&' ]; then op+='&'; i=$((i+1)); fi
        if [ "$c" = '<' ] && [ "$d" = '<' ]; then
          op+='<'; i=$((i+1))
          [ "${s:i+1:1}" = '<' ] && { op+='<'; i=$((i+1)); }
          [ "${s:i+1:1}" = '-' ] && i=$((i+1))
        fi
        SH_T+=("$op"); i=$((i+1)); continue ;;
      '\')
        if [ "$mode" != ps ]; then
          d="${s:i+1:1}"
          [ "$d" = $'\n' ] || { cur+="$d"; has=1; }       # 줄 잇기는 버린다
          i=$((i+2)); continue
        fi ;;
      '#')
        if [ "$has" = 0 ]; then                           # 주석 - 줄 끝까지 건너뛴다
          while [ "$i" -lt "$n" ] && [ "${s:i:1}" != $'\n' ]; do i=$((i+1)); done
          continue
        fi ;;
      '$')
        if [ "${s:i+1:1}" = '(' ]; then cur+='$('; has=1; depth=1; i=$((i+2)); continue; fi ;;
    esac
    cur+="$c"; has=1; i=$((i+1))
  done
  [ "$has" = 1 ] && SH_T+=("$cur")
}

# 히어독 본문을 떼어 낸다. 본문은 명령이 아니다 → SH_TEXT (본문 뺀 것), SH_BODY (본문)
sh_strip_heredoc() {
  local line out="" body="" delim="" t
  local rx='(^|[^<])<<-?[[:space:]]*["'"'"']?([A-Za-z_][A-Za-z0-9_]*)["'"'"']?'
  local rest="$1"
  while [ -n "$rest" ]; do
    line="${rest%%$'\n'*}"
    if [ "$line" = "$rest" ]; then rest=""; else rest="${rest#*$'\n'}"; fi
    if [ -n "$delim" ]; then
      t="${line#"${line%%[![:space:]]*}"}"; t="${t%$'\r'}"
      if [ "$t" = "$delim" ]; then delim=""; else body+="$line"$'\n'; fi
      continue
    fi
    out+="$line"$'\n'
    [[ "$line" =~ $rx ]] && delim="${BASH_REMATCH[2]}"
  done
  SH_TEXT="$out"; SH_BODY+="$body"
}

# 인터프리터에 준 코드가 TODO.md 를 덮어쓰거나 지우는가
sh_code_kills_todo() {
  local code="$1"
  case "$code" in *TODO.md*) ;; *) return 1 ;; esac
  local q="['\"]"
  local rx1="TODO\.md${q}[[:space:]]*,[[:space:]]*(mode[[:space:]]*=[[:space:]]*)?${q}[wx]"
  local rx2="TODO\.md${q}[[:space:]]*\)[[:space:]]*\.[[:space:]]*(write_text|write_bytes|unlink|open\(${q}[wx])"
  local rx3="(os\.remove|os\.unlink|shutil\.(move|copy[a-z0-9]*)|writeFileSync|unlinkSync|rmSync)\([^)]*TODO\.md"
  [[ "$code" =~ $rx1 ]] || [[ "$code" =~ $rx2 ]] || [[ "$code" =~ $rx3 ]]
}

# 인터프리터 코드가 파일을 쓰는 기색이 있는가 - 없으면 조회로 본다
sh_code_writes() {
  local rx="open\([^)]*['\"][wax]|\.write\(|write_text|write_bytes|os\.(remove|unlink|rename|replace|makedirs|mkdir|system)|shutil\.|subprocess|\.save\(|to_csv|to_excel|dump\(|writeFileSync|appendFileSync|unlinkSync|mkdirSync|rmSync|child_process"
  [[ "$1" =~ $rx ]]
}

# 인터프리터 한 줄 (python · node …)
sh_interp() {
  local w="$1"; shift
  local a=("$@") k=0 n=$#
  case "${a[0]:-}" in
    --version|-V|-h|--help) return 0 ;;
    -m)
      case "${a[1]:-}" in
        unittest|pytest|py_compile|pydoc|json.tool|this|pip)
          [ "${a[1]}" = pip ] && { case "${a[2]:-}" in list|show|freeze|--version) return 0 ;; esac; sh_work; }
          return 0 ;;
      esac
      sh_work; return 0 ;;
    -c|-e|-p|--eval|--print)
      local code="${a[1]:-}"
      sh_code_kills_todo "$code" && SH_TODO_KILL=1
      sh_code_writes "$code" && sh_work
      return 0 ;;
  esac
  # 표준 입력(히어독)으로 코드를 받으면 본문을 보고 가른다 - python - <<EOF … EOF
  #   질문에 답하려고 슬라이드 장 수를 세는 스크립트까지 작업으로 보면, 질문 턴의 등록이
  #   지워지지 않고 턴 종료가 막혀 done 호출이 한 번 더 붙었다 (긴 슬라이드 벤치마크 6턴)
  sh_code_kills_todo "$SH_BODY" && SH_TODO_KILL=1
  sh_positional "${a[@]}"
  if [ -n "$SH_BODY" ] && { [ "${#SH_POS[@]}" = 0 ] || [ "${SH_POS[0]}" = "-" ]; }; then
    sh_code_writes "$SH_BODY" && sh_work
    return 0
  fi
  # 스크립트 파일을 돌리면 무엇을 하는지 모른다
  sh_work
}

# git 한 줄
sh_git() {
  local a=("$@") k=0 n=$# sub
  while [ "$k" -lt "$n" ]; do
    case "${a[k]}" in
      -C) sh_cd "${a[k+1]:-}"; k=$((k+2)) ;;
      -c|--git-dir|--work-tree) k=$((k+2)) ;;
      -*) k=$((k+1)) ;;
      *) break ;;
    esac
  done
  sub="${a[k]:-}"
  case "$sub" in
    status|log|diff|show|ls-files|ls-tree|ls-remote|rev-parse|blame|describe|shortlog|grep|cat-file|fetch|version|help|reflog|whatchanged|count-objects|check-ignore|name-rev|merge-base|for-each-ref|show-ref|--version)
      return 0 ;;
    remote)
      case "${a[k+1]:-}" in ''|-v|--verbose|show|get-url) return 0 ;; esac ;;
    config)
      # 값 읽기 - --get · --list · 키 하나만 준 것 (git config --local user.name)
      case " ${a[*]} " in *" --get"*|*" --list "*|*" -l "*|*" --show-origin "*) return 0 ;; esac
      sh_positional "${a[@]:k+1}"
      [ "${#SH_POS[@]}" -le 1 ] && return 0 ;;
    branch|tag|stash)
      local rest=" ${a[*]:k+1} "
      case "$rest" in "  "|*" -l "*|*" --list "*|*" -a "*|*" -v "*|*" -vv "*|*" list "*|*" show "*) return 0 ;; esac ;;
    checkout|restore|rm|mv|reset|clean)
      local x
      for x in "${a[@]:k+1}"; do sh_is_todo_path "$x" && SH_TODO_KILL=1; done ;;
  esac
  sh_work
}

sh_cd() {
  local d="$1"
  [ -n "$d" ] || { SH_CWD="$HOME"; return; }
  case "$d" in
    '~'|'~/'*) d="$HOME${d#\~}" ;;
    '$HOME'*) d="$HOME${d#\$HOME}" ;;
  esac
  case "$d" in
    /*|[A-Za-z]:*|\\*) SH_CWD="$d" ;;
    -) ;;
    *) SH_CWD="$SH_CWD/$d" ;;
  esac
}

# 옵션이 아닌 인자만 → SH_POS
sh_positional() {
  SH_POS=()
  local x
  for x in "$@"; do
    case "$x" in -*) ;; *) SH_POS+=("$x") ;; esac
  done
}

# bash 명령 한 토막
sh_seg_bash() {
  local a=("$@") k=0 n=$# w
  # 앞에 붙은 변수 대입 · 감싸는 명령을 건너뛴다
  while [ "$k" -lt "$n" ]; do
    w="${a[k]}"
    if [[ "$w" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then k=$((k+1)); continue; fi
    case "$w" in
      sudo|env|nohup|time|command|exec|nice|stdbuf|builtin|'!') k=$((k+1)); continue ;;
      timeout) k=$((k+2)); continue ;;
    esac
    break
  done
  [ "$k" -lt "$n" ] || return 0
  w="${a[k]##*/}"
  local r=("${a[@]:k+1}")
  case "$w" in
    ls|cat|head|tail|less|more|grep|egrep|fgrep|rg|find|fd|pwd|wc|stat|file|which|type|      tree|du|df|date|whoami|env|printenv|echo|printf|sort|uniq|cut|jq|tr|basename|dirname|      realpath|readlink|test|'['|'[['|']]'|true|false|nl|diff|cmp|md5sum|sha1sum|sha256sum|      sleep|for|while|until|do|done|then|else|elif|fi|case|esac|if|'{'|'}'|'('|')'|column|      paste|join|seq|xxd|od|hexdump|strings|ps|hostname|uname|history|man|help|:|local|      export|declare|typeset|read|set|unset|shift|return|exit|break|continue|wait|trap|      function|select|let|awk|gawk|iconv|base64|comm|expand|fold|fmt|rev|tac|      pytest|py.test|lsof|netstat|ping|nslookup|tasklist|where|claude)
      case "$w" in
        find) case " ${r[*]} " in *" -delete "*|*" -exec "*|*" -execdir "*|*" -ok "*) sh_work ;; esac ;;
        awk|gawk) case " ${r[*]} " in *" -i inplace "*|*" --inplace "*) sh_work ;; esac ;;
        claude) case "${r[0]:-}" in --version|-v|--help|-h) ;; *) sh_work ;; esac ;;
      esac ;;
    cd|pushd) sh_cd "${r[0]:-}" ;;
    popd) ;;
    sed|perl)
      local inplace=0 script=1 x
      for x in "${r[@]}"; do
        case "$x" in
          --in-place*|-i*|-[a-zA-Z]*i*) [[ "$x" == --* && "$x" != --in-place* ]] || inplace=1 ;;
        esac
        case "$x" in -e|-f|--expression*|--file*) script=0 ;; esac
      done
      [ "$w" = perl ] && [ "$inplace" = 0 ] && { sh_interp perl "${r[@]}"; return 0; }
      [ "$inplace" = 1 ] || return 0
      sh_positional "${r[@]}"
      local i0=$script
      for ((x=i0; x<${#SH_POS[@]}; x++)); do sh_target "${SH_POS[x]}" 0; done
      sh_need_target ;;
    cp|mv|install|rsync|scp|ln)
      local x tdir=""
      for ((x=0; x<${#r[@]}; x++)); do
        case "${r[x]}" in -t) tdir="${r[x+1]:-}" ;; --target-directory=*) tdir="${r[x]#*=}" ;; esac
      done
      sh_positional "${r[@]}"
      if [ -n "$tdir" ]; then sh_target "$tdir" 1
      elif [ "${#SH_POS[@]}" -ge 2 ]; then sh_target "${SH_POS[${#SH_POS[@]}-1]}" 1
      fi
      sh_need_target ;;
    rm|rmdir|unlink|shred|truncate|touch|mkdir|chmod|chown|chgrp)
      sh_positional "${r[@]}"
      local x s=0
      case "$w" in chmod|chown|chgrp) s=1 ;; esac
      for ((x=s; x<${#SH_POS[@]}; x++)); do
        case "$w" in
          touch|mkdir|chmod|chown|chgrp) sh_target "${SH_POS[x]}" 0 ;;
          *) sh_target "${SH_POS[x]}" 1 ;;
        esac
      done
      sh_need_target ;;
    tee)
      local app=0 x
      case " ${r[*]} " in *" -a "*|*" --append "*) app=1 ;; esac
      sh_positional "${r[@]}"
      for x in "${SH_POS[@]}"; do sh_target "$x" $((1-app)); done ;;
    dd)
      local x
      for x in "${r[@]}"; do case "$x" in of=*) sh_target "${x#of=}" 1 ;; esac; done
      sh_work ;;
    git) sh_git "${r[@]}" ;;
    python|python3|py|pythonw|node|deno|bun|ruby|php|Rscript)
      sh_interp "$w" "${r[@]}" ;;
    bash|sh|zsh|source|.)
      local sc="${r[0]:-}"
      case "$sc" in
        -n) return 0 ;;                                   # 문법 검사만
        -c) sh_run "${r[1]:-}" bash; return 0 ;;
      esac
      sc="${sc//\\//}"
      case "$sc" in
        */todo-guard/scripts/todo.sh)
          [ "${r[1]:-}" = add ] && SH_TODO_ADD=1
          sh_todo; return 0 ;;
        */todo-guard/scripts/rule.sh|*/todo-guard/scripts/doctor.sh)
          sh_todo; return 0 ;;
      esac
      sh_work ;;
    curl)
      local x
      for ((x=0; x<${#r[@]}; x++)); do
        case "${r[x]}" in
          -o|--output) sh_target "${r[x+1]:-}" 1 ;;
          -O|--remote-name|-d|--data*|-F|--form|-T|--upload-file|--request|-X)
            case "${r[x]}" in -X|--request) case "${r[x+1]:-}" in GET|HEAD) continue ;; esac ;; esac
            sh_work ;;
        esac
      done ;;
    wget)
      case " ${r[*]} " in *" -O- "*|*" -qO- "*|*" -O - "*|*"--output-document=-"*|*" --spider "*) ;; *) sh_work ;; esac ;;
    powershell|pwsh|powershell.exe|pwsh.exe)
      local x lw
      for ((x=0; x<${#r[@]}; x++)); do
        tg_lower_to lw "${r[x]}"
        case "$lw" in -command|-c) sh_run "${r[x+1]:-}" ps; return 0 ;; esac
      done
      sh_work ;;
    *) sh_work ;;
  esac
}

# 파워셸 인자에서 이름 붙은 값과 위치 인자를 가른다 → PS_NAMED (이름=값 줄들), SH_POS
ps_args() {
  local a=("$@") n=$# k=0 x name
  PS_NAMED=""; SH_POS=()
  while [ "$k" -lt "$n" ]; do
    x="${a[k]}"
    if [[ "$x" == -[A-Za-z]* ]]; then
      tg_lower_to name "${x#-}"
      if [[ "$name" == *:* ]]; then
        PS_NAMED+="${name%%:*}=${x#*:}"$'\n'; k=$((k+1)); continue
      fi
      case "$name" in
        force|recurse|append|nonewline|noclobber|passthru|whatif|confirm|raw|notypeinformation|verbose|asjob|wait|nonewwindow|usetransaction)
          k=$((k+1)); continue ;;
      esac
      PS_NAMED+="$name=${a[k+1]:-}"$'\n'; k=$((k+2)); continue
    fi
    SH_POS+=("$x"); k=$((k+1))
  done
}

ps_named() {       # ps_named 이름…  → REPLY (처음 찾은 값)
  local nm line
  REPLY=""
  for nm in "$@"; do
    while IFS= read -r line; do
      [ "${line%%=*}" = "$nm" ] && { REPLY="${line#*=}"; return 0; }
    done <<< "$PS_NAMED"
  done
  return 1
}

# 파워셸 명령 한 토막
sh_seg_ps() {
  local a=("$@") k=0 n=$# w
  # $x = … 대입은 오른쪽을 본다
  if [[ "${a[0]}" == '$'* ]] && [ "${a[1]:-}" = "=" ]; then k=2; fi
  if [[ "${a[0]}" == '$'*=* ]]; then a[0]="${a[0]#*=}"; fi
  [ "${a[k]:-}" = "&" ] && { sh_work; return 0; }         # & "C:\x.exe" - 무엇을 할지 모른다
  [ "$k" -lt "$n" ] || return 0
  tg_lower_to w "${a[k]}"
  local r=("${a[@]:k+1}")
  case "$w" in
    get-*|select-*|where-object|where|'?'|foreach-object|'%'|sort-object|sort|measure-*|format-*|test-*|      write-output|write-host|write-verbose|write-information|echo|out-host|out-string|out-null|      convertfrom-*|convertto-*|push-location|pushd|pop-location|popd|ls|dir|gci|cat|gc|type|pwd|gl|      resolve-path|rvpa|split-path|join-path|compare-object|group-object|group|select-string|sls|      start-sleep|sleep|findstr|tree|if|else|elseif|foreach|for|while|do|switch|try|catch|finally|      param|return|exit|break|continue|'{'|'}'|'('|')'|clear-host|cls|help|man|whoami|hostname|      '$'*|true|false|'['*)
      ;;
    set-location|cd|sl|chdir)
      ps_args "${r[@]}"
      ps_named path literalpath && sh_cd "$REPLY" || sh_cd "${SH_POS[0]:-}" ;;
    set-content|sc|out-file|clear-content|clc|remove-item|rm|del|erase|rd|rmdir|ri|      new-item|ni|md|mkdir|add-content|ac|rename-item|ren|rni|export-csv|epcsv|export-clixml|tee-object|tee)
      ps_args "${r[@]}"
      local t=""
      ps_named path literalpath filepath lp && t="$REPLY" || t="${SH_POS[0]:-}"
      local kill=1
      case "$w" in add-content|ac|new-item|ni|md|mkdir) kill=0 ;; esac
      case "$w" in tee-object|tee) case "$PS_NAMED" in *append=*) kill=0 ;; esac ;; esac
      [ -n "$t" ] && sh_target "$t" "$kill"
      sh_need_target ;;
    copy-item|copy|cp|cpi|move-item|move|mv|mi)
      ps_args "${r[@]}"
      local t=""
      ps_named destination dest && t="$REPLY" || t="${SH_POS[1]:-}"
      [ -n "$t" ] && sh_target "$t" 1
      sh_need_target ;;
    git) sh_git "${r[@]}" ;;
    python|python3|py|pythonw|node|deno|bun|ruby|php|rscript|python.exe|node.exe)
      sh_interp "$w" "${r[@]}" ;;
    bash|bash.exe|sh)
      sh_seg_bash bash "${r[@]}" ;;
    *) sh_work ;;
  esac
}

# 토막 하나 - 리다이렉트를 떼어 쓰기 대상으로 적고, 나머지를 명령으로 본다
sh_segment() {
  local mode="$1"; shift
  local toks=("$@") n=$# i t args=()
  SH_SEG_T0=${#SH_TGT[@]}
  for ((i=0; i<n; i++)); do
    t="${toks[i]}"
    case "$t" in
      '>'|'>|'|[0-9]'>'|'*>'|'&>'|[0-9]'>|')   sh_target "${toks[i+1]:-}" 1; i=$((i+1)) ;;
      '>>'|[0-9]'>>'|'*>>'|'&>>')             sh_target "${toks[i+1]:-}" 0; i=$((i+1)) ;;
      '>&'|[0-9]'>&'|'<'|[0-9]'<'|'<<'|'<<<') i=$((i+1)) ;;
      *) args+=("$t") ;;
    esac
  done
  [ "${#args[@]}" -gt 0 ] || return 0
  if [ "$mode" = ps ]; then sh_seg_ps "${args[@]}"; else sh_seg_bash "${args[@]}"; fi
}

# 명령 전체를 훑는다. 결과를 비우지 않고 쌓는다 (bash -c 안쪽을 다시 훑을 때 쓴다)
sh_run() {
  local text="$1" mode="$2"
  if [ "${#text}" -gt "$SH_MAX" ]; then sh_work; return 0; fi
  if [ "$mode" != ps ]; then sh_strip_heredoc "$text"; text="$SH_TEXT"; fi
  sh_tokenize "$text" "$mode"
  local toks=("${SH_T[@]}") seg=() t
  for t in "${toks[@]}" ";"; do
    if [ "$t" = ";" ]; then
      [ "${#seg[@]}" -gt 0 ] && sh_segment "$mode" "${seg[@]}"
      seg=()
    else
      seg+=("$t")
    fi
  done
}

sh_classify() {
  sh_reset
  sh_run "$1" "$2"
}
