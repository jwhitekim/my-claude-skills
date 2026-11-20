---
name: seminar-slides
description: Use when writing or revising a seminar or lecture deck — a markdown slide spec first, then a pptx built from the bundled personal template or a lab template — "세미나 발표자료 만들어줘", "슬라이드 문체 점검해줘", "발표 원고 마크다운으로 먼저 써줘", "템플릿으로 PPT 만들어줘".
---

# seminar-slides

세미나·강의 발표자료를 마크다운 명세로 먼저 쓰고, 검증한 뒤 템플릿 pptx로 옮기는 절차와 규칙이다.

## 쓰는 법

1. 작업 전에 같은 폴더의 `rules.md`를 읽는다. 내용, 문체, 형식, 절차 규칙이 모두 거기에 있다. 사용자 기준 파일(`~/.config/my-claude-skills/seminar-slides/rules.md`)이 있으면 그것도 읽고, 겹치면 사용자 기준을 우선한다.
2. 마크다운 명세는 `## Slide N. 제목` 단위로 쓴다. 한 장은 제목, 헤드라인(평문 한 줄), 불릿, 표(최대 1개), 뒤따르는 평문 줄, `> 발표 멘트:`·`> 확인 메모:`, `출처:`·`하단 서지:` 줄로 구성한다. 생성 뒤에는 모든 줄이 슬라이드나 노트에 들어갔는지 확인한다.
3. 명세를 검증한 뒤 템플릿에 옮긴다. 기본은 스킬에 든 개인 템플릿이다.

### 기본: 개인 템플릿 (`assets/lecture-template.pptx`)

남색·청록·주황 색 구성에 Pretendard 글꼴을 쓰는 16:9 템플릿이다. 레이아웃은 7종이다: COVER(표지), SECTION(파트 구분), CONTENT(본문, 표는 불릿 아래), TEXT_IMAGE(왼쪽 글·오른쪽 그림 판), IMAGE(큰 그림), APPENDIX(부록), END(마지막 장). PowerPoint에서 직접 새 발표를 시작할 때는 같은 디자인의 `assets/lecture-template.potx`를 쓴다.

```bash
python3 -m venv venv && ./venv/bin/pip install python-pptx pillow
./venv/bin/python ${CLAUDE_SKILL_DIR}/scripts/build_template_deck.py ${CLAUDE_SKILL_DIR}/assets/lecture-template.pptx <명세.md> <출력.pptx>
```

- 레이아웃은 자동으로 고른다: 1번 장은 COVER, 제목이 "부록"으로 시작하면 APPENDIX, 그림만 있으면 IMAGE, 그림이 있으면 TEXT_IMAGE, 나머지는 CONTENT. 장마다 `레이아웃: SECTION`처럼 직접 지정할 수 있다.
- 1번 장의 헤드라인은 부제, 뒤따르는 평문 줄은 발표자·날짜 칸에 들어간다. 바닥글에는 1번 장 제목이 들어간다.
- 그림은 그림 판 안에 비율을 지켜 넣고, 가로 1400px·256색으로 줄여 파일 크기를 줄인다. 원본 이미지는 그대로 둔다.
- 표 행 높이는 칸 너비와 글 길이로 어림한다. 그림과 함께 놓는 표는 6행, 일반 표는 8행, 부록 표는 10행 이내로 쓴다.
- 템플릿을 고치려면 `scripts/make_template.js`를 고쳐 다시 만든다(`npm install pptxgenjs` 후 `NODE_PATH=<node_modules> node make_template.js <출력.pptx>`, 같은 이름의 .potx도 함께 생긴다). 자리표시자 이름은 파일에 남지 않고 번호로만 남으므로, 레이아웃의 자리표시자 순서를 바꾸면 `build_template_deck.py`의 `PH_ORDER`도 함께 고친다.

### 연구실 템플릿 (`scripts/build_deck.py`)


```bash
python3 -m venv venv && ./venv/bin/pip install python-pptx
./venv/bin/python ${CLAUDE_SKILL_DIR}/scripts/build_deck.py <템플릿.pptx> <명세.md> <출력.pptx>
```

- 이 스크립트는 템플릿의 1~3번 슬라이드(표지와 그림 포함 본문)를 재사용하고 4번 슬라이드를 지운다. 실행 전에 4번이 지워도 되는 빈 장인지 확인한다.
- 발표 멘트와 확인 메모는 슬라이드 노트에 넣는다. 본문·표·표지의 `[확인...]` 표시는 빨간 글씨로 넣고, 제목·하단 인용·노트에는 적용하지 않는다.
- 스크립트는 템플릿 구조(레이아웃 1번 본문, 3번 슬라이드의 바닥글·번호·인용 도형)에 맞춰 쓴 것이다. 템플릿이 바뀌면 먼저 구조를 확인한다.

## 주의

- 발표마다 다른 맥락(발표자 말, 확인한 사실, 이번 발표에서 바꾼 규칙 적용 범위)은 발표 작업 폴더의 `context.md`에 둔다. 스킬 폴더는 공개 저장소라 발표 내용을 넣지 않는다.
- 템플릿이 빈 틀이 아니라 지난 발표 내용이 든 파일이면, 스크립트가 2~3번 장을 재사용하고 4번만 지우므로 옛 장과 그림이 남는다. 실행 전에 장 구성을 확인하고, 다르면 표지만 남기고 본문은 레이아웃으로 새로 만드는 방식으로 조립을 바꾼다.
- macOS에서 온 한글 파일명은 자모가 분리된 형태(NFD)라 셸에서 이름을 그대로 쳐도 못 찾을 수 있다. `ls | grep`으로 받은 이름을 쓴다.

- 슬라이드 모양은 LibreOffice로 PDF를 만들어 이미지로 확인할 수 있다(`soffice --headless --convert-to pdf`, `pdftoppm -jpeg`). 서버에 없으면 사용자 폴더에 설치할 수 있다. 확인 항목: 표가 좁게 찌그러지지 않는지, 표 아래 글이 표와 겹치지 않는지, 글이 슬라이드 밖으로 넘치지 않는지. 렌더러가 PowerPoint와 다를 수 있으니 최종 모양은 사용자가 PowerPoint로 열어 확인한다.
- 규칙은 계속 고친다. 사용자가 새 기준을 말하면 `~/.config/my-claude-skills/seminar-slides/rules.md`(없으면 만든다)에 근거 표시와 함께 추가한다. 플러그인 캐시 안 `rules.md`는 업데이트 때 사라지므로 고치지 않는다.
