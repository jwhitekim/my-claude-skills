---
name: paper-search
description: "Use when asked to find research papers, look up paper metadata, or download open-access full text to check numbers or benchmark results in the original, such as \"관련 논문 찾아줘\", \"이 논문 정보 확인해줘\", or \"논문 원문 받아서 표 수치 확인해줘\"."
---

# paper-search

논문을 검색하고 오픈 액세스 원문을 파일로 받는다. Semantic Scholar(S2)를 먼저 쓰고, 막히면
OpenAlex로 넘어간다. 원문을 읽고 해석하는 일은 Claude가 Read 도구로 직접 한다.

## 실행

Python 3 표준 라이브러리만 쓴다.

```bash
python3 ~/.claude/skills/paper-search/scripts/papers.py search "retrieval augmented generation" --limit 5 --year 2023- --oa-only
python3 ~/.claude/skills/paper-search/scripts/papers.py paper ARXIV:2005.11401 --text
python3 ~/.claude/skills/paper-search/scripts/papers.py fetch ARXIV:2005.11401
```

| 옵션 | 명령 | 동작 |
|---|---|---|
| `--limit N` | `search` | 반환 건수. 기본 10, 최대 100 |
| `--year` | `search` | `2023`, `2020-2024`, `2023-`, `-2024` |
| `--oa-only` | `search` | API가 오픈 액세스로 표시한 논문만. 실제 다운로드 성공을 보장하지는 않는다 |
| `--source auto\|s2\|openalex` | `search`, `paper` | 기본 `auto`. `s2`는 OpenAlex로 넘어가지 않는다 |
| `--text` | 모두 | JSON 대신 사람이 읽는 목록으로 출력 |
| `--out DIR` | `fetch` | 저장 위치. 기본 `${XDG_CACHE_HOME:-~/.cache}/my-claude-skills/papers` |

ID는 `DOI:10.x/...`, `ARXIV:2005.11401`, S2 `paperId`, OpenAlex `W...` 형식이다. OpenAlex
ID는 S2를 거치지 않는다.

`auto`에서 `search`는 S2가 429일 때, `paper`와 `fetch`는 S2가 429나 404일 때 OpenAlex로
넘어간다. 다른 API 오류는 그대로 실패한다.

## 키

`S2_API_KEY`, `OPENALEX_API_KEY`는 선택이다. 환경변수를 먼저 보고, 없으면
`~/.config/my-claude-skills/secrets.env`에서 읽는다. 등록은 my-claude-skills 레포 루트
`.env`에 넣고 `./install.sh`를 실행한다.

S2 키가 없으면 공용 한도를 나눠 써서 429가 잦다. 이때는 기다리지 않고 바로 OpenAlex로
넘어간다. 키가 있으면 2초, 5초 뒤 두 번 더 시도한다.

## 사용 순서

1. `search`로 후보를 찾고 제목·연도·발표처로 고른다. 초록이 필요하면 `paper`로 본다.
2. 답에 필요한 논문만 `fetch`한다. arXiv HTML판이 있으면 표를 ` | ` 행으로 남긴 `.txt`로,
   없으면 arXiv PDF나 오픈 액세스 PDF로 저장한다.
3. 결과의 `path`를 Read로 열어 필요한 섹션과 표만 읽는다. PDF는 `pages`로 범위를 정한다
   (한 번에 최대 20페이지). WebFetch는 요약 과정에서 표 수치가 빠질 수 있어 원문 확인에
   쓰지 않는다.
4. 논문 제목과 DOI·arXiv 링크를 붙여 답한다. 수치를 인용할 때는 **표 번호와 실험 조건**
   (데이터셋 버전, 지표, shot 수, 모델 크기 등)을 함께 적는다. 원문을 받지 못했으면
   근거가 초록뿐임을 밝히고, 초록에도 없는 수치는 추정하지 않는다.

## 출력과 종료 코드

기본 출력은 JSON이다.

- 논문 레코드: `source`, `id`, `title`, `year`, `venue`, `authors`(최대 6명), `citations`,
  `doi`, `arxiv`, `oa_pdf`, `url`, `tldr`, `abstract`. S2 검색 결과에는 초록이 없다.
- `search`: `source`, `total`, `results`, `note`. OpenAlex로 넘어갔으면 `note`에 사유가 있다.
- `fetch`: 성공하면 `result: "ok"`, `format`(`text`/`pdf`), `path`, `from`, `paper`.
  원문이 없으면 `result: "no_open_access"`와 시도한 URL 목록 `tried`.

| 종료 코드 | 의미 |
|---|---|
| `0` | 성공. 검색 결과 0건도 포함 |
| `1` | API 오류, 호출 한도 초과, 논문 없음. 메시지는 stderr |
| `2` | 잘못된 명령 인자 |
| `3` | `fetch`에서 오픈 액세스 원문을 받지 못함 |

## 한계

- 유료 논문의 원문은 받지 못한다. 다운로드 실패를 곧 유료 논문이라고 단정하지 않는다.
- OpenAlex 결과에는 중복이나 관련 없는 항목이 섞일 수 있다. 제목·저자·DOI로 확인한다.
- 조건이 다른 수치를 한 표에서 비교해도 되는지는 Claude가 원문을 읽고 판단한다.
