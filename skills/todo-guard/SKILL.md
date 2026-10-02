---
name: todo-guard
description: 별칭 "투두가드" — 사용자가 이 별칭으로 부르면 이 스킬(todo-guard)을 뜻한다. TODO.md 기반 작업 추적과 Stop hook 검증을 세팅해 지시를 드랍하지 않게 만든다. 다음 상황에서 사용할 것 - 사용자가 "todo-guard"·"투두가드"를 지목해 세팅을 요청할 때, 작업 누락 방지 체계 구축을 요청할 때, "앞으로 ~하지 마"·"항상 ~해"처럼 항상 지킬 규칙을 말할 때, "투두가드 세팅 지워줘"·"투두가드 걷어내줘"·"투두가드 빼줘"처럼 세팅 제거를 요청할 때, "투두가드 세팅된 프로젝트 훑어줘"처럼 점검을 요청할 때. TODO.md 가 있는 프로젝트에서 작업할 때는 이 스킬의 운영 규칙을 따를 것. 문서 문체 검사(슬라이드 · 보고서 검수)는 이 스킬이 하지 않는다 - 글검수(geulgeomsu) 스킬이 한다.
---

# todo-guard (투두가드)

TODO.md를 단일 진실 소스로 사용하는 작업 누락 방지 체계. **지시는 훅이 받는 순간 TODO.md 에 적고**,
미완료 항목(`- [ ]`)이 남으면 턴 종료를 막는다. Claude 는 TODO.md 를 열지 않고 번호로 완료만 알린다.

이 스킬은 `~/.claude/skills/todo-guard/`에 전역 설치되어 있고, 번들 스크립트는 `~/.claude/skills/todo-guard/scripts/`에 있다.

상황 판단:

| 상황 | 수행할 섹션 |
|---|---|
| 사용자가 todo-guard를 지목해 이 프로젝트/세션에 세팅 요청 | A. 프로젝트 로컬 세팅 |
| TODO.md + .claude/hooks/check-todo.sh가 이미 있는 프로젝트에서 작업 중 | B. 운영 규칙 준수 |

---

## A. 프로젝트 로컬 세팅

「투두가드로 이 프로젝트 세팅해줘」를 받으면 **아래 한 줄을 실행한다.**
단계를 손으로 따라 하지 않는다. 빠뜨리는 항목이 생긴다.

```bash
bash ~/.claude/skills/todo-guard/scripts/setup.sh
```

### 장부 정리는 훅이 한다

Claude 가 TODO.md 를 Read · Edit 하면 도구 호출 한 번이 대화 전체를 다시 읽는다.
긴 세션에서는 한 번에 50만 토큰이다. 예전 방식(모델이 직접 등록 · 완료 표시)은 지시 하나에
3~8회를 불렀고, 실제 세션에서 투두가드 몫이 토큰의 9~12% 였다.
훅은 모델 밖에서 돌아 토큰을 쓰지 않는다. 그래서 장부 정리를 훅으로 옮겼다.

```
지시 받음   → prompt-mark 훅이 「- [ ] #14 지시 첫머리」 를 적고 번호를 알린다
              「1. 2. 3.」 번호 매긴 지시는 #14.1 #14.2 … 로 항목마다 적는다
작업        → pre-tool 훅이 TODO.md 이력 삭제 · 프로젝트 밖 편집을 막는다
완료        → Claude 가 마지막 확인 명령 뒤에 && todo.sh done 14 를 붙인다 (추가 호출 없음)
턴 종료     → check-todo 훅이 파일을 안 바꾼 질문 · 의견의 등록을 지우고, - [ ] 가 남았으면 막는다
              남은 게 줄어드는 동안은 계속 막고, 진전이 없으면 풀어 주며 남은 항목을 화면에 띄운다
```

| | 어떻게 되나 |
|---|---|
| 질문 · 의견 | 일단 적히고, 파일을 바꾸지 않은 채 턴이 끝나면 훅이 지운다 |
| 지시 (애매하면 지시로 본다) | 적힌 채 남는다. 하겠다고만 하고 끝내도 지워지지 않는다. 끝나면 done |
| 「응」 「진행해」 「계속」 | 새 지시가 아니다. 적지 않는다 |
| 배경 알림(`<task-notification>`) | 지시가 아니다. 적지 않는다 |

