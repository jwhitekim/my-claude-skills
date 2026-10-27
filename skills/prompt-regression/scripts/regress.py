# -*- coding: utf-8 -*-
"""프롬프트 변경 전후 출력을 기준선(baseline)과 비교해 회귀를 찾는다.

사용: regress.py <묶음 폴더> snapshot|compare|accept

묶음 폴더 구성:
  cases.jsonl  케이스마다 {"id": "...", "input": "...", "criteria": "..."}
  cmd          입력을 stdin으로 받아 출력을 stdout으로 내는 실행 명령 한 줄
               (프로젝트 루트에서 실행된다)
  baseline/    snapshot/accept가 만든 기준선 출력 (<id>.txt)
  latest/      compare가 만든 최근 출력 (<id>.txt)
"""
import json
import math
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

JEV = Path.home() / ".claude/skills/jev-eval/scripts/jev.sh"
LABELS = ["fails", "partially_meets", "fully_meets"]


def threshold(name, default, upper):
    value = float(os.environ.get(name, default))
    if not math.isfinite(value) or not 0 <= value <= upper:
        raise ValueError(f"{name}은 0~{upper}의 유한한 수여야 합니다.")
    return value


# 기본값은 초기 경험값이다. 모델 점수는 측정된 품질이 아닌 모델 추정치다.
REGRESSION_DROP = threshold("PROMPT_REGRESSION_DROP", 0.3, 2)
AMBIGUOUS_DROP = threshold("PROMPT_AMBIGUOUS_DROP", 0.1, 2)
LOW_CONFIDENCE = threshold("PROMPT_LOW_CONFIDENCE", 0.5, 1)
BOUNDARY_MARGIN = threshold("PROMPT_BOUNDARY_MARGIN", 0.02, 1)
if AMBIGUOUS_DROP >= REGRESSION_DROP:
    raise ValueError("PROMPT_AMBIGUOUS_DROP은 PROMPT_REGRESSION_DROP보다 작아야 합니다.")
RUN_TIMEOUT = 180


def load_cases(suite):
    cases = []
    with open(suite / "cases.jsonl", encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            c = json.loads(line)
            for key in ("id", "input", "criteria"):
                if key not in c:
                    sys.exit(f"[prompt-regression] cases.jsonl {n}번째 줄에 '{key}'가 없습니다.")
            if not all(isinstance(c[key], str) for key in ("id", "input", "criteria")):
                sys.exit(f"[prompt-regression] {n}번째 줄의 id/input/criteria는 문자열이어야 합니다.")
            if not re.fullmatch(r"[\w.-]+", c["id"]) or c["id"] in (".", ".."):
                sys.exit(f"[prompt-regression] 안전하지 않은 케이스 id: {c['id']!r}")
            if any(old["id"] == c["id"] for old in cases):
                sys.exit(f"[prompt-regression] 중복 케이스 id: {c['id']}")
            cases.append(c)
    if not cases:
        sys.exit("[prompt-regression] cases.jsonl이 비어 있습니다.")
    return cases


def project_root(suite):
    r = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=suite,
                       capture_output=True, text=True)
    return Path(r.stdout.strip()) if r.returncode == 0 else suite.parent


def run_all(suite, cases, out_dir):
    # 실패한 케이스에 이전 실행의 출력이 남지 않게 실행 전에 초기화한다.
    if out_dir.is_symlink():
        sys.exit(f"[prompt-regression] 출력 폴더가 심볼릭 링크입니다: {out_dir}")
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir()
    cmd = (suite / "cmd").read_text(encoding="utf-8").strip()
    if not cmd:
        sys.exit("[prompt-regression] cmd 파일이 비어 있습니다.")
    root = project_root(suite)
    failed = []
    for c in cases:
        try:
            r = subprocess.run(cmd, shell=True, cwd=root, input=c["input"],
                               capture_output=True, text=True, timeout=RUN_TIMEOUT)
        except subprocess.TimeoutExpired:
            failed.append((c["id"], f"{RUN_TIMEOUT}초 초과"))
            continue
        if r.returncode != 0:
            failed.append((c["id"], r.stderr.strip().splitlines()[-1:] or ["exit " + str(r.returncode)]))
            continue
        (out_dir / f'{c["id"]}.txt').write_text(r.stdout, encoding="utf-8")
        print(f'  - {c["id"]}: 실행 완료')
    for cid, err in failed:
        print(f"  - {cid}: 실행 실패 — {err}")
    return failed


