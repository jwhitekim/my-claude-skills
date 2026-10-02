---
name: docs-init
description: Use when a project has no spec/design documentation yet and needs one set up, or when asked to create a docs/ structure, contract/proposal/design/tasks layout, or capability specs for the first time.
---

# docs-init

SDD(Spec-Driven Development) 스타일 문서 구조를 처음 세팅한다. OpenSpec 같은 도구의 Requirement/Scenario 형식은 참고하되, `openspec/`나 `changes/<change-id>/` 같은 델타 폴더 구조는 쓰지 않는다 — `docs/` 하나 아래에 평탄화한다.

## 항상 만드는 구조

```
docs/
├── README.md          # docs/ 진입점, 읽는 순서 안내
├── contract.md         # 상위 계약, FROZEN — 이후 절대 재해석하지 않고 인용만 함
├── proposal.md          # 왜/무엇을 바꾸는지 + 변경이력 표
├── design.md            # capability를 가로지르는 기술 결정 (프로젝트에 1개만)
├── tasks.md              # 전체 구현 체크리스트 (프로젝트에 1개만)
└── specs/
    └── <capability>/
        └── spec.md        # capability별 요구사항만
```

## 절대 하지 말 것

- **capability마다 design.md/tasks.md를 따로 만들지 않는다.** design.md와 tasks.md는 프로젝트 전체에 각각 딱 1개(`docs/design.md`, `docs/tasks.md`)만 존재한다. capability별로 나누고 싶은 충동이 들어도, 그 안의 섹션을 나누는 것으로 대신한다.
- `openspec/`, `AGENTS.md`, `changes/<id>/` 같은 OpenSpec 전용 이름/구조를 쓰지 않는다.
- 버전 번호를 파일명에 넣지 않는다(`contract-v0.1.md` 금지). 버전은 파일 내부 제목과 `proposal.md`의 변경이력 표로만 관리한다.
- `contract.md`는 세팅 후 FROZEN이다 — 최초 1회만 작성하고 이후 재해석하지 않는다.

## 진행 순서

1. capability 목록과 의존성 순서를 사용자에게 **직접 물어본다**(하드코딩하지 않는다 — 프로젝트마다 다르다).
2. 위 구조대로 `docs/README.md, contract.md, proposal.md, design.md, tasks.md`와 `specs/<capability>/spec.md`(capability마다 하나씩, 다른 파일 없이)를 생성한다.
3. 프로젝트의 하네스 설정 파일(대개 `CLAUDE.md`)에 "문서 배치는 docs/docs-rules.md를 따른다" 한 줄을 추가한다. `docs/docs-rules.md`가 아직 없으면 이 SKILL.md의 규칙 요약을 그 파일로도 만들어둔다.

## Requirement/Scenario 작성 형식 (참고)

`specs/<capability>/spec.md`에 요구사항을 쓸 때는 `docs-compliance` 스킬이 강제하는 형식(`### Requirement: <이름>` + SHALL 문장, `GIVEN/WHEN/THEN` 시나리오)을 따른다 — 이 스킬은 뼈대만 만들고, 실제 요구사항 작성/검증은 `docs-compliance`가 담당한다.