훅이 보는 도구는 **Write · Edit · NotebookEdit · Bash · PowerShell** 이다.
셸 명령은 따옴표를 가려 토막 내고, 명령마다 쓰기 대상을 뽑는다 (`>` · `cp` · `mv` · `rm` · `sed -i` ·
`Set-Content` · `Copy-Item` …). 읽기 명령(`ls` `grep` `git status` `git config user.name` `python -c "print()"` …)은
파일을 바꾸는 작업으로 보지 않는다.

### setup.sh 가 하는 일

| # | 하는 일 | 결과 |
|---|---|---|
| 1 | 전역 `~/.claude/CLAUDE.md` 에 「세션 밖 폴더」 규칙 확인 | 없으면 넣음 (있으면 안 건드림) |
| 1-1 | 윈도우만: bash.exe 속도 점검 (`pick-shell.py`) | bash.exe · sh.exe 를 재서 bash.exe 만 0.3초 넘게 느리면 알린다. **셸은 바꾸지 않는다.** 옛 판이 넣어 둔 `env.CLAUDE_CODE_GIT_BASH_PATH` = sh.exe 설정이 있으면 걷어낸다 |
| 2 | `TODO.md` 생성 | 항상 지킬 것 / 진행 중 / 완료 / 보류 |
| 3 | 훅 4개 등록 | `.claude/hooks/` 에 **껍데기** (본체를 불러오기만 함) |
| 4 | `.claude/settings.json` 에 훅 등록 | SessionStart · UserPromptSubmit · PreToolUse(Write·Edit·NotebookEdit·Bash·PowerShell) · Stop. 윈도우는 `. "…"` 꼴(bash 를 한 번 덜 띄운다) |
| 5 | 프로젝트 `CLAUDE.md` 에 운영 규칙 | 없으면 넣고, 옛 판이면 그 대목만 v6 로 바꾼다 (백업은 `.claude/`) |
| 6 | `투두가드설명서.md` | 없으면 만들고, 옛 판이면 새로 쓴다 |

운영 규칙 원본은 `rules/claude-md-block.md` 한 벌이다. 고치면 `doctor.sh --fix` 로 세팅한 곳에 퍼진다.

옛 세팅의 문서 검사 훅(`doc-check.sh`)이 있으면 걷어낸다. 문서 검사는 글검수 스킬로 옮겼다.

`settings.json` 은 통째로 다시 쓰지 않는다. 이 스킬이 넣은 훅만 갈아끼우고
`permissions` 같은 다른 키와 남이 걸어 둔 훅은 그대로 둔다.

### 항상 지킬 것 - TODO.md 맨 위

사용자가 한 번 말한 금지·필수 사항이 몇 턴 지나면 잊힌다. 그래서 TODO.md 맨 위에 두고,
세션 시작과 턴 종료가 막힐 때 훅이 보여 준다.

```markdown
# TODO

## 항상 지킬 것

- PDF·PPTX 는 사용자가 만들라고 할 때까지 만들지 않는다
- 커밋은 사용자가 하라고 할 때만 한다

## 진행 중
```

사용자가 「앞으로 ~하지 마라」 「항상 ~해라」 라고 하면 **그 자리에서 등록한다.**

```bash
bash ~/.claude/skills/todo-guard/scripts/rule.sh add "규칙 문장"
bash ~/.claude/skills/todo-guard/scripts/rule.sh list
bash ~/.claude/skills/todo-guard/scripts/rule.sh remove <번호>
bash ~/.claude/skills/todo-guard/scripts/rule.sh tidy [--apply]   # 규칙 자리에 섞인 끝난 일을 옮긴다
```

**규칙 자리에는 규칙만 둔다.** 끝난 일(`- [x]`)이나 보류(`- [?]`)를 여기에 적지 않는다.

- 훅은 체크박스 줄(`- [ ]` · `- [x]` · `- [?]`)을 규칙으로 보지 않는다. 섞여 있어도 규칙으로 나오지는 않는다
- 그래도 파일이 지저분해지므로 `rule.sh tidy` 로 옮긴다. `- [x]` 는 「완료」 맨 위로, `- [?]` 는 「보류」로.
  열린 항목(`- [ ]`)은 그대로 둔다(턴 종료를 막는 항목이다). 지우는 것은 없고, 옛 파일은 `TODO.md.정리전백업_<시각>` 에 남는다
