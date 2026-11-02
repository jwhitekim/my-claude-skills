#!/usr/bin/env bash
# 선언된 스크립트·타깃·도구 설정과 실행 파일을 확인한다. 추측한 명령은 출력하지 않는다.
set -euo pipefail
if ! command -v python3 >/dev/null 2>&1; then
  echo "[commit-and-push] 탐지에 python3이 필요합니다. 프로젝트 설정에서 직접 확인하세요." >&2
  exit 1
fi
python3 - <<'PY'
import configparser
import json
import re
import shutil
import sys
from pathlib import Path


def emit(command, executable, source):
    if shutil.which(executable):
        print(command)
        print(f"[commit-and-push] 근거: {source}", file=sys.stderr)
    else:
        print(f"[commit-and-push] {source}: {executable} 없음 — 실행 생략", file=sys.stderr)


pkg = Path("package.json")
if pkg.is_file():
    data = json.loads(pkg.read_text())
    manager = str(data.get("packageManager", "")).split("@", 1)[0]
    if manager not in ("npm", "pnpm", "yarn", "bun"):
        locks = [("pnpm-lock.yaml", "pnpm"), ("yarn.lock", "yarn"), ("bun.lock", "bun"),
                 ("bun.lockb", "bun"), ("package-lock.json", "npm")]
        managers = {m for f, m in locks if Path(f).is_file()}
        manager = next(iter(managers)) if len(managers) == 1 else "npm"
        if len(managers) > 1:
            print("[commit-and-push] lockfile이 여러 종류입니다. 패키지 매니저 기본값 npm을 확인하세요.", file=sys.stderr)
    for name in ("build", "test", "lint", "typecheck", "check"):
        if isinstance(data.get("scripts", {}).get(name), str) and data["scripts"][name].strip():
            emit(f"{manager} run {name}", manager, f"package.json scripts.{name}")

for filename in ("GNUmakefile", "makefile", "Makefile"):
    path = Path(filename)
    if not path.is_file():
        continue
    targets = set()
    for line in path.read_text().splitlines():
        match = re.match(r"^([\w .-]+)\s*:(?!=)", line)
        if match:
            targets.update(match.group(1).split())
    for name in ("build", "test", "lint", "typecheck", "check"):
        if name in targets:
            emit(f"make {name}", "make", f"{filename} target {name}")
    break

config = {}
if Path("pyproject.toml").is_file():
    try:
        import tomllib
    except ImportError:
        print("[commit-and-push] pyproject.toml 자동 해석은 Python 3.11+ 필요 — 직접 확인하세요.", file=sys.stderr)
    else:
        config = tomllib.loads(Path("pyproject.toml").read_text())

tool = config.get("tool", {})
project = config.get("project", {})
deps = list(project.get("dependencies", []))
for group in project.get("optional-dependencies", {}).values():
    deps.extend(group)
for group in config.get("dependency-groups", {}).values():
    deps.extend(item for item in group if isinstance(item, str))
poetry = tool.get("poetry", {})
deps.extend(poetry.get("dependencies", {}).keys())
deps.extend(poetry.get("dev-dependencies", {}).keys())
for group in poetry.get("group", {}).values():
    deps.extend(group.get("dependencies", {}).keys())
for path in Path(".").glob("*requirements*.txt"):
    deps.extend(line.split("#", 1)[0].strip() for line in path.read_text().splitlines())
dep_names = {re.split(r"[\s\[<>=!~;@]", item, 1)[0].lower().replace("_", "-") for item in deps}
ini = configparser.ConfigParser()
for filename in ("setup.cfg", "tox.ini", "pytest.ini"):
    if Path(filename).is_file():
        ini.read(filename)
pytest_tests = any(Path(".").glob("test_*.py")) or any(Path(".").glob("*_test.py")) or any(
    path.is_dir() and any(path.rglob("*.py")) for path in (Path("tests"), Path("test")))
checks = (
    ("pytest", "pytest -q", "pytest" in tool or any(ini.has_section(s) for s in ("pytest", "tool:pytest")) or pytest_tests),
    ("ruff", "ruff check .", "ruff" in tool or any(Path(f).is_file() for f in ("ruff.toml", ".ruff.toml"))),
    ("mypy", "mypy .", "mypy" in tool or any(ini.has_section(s) for s in ("mypy",)) or any(Path(f).is_file() for f in ("mypy.ini", ".mypy.ini"))),
)
for name, command, configured in checks:
    if configured or name in dep_names:
        emit(command, name, f"{name} 설정·의존 선언·테스트 파일")

for filename, executable, commands in (
    ("Cargo.toml", "cargo", ("cargo build", "cargo test")),
    ("go.mod", "go", ("go build ./...", "go vet ./...")),
):
    if Path(filename).is_file():
        for command in commands:
            emit(command, executable, filename)
PY
