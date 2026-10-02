---
name: api-contract-guard
description: OpenAPI/Swagger 스펙 파일(openapi.yaml, swagger.json 등)이 바뀐 커밋에서 breaking change(엔드포인트 삭제, 필드가 새로 required가 됨, 필드/스키마 삭제, 타입 변경, enum 값 제거)를 감지한다. change-impact가 스펙 변경을 감지하면 대신 호출한다. "API 스펙 breaking change 확인해줘" 같은 요청에도 수동으로 사용한다. 파일명에 openapi 또는 swagger가 들어간 .yaml/.yml/.json 파일만 대상으로 한다 — 그런 파일이 없는 프로젝트에서는 아무 일도 하지 않는다.
---

# api-contract-guard

OpenAPI/Swagger 스펙의 old/new를 구조적으로 비교해서 하위 호환을 깨는 변경을 찾는다.
스펙 파일이 없는 프로젝트에서는 아무것도 하지 않는다 — 강제로 OpenAPI를 쓰게 만들지
않는다.

## 실행

```bash
bash ~/.claude/skills/api-contract-guard/scripts/check.sh          # staged 기준 (기본)
bash ~/.claude/skills/api-contract-guard/scripts/check.sh last     # 마지막 커밋 기준
```

파일명에 `openapi` 또는 `swagger`가 들어간 `.yaml`/`.yml`/`.json` 파일이 변경 목록에
있을 때만 동작한다.

## 잡는 것

| 항목 | 설명 |
|---|---|
| 엔드포인트 삭제 | `paths` 아래 path+method 조합이 old에는 있었는데 new에 없음 |
| 파라미터가 새로 required가 됨 | 기존엔 선택이던 파라미터가 필수로 바뀜 — 기존 클라이언트가 깨짐 |
| 스키마/필드 삭제 | `components.schemas.*`의 스키마 자체 또는 그 안의 `properties` 필드가 사라짐 |
| 필드가 새로 required가 됨 | 스키마의 `required` 배열에 새 필드가 추가됨 |
| 타입 변경 | 같은 필드의 `type`이 바뀜 (예: string → integer) |
| enum 값 제거 | 기존에 허용되던 enum 값이 사라짐 |

## 잡지 않는 것 (의도적으로 보수적)

- **`$ref` 간접 참조를 재귀적으로 추적하지 않는다.** 참조 해석까지 하면 복잡도가 급격히
  올라가는데, 개인 도구로 쓰기엔 효용 대비 비용이 안 맞다 — 직접 눈으로 확인 권장.
- **새 필드/엔드포인트 추가는 breaking이 아니므로 보고하지 않는다.** 추가는 보통
  하위 호환이다.
- **스펙과 실제 구현(코드)이 일치하는지는 확인하지 않는다.** 스펙 파일 자체의 diff만
  본다 — 구현이 스펙을 따르는지는 별개 문제다.

## change-impact와의 연계

`change-impact`가 diff에 OpenAPI/Swagger 스펙 변경이 있으면 `check.sh`를 대신 호출한다.
breaking change가 보이면 사용자에게 알리고, API 버전을 올리거나(`/v2` 등) 하위 호환을
유지할 방법을 검토할지 확인한다. 아무것도 막지 않는다.

## PyYAML 없는 환경

`.yaml`/`.yml` 스펙은 PyYAML이 필요하다. 없으면 "건너뜁니다" 메시지만 내고 조용히
지나간다(에러로 죽지 않음). `.json` 스펙은 표준 라이브러리만으로 동작한다.