- **턴을 막을 때는 규칙을 찍지 않는다** (2026-09-26). 사용자 화면에서 답변을 밀어 올리고 문맥에도 쌓였다.
  세션 시작에만 12개 · 줄마다 120자까지 보여 준다. 규칙은 TODO.md 맨 위에 그대로 있다

### 세팅을 걷어낼 때

「투두가드 세팅 지워줘」 라고 하면 이것을 실행한다.

```bash
bash ~/.claude/skills/todo-guard/scripts/uninstall.sh --dry   # 무엇을 지울지 먼저 보여준다
bash ~/.claude/skills/todo-guard/scripts/uninstall.sh         # 걷어낸다
```

**먼저 `--dry` 로 보여주고 사용자 확인을 받은 뒤 지운다.**

| 걷어내는 것 | 남기는 것 |
|---|---|
| 이 스킬이 깐 훅 4개 (옛 문서 검사 훅도 함께) | 남이 걸어 둔 훅 |
| `settings.json` 의 이 스킬 훅 등록 | `permissions` 등 나머지 키 |
| `.claude/todo-guard.json` · `.claude/todo-guard/` (번호 · 턴 기록) | |
| `.todoguarddocs` (옛 문서 목록) | |
| `CLAUDE.md` 의 「작업 관리 규칙 (todo-guard)」 대목 | 사용자가 쓴 나머지 |
| | **`TODO.md` · `TODO-완료.md`** - 사용자의 작업 기록이다 (`--todo` 를 붙이면 함께 지운다) |

**전역 규칙은 걷어내지 않는다.** `~/.claude/CLAUDE.md` 의 「세션 밖 폴더」 규칙은
모든 프로젝트가 같이 쓰고, 동작을 바꾸지 않고 **경고만 한다.** 사용자가 「전역 규칙 빼줘」라고
따로 말할 때만 뺀다.

```bash
bash ~/.claude/skills/todo-guard/scripts/ensure-global-rule.sh remove
```

이 명령은 **스킬이 넣은 표시(`<!-- todo-guard:outside-rule:begin -->`) 안쪽만** 잘라낸다.
표시가 없으면 사용자가 직접 쓴 것으로 보고 손대지 않는다.

지우기 전에 `.claude/todo-guard_걷어내기전_<날짜>` 로 백업한다.
훅은 세션을 열 때 한 번 읽히므로, `/exit` 로 나갔다 들어와야 실제로 풀린다.

**스킬 자체를 지워 달라는 것과 구분한다.** 「투두가드 스킬 지워줘」 는
`~/.claude/skills/todo-guard` 폴더를 지우라는 말이다. 그 경우 먼저
세팅된 프로젝트가 있는지 `doctor.sh` 로 확인한다. 스킬을 지우면 프로젝트에 깔린
껍데기 훅이 없는 파일을 부르게 되므로, 프로젝트 세팅부터 걷어내야 한다.

### 이미 세팅한 프로젝트를 훑어볼 때

훅이 껍데기라 스킬 본체를 부르므로 스크립트를 고치면 그 자리에서 적용된다.
settings.json 등록 · CLAUDE.md 운영 규칙 · 설명서는 프로젝트에 있으므로 `--fix` 로 맞춘다.

```bash
bash ~/.claude/skills/todo-guard/scripts/doctor.sh <프로젝트 상위 폴더> [...]        # 상태만
bash ~/.claude/skills/todo-guard/scripts/doctor.sh --fix <프로젝트 상위 폴더> [...]  # 손봐야 할 것만
```

「손봐야 함」 으로 잡는 것: 사본 훅 · 빠진 훅 등록 · PowerShell 을 보지 않는 옛 등록 ·
옛 판 CLAUDE.md 운영 규칙 · 옛 판 설명서 · 옛 문서 검사 훅.

### 남에게 줄 zip 만들기

```bash
bash ~/.claude/skills/todo-guard/scripts/pack.sh [낼 경로]
```

