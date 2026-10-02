# -*- coding: utf-8 -*-
"""OpenAPI/Swagger 스펙 두 버전(old, new)을 비교해 breaking change를 찾는다.

사용: compare-openapi.py <old파일> <new파일>
old파일이 비어있거나 없으면(신규 생성) 비교할 게 없어 조용히 끝낸다.

잡는 것:
- 삭제된 path+method (엔드포인트 제거)
- components.schemas.*의 required 배열에 새로 추가된 필드 (클라이언트가 안 보내면 깨짐)
- components.schemas.*에서 제거된 property
- property의 type이 바뀐 경우
- enum에서 제거된 값

안 잡는 것(의도적으로 보수적으로 둠 — 과한 오탐 방지):
- $ref로 간접 참조된 스키마까지 재귀적으로 추적하는 건 하지 않는다 (복잡도 대비 효용 낮음)
- 파라미터 자체의 required 변경은 스키마보다 흔한 패턴이라 별도로 확인한다(아래)
"""
import json
import sys


def load(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            text = f.read()
    except FileNotFoundError:
        return {}
    if not text.strip():
        return {}
    if path.endswith((".yaml", ".yml")):
        try:
            import yaml
        except ImportError:
            print(f"[api-contract-guard] PyYAML이 없어 {path}를 건너뜁니다 (pip install pyyaml)")
            return None
        try:
            return yaml.safe_load(text) or {}
        except Exception as e:
            print(f"[api-contract-guard] {path} 파싱 실패: {e}")
            return None
    else:
        try:
            return json.loads(text)
        except Exception as e:
            print(f"[api-contract-guard] {path} 파싱 실패: {e}")
            return None


def endpoints(spec):
    out = set()
    for path, methods in (spec.get("paths") or {}).items():
        if not isinstance(methods, dict):
            continue
        for method in methods:
            if method.lower() in ("get", "post", "put", "patch", "delete", "options", "head"):
                out.add((path, method.lower()))
    return out


def param_required_map(spec):
    """(path, method, param_name) -> required(bool)"""
    out = {}
    for path, methods in (spec.get("paths") or {}).items():
        if not isinstance(methods, dict):
            continue
        for method, op in methods.items():
            if method.lower() not in ("get", "post", "put", "patch", "delete"):
                continue
            if not isinstance(op, dict):
                continue
            for p in op.get("parameters") or []:
                if isinstance(p, dict) and "name" in p:
                    out[(path, method.lower(), p["name"])] = bool(p.get("required", False))
    return out


def schemas(spec):
    comps = spec.get("components") or {}
    return comps.get("schemas") or {}


def main():
    if len(sys.argv) != 3:
        print("사용법: compare-openapi.py <old> <new>")
        sys.exit(1)

    old = load(sys.argv[1])
    new = load(sys.argv[2])
    if old is None or new is None:
        return  # 파싱 실패, 이미 메시지 출력함
    if not old:
        return  # 신규 스펙, 비교 대상 없음

    issues = []

    old_eps = endpoints(old)
    new_eps = endpoints(new)
    for path, method in sorted(old_eps - new_eps):
        issues.append(f"엔드포인트 삭제: {method.upper()} {path}")

    old_params = param_required_map(old)
    new_params = param_required_map(new)
    for key, was_required in old_params.items():
        now_required = new_params.get(key)
        if now_required is True and was_required is False:
            path, method, name = key
            issues.append(f"파라미터가 새로 필수가 됨: {method.upper()} {path} / {name}")

    old_schemas = schemas(old)
    new_schemas = schemas(new)
    for name, old_schema in old_schemas.items():
        new_schema = new_schemas.get(name)
        if new_schema is None:
            issues.append(f"스키마 삭제: {name}")
            continue
        if not isinstance(old_schema, dict) or not isinstance(new_schema, dict):
            continue

        old_required = set(old_schema.get("required") or [])
        new_required = set(new_schema.get("required") or [])
        for field in new_required - old_required:
            issues.append(f"{name}: '{field}' 필드가 새로 required가 됨")

        old_props = old_schema.get("properties") or {}
        new_props = new_schema.get("properties") or {}
        for prop in old_props:
            if prop not in new_props:
                issues.append(f"{name}: '{prop}' 필드 삭제됨")
                continue
            old_type = old_props[prop].get("type") if isinstance(old_props[prop], dict) else None
            new_type = new_props[prop].get("type") if isinstance(new_props[prop], dict) else None
            if old_type and new_type and old_type != new_type:
                issues.append(f"{name}.{prop}: 타입 변경 {old_type} -> {new_type}")

            old_enum = set(old_props[prop].get("enum") or []) if isinstance(old_props[prop], dict) else set()
            new_enum = set(new_props[prop].get("enum") or []) if isinstance(new_props[prop], dict) else set()
            removed_enum = old_enum - new_enum
            if removed_enum:
                issues.append(f"{name}.{prop}: enum 값 제거됨 -> {sorted(removed_enum)}")

    if issues:
        print(f"[api-contract-guard] breaking change 가능성 {len(issues)}건")
        for i in issues:
            print(f"  - [BREAKING] {i}")


if __name__ == "__main__":
    main()
