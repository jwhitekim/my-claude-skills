---
name: naver-search
description: "Use when searching Korean-language web content such as Naver blogs, news, cafe posts, Knowledge iN answers, or web documents, especially recent domestic issues or reviews that WebSearch covers poorly — \"네이버에서 찾아줘\", \"국내 기사 최신순으로 찾아줘\", \"블로그 후기 찾아줘\"."
---

# naver-search

WebSearch는 미국 기준이라 한국어 자료에 약하다. 네이버 검색 Open API로 국내
블로그·뉴스·카페·지식iN·웹문서를 찾아 보완한다.

## 실행

Python 3 표준 라이브러리만 쓴다.

```bash
python3 ~/.claude/skills/naver-search/scripts/naver.py "제주 대중교통 여행"
python3 ~/.claude/skills/naver-search/scripts/naver.py "전기차 보조금" --type news --sort date --limit 5 --text
python3 ~/.claude/skills/naver-search/scripts/naver.py "전세 계약 주의사항" --type cafe,kin
```

| 옵션 | 동작 |
|---|---|
| `--type` | `blog`, `news`, `cafe`, `kin`(지식iN), `web`(웹문서). 쉼표로 여러 개. 기본 `blog,news,web` |
| `--limit N` | 종류별 건수. 기본 10, 1~100 |
| `--start N` | 시작 위치. 기본 1, 최대 1000 |
| `--sort sim\|date\|point` | 기본 `sim`(정확도순). `date`는 최신순, `point`는 평점순(지식iN만) |
| `--text` | JSON 대신 사람이 읽는 목록으로 출력 |

웹문서는 정렬 옵션이 없어 `--sort`를 무시한다. 지식iN이 아닌 종류에 `point`를 주면
`sim`으로 검색한다.

## 키

`NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET`이 모두 필요하다. 환경변수를 먼저 보고, 없으면
`~/.config/my-claude-skills/secrets.env`에서 읽는다.

검색 API는 네이버 개발자센터에서 네이버 클라우드 플랫폼의 NAVER API HUB로 옮겨졌다.
개발자센터 키로는 인증에 실패한다. 발급은 네이버 클라우드 콘솔의 **Application Services >
NAVER API HUB > Application**에서 앱을 등록하고 검색 API를 고른다
([공식 안내](https://api.ncloud-docs.com/docs/naver-api-hub-overview)). 받은 Client ID와
Client Secret을 my-claude-skills 레포 루트 `.env`에 넣고 `./install.sh`를 실행한다.

## 사용 순서

1. 한국어 검색어로 후보를 찾는다. 최신 이슈는 `--sort date`, 필요하면 종류를 좁힌다.
2. 내용 확인이 필요한 링크는 원문을 읽는다. 뉴스는 `original_link`(언론사 원문)를 먼저
   읽는다. 블로그·카페가 로그인이나 iframe 때문에 WebFetch로 안 열리면
   [agent-browser](../agent-browser/SKILL.md)를 쓴다.
3. 원문에서 확인한 내용에 출처 링크와 날짜를 붙여 답한다. `description`은 요약 일부라
   이것만으로 사실을 단정하지 않는다. 원문을 못 읽었으면 그 한계를 밝힌다.

## 출력과 종료 코드

기본 출력은 JSON이다.

- 최상위: `query`, `groups`(종류별 결과).
- 그룹: `type`, `total`(전체 결과 수), `results`.
- 결과: `type`, `title`, `link`, `original_link`, `description`, `date`, `source`(블로그명·카페명).
  `<b>` 태그와 HTML 엔티티는 지운다. 날짜는 뉴스는 ISO 형식(변환에 실패하면 원래 문자열),
  블로그는 `YYYY-MM-DD`이고, 없으면 `null`이다.

| 종료 코드 | 의미 |
|---|---|
| `0` | 성공. 결과 0건도 포함 |
| `1` | 키 없음, API·네트워크 오류. 메시지는 stderr |
| `2` | 잘못된 명령 인자 |

API 오류 메시지에는 HTTP 상태와, 응답에 있으면 네이버 오류 코드가 붙는다. 400은 요청 값 오류(`SE01`~`SE04`, `SE06`),
404는 없는 검색 종류(`SE05`), 500은 서버 오류(`SE99`)다. 401은 인증 실패라 키를 확인한다. 여러 종류 중 하나라도
실패하면 다른 종류의 결과도 출력하지 않는다.

## 한계

- 하루 호출 한도는 25,000회다. 종류마다 한 번씩 호출하므로 기본 실행은 3회를 쓴다.
- 스크립트는 검색 결과만 반환한다. 원문을 가져오지 않고, 자동 재시도도 하지 않는다.
- 광고성 글이나 개인 경험이 섞일 수 있다. 원문의 작성 시점과 근거를 확인한다.
