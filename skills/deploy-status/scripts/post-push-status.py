"""push 뒤 같은 커밋의 모든 실행을 보고한다. 외부 Python 패키지는 쓰지 않는다."""
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import time


def report(message, error=False):
    print(f"[deploy-status] {message}", file=sys.stderr if error else sys.stdout, flush=True)


def is_push(command):
    # 따옴표 안의 문자열은 명령 경계로 보지 않는다(echo "git push" 등).
    lexer = shlex.shlex(command, posix=False, punctuation_chars=";&|\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    commands = [[]]
    try:
        for token in lexer:
            if token and all(char in ";&|\n" for char in token):
                commands.append([])
            else:
                commands[-1].append(shlex.split(token)[0])
    except ValueError:
        return False
    for args in commands:
        while args and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", args[0]):
            args = args[1:]
        if args[:2] == ["git", "push"]:
            return True
        if args and Path(args[0]).name in ("bash", "sh"):
            args = args[1:]
        if args and Path(args[0]).name == "safe-push.sh":
            return True
    return False


def has_environment(path):
    # YAML의 키만 찾고, 주석이나 run: | 등의 블록 문자열은 건너뛴다.
    block_indent = None
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())
        if block_indent is not None:
            if indent > block_indent:
                continue
            block_indent = None
        if re.match(r'''\s*(?:environment|'environment'|"environment")\s*:''', line):
            return True
        if re.search(r":\s*[|>][0-9+-]*\s*(?:#.*)?$", line):
            block_indent = indent
    return False


def deployment_reason(workflow, configured, environments):
    name, path = workflow["name"], workflow.get("path", "")
    if configured:
        matches = configured.intersection((name, path, Path(path).name))
        return "DEPLOY_STATUS_WORKFLOW=" + ",".join(sorted(matches)) if matches else ""
    reasons = []
    if path in environments:
        reasons.append(f"{path}에 environment: 키")
    if re.search(r"deploy|release|publish", name + " " + Path(path).name, re.I):
        reasons.append("이름·파일명에 deploy/release/publish 포함")
    return "; ".join(reasons)


def run_state(run):
    status = run.get("status") or "unknown"
    if status != "completed":
        return f"진행 중 ({status})"
    conclusion = run.get("conclusion") or "unknown"
    label = {"success": "성공", "failure": "실패", "cancelled": "취소"}.get(conclusion, "기타 결과")
    return f"{label} ({conclusion})"


