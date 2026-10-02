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
import shutil
import subprocess
import sys
from pathlib import Path

JEV = Path.home() / ".claude/skills/jev-eval/scripts/jev.sh"
LABELS = ["fails", "partially_meets", "fully_meets"]
REGRESSION_DROP = 0.3   # 점수(0~2)가 이만큼 이상 떨어지면 회귀
AMBIGUOUS_DROP = 0.1    # 이 이상 떨어졌지만 회귀 기준 미만이면 확인 필요
LOW_CONFIDENCE = 0.5    # 채점 확신도가 이보다 낮으면 확인 필요
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
            cases.append(c)
    if not cases:
        sys.exit("[prompt-regression] cases.jsonl이 비어 있습니다.")
    return cases


def project_root(suite):
    r = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=suite,
                       capture_output=True, text=True)
    return Path(r.stdout.strip()) if r.returncode == 0 else suite.parent


def run_all(suite, cases, out_dir):
    cmd = (suite / "cmd").read_text(encoding="utf-8").strip()
    if not cmd:
        sys.exit("[prompt-regression] cmd 파일이 비어 있습니다.")
    root = project_root(suite)
    out_dir.mkdir(exist_ok=True)
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
    r = subprocess.run(["bash", str(JEV), state, questions], capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        err = r.stderr.strip()
        # 게이트웨이 에러 본문(JSON)이 길어서 message 한 줄만 남긴다.
        try:
            body = json.loads(err[err.index("{"):])
            err = body.get("error", {}).get("message") or err
        except ValueError:
            pass
        return None, None, err[:200]
    q = json.loads(r.stdout)["quality"]
    return float(q["score"]), float(q.get("confidence", 0)), None


def compare(suite, cases):
    base_dir, latest_dir = suite / "baseline", suite / "latest"
    if not base_dir.is_dir():
        sys.exit("[prompt-regression] 기준선이 없습니다. 프롬프트를 고치기 전에 snapshot을 먼저 실행하세요.")
    print("[prompt-regression] 새 출력 생성")
    run_all(suite, cases, latest_dir)

    print("\n[prompt-regression] 채점 (jev-eval, 0=fails ~ 2=fully_meets)")
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
        detail = f"기준선 {bs:.2f}(확신 {bc:.2f}) → 새 {ls:.2f}(확신 {lc:.2f}), 차이 {delta:+.2f}"
        if delta <= -REGRESSION_DROP:
            verdict = "회귀"
        elif delta <= -AMBIGUOUS_DROP or min(bc, lc) < LOW_CONFIDENCE:
            verdict = "확인 필요"
        else:
            verdict = "통과"
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

    if action == "accept":
        latest = suite / "latest"
        if not latest.is_dir():
            sys.exit("[prompt-regression] latest/가 없습니다. compare를 먼저 실행하세요.")
        shutil.rmtree(suite / "baseline", ignore_errors=True)
        shutil.copytree(latest, suite / "baseline")
        print("[prompt-regression] 최근 출력을 새 기준선으로 확정했습니다.")
        return

    cases = load_cases(suite)
    if action == "snapshot":
        print("[prompt-regression] 기준선 생성")
        shutil.rmtree(suite / "baseline", ignore_errors=True)
        failed = run_all(suite, cases, suite / "baseline")
        print(f"\n[prompt-regression] 기준선 {len(cases) - len(failed)}/{len(cases)}건 저장")
    else:
        compare(suite, cases)


if __name__ == "__main__":
    main()