받는 사람은 `~/.claude/skills/` 에 풀면 끝난다. zip 안에 `todo-guard/` 폴더가 들어 있다.
줄끝을 LF 로 맞춰 담으므로, 윈도우에서 만들어도 macOS·리눅스에서 그대로 돈다.

### 훅을 복사하지 않고 껍데기로 두는 이유

프로젝트에 놓이는 훅은 스킬 본체를 불러오기만 한다.

```bash
. "$HOME/.claude/skills/todo-guard/scripts/session-start.sh"
```

내용을 복사하면 규칙을 고쳐도 **이미 세팅한 프로젝트는 옛 사본으로 돈다.**

### 세팅 완료 보고

1. `setup.sh` 출력을 그대로 보여준다
2. **훅은 세션을 열 때 한 번 읽힌다.** `/exit` 로 나갔다 다시 들어와야 적용된다고 알린다

---

## A-2. 사용자가 말하면 실행할 것

| 사용자 말 | 실행 |
|---|---|
| 앞으로 ~하지 마 / 항상 ~해 | `bash ~/.claude/skills/todo-guard/scripts/rule.sh add "규칙 문장"` |
| 항상 지킬 것 정리해줘 / 규칙 자리 지저분해 | `bash ~/.claude/skills/todo-guard/scripts/rule.sh tidy` 로 먼저 보여준 뒤 `--apply` |
| 투두가드 세팅 지워줘 / 걷어내줘 | `bash ~/.claude/skills/todo-guard/scripts/uninstall.sh --dry` 로 먼저 보여준 뒤 확인받고 실행 |
| 세팅된 프로젝트 훑어줘 | `bash ~/.claude/skills/todo-guard/scripts/doctor.sh <폴더> [...]` |
| TODO 정리해줘 / 완료 항목 치워줘 | `bash ~/.claude/skills/todo-guard/scripts/todo.sh archive` |
| 세션 밖 규칙 확인해줘 | `bash ~/.claude/skills/todo-guard/scripts/ensure-global-rule.sh check` (없으면 `install`) |
| 배포용 zip 만들어줘 | `bash ~/.claude/skills/todo-guard/scripts/pack.sh [낼 경로]` |
| 명령이 느려 / bash 가 느린지 봐줘 (윈도우) | `bash ~/.claude/skills/todo-guard/scripts/fix-slow-bash.sh` 로 잰다. 느리면 아래 「bash.exe 가 느린 PC」를 설명하고 동의받은 뒤 `--apply` |

### 문서 문체 검사는 글검수로 옮겼다

슬라이드 · 보고서 문체 검사는 2026-09-14 부터 **글검수(geulgeomsu)** 스킬이 한다.
이 스킬은 문서를 검사하지 않는다. 옛 세팅의 흔적은 `doctor.sh --fix` 가 걷어낸다.

---

## B. 운영 규칙 (세팅된 프로젝트에서 상시)

1. **직접 등록하지 않는다.** 지시는 훅이 적고 `[todo-guard] #14 등록` 으로 번호를 알린다.
   **TODO.md 를 Read · Edit 하지 않는다.** 호출 한 번이 대화 전체를 다시 읽는다.
2. **완료는 번호로, 확인 명령에 붙여서.** 실제 파일 반영 · 테스트 통과 · 결과물 출력을 확인하는
   마지막 명령 뒤에 붙인다. 완료 표시만 하려고 따로 호출하지 않는다.

   ```bash
   python -m unittest && bash "$HOME/.claude/skills/todo-guard/scripts/todo.sh" done 14
   ```

3. **거짓 완료 금지.** 끝나지 않은 것을 done 하지 않는다. 적힌 뒤 파일을 바꾼 횟수보다 많이 done 하면
   거부된다. 파일을 바꾸지 않는 일(빌드 · 테스트 · 조사 · 답변)은 `todo.sh done 14 --why "빌드 성공"`.
4. **진행 불가 시 hold.** 사용자 판단이 필요하면 `todo.sh hold 14 "사유"` 로 남기고 사용자에게 묻는다.
   작업 지시를 받고 되묻기만 한 채 턴을 끝낼 때도 hold 로 남긴다.
   종료 차단을 피하려고 hold 를 남용하지 않는다.
