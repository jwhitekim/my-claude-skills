---
name: deploy-status
description: "Use right after pushing to a project with a GitHub Actions deployment pipeline to check deployment status or diagnose failures, or when asked to write a postmortem after an outage, failed deployment, or production incident — \"배포 상태 확인해줘\", \"배포 잘 됐나 확인\", \"방금 푸시한 거 배포 성공했어?\", \"장애 회고 써줘\", \"아까 배포 터진 거 정리해줘\", \"incident review\"."
---

# deploy-status

`git push`가 GitHub Actions 배포를 트리거하는 프로젝트에서, 배포가 끝날 때까지 사람이
Actions 탭을 직접 열어보지 않아도 되게 한다. `gh` CLI로 확인하고, 실패 시 로그를 읽어
원인을 진단한다. 장애·배포 실패 회고를 요청받으면 커밋·Actions 실행·실패 로그를 모아
회고 문서를 작성한다.

## 전제조건

아래는 배포 상태 확인·실패 진단의 전제조건이다. 장애 회고 작성은 `gh`나 GitHub 원격,
워크플로가 없어도 확보한 커밋·사용자 제공 로그로 진행하고, 빠진 근거를 밝힌다.

- `gh` CLI가 설치되어 있고 인증돼 있어야 한다 (`gh auth status`로 확인, 안 돼 있으면
  사람에게 `gh auth login`을 직접 실행하라고 안내 — 로그인은 사람이 한다).
- 프로젝트에 `.github/workflows/*.yml` 또는 `*.yaml`이 있어야 한다. 없으면 배포 상태 확인 대상이 아니다.

## 절차

배포 상태 확인·실패 진단은 1~4를 따른다. 회고 요청은 아래 **장애 회고 작성** 하위 절차를 따른다.

1. **워크플로 실행 찾기**

   ```bash
   gh run list --commit "$(git rev-parse HEAD)" --limit 100 \
     --json databaseId,name,workflowName,workflowDatabaseId,status,conclusion,event,headBranch,url
   ```

   대상 커밋 SHA의 실행을 모두 가져와 워크플로별로 본다. 반환 수가 limit에 닿으면
   limit을 늘려 다시 조회한다. 최신 실행 하나나 같은 SHA의 첫 실행만 고르지 않는다.
   아직 안 떴으면 잠시 후 다시 조회한다 — 짧은 폴링 간격(몇십 초)으로 몇 차례 재시도하고,
   그래도 안 뜨면 워크플로 트리거 조건(브랜치, 경로 필터 등)이 이 푸시와 안 맞는 건 아닌지
   `.github/workflows/*.yml`의 `on:` 조건을 확인한다.

   `DEPLOY_STATUS_WORKFLOW`가 있으면 이름 또는 파일명으로 일치하는 것만 배포로 본다
   (쉼표로 여러 개 지정). 파일명은 `gh workflow list --all --json id,name,path`로
   `workflowDatabaseId`와 연결한다. 이 목록도 limit에 닿으면 늘려 조회한다.
   지정이 없으면 워크플로 파일(`*.yml`, `*.yaml`)에 `environment:` 키가 있거나,
   이름·파일명에 deploy/release/publish가 들어간 것을 **배포 후보**로 표시하고 근거를
   출력한다. 후보가 없으면 "배포 워크플로를 특정하지 못함"을 알리고 모든 실행 상태를
   보여 준다. CI 성공만으로 배포 성공을 단정하지 않는다.

2. **완료까지 대기**

   ```bash
   gh run watch <배포-run-id> --exit-status
   ```

   배포는 보통 몇 분 걸린다. 오래 걸리는 작업이므로, 대화 흐름상 즉시 응답이 필요하면
   백그라운드로 돌리고 완료 후 보고하는 방식을 쓴다(에이전트 환경이면 `run_in_background`).
   배포로 지정된 워크플로 또는 배포 후보의 실행을 각각 확인한다.
   자동 훅은 `DEPLOY_STATUS_WAIT_SECONDS`(0 이상의 정수, 기본 300초) 동안 동기 대기한다.
   실행 생성 대기도 이 제한에 포함하며, 시간이 지나도 끝나지 않으면 "아직 진행 중"으로
   종료한다. 대기 시간 초과를 실패로 처리하지 않는다.

3. **결과 보고**

   워크플로별로 배포 지정·후보와 그 외 실행을 구분하고, 후보의 결과를 전체 배포 결과로
   단정하지 않는다. 같은 워크플로에 실행이 여러 개면 모두 보여 준다.

   - **성공(`conclusion: success`)**: 워크플로 이름, 소요 시간, 실행 URL, 배포 대상(있다면 URL)을
     간단히 보고한다.
   - **실패(`conclusion: failure`)**: 해당 배포 워크플로의 다음 단계로 진행한다.
   - **취소(`conclusion: cancelled`)**: 실패와 구분해서 알린다.
   - **진행 중(`status: in_progress`·`queued` 등)**: 현재 상태를 그대로 알린다.
   - **실행 없음**: 트리거 조건이 맞지 않을 수 있음을 알린다. 성공·실패로 단정하지 않는다.
   - 그 밖의 결론(`skipped`, `neutral`, `timed_out` 등)은 원래 값을 보여 준다.

4. **실패 시 진단**

   ```bash
   gh run view <run-id> --log-failed
   ```

   실패한 job/step의 로그만 뽑아서 읽는다. 전체 로그를 다 훑지 않는다 — 실패 지점만 보면
   대개 원인(빌드 에러, 테스트 실패, 환경변수 누락, 권한 문제 등)이 드러난다.

   원인을 특정했으면:
   - 코드/설정의 문제면 수정안을 제시하고, 사람이 동의하면 고친 뒤 `commit-and-push`
     스킬로 다시 커밋·푸시한다.
   - 워크플로 자체의 설정 문제(시크릿 누락, 잘못된 스텝 순서 등)면 `.github/workflows/`
     수정도 같은 방식(수정안 제시 → 승인 → 커밋)으로 처리한다.
   - 원인이 이 저장소 밖(예: 배포 대상 인프라, 외부 서비스 장애)이면 로그 근거와 함께
     사람에게 보고하고 직접 처리하도록 안내한다 — 인프라 설정은 이 스킬의 범위 밖이다.

### 장애 회고 작성

회고를 요청받으면 [장애 회고 작성 절차와 문서 양식](incident.md)을 읽고 따른다.
장애 시각과 증상을 확인하고 `scripts/incident/collect.sh`로 재료를 모은 뒤,
`docs/incidents/YYYY-MM-DD-<짧은-영문-제목>.md`에 저장한다.
수집 스크립트의 오류 메시지는 `[deploy-status:incident]` 표지를 사용한다.
로그·커밋으로 확인한 사실과 추측을 구분하고, 사람을 탓하지 않으며 실행 가능한 액션 아이템을 쓴다.
회고 작성 중 장애 수정은 별도로 진행한다.

## 하지 않는 것

- 실패 원인 파악 없이 재실행(`gh run rerun`)부터 하지 않는다 — 재시도로 우연히 통과하면
  진짜 원인을 놓친다. 일시적 인프라 문제로 확실히 판단될 때만 재실행을 제안한다.
- 워크플로 시크릿 값이나 배포 자격증명을 로그에서 읽어 노출하지 않는다.
- 사람 승인 없이 워크플로 파일이나 코드를 고쳐서 바로 커밋하지 않는다.

## 관련 스킬

- 푸시 자체는 `commit-and-push` 스킬이 담당하고, 이 스킬은 그 다음 단계(배포 확인)를 잇는다.
