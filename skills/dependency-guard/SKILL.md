---
name: dependency-guard
description: "Use when package-lock.json, yarn.lock, or pnpm-lock.yaml changed and you need to judge whether the dependency updates are safe — \"의존성 변경 요약해줘\", \"이 lockfile 변경 안전해?\" — including updates made locally without Renovate/Dependabot."
---

# dependency-guard

lockfile diff를 사람이 눈으로 읽기 번거로운 걸 자동화한다. **버전 비교는 네트워크 없이
항상 돈다. 라이선스 조회만 네트워크가 필요하다. 기본은 major 변경만 선택적으로 조회하며,
옵션으로 patch/minor까지 조회한다.**

## 버전 변경 요약 (네트워크 없음)

```bash
bash ~/.claude/skills/dependency-guard/scripts/diff-versions.sh          # staged 기준 (기본)
bash ~/.claude/skills/dependency-guard/scripts/diff-versions.sh last     # 마지막 커밋 기준
```

- `package-lock.json`(v1/v2/v3 포맷 모두), `yarn.lock`, `pnpm-lock.yaml`을 지원한다.
- 신규 설치된 패키지(old 쪽에 없던 것)는 "변경"이 아니라 "추가"이므로 비교 대상에서 뺀다.
- major 버전(첫 번째 숫자)이 바뀐 패키지는 `[MAJOR]`로 강조해서 따로 모아 보여준다.

## 라이선스 정책 대조 (네트워크 필요, npm만)

**major 변경만 조회하는 것은 네트워크 호출을 줄이는 초기 기본값**이다. patch/minor에도
라이선스가 바뀔 수 있다. 저장소 정책과 요청에 따라 전체 변경 버전을 조회한다.

```bash
bash ~/.claude/skills/dependency-guard/scripts/check-license-risk.sh <pkg>@<새버전> [...]
bash ~/.claude/skills/dependency-guard/scripts/check-license-risk.sh --scope major staged
bash ~/.claude/skills/dependency-guard/scripts/check-license-risk.sh --scope all last
```

- npm registry(`registry.npmjs.org`)에서 라이선스 필드를 조회한다.
- 정책 JSON 해석에는 Python 3이 필요하다. 정책 형식 오류는 조회 전에 실패로 보고한다.
- `DEPENDENCY_LICENSE_POLICY=<JSON 경로>`로 `allow`(정확한 문자열), `review`(glob 패턴)
  목록을 지정한다. 예: `{"allow":["MIT"],"review":["GPL*","AGPL*"]}`. 저장소의 명시 정책이
  우선이다. 환경변수는 호출 시에만 주고 지속 규칙 설치는 별도 요청이 있어야 한다.
- 정책 미지정 시 초기 검토 목록은 `GPL*`/`AGPL*`/`SSPL*`/`CC-BY-NC*`, 허용 목록은 빈 값이다.
  검토 목록 일치가 우선이다. 미분류·누락·조회 실패도 `[정책 확인 필요]`로 이유를 표시한다.
  복합 SPDX 식은 정확히 허용한 식이 아니면 사람에게 넘긴다. 법적 적합성을 확정하지 않는다.
- 네트워크 실패는 미확인 상태로 남기고 다음 패키지를 조회한다. 실패를 위험으로 단정하지 않는다.
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
- **기본 조회 범위를 전체로 확대하지 않는다.** `--scope all`은 patch/minor를 포함한 변경
  버전 전체를 조회하는 명시 옵션이다. 신규 패키지는 기존 비교 범위 밖이므로 직접 지정한다.
