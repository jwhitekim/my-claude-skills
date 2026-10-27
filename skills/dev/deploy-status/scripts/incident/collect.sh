#!/usr/bin/env bash
# 장애 시각 전후의 커밋과 GitHub Actions 실행 기록, 실패 로그를 모은다.
# 회고 문서를 쓰기 위한 재료만 모은다 — 원인 판단은 Claude가 한다.
# 사용법: collect.sh "<장애 시각, 예: 2026-10-02 14:30>" [앞뒤 범위(시간), 기본 24]
set -u

INCIDENT="${1:?사용법: collect.sh \"YYYY-MM-DD HH:MM\" [범위 시간]}"
HOURS="${2:-24}"

PY_BIN="python3"
command -v python3 >/dev/null 2>&1 || PY_BIN="python"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[incident-review] git 저장소가 아닙니다."
  exit 1
fi
cd "$(git rev-parse --show-toplevel)" || exit 1

# 장애 시각을 기준으로 범위의 시작/끝을 ISO 형식으로 계산 (로컬 시간대 기준)
read -r SINCE UNTIL < <("$PY_BIN" - "$INCIDENT" "$HOURS" <<'EOF'
import sys
from datetime import datetime, timedelta
t = datetime.strptime(sys.argv[1], "%Y-%m-%d %H:%M").astimezone()
h = timedelta(hours=float(sys.argv[2]))
print((t - h).isoformat(timespec="seconds"), (t + h).isoformat(timespec="seconds"))
EOF
)
[ -z "${SINCE:-}" ] && { echo "[incident-review] 시각 형식이 잘못됐습니다 (예: 2026-10-02 14:30)"; exit 1; }

echo "## 범위: ${SINCE} ~ ${UNTIL} (장애 시각 ${INCIDENT} 기준 ±${HOURS}시간)"
echo

echo "## 커밋"
COMMITS=$(git log --all --since="$SINCE" --until="$UNTIL" --date=iso-local \
  --pretty=format:'- %ad %h %s (%an)' 2>/dev/null)
if [ -n "$COMMITS" ]; then
  echo "$COMMITS"
else
  echo "- (범위 안 커밋 없음)"
fi
echo

echo "## GitHub Actions 실행"
if ! command -v gh >/dev/null 2>&1; then
  echo "- (gh CLI 없음 — 건너뜀)"
  exit 0
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "- (gh 로그인 안 됨 — 건너뜀)"
  exit 0
fi

RUNS_JSON=$(gh run list --limit 100 \
  --json databaseId,createdAt,workflowName,headBranch,headSha,conclusion,status,displayTitle 2>/dev/null)
if [ -z "$RUNS_JSON" ]; then
  echo "- (GitHub 원격 저장소가 없거나 조회 실패 — 건너뜀)"
  exit 0
fi

# heredoc이 stdin을 차지하므로 JSON은 환경변수로 넘긴다.
FILTERED=$(RUNS_JSON="$RUNS_JSON" "$PY_BIN" - "$SINCE" "$UNTIL" <<'EOF'
import json, os, sys
from datetime import datetime
since = datetime.fromisoformat(sys.argv[1])
until = datetime.fromisoformat(sys.argv[2])
runs = json.loads(os.environ["RUNS_JSON"])
for r in sorted(runs, key=lambda r: r["createdAt"]):
    created = datetime.fromisoformat(r["createdAt"].replace("Z", "+00:00"))
    if since <= created <= until:
        local = created.astimezone().strftime("%Y-%m-%d %H:%M")
        result = r.get("conclusion") or r.get("status")
        print(f'{r["databaseId"]}\t{local}\t{result}\t{r["workflowName"]}\t{r["headBranch"]}\t{r["headSha"][:7]}\t{r["displayTitle"]}')
EOF
)

if [ -z "$FILTERED" ]; then
  echo "- (범위 안 실행 기록 없음)"
  exit 0
fi

echo "$FILTERED" | while IFS=$'\t' read -r id when result wf branch sha title; do
  echo "- ${when} [${result}] ${wf} (${branch} ${sha}) ${title} — run ${id}"
done
echo

FAILED_IDS=$(echo "$FILTERED" | awk -F'\t' '$3=="failure"{print $1}' | head -3)
if [ -n "$FAILED_IDS" ]; then
  echo "## 실패한 실행 로그 (최대 3개, 정리 단계 이전 끝부분 30줄)"
  for id in $FAILED_IDS; do
    echo
    echo "### run ${id}"
    echo '```'
    # "Post job cleanup" 이후는 정리 작업 잡음이라 버리고, 줄 앞의 "job<TAB>step<TAB>타임스탬프 "를 뗀다.
    gh run view "$id" --log-failed 2>/dev/null \
      | awk -F'\t' '/Post job cleanup/{exit} {line=$3; sub(/^[0-9T:.\-]+Z /, "", line); print $1": "line}' \
      | tail -30 || echo "(로그 조회 실패)"
    echo '```'
  done
fi
