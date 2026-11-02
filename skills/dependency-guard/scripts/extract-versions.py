# -*- coding: utf-8 -*-
"""lockfile 내용(stdin)에서 "이름<TAB>버전" 목록을 뽑는다. 최상위 의존성/중첩 구분 없이
전부 뽑는다 — 중복 이름은 여러 버전이 섞여 있을 수 있어 호출 쪽에서 set으로 처리한다.

사용: extract-versions.py <package-lock.json|yarn.lock|pnpm-lock.yaml>  (파일명으로 타입 판단)
      내용은 stdin으로 받는다.
"""
import json
import re
import sys


def extract_package_lock(content):
    data = json.loads(content)
    if not isinstance(data, dict) or data.get("lockfileVersion", 1) not in (1, 2, 3):
        raise ValueError("지원하지 않는 npm lockfile 형식")
    out = []
    packages = data.get("packages")
    if isinstance(packages, dict):
        for key, info in packages.items():
            if not key or "node_modules/" not in key:
                continue
            name = key.rsplit("node_modules/", 1)[-1]
            version = info.get("version") if isinstance(info, dict) else None
            if name and version:
                out.append((name, version))
        return out
    # package-lock.json v1 포맷 (dependencies 트리)
    def walk(deps):
        for name, info in deps.items():
            version = info.get("version") if isinstance(info, dict) else None
            if name and version:
                out.append((name, version))
            if isinstance(info, dict) and isinstance(info.get("dependencies"), dict):
                walk(info["dependencies"])

    # 의존성이 없는 v1 lockfile은 dependencies 자체를 생략하기도 한다.
    deps = data.get("dependencies", {} if data.get("lockfileVersion") == 1 else None)
    if not isinstance(deps, dict):
        raise ValueError("npm packages/dependencies를 찾을 수 없음")
    walk(deps)
    return out


def extract_yarn_lock(content):
    name = None
    out = []
    for line in content.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if not line.startswith((" ", "\t")):
            if name:
                raise ValueError(f"Yarn 패키지 버전을 찾을 수 없음: {name}")
            if not line.endswith(":"):
                raise ValueError("지원하지 않는 Yarn lockfile 형식")
            header = line[:-1]
            if header == "__metadata":
                continue
            first_spec = header.split(",")[0].strip().strip('"')
            # scoped 패키지(@scope/name@range)와 일반 패키지(name@range) 모두 처리
            if first_spec.startswith("@"):
                m2 = re.match(r"^(@[^/]+/[^@]+)@", first_spec)
                name = m2.group(1) if m2 else None
            else:
                m2 = re.match(r"^([^@]+)@", first_spec)
                name = m2.group(1) if m2 else None
            if not name:
                raise ValueError(f"지원하지 않는 Yarn 패키지 키: {header}")
        elif name:
            version = re.match(r"^\s+version(?::\s*|\s+)[\"']?([^\s\"']+)", line)
            if version:
                out.append((name, version.group(1)))
                name = None
    if name:
        raise ValueError(f"Yarn 패키지 버전을 찾을 수 없음: {name}")
    if not out and any(line.strip() and not line.lstrip().startswith("#") for line in content.splitlines()):
        # 의존성이 없는 Berry lockfile에는 __metadata만 있다.
        if "__metadata:" not in content.splitlines():
            raise ValueError("지원하지 않는 Yarn lockfile 형식")
    return out


def extract_pnpm_lock(content):
    # pnpm 5의 /name/version, 6/9의 /name@version 또는 name@version.
    simple = re.compile(r"^/?(@[^/]+/[^@/]+|[^@/][^@/]*?)[@/]([0-9][^:()_]*)(?:[(_].*)?$")
    out = []
    in_packages = False
    recognized = False
    for line in content.splitlines():
        if line and not line.startswith((" ", "\t", "#")):
            in_packages = line.strip() == "packages:"
            if line.startswith("lockfileVersion:") or line.strip() in ("packages:", "packages: {}"):
                recognized = True
            if line.startswith("packages:") and line.strip() not in ("packages:", "packages: {}"):
                raise ValueError("지원하지 않는 pnpm packages 형식")
        if in_packages and re.match(r"^  [^\s#]", line):
            entry = re.fullmatch(r"  (.+):\s*(?:\{\s*\})?", line)
            if not entry:
                raise ValueError(f"지원하지 않는 pnpm 패키지 항목: {line.strip()}")
            key = entry.group(1).strip("\"'")
            m = simple.fullmatch(key)
            if not m:
                raise ValueError(f"지원하지 않는 pnpm 패키지 키: {key}")
            out.append((m.group(1), m.group(2)))
    if not recognized:
        raise ValueError("지원하지 않는 pnpm lockfile 형식")
    return out


def main():
    if len(sys.argv) < 2:
        return
    filename = sys.argv[1]
    content = sys.stdin.read()
    if not content.strip():
        return
    extractors = {
        "package-lock.json": extract_package_lock,
        "yarn.lock": extract_yarn_lock,
        "pnpm-lock.yaml": extract_pnpm_lock,
    }
    try:
        if filename not in extractors:
            raise ValueError("지원하지 않는 lockfile 형식")
        versions = extractors[filename](content)
    except ValueError as e:
        print(f"[dependency-guard] 경고: {filename} 해석 실패: {e}", file=sys.stderr)
        sys.exit(1)
    for name, version in versions:
        print(f"{name}\t{version}")


if __name__ == "__main__":
    main()
