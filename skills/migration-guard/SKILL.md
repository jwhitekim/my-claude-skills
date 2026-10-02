---
name: migration-guard
description: "*/migrations/*.sql (Supabase CLI, 또는 비슷한 구조의 DB 마이그레이션) 변경을 검사한다. 새로 추가된 마이그레이션에서 destructive 변경(DROP TABLE/COLUMN, TRUNCATE), lock 위험(DEFAULT 없는 NOT NULL 컬럼 추가, CONCURRENTLY 없는 인덱스 생성, 컬럼 타입 변경)을 찾고, 이미 커밋된 마이그레이션 파일을 수정하는 경우(이미 적용된 환경엔 반영 안 됨)도 경고한다. change-impact가 마이그레이션 변경을 감지하면 대신 호출한다. \"마이그레이션 파일 위험한 거 없나 봐줘\" 같은 요청에도 수동으로 사용한다."
---

# migration-guard

`supabase/migrations/*.sql`처럼 타임스탬프 파일로 쌓이는 DB 마이그레이션을 대상으로 한다.
**SQL 파서가 아니라 키워드 휴리스틱**이다 — "이 패턴이 보이니 확인하라"는 신호지, 정밀
분석이 아니다.

## 실행

```bash
bash ~/.claude/skills/migration-guard/scripts/check.sh          # staged 기준 (기본)
bash ~/.claude/skills/migration-guard/scripts/check.sh last     # 마지막 커밋 기준
```

`*/migrations/*.sql` 경로 패턴에 걸리는 파일만 대상으로 한다 — Supabase CLI
(`supabase/migrations/`), Rails(`db/migrate/`는 확장자가 다르면 안 잡힘), 기타 비슷한
구조를 느슨하게 커버한다.

## 새로 추가된 마이그레이션 — destructive/lock 패턴

| 패턴 | 분류 | 이유 |
|---|---|---|
| `DROP TABLE` | destructive | 테이블 전체 삭제, 되돌릴 수 없음 |
| `DROP COLUMN` | destructive | 해당 컬럼 데이터 전부 유실 |
| `TRUNCATE` | destructive | 테이블의 모든 행 삭제 |
| `DELETE FROM` | 확인 필요 | WHERE 절 유무를 grep만으로 정확히 못 봐서 "확인하라"로만 표시 |
| `DEFAULT` 없는 `NOT NULL` 컬럼 추가 | lock 위험 | 기존 행 있으면 실패하거나 테이블 전체 락 |
| `CONCURRENTLY` 없는 `CREATE INDEX` | lock 위험 | 큰 테이블이면 쓰기 잠금 발생 가능 |
| 컬럼 타입 변경(`ALTER COLUMN ... TYPE`) | lock 위험 | 테이블 재작성 필요할 수 있음 |

## 기존 마이그레이션 파일 수정

Supabase류 마이그레이션은 **append-only**가 원칙이다 — 이미 커밋된 마이그레이션 파일을
고치면, 이미 그 파일을 적용한 환경(로컬/스테이징/운영)에는 변경이 반영되지 않는다.
이 패턴이 감지되면 새 마이그레이션 파일을 추가하라고 권한다.

## 잡지 않는 것

- **진짜 SQL 파서가 아니다.** 문자열/주석 안에 우연히 키워드가 들어가면 오탐할 수 있다.
- **실제 롤백 가능 여부는 판단하지 않는다.** Supabase 마이그레이션은 관례상 down 파일이
  없다 — "되돌릴 수 없는 변경이니 백업/확인하라"는 경고까지만 한다.
- **스키마와 애플리케이션 코드의 정합성은 보지 않는다.**

## change-impact와의 연계

`change-impact`가 diff에 `*/migrations/*.sql` 변경이 있으면 `check.sh`를 대신 호출한다.
destructive/lock 패턴이나 기존 마이그레이션 수정이 보이면 사용자에게 알린다. 아무것도
막지 않는다 — DB 변경은 때로 의도적으로 destructive해야 하므로(예: 정말 컬럼을 지워야
하는 경우) 최종 판단은 사용자에게 맡긴다.