def main():
    try:
        command = json.load(sys.stdin).get("tool_input", {}).get("command", "")
    except (ValueError, AttributeError):
        return 0
    if not isinstance(command, str) or not is_push(command):
        return 0
    directory = Path(".github/workflows")
    if not directory.is_dir():
        return 0
    if not shutil.which("gh"):
        report("gh CLI가 없어 배포 상태를 자동 확인할 수 없습니다.")
        return 0
    if subprocess.run(["gh", "auth", "status"], stdout=subprocess.DEVNULL,
                      stderr=subprocess.DEVNULL, timeout=15).returncode:
        report("gh 인증이 안 되어 있어 배포 상태를 자동 확인할 수 없습니다.")
        return 0
    commit = subprocess.run(["git", "rev-parse", "HEAD"], capture_output=True, text=True)
    if commit.returncode:
        return 0
    sha = commit.stdout.strip()
    # 기존 완료 대기 기본값 300초는 초기 경험값이다. 실행 생성 대기도 이 시간에 포함한다.
    try:
        wait_seconds = int(os.environ.get("DEPLOY_STATUS_WAIT_SECONDS", "300"))
        if wait_seconds < 0:
            raise ValueError
    except ValueError:
        report("DEPLOY_STATUS_WAIT_SECONDS는 0 이상의 정수여야 합니다. 기본값 300초를 씁니다.")
        wait_seconds = 300
    deadline = time.monotonic() + wait_seconds

    def gh_list(args):
        # gh의 기본 limit으로 실행이 누락되지 않도록 필요한 만큼 늘려 조회한다.
        limit = 100
        while True:
            result = subprocess.run(["gh", *args, "--limit", str(limit)],
                                    capture_output=True, text=True,
                                    timeout=max(1, deadline - time.monotonic()))
            if result.returncode:
                raise RuntimeError("gh 조회 실패 — 배포 결과를 확인할 수 없습니다.")
            rows = json.loads(result.stdout)
            if len(rows) < limit:
                return rows
            limit *= 2

    configured = {value.strip() for value in os.environ.get("DEPLOY_STATUS_WORKFLOW", "").split(",")
                  if value.strip()}
    environments = {path.as_posix() for pattern in ("*.yml", "*.yaml")
                    for path in directory.glob(pattern) if has_environment(path)}
    # 파일명 설정과 실행의 표시 이름이 달라도 같은 워크플로로 연결한다.
    workflows = gh_list(["workflow", "list", "--all", "--json", "id,name,path"])
    reasons = {w["id"]: deployment_reason(w, configured, environments) for w in workflows}
    announced = False
    while True:
        if announced and time.monotonic() >= deadline:
            break
        runs = gh_list(["run", "list", "--commit", sha, "--json",
                        "databaseId,name,workflowName,workflowDatabaseId,status,conclusion,event,headBranch,url"])
        grouped = {w["id"]: [] for w in workflows}
        for run in runs:
            workflow_id = run.get("workflowDatabaseId")
            if workflow_id not in grouped:
                # 삭제됐거나 목록에 없는 워크플로도 실행 결과를 숨기지 않는다.
                workflow_id = workflow_id or run.get("workflowName") or run["databaseId"]
                if workflow_id not in grouped:
                    workflow = {"id": workflow_id, "name": run.get("workflowName") or "이름 불명", "path": ""}
                    workflows.append(workflow)
                    reasons[workflow_id] = deployment_reason(workflow, configured, environments)
                    grouped[workflow_id] = []
            grouped[workflow_id].append(run)
        selected = {key for key, reason in reasons.items() if reason}
        watched = [run for key in selected for run in grouped[key]] if selected else runs
        missing = any(not grouped[key] for key in selected)
        pending = any(run.get("status") != "completed" for run in watched)
        if (watched and not pending and not missing) or time.monotonic() >= deadline:
            break
        if not announced:
            report(f"커밋 {sha}의 실행 확인 중. 최대 {wait_seconds}초 대기합니다...")
            announced = True
        time.sleep(min(15 if runs else 6, max(0, deadline - time.monotonic())))

    report(f"커밋 {sha}의 워크플로별 상태")
    if not selected:
        if configured:
            report("DEPLOY_STATUS_WORKFLOW와 일치하는 배포 워크플로를 특정하지 못함.")
        else:
            report("배포 워크플로를 특정하지 못함. 모든 실행 상태를 보여 줍니다.")
    failed = False
    for workflow in workflows:
        key = workflow["id"]
        reason = reasons[key]
        label = ("배포" if configured else "배포 후보") if reason else "일반 워크플로"
        details = f" (판정 근거: {reason})" if reason else ""
        if not grouped[key]:
            if reason:
                report(f"{label} {workflow['name']}: 실행 없음{details}")
            continue
        for run in grouped[key]:
            run_failed = reason and run.get("status") == "completed" and run.get("conclusion") == "failure"
            report(f"{label} {workflow['name']}: {run_state(run)}{details} "
                   f"[run {run['databaseId']}, event: {run.get('event', '')}, "
                   f"branch: {run.get('headBranch', '')}] {run.get('url', '')}", error=run_failed)
            if run_failed:
                failed = True
                report(f"deploy-status 스킬로 원인을 진단하십시오: gh run view {run['databaseId']} --log-failed", error=True)
    if not runs:
        report("워크플로 실행 없음(트리거 조건이 이 push와 안 맞을 수 있음).")
    if pending:
        report(f"{wait_seconds}초 대기 후에도 아직 진행 중. 나중에 deploy-status 스킬로 다시 확인하십시오.")
    return 2 if failed else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, ValueError, OSError, subprocess.TimeoutExpired) as error:
        report(f"상태 조회를 완료하지 못했습니다: {error}. 배포 성공·실패를 단정할 수 없습니다.")
        sys.exit(0)