5. **지시에 없던 일은 add.** `todo.sh add "할 일"` — 작업 명령 앞에 `&&` 로 붙여도 된다.
6. **세션 시작 시 미완료 보고.** SessionStart 훅이 미완료 항목을 알려주면 사용자에게 보고 후 이어서 처리한다.
7. 번호 없는 옛 항목(`- [ ] 항목`)은 예전처럼 Edit 로 `- [x]` 로 바꾼다. 완료 이력(`- [x]`)은 지우지 않는다.

---

## 거짓 완료 감지 강화 (선택)

사용자가 특정 작업의 실제 검증을 요청하면 `.claude/hooks/check-todo.sh` 껍데기의 **스킬 본체를 불러오는 줄 앞에** grep·테스트 기반 판정 블록을 넣는다. 예:

```bash
# 예: 인라인 렌더링 코드가 남아 있으면 "통합 완료" 항목을 거짓 완료로 판정
if grep -q '\[x\].*인라인 창 통합' TODO.md; then
  if grep -rq 'renderInline' src/; then
    echo "TODO에는 완료로 표시됐지만 src/에 renderInline 호출이 남아 있습니다. 실제로 통합을 완료하십시오." >&2
    exit 2
  fi
fi
```

---

## 윈도우 환경 참고

- 스크립트 실행은 Git Bash 기반이다 (Claude Code 윈도우 버전의 요구사항이므로 별도 설치 불필요).
- PowerShell 도구에서도 `bash "$HOME/.claude/skills/todo-guard/scripts/todo.sh" done 14` 가 그대로 돈다.
- 윈도우 편집기로 저장한 CRLF TODO.md 는 줄끝을 그대로 지킨다.
- 스크립트 파일이 CRLF로 변환되면 bash 실행이 깨질 수 있다. 복사 후 실행 오류가 나면 `sed -i 's/\r$//' .claude/hooks/*.sh`로 LF 변환한다.

### bash.exe 가 느린 PC — Claude Code 명령마다 0.4초씩 늦을 때

2026-09-23 한 PC 에서 끝까지 파고든 결과다. 같은 증상이면 아래대로 대처한다.

**증상** — 투두가드 훅 한 번 · Claude Code 의 Bash 명령 한 번이 매번 0.4~0.5초씩 늦다. 확인:

```bash
bash ~/.claude/skills/todo-guard/scripts/fix-slow-bash.sh     # 재기만 한다
```

`bash.exe 450ms · sh.exe 45ms` 처럼 bash.exe 만 수백 ms 면 이 증상이다. 세팅 때 `pick-shell.py` 도 같은 알림을 띄운다.
(sh.exe 는 견줄 잣대로만 쓴다. 훅을 sh.exe 로 돌리지 않는다 — 아래 참고)