def score(case, output):
    state = json.dumps({"input": case["input"], "criteria": case["criteria"], "output": output},
                       ensure_ascii=False)
    questions = json.dumps({"quality": {
        "type": "score",
        "instructions": "How well does the output satisfy the criteria for this input?",
        "criteria": LABELS,
    }})
    try:
        r = subprocess.run(["bash", str(JEV), state, questions], capture_output=True, text=True, timeout=60)
    except (subprocess.TimeoutExpired, OSError) as exc:
        return None, None, str(exc)[:200]
    if r.returncode != 0:
        err = r.stderr.strip()
        # 게이트웨이 에러 본문(JSON)이 길어서 message 한 줄만 남긴다.
        try:
            body = json.loads(err[err.index("{"):])
            err = body.get("error", {}).get("message") or err
        except ValueError:
            pass
        return None, None, err[:200]
    try:
        q = json.loads(r.stdout)["quality"]
        value, confidence = float(q["score"]), float(q.get("confidence", 0))
        if not (math.isfinite(value) and 0 <= value <= 2 and
                math.isfinite(confidence) and 0 <= confidence <= 1):
            raise ValueError("점수/확신도 범위 오류")
        return value, confidence, None
    except (ValueError, KeyError, TypeError) as exc:
        return None, None, f"채점 응답 오류: {exc}"


def verdict_for(bs, bc, ls, lc):
    drop = bs - ls
    # 저확신과 경계값을 먼저 처리한다. 큰 점수 하락도 이를 덮어쓰지 않는다.
    if min(bc, lc) <= LOW_CONFIDENCE + BOUNDARY_MARGIN:
        return "확인 필요"
    if any(abs(drop - cut) <= BOUNDARY_MARGIN + 1e-9
           for cut in (AMBIGUOUS_DROP, REGRESSION_DROP)):
        return "확인 필요"
    if drop > REGRESSION_DROP:
        return "회귀"
    if drop >= AMBIGUOUS_DROP:
        return "확인 필요"
    return "통과"


def compare(suite, cases):
    base_dir, latest_dir = suite / "baseline", suite / "latest"
    if not base_dir.is_dir():
        sys.exit("[prompt-regression] 기준선이 없습니다. 프롬프트를 고치기 전에 snapshot을 먼저 실행하세요.")
    print("[prompt-regression] 새 출력 생성")
    run_all(suite, cases, latest_dir)

    print("\n[prompt-regression] 모델 추정치 (jev-eval, 0=fails ~ 2=fully_meets)")
    print(f"  설정: 회귀 하락 {REGRESSION_DROP}, 확인 하락 {AMBIGUOUS_DROP}, "
          f"최소 확신 {LOW_CONFIDENCE}, 경계 폭 ±{BOUNDARY_MARGIN}")
    rows = []
    for c in cases:
        b, l = base_dir / f'{c["id"]}.txt', latest_dir / f'{c["id"]}.txt'
        if not b.exists() or not l.exists():
            rows.append((c["id"], "확인 필요", "기준선 또는 새 출력 없음"))
            continue
        base_text, latest_text = b.read_text(encoding="utf-8"), l.read_text(encoding="utf-8")
        if base_text == latest_text:
            rows.append((c["id"], "통과", "기준선과 출력이 같음 (채점 생략)"))
            continue
        bs, bc, berr = score(c, base_text)
        ls, lc, lerr = score(c, latest_text)
        if berr or lerr:
            rows.append((c["id"], "확인 필요", f"채점 실패: {berr or lerr}"))
            continue
        delta = ls - bs
        detail = f"모델 추정치: 기준선 {bs:.2f}(확신 {bc:.2f}) → 새 {ls:.2f}(확신 {lc:.2f}), 차이 {delta:+.2f}"
        verdict = verdict_for(bs, bc, ls, lc)
        rows.append((c["id"], verdict, detail))

    for cid, verdict, detail in rows:
        print(f"  - [{verdict}] {cid}: {detail}")
    counts = {v: sum(1 for _, x, _ in rows if x == v) for v in ("회귀", "확인 필요", "통과")}
    print(f"\n[prompt-regression] 회귀 {counts['회귀']} / 확인 필요 {counts['확인 필요']} / 통과 {counts['통과']}")
    if counts["회귀"] or counts["확인 필요"]:
        print(f"  출력 비교: {base_dir}/<id>.txt vs {latest_dir}/<id>.txt")


def main():
    if len(sys.argv) != 3 or sys.argv[2] not in ("snapshot", "compare", "accept"):
        sys.exit("사용법: regress.py <묶음 폴더> snapshot|compare|accept")
    suite = Path(sys.argv[1]).resolve()
    action = sys.argv[2]
    cases = load_cases(suite)

    if action == "accept":
        latest = suite / "latest"
        if not latest.is_dir():
            sys.exit("[prompt-regression] latest/가 없습니다. compare를 먼저 실행하세요.")
        if any(not (latest / f'{c["id"]}.txt').is_file() for c in cases):
            sys.exit("[prompt-regression] 새 출력이 불완전합니다. 실패를 해결하고 compare를 다시 실행하세요.")
        shutil.rmtree(suite / "baseline", ignore_errors=True)
        shutil.copytree(latest, suite / "baseline")
        print("[prompt-regression] 최근 출력을 새 기준선으로 확정했습니다.")
        return

    if action == "snapshot":
        print("[prompt-regression] 기준선 생성")
        failed = run_all(suite, cases, suite / "baseline")
        print(f"\n[prompt-regression] 기준선 {len(cases) - len(failed)}/{len(cases)}건 저장")
        if failed:
            sys.exit(1)
    else:
        compare(suite, cases)


if __name__ == "__main__":
    main()
