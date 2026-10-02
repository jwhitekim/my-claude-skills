---
name: skill-lint
description: my-claude-skills 레포의 skills/*/ 구성이 망가지지 않았는지 검사한다. SKILL.md 누락, frontmatter 오류, 깨진 스크립트 경로 참조, 실행 권한 없는 스크립트, README 누락, 완전히 중복된 description을 찾는다. "skill-lint 돌려줘", "스킬 저장소 점검해줘", 새 스킬을 만들거나 이름을 바꾼 직후에 사용한다. install.sh 실행 시에도 자동으로 돈다(경고만 하고 설치를 막지는 않음).
---

# skill-lint

이 레포 자체(스킬 모음집)를 위한 메타 스킬. 스킬을 새로 만들거나 이름을 바꿀 때마다
경로 참조가 깨지거나 README가 안 맞는 일이 실제로 반복됐다 — 이걸 기계적으로 잡는다.
아무것도 자동으로 고치지 않는다. 문제만 알린다.

## 실행

```bash
bash ~/.claude/skills/skill-lint/scripts/lint.sh            # 전체 스킬 검사
bash ~/.claude/skills/skill-lint/scripts/lint.sh <스킬명>    # 스킬 하나만 검사
```

`install.sh`가 symlink를 걸기 전에 자동으로 이걸 돌린다. 문제가 있어도 설치는 계속
진행된다 — 설치를 막으면 사소한 경고 하나로 전체 작업이 멈추는 게 더 성가시다.

## 검사 항목

| 항목 | 내용 |
|---|---|
| SKILL.md 존재 | 스킬 폴더에 SKILL.md가 없으면 경고 |
| frontmatter `name:` | 폴더명과 일치하는지 |
| frontmatter `description:` | 비어있지 않은지 |
| 스크립트 경로 참조 | SKILL.md 본문이 언급하는 `scripts/*.sh`, `scripts/*.py`가 실제로 존재하는지 |
| 실행 권한 | `scripts/` 안의 `.sh` 파일이 `chmod +x` 되어 있는지 |
| description 완전 중복 | 두 스킬의 description이 글자 하나까지 똑같은 복붙 실수 (전체 검사일 때만) |
| README 등재 | README.md의 스킬 표에 폴더명이 등장하는지 (전체 검사일 때만) |

## 하지 않는 것

- **의미적 description 중복 검사는 하지 않는다.** "비슷한 상황에서 트리거될 수 있다"는
  판단은 휴리스틱으로 하기엔 오탐이 너무 많다 — 완전 문자열 일치만 잡는다.
- **자동 수정하지 않는다.** 경로가 깨졌으면 사람이 고치거나 Claude에게 직접 고쳐달라고
  요청해야 한다.
- **다른 프로젝트의 `.claude/skills/`는 검사하지 않는다.** 이 레포(`my-claude-skills`)
  전용이다.

## 문제를 발견했을 때

경고 목록을 그대로 보여주고, 사용자가 원하면 하나씩 고친다 (예: 경로 참조 수정,
`chmod +x`, README 표에 항목 추가). 여러 개를 한 번에 고칠지, 하나씩 확인받으며 고칠지는
문제 개수에 따라 판단한다.
