#!/usr/bin/env bash
# npm registry의 메타데이터를 명시된 라이선스 정책과 대조한다. 법적 적합성 판정은 하지 않는다.
# 사용: check-license-risk.sh <pkg>@<version> [...]
#       check-license-risk.sh --scope major|all [staged|last]
set -euo pipefail
_DIR="${BASH_SOURCE[0]%/*}"
POLICY="${DEPENDENCY_LICENSE_POLICY:-}"
[ "$#" -eq 0 ] && exit 0
if [ "$1" = --scope ]; then
  if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "사용법: check-license-risk.sh --scope major|all [staged|last]" >&2
    exit 1
  fi
  specs=$(bash "$_DIR/diff-versions.sh" "${3:-staged}" --packages "$2")
  set --
  while IFS= read -r spec; do
    [ -z "$spec" ] || set -- "$@" "$spec"
  done <<< "$specs"
fi
command -v python3 >/dev/null 2>&1 || { echo "라이선스 정책 해석에 python3이 필요합니다." >&2; exit 1; }
# 정책 오류를 네트워크 조회 전에 드러낸다.
python3 - "$POLICY" <<'PY'
import json
import sys
if sys.argv[1]:
    with open(sys.argv[1]) as f:
        policy = json.load(f)
    if not isinstance(policy, dict) or set(policy) - {"allow", "review"}:
        sys.exit("라이선스 정책은 allow/review 목록만 받습니다.")
    for key in ("allow", "review"):
        if not isinstance(policy.get(key, []), list) or not all(isinstance(x, str) and x for x in policy.get(key, [])):
            sys.exit(f"라이선스 정책 {key}는 비어 있지 않은 문자열의 목록이어야 합니다.")
PY
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
for spec in "$@"; do
  name="${spec%@*}"
  version="${spec##*@}"
  if [ "$name" = "$spec" ] || [ -z "$name" ] || [ -z "$version" ]; then
    echo "  - ${spec}: 패키지@버전 형식 확인 필요"
    continue
  fi
  if ! curl -fsS --max-time 5 -o "$TMP" "https://registry.npmjs.org/${name}/${version}" 2>/dev/null; then
    echo "  - [정책 확인 필요] ${spec}: 조회 실패(라이선스 미확인)"
    continue
  fi
  python3 - "$spec" "$POLICY" "$TMP" <<'PY'
import fnmatch
import json
import re
import sys
spec, policy_path, response_path = sys.argv[1:]
# 초기 검토 목록. 프로젝트의 배포 방식과 의무를 대신 판단하지 않는다.
policy = {"allow": [], "review": ["GPL*", "AGPL*", "SSPL*", "CC-BY-NC*"]}
if policy_path:
    with open(policy_path) as f:
        policy = json.load(f)
try:
    with open(response_path) as f:
        license = json.load(f).get("license")
    if isinstance(license, dict):
        license = license.get("type")
    if not isinstance(license, str) or not license.strip():
        license = "(명시 안 됨)"
except (ValueError, AttributeError):
    license = "(응답 해석 실패)"
source = policy_path or "초기 검토 목록"
tokens = re.findall(r"[A-Za-z0-9][A-Za-z0-9.+:-]*", license)
review = any(fnmatch.fnmatchcase(value, pattern) for pattern in policy.get("review", []) for value in [license, *tokens])
if review:
    reason = "검토 목록 일치"
elif license in policy.get("allow", []):
    print(f"  - {spec}: 라이선스 {license} (허용 목록 일치; 정책: {source})")
    sys.exit(0)
else:
    reason = "허용 목록 미등재/메타데이터 확인 필요"
print(f"  - [정책 확인 필요] {spec}: 라이선스 {license} ({reason}; 정책: {source})")
PY
done
