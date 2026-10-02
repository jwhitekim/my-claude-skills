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
    try:
        data = json.loads(content)
    except ValueError:
        return
    packages = data.get("packages")
    if isinstance(packages, dict):
        for key, info in packages.items():
            if not key or "node_modules/" not in key:
                continue
            name = key.rsplit("node_modules/", 1)[-1]
            version = info.get("version") if isinstance(info, dict) else None
            if name and version:
                print(f"{name}\t{version}")
        return
    # package-lock.json v1 포맷 (dependencies 트리)
    deps = data.get("dependencies")
    if isinstance(deps, dict):
        for name, info in deps.items():
            version = info.get("version") if isinstance(info, dict) else None
            if name and version:
                print(f"{name}\t{version}")


def extract_yarn_lock(content):
    name = None
    for line in content.splitlines():
        if line and not line.startswith((" ", "\t", "#")) and line.endswith(":"):
            header = line[:-1]
            first_spec = header.split(",")[0].strip().strip('"')
            m = re.match(r"^(@?[^@]+(?:@[^@]+)?)@", first_spec)
            # scoped 패키지(@scope/name@range)와 일반 패키지(name@range) 모두 처리
            if first_spec.startswith("@"):
                m2 = re.match(r"^(@[^/]+/[^@]+)@", first_spec)
                name = m2.group(1) if m2 else None
            else:
                m2 = re.match(r"^([^@]+)@", first_spec)
                name = m2.group(1) if m2 else None
        elif name and line.strip().startswith("version "):
            version = line.strip().split(None, 1)[1].strip().strip('"')
            print(f"{name}\t{version}")
            name = None


def extract_pnpm_lock(content):
    # packages: 섹션의 키가 "/name@version:" 또는 "name@version:" 형태.
    pattern = re.compile(r"^\s*/?(@?[^\s@][^@]*@[^@]*?)\((.*)\)?:$")
    simple = re.compile(r"^\s*/?(@[^/]+/[^@]+|[^@/][^@]*)@([0-9][^:()]*?)(\(.*\))?:$")
    for line in content.splitlines():
        m = simple.match(line)
        if m:
            name, version = m.group(1), m.group(2)
            print(f"{name}\t{version}")


def main():
    if len(sys.argv) < 2:
        return
    filename = sys.argv[1]
    content = sys.stdin.read()
    if filename == "package-lock.json":
        extract_package_lock(content)
    elif filename == "yarn.lock":
        extract_yarn_lock(content)
    elif filename == "pnpm-lock.yaml":
        extract_pnpm_lock(content)


if __name__ == "__main__":
    main()
