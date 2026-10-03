---
name: release-guard
description: "Use when preparing a release or tagging a version — \"릴리즈 준비해줘\", \"버전 올려줘\" — when a tag push was blocked by the pre-push hook, or when asked to install release-guard in a project. Not for ordinary branch pushes or commits."
---

# release-guard

일반 커밋·푸시마다 돌면 토큰과 신경을 쓸데없이 갉아먹는다. 그래서 이 스킬은 **git
pre-push 훅**으로 구현되어 있고, **태그를 푸시할 때만** 체크리스트가 돈다 — 모델 호출
없이 셸 스크립트로만 판단하므로 평소엔 비용이 0이다.

## 설치

```bash
cd <대상 프로젝트 루트>
bash ~/.claude/skills/release-guard/scripts/setup.sh
```

- `.git/hooks/pre-push`에 껍데기를 깐다 (본체는 `scripts/pre-push-check.sh` 한 벌 —
  고치면 설치된 모든 프로젝트에 바로 적용된다).
- 이미 다른 pre-push 훅이 있으면 덮어쓰지 않고, 수동으로 합칠 안내만 한다.
- `.git/hooks/`는 git이 추적하지 않으므로, 새 clone마다 `setup.sh`를 다시 돌려야 한다.

## 체크리스트 (태그 푸시 시에만)

| 항목 | 내용 | 해당 파일/항목이 없으면 |
|---|---|---|
| 버전 파일 일치 | `package.json`/`VERSION`/`pyproject.toml`의 버전과 태그 이름(`v` 제외)이 같은지 | 건너뜀 |
| CHANGELOG 항목 | `CHANGELOG.md`에 해당 버전 문자열이 있는지 | `CHANGELOG.md` 자체가 없으면 건너뜀 |
| working tree | `git status --porcelain`이 비어있는지 | — |

하나라도 실패하면 푸시를 **차단**한다(`exit 1`). 급하면 `git push --no-verify`로 우회
가능 — 훅은 안전장치일 뿐 강제가 아니다.

## 버전 올리기

**이 스크립트는 그 자리에서 커밋 + 태그 생성까지 한다.** 실행 전 사용자에게 어떤
버전으로 올릴지, 커밋/태그가 생긴다는 점을 확인받는다.

```bash
bash ~/.claude/skills/release-guard/scripts/bump-version.sh <새버전> ["변경 요약"]
# 예: bash ~/.claude/skills/release-guard/scripts/bump-version.sh 1.3.0 "- 로그인 버그 수정"
```

- 버전 파일을 갱신하고, `CHANGELOG.md` 맨 위에 새 항목을 추가하고, `release: vX.Y.Z`
  커밋을 만들고, `vX.Y.Z` annotated 태그를 단다.
- **푸시는 하지 않는다.** `git push && git push --tags`는 사용자가 직접 하거나 별도
  확인 후 진행한다.

### 새 버전 번호를 정하는 법

이 스크립트는 patch/minor/major를 판단하지 않는다 — 판단은 Claude가 한다:

```bash
git log $(git describe --tags --abbrev=0)..HEAD --oneline
```

이 커밋 로그를 보고 breaking change가 있으면 major, 새 기능이면 minor, 그 외엔 patch로
판단해 사용자에게 제안하고 확인받은 뒤 `bump-version.sh`를 호출한다.

## deploy-status와의 관계

- `release-guard`: 태그를 **푸시하기 전** 막는 안전장치
- `deploy-status`: 푸시 **후** 실제 배포(CI/CD)가 성공했는지 확인

순서상 release-guard → (통과) → 푸시 → deploy-status.

## 걷어내기

`.git/hooks/pre-push` 파일을 지운다(이 스킬이 설치한 껍데기인지는 `release-guard`
문자열 포함 여부로 확인). 다른 pre-push 훅과 합쳐놓은 경우엔 해당 줄만 지운다.
