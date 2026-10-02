#!/usr/bin/env bash
# 마이그레이션 SQL 파일 하나를 받아 destructive/lock 위험 패턴을 찾는다.
# 문장 단위 파싱이 아니라 파일 전체 텍스트에 대한 키워드 휴리스틱이다 — 정확한 SQL
# 파서가 아니므로 오탐/누락 가능. "확인이 필요하다"는 신호로만 쓴다.
# 사용법: check-sql.sh <sql파일>
set -u

FILE="$1"
[ -f "$FILE" ] || exit 0

CONTENT="$(cat "$FILE")"
UPPER="$(echo "$CONTENT" | tr '[:lower:]' '[:upper:]')"

report() { echo "  - [${1}] ${2}"; }

FOUND=0

echo "$UPPER" | grep -qE '\bDROP[[:space:]]+TABLE\b' && { report DESTRUCTIVE "DROP TABLE 발견 — 테이블 전체 삭제, 되돌릴 수 없음"; FOUND=1; }
echo "$UPPER" | grep -qE '\bDROP[[:space:]]+COLUMN\b' && { report DESTRUCTIVE "DROP COLUMN 발견 — 해당 컬럼 데이터 전부 유실"; FOUND=1; }
echo "$UPPER" | grep -qE '\bTRUNCATE\b' && { report DESTRUCTIVE "TRUNCATE 발견 — 테이블의 모든 행 삭제"; FOUND=1; }
echo "$UPPER" | grep -qE '\bDELETE[[:space:]]+FROM\b' && { report "확인 필요" "DELETE FROM 발견 — WHERE 절로 범위가 제한되는지 직접 확인"; FOUND=1; }

if echo "$UPPER" | grep -qE 'ADD[[:space:]]+COLUMN'; then
  while IFS= read -r line; do
    up="$(echo "$line" | tr '[:lower:]' '[:upper:]')"
    if echo "$up" | grep -qE 'ADD[[:space:]]+COLUMN' && echo "$up" | grep -q 'NOT NULL' && ! echo "$up" | grep -q 'DEFAULT'; then
      report "LOCK 위험" "DEFAULT 없는 NOT NULL 컬럼 추가 — 기존 행이 있으면 실패하거나 테이블 전체 락"
      FOUND=1
    fi
  done <<< "$CONTENT"
fi

if echo "$UPPER" | grep -qE '\bCREATE[[:space:]]+INDEX\b' && ! echo "$UPPER" | grep -qE 'CONCURRENTLY'; then
  report "LOCK 위험" "CONCURRENTLY 없는 CREATE INDEX — 큰 테이블이면 쓰기 잠금 발생 가능"
  FOUND=1
fi

echo "$UPPER" | grep -qE 'ALTER[[:space:]]+COLUMN.*TYPE' && { report "LOCK 위험" "컬럼 타입 변경 — 테이블 재작성이 필요할 수 있음(대형 테이블 주의)"; FOUND=1; }

exit "$FOUND"
