---
name: docs-compliance
description: Use when writing or editing a Requirement/Scenario in specs/<capability>/spec.md, adding an entry to tasks.md, or auditing an existing docs/ tree for layout violations.
---

# docs-compliance

`docs/` 문서가 SDD 배치 규칙(`docs-init`이 세팅한 구조)을 지키는지 강제·점검한다. `spec.md`는 문법 단위로 엄격하게, 나머지 `docs/`는 배치 규칙만 느슨하게 본다 — 문체/톤 검사는 이 스킬의 범위가 아니다(그건 글검수 스킬).

## spec.md 작성 시 반드시 지킬 형식

```markdown
### Requirement: <이름>
<주어> SHALL <내용>.

#### Scenario: <이름>
- GIVEN <전제 상태>
- WHEN <트리거 조건>
- THEN <기대 결과>
```

- Requirement 제목 바로 아래 문장은 **SHALL로 끝나는 단정문**이어야 한다.
- Scenario는 **GIVEN/WHEN/THEN 3줄 모두** 있어야 한다(WHEN/THEN만 쓰고 GIVEN을 생략하지 않는다).
- `- GIVEN`, `- WHEN`, `- THEN`은 **plain text**로 쓴다. `**WHEN**`처럼 볼드로 감싸지 않는다.

## tasks.md 작성 시

모든 작업 항목은 어떤 Requirement를 근거로 하는지 **본문에 그 Requirement 이름을 명시**한다(예: `- [ ] 계정 잠금 구현 (근거: Account Lockout on Repeated Login Failures)`). 근거 없는 작업은 범위 이탈로 보고 사용자에게 되묻거나 삭제를 제안한다. 자동으로 매핑을 만들어주지는 않는다 — 항상 사람이 명시한다.

## 검증 스크립트

```bash
bash ~/.claude/skills/docs-compliance/scripts/check-spec.sh <spec.md 파일 또는 docs/ 디렉터리>
```

- 단일 `spec.md` 경로를 주면 Requirement/Scenario 문법만 검사한다.
- `docs/` 디렉터리를 주면 전체 감사: 금지 파일명(`openspec/`, `AGENTS.md`, 버전넘버 파일명), capability별 중복 design.md/tasks.md, `contract.md` 최근 변경 여부를 함께 확인하고 그 아래 모든 `spec.md`도 검사한다.
- 위반이 있으면 각 줄을 지적하고 non-zero로 종료한다. 위반 없으면 `OK`.

spec.md를 쓰거나 수정한 직후, 또는 tasks.md에 항목을 추가한 직후에는 이 스크립트로 검증하고, 실패하면 고친 뒤 다시 돌린다(고치기 전까지 다음 작업으로 넘어가지 않는다).

## 하지 않는 것

- 문장 톤/문체 검사(글검수 스킬 영역)
- Requirement-Task 자동 연결(사람이 명시한 텍스트 매칭 여부만 확인)
- `contract.md` 내용을 재해석하거나 수정 여부를 강제로 막는 것(경고만 하고 판단은 사람에게)
