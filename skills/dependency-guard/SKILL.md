---
name: dependency-guard
description: lockfile(package-lock.json/yarn.lock/pnpm-lock.yaml)이 바뀐 커밋에서 어떤 패키지가 얼마나 바뀌었는지 요약하고, major 버전 업그레이드를 강조하고, 필요하면 npm 라이선스 변경도 확인한다. change-impact가 lockfile 변경을 감지하면 대신 호출한다. "의존성 변경 요약해줘", "이 lockfile 변경 안전해?" 같은 요청에도 수동으로 사용한다. Renovate/Dependabot 없이 로컬에서 직접 올린 의존성도 동일하게 다룬다(이 레포 사용자는 PR 워크플로를 안 씀).
---

# dependency-guard

lockfile diff를 사람이 눈으로 읽기 번거로운 걸 자동화한다. **버전 비교는 네트워크 없이
항상 돈다. 라이선스 조회만 네트워크가 필요하고, major 업그레이드가 있을 때만 선택적으로
돈다.**

## 버전 변경 요약 (네트워크 없음)

```bash
bash ~/.claude/skills/dependency-guard/scripts/diff-versions.sh          # staged 기준 (기본)
bash ~/.claude/skills/dependency-guard/scripts/diff-versions.sh last     # 마지막 커밋 기준
```

- `package-lock.json`(v1/v2/v3 포맷 모두), `yarn.lock`, `pnpm-lock.yaml`을 지원한다.
- 신규 설치된 패키지(old 쪽에 없던 것)는 "변경"이 아니라 "추가"이므로 비교 대상에서 뺀다.
- major 버전(첫 번째 숫자)이 바뀐 패키지는 `[MAJOR]`로 강조해서 따로 모아 보여준다.

## 라이선스 위험 확인 (네트워크 필요, npm만)

**major 업그레이드가 있을 때만** 호출을 검토한다 — 매 커밋마다 네트워크를 쓰면 느려지고
오프라인이면 실패하므로, 선택적으로만 돈다.

```bash
bash ~/.claude/skills/dependency-guard/scripts/check-license-risk.sh <pkg>@<새버전> [...]
```

- npm registry(`registry.npmjs.org`)에서 라이선스 필드를 조회한다.
- `GPL`/`AGPL`/`SSPL`/`CC-BY-NC` 계열이 나오면 `[위험]`으로 표시한다 — 그 외는 정보성으로만
  보여준다(라이선스 적합성 최종 판단은 Claude/사용자가 한다).
- 네트워크 실패나 조회 불가 패키지는 **조용히 건너뛴다** — 실패가 곧 "문제 있음"은 아니다.
- yarn.lock/pnpm-lock.yaml에서 뽑은 패키지도 이름만 npm registry에 있으면 동작한다.

## change-impact와의 연계

`change-impact`가 diff에 lockfile 변경이 있으면 `diff-versions.sh`를 대신 호출한다.
`[MAJOR]` 항목이 있으면 사용자에게 알리고, 원하면 `check-license-risk.sh`로 라이선스까지
확인한다. 정보 제공까지만 하고 아무것도 막지 않는다.

## 하지 않는 것

- **커밋/푸시를 막지 않는다.** 아무리 위험한 라이선스/major 업그레이드가 보여도 최종
  판단은 사용자에게 맡긴다.
- **CVE/보안 취약점 스캔은 하지 않는다.** 이건 버전·라이선스 변경 요약 스킬이다 — 보안
  스캔이 필요하면 `npm audit`/`pip-audit` 같은 전용 도구를 직접 쓴다.
- **라이선스 조회를 모든 패키지에 하지 않는다.** major 업그레이드가 아닌 patch/minor
  변경까지 네트워크를 쓰는 건 낭비라 하지 않는다.
