---
name: spec-docs
description: "Use when setting up a project's first SDD docs/ structure with contract, proposal, design, tasks, and capability specs, writing or editing Requirement/Scenario entries in capability spec.md files or tasks.md items, or auditing docs/ layout — \"SDD 문서 구조 잡아줘\", \"요구사항 작성해줘\", \"작업 항목 추가해줘\", \"문서 배치 점검해줘\"."
---

# spec-docs

SDD(Spec-Driven Development) 문서 구조를 처음 세팅하고, 요구사항·작업 항목을 작성하거나
기존 문서의 형식과 배치를 점검한다. 처음 구조를 잡을 때는 [처음 세팅](#처음-세팅)을,
내용을 쓰거나 감사할 때는 [작성 형식과 검증](#작성-형식과-검증)을 따른다.

OpenSpec의 Requirement/Scenario 형식은 참고하되, 문서는 `docs/` 아래에 모은다.
`spec.md`는 문법을 엄격하게 확인하고, 나머지 문서는 배치 규칙을 중심으로 점검한다.
문장 톤과 문체 검사는 이 스킬의 범위에 포함하지 않는다.

## 처음 세팅

### 문서 구조

```text
docs/
├── README.md          # docs/ 진입점과 읽는 순서
├── contract.md        # 상위 계약, 최초 작성 후 FROZEN — 이후 인용만 함
├── proposal.md        # 왜/무엇을 바꾸는지와 변경이력 표
├── design.md          # capability를 가로지르는 기술 결정, 프로젝트에 하나
├── tasks.md           # 전체 구현 체크리스트, 프로젝트에 하나
└── specs/
    └── <capability>/
        └── spec.md    # capability별 요구사항만
```

### 하지 말 것

- capability마다 `design.md`나 `tasks.md`를 만들지 않는다. 프로젝트 전체에
  `docs/design.md`, `docs/tasks.md`를 각각 하나만 두고, 필요한 구분은 그 안의 섹션으로 표현한다.
- `openspec/`, `AGENTS.md`, `changes/<id>/` 같은 OpenSpec 전용 이름과 델타 폴더 구조를 쓰지 않는다.
- 버전 번호를 파일명에 넣지 않는다. 예를 들어 `contract-v0.1.md` 대신 `contract.md`를 쓰고,
  버전은 파일 내부 제목과 `proposal.md`의 변경이력 표에서만 관리한다.
- `contract.md`는 최초 한 번만 작성한다. 세팅 후에는 FROZEN으로 두고 재해석하지 않으며 인용만 한다.

### 진행 순서

1. capability 목록과 의존성 순서를 사용자에게 직접 묻는다. 프로젝트마다 다르므로 하드코딩하지 않는다.
2. 위 구조대로 `docs/README.md`, `contract.md`, `proposal.md`, `design.md`, `tasks.md`와
   `specs/<capability>/spec.md`를 생성한다. capability 폴더에는 `spec.md`만 둔다.
3. 프로젝트의 하네스 설정 파일(대개 `CLAUDE.md`)에 "문서 배치는 docs/docs-rules.md를 따른다"를
   한 줄 추가한다. `docs/docs-rules.md`가 아직 없으면 이 처음 세팅 절의 문서 배치 규칙 요약을
   그 파일로도 만들어 둔다.

처음 세팅은 문서 뼈대를 만드는 단계다. 실제 요구사항 작성과 검증은 아래 절을 따른다.

## 작성 형식과 검증

### spec.md 작성 형식

`docs/specs/<capability>/spec.md`의 요구사항은 다음 형식으로 작성한다.

```markdown
### Requirement: <이름>
<주어> SHALL <내용>.

#### Scenario: <이름>
- GIVEN <전제 상태>
- WHEN <트리거 조건>
- THEN <기대 결과>
```

- Requirement 제목 바로 아래에는 `SHALL`을 쓰는 단정문을 둔다.
- Scenario에는 `GIVEN`, `WHEN`, `THEN` 세 줄이 모두 있어야 한다. `GIVEN`을 생략하지 않는다.
- `- GIVEN`, `- WHEN`, `- THEN`은 일반 텍스트로 쓴다. `**WHEN**`처럼 볼드로 감싸지 않는다.

### tasks.md 작성 형식

모든 작업 항목은 근거가 되는 Requirement 이름을 본문에 명시한다.

```markdown
- [ ] 계정 잠금 구현 (근거: Account Lockout on Repeated Login Failures)
```

근거 없는 작업은 범위 이탈로 보고 사용자에게 되묻거나 삭제를 제안한다.
Requirement와 작업의 연결은 사람이 명시하며, 자동으로 매핑을 만들지 않는다.
사람이 명시한 이름이 실제 Requirement와 일치하는지 확인한다.

### 검증

```bash
bash ~/.claude/skills/spec-docs/scripts/check-spec.sh <spec.md 파일 또는 docs/ 디렉터리>
```

- `spec.md` 파일을 주면 Requirement/Scenario 문법을 검사한다.
- `docs/` 디렉터리를 주면 금지 이름(`openspec/`, `AGENTS.md`, 버전 번호를 넣은 Markdown 파일명),
  capability별 중복 `design.md`·`tasks.md`, 그 아래 모든 `spec.md`를 함께 검사한다.
  Git 저장소라면 `HEAD~5`와 현재 작업 트리 사이에 `contract.md`가 달라졌는지 보고 경고한다.
- 위반이 있으면 파일·줄 또는 해당 경로를 알리고 0이 아닌 코드로 종료한다. 위반이 없으면 `OK`를 출력한다.

`spec.md`를 쓰거나 수정한 직후, 또는 `tasks.md`에 항목을 추가한 직후에는 이 스크립트를 실행한다.
실패하면 고친 뒤 다시 실행하고, 통과하기 전까지 다음 작업으로 넘어가지 않는다.

스크립트는 `SHALL` 포함 여부와 Scenario 제목 다음 6줄을 보는 간단한 검사다.
제목 오탈자, 빈 Requirement 본문, Scenario 사이의 경계, `-v<숫자>` 밖의 버전 표기는
가려내지 못하므로 직접 확인한다. `tasks.md`의 Requirement 근거 대조는 수행하지 않으므로 위 작성 형식에 따라 직접 확인한다.
`contract.md` 변경은 경고만 하며, 내용을 재해석하거나 변경을 강제로 막지 않고 판단을 사람에게 맡긴다.
