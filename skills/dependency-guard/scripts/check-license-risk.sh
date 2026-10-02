#!/usr/bin/env bash
# npm 패키지의 라이선스를 registry API로 조회한다. 네트워크가 필요하다 — 실패하면
# 조용히 건너뛴다(커밋을 막지 않는다). npm 패키지만 지원한다(yarn/pnpm도 npm registry를
# 쓰므로 이름만 맞으면 동작하지만, pnpm-lock.yaml/yarn.lock 전용 레지스트리는 다룰 수 없음).
#
# 사용법: check-license-risk.sh <pkg>@<version> [pkg2@version2 ...]
set -u

[ "$#" -eq 0 ] && exit 0

RISKY='GPL|AGPL|SSPL|CC-BY-NC'

for spec in "$@"; do
  name="${spec%@*}"
  version="${spec##*@}"
  [ -z "$name" ] || [ -z "$version" ] && continue

  url="https://registry.npmjs.org/${name}/${version}"
  resp=$(curl -fsS --max-time 5 "$url" 2>/dev/null) || { echo "  - ${spec}: 조회 실패(네트워크/패키지 확인 불가, 건너뜀)"; continue; }

  license=$(echo "$resp" | grep -oE '"license"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"([^"]+)"$/\1/')
  [ -z "$license" ] && license="(명시 안 됨)"

  if echo "$license" | grep -qE "$RISKY"; then
    echo "  - [위험] ${spec}: 라이선스 ${license}"
  else
    echo "  - ${spec}: 라이선스 ${license}"
  fi
done