**원인** — Git 의 `usr\bin\bash.exe` **파일 하나에 윈도우가 붙여 둔 상태**. 지연은 bash 가 시작되기 **전**(윈도우가 띄우는 단계)에 생긴다.
- 같은 바이트인 `sh.exe`(Git 의 sh.exe 는 bash.exe 와 같은 파일이다), 다른 폴더에 복사한 bash.exe 는 40~70ms 로 빠르다
- `…\Program Files\Git\usr\bin\` 과 같은 모양의 다른 경로에 복사해도 빠르다 → 이름 · 경로 규칙이 아니라 그 파일 하나다
- 같은 내용의 새 파일로 바꿔 넣으면 537 → 55ms. 원본을 다시 넣으면 도로 461ms. 되풀이해도 같다
- 정확히 윈도우의 어떤 캐시인지는 밝히지 못했다

**원인이 아닌 것** (모두 확인함 — 여기서 시간을 쓰지 않는다)

| 의심 | 확인 방법 | 결과 |
|---|---|---|
| 백신 실시간 검사 | `New-MpPerformanceRecording` 으로 bash.exe 30번 띄우며 기록 | bash.exe 검사 시간 0 |
| 백신 폴더 제외 | `C:\Program Files\Git` 을 제외에 넣고 다시 잼 | 그대로 느림 → **넣지 않는다** (보안만 낮아짐) |
| 프리페치 기록 | `C:\Windows\Prefetch\BASH.EXE-*.pf` 백업 후 삭제 | 그대로 느림 |
| 호환성 보정(shim) | 느린 · 빠른 프로세스의 적재 모듈 비교 | 같은 26개 |
| 확장 속성 · 하드링크 · 서명 · 속성 | `fsutil` · `Get-AuthenticodeSignature` | sh.exe 와 같음 |
| bash 설정 파일 · POSIX 모드 | 빈 `/etc` · Git 의 `/etc` · `--posix` | 차이 없음 |
| 상주 프로그램 | 의심 프로그램을 끄고 잼 | 그대로 느림 |
| 이미 떠 있는 bash | 복사본을 3개 띄워 두고 잼 | 복사본은 여전히 빠름 |

**셸을 바꿔 피하지 않는다** (2026-09-25) — 전에는 `env.CLAUDE_CODE_GIT_BASH_PATH` 를 같은 프로그램인 sh.exe 로 돌렸다.
훅은 빨라졌지만 **Claude Code 는 bash.exe 를 요구한다.** 그 설정이 있는 채로 세션을 열면 「No suitable shell found」 로
Bash 도구가 통째로 막힌다. 헤드리스 시험에서는 안 드러나고 다른 세션에서 터졌다. 세팅할 때 그 설정이 남아 있으면 걷어낸다.

**대처** — 원인을 고친다. **사용자에게 증상과 방법을 말하고 동의를 받은 뒤**:

   ```bash
   bash ~/.claude/skills/todo-guard/scripts/fix-slow-bash.sh --apply
   ```

   권한 창(UAC)이 한 번 뜬다. 원본을 `~/.claude/todo-guard-bash-backup/<시각>/` 에 백업 → 같은 폴더에 복사 →
   원본은 `bash.exe.old-<시각>` 으로 이름만 바꿈 → 복사본을 `bash.exe` 로 → 다시 재서 빨라지지 않았으면 되돌린다.
   파일 내용은 바뀌지 않는다(해시 같음). 실행 중인 bash 가 있어도 이름 바꾸기는 된다.
   또는 Git for Windows 를 다시 설치한다 (새 파일이 깔린다)

**되돌리기** — 관리자 권한으로 `bash.exe` 를 지우고 `bash.exe.old-<시각>` 을 `bash.exe` 로 바꾼다.
Git 을 업데이트하면 새 파일이 깔리므로, 나중에 다시 느려지면 1번의 확인부터 다시 한다.

## 한계

- 질문과 지시는 문구로 가른다. 애매하면 지시로 본다. 질문 · 의견으로 본 것만, 파일을 바꾸지 않은 채 턴이 끝나면 지운다.
- 브라우저 조작 · MCP 도구만 쓴 일은 파일 변경으로 세지 않는다. 그런 일은 `done 14 --why "사유"` 로 닫는다.
- 훅은 적힌 항목과 실제 결과가 맞는지 판단하지 못한다. done 때 잡는 것은 셋이다 — 「편집 2번으로 8개를 끝냈다」, 항목에 적힌 파일(c.txt · Deck.tsx)을 바꾸지 않은 것, 슬라이드마다 파일이 따로 있는 구조에서 그 번호 파일(slide03.tsx)을 바꾸지 않은 것. 파일 내용까지는 보지 않는다. 중요 작업은 위의 검증 블록을 추가할 것.
- 한 번에 준 2~3개 지시(「고치고 커밋해」)는 항목 하나로 적는다. 나누는 것은 슬라이드 번호 · 줄 머리 번호뿐이다. 대신 항목에 파일이 여럿 적혀 있으면 done 때 전부 바꿨는지 본다.
- 셸 명령의 쓰기 대상은 흔한 명령(`>` · `cp` · `mv` · `rm` · `sed -i` · `tee` · `Set-Content` · `Copy-Item` …)만 뽑는다. 변수로 만든 경로(`$OUT/x`)와 스크립트 안에서 쓰는 파일은 보지 못한다.
- 턴 종료 차단은 남은 항목이 줄어드는 동안만 되풀이한다. 진전이 없으면 풀어 주고 남은 항목을 사용자 화면에 띄운다.
- 한 프로젝트에서 세션 둘이 같이 돌면, 다른 세션이 적고 아직 움직이는 항목은 이 세션의 종료를 막지 않는다. 그 세션이 멈춘 뒤 연 세션(/clear 포함)은 남은 항목을 맡는다.
