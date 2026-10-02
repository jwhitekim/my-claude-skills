#!/usr/bin/env bash
# Git 의 bash.exe 가 이 PC 에서만 유난히 느리면, 같은 내용의 새 파일로 바꿔 넣는다 (윈도우 전용).
#
# 왜
#   어떤 PC 에서는 Git 의 usr\bin\bash.exe 파일 하나만 실행마다 0.45초씩 늦는다. 같은 바이트의
#   sh.exe 나 다른 폴더로 복사한 것은 0.05초다. 백신 검사 · 프리페치 · 호환성 보정 · 파일 속성이
#   모두 아니었고, 새 파일로 바꿔 넣자 537 → 55ms 가 됐다(원본을 다시 넣으면 도로 느려졌다).
#   Claude Code 는 Bash 명령마다 이 파일을 띄우므로 명령마다 그만큼 늦다.
#   투두가드 훅은 pick-shell.py 가 sh.exe 로 돌려 피하지만, Claude Code 의 Bash 명령은 이것으로만 풀린다.
#
# 사용
#   fix-slow-bash.sh          재기만 한다. 느리면 「고칠 수 있다」고 알린다
#   fix-slow-bash.sh --apply  고친다. 권한 창(UAC)이 한 번 뜬다. 사용자가 동의했을 때만 쓴다
#
# 하는 일 (--apply): 원본 백업 → 같은 폴더에 복사 → 원본은 bash.exe.old-<시각> 으로 이름만 바꿈 →
#   복사본을 bash.exe 로 → 다시 잼 → 빨라지지 않았으면 원래대로 되돌림.
#   백업: ~/.claude/todo-guard-bash-backup/<시각>/bash.exe
#   되돌리기: bash.exe 를 지우고 bash.exe.old-<시각> 을 bash.exe 로 (관리자 권한)
_TG_DIR="${BASH_SOURCE[0]%/*}"
[ -f "$_TG_DIR/_root.sh" ] || _TG_DIR="$HOME/.claude/skills/todo-guard/scripts"
. "$_TG_DIR/_root.sh"

if [ "$IS_WIN" != "1" ] || ! command -v cygpath >/dev/null 2>&1; then
  echo "[todo-guard] 윈도우 Git Bash 에서만 쓰는 도구입니다."; exit 0
fi

# TG_FIX_BASH_BIN · TG_FIX_FORCE 는 시험용이다 (다른 폴더를 대상으로, 느리지 않아도 돌린다)
BIN_W="$(cygpath -w "${TG_FIX_BASH_BIN:-/usr/bin}")"
BASH_W="$BIN_W\\bash.exe"
SH_W="$BIN_W\\sh.exe"

# 잰다 - 각각 7번 띄운 중간값 (파이썬 없이 PowerShell 로)
measure() {
  powershell.exe -NoProfile -Command "\$e='$1'; & \$e -c ':' | Out-Null; \$m=@(); for(\$i=0;\$i -lt 7;\$i++){ \$m += (Measure-Command { & \$e -c ':' | Out-Null }).TotalMilliseconds }; \$m=\$m|Sort-Object; [int]\$m[3]" 2>/dev/null | tr -d '\r'
}
B="$(measure "$BASH_W")"; S="$(measure "$SH_W")"
[[ "$B" =~ ^[0-9]+$ ]] && [[ "$S" =~ ^[0-9]+$ ]] || { echo "[todo-guard] 재지 못했습니다 (bash=$B sh=$S)"; exit 1; }
echo "[todo-guard] bash.exe ${B}ms · sh.exe ${S}ms  ($BASH_W)"

if [ $((B - S)) -le 300 ] && [ "${TG_FIX_FORCE:-0}" != 1 ]; then
  echo "  느리지 않습니다. 할 일이 없습니다."; exit 0
fi
if [ "$1" != "--apply" ]; then
  echo "  bash.exe 만 유난히 느립니다. Claude Code 의 모든 Bash 명령이 명령마다 $((B - S))ms 씩 늦습니다."
  echo "  사용자에게 묻고, 동의하면: bash \"\$HOME/.claude/skills/todo-guard/scripts/fix-slow-bash.sh\" --apply"
  echo "  (권한 창이 한 번 뜹니다. 원본은 백업하고, 빨라지지 않으면 되돌립니다)"
  exit 0
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
BK_W="$(cygpath -w "$HOME")\\.claude\\todo-guard-bash-backup\\$STAMP"
OUT_W="$(cygpath -w "${TMPDIR:-/tmp}")\\tg-fix-bash-$STAMP.txt"
PS1_W="$(cygpath -w "$_TG_DIR/fix-slow-bash.ps1")"
echo "  권한 창이 뜹니다. 「예」를 누르십시오."
powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','\"$PS1_W\"','-Dir','\"$BIN_W\"','-BackupDir','\"$BK_W\"','-Out','\"$OUT_W\"'" 2>/dev/null
OUT_U="$(cygpath -u "$OUT_W")"
if [ ! -f "$OUT_U" ]; then
  echo "  권한 창에서 취소됐거나 실행되지 않았습니다. 바뀐 것은 없습니다."; exit 1
fi
res=""; before=""; after=""; err=""
while IFS='=' read -r k v; do
  v="${v%$'\r'}"
  case "$k" in before_ms) before="$v" ;; after_ms) after="$v" ;; result) res="$v" ;; error) err="$v" ;; backup) bk="$v" ;; esac
done < "$OUT_U"
rm -f "$OUT_U"
case "$res" in
  replaced) echo "  바꿨습니다: bash.exe ${before}ms → ${after}ms. 원본 백업: $bk" ;;
  reverted) echo "  바꿔 봤지만 빨라지지 않아(${before}ms → ${after}ms) 원래대로 되돌렸습니다." ;;
  *)        echo "  실패: ${err:-알 수 없음}. 바뀐 것은 없거나 되돌렸습니다." ;;
esac
