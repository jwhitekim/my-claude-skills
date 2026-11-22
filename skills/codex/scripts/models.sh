#!/usr/bin/env bash
# 이 계정에서 고를 수 있는 Codex 모델과 지원 추론 강도, 현재 기본값을 보여 준다.
# Codex CLI가 받아 둔 모델 목록 캐시(models_cache.json)를 읽으며, 네트워크 호출은 하지 않는다.
set -euo pipefail

CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
CACHE="$CODEX_DIR/models_cache.json"
CONFIG="$CODEX_DIR/config.toml"

if [ -f "$CONFIG" ]; then
  echo "[기본값] $(grep -E '^(model|model_reasoning_effort)[[:space:]]*=' "$CONFIG" | tr '\n' ' ')"
fi
if [ ! -s "$CACHE" ]; then
  echo "[codex] 모델 목록 캐시가 없습니다: $CACHE (Codex를 한 번 실행하면 생깁니다)" >&2
  exit 1
fi
python3 - "$CACHE" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
models = d.get("models", []) if isinstance(d, dict) else d
for m in models:
    if not isinstance(m, dict) or m.get("visibility") == "hide":
        continue
    levels = ",".join(l.get("effort", "") for l in m.get("supported_reasoning_levels", []))
    print(f"{m.get('slug')}\t[{levels}]\t{m.get('description', '')}")
PY
