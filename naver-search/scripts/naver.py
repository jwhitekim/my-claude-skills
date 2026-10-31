#!/usr/bin/env python3
"""네이버 검색 API(네이버 클라우드 NAVER API HUB)로 블로그·뉴스·카페·지식iN·웹문서를 검색한다.

사용:
  naver.py "<검색어>" [--type blog,news,...] [--limit N] [--start N] [--sort sim|date|point] [--text]

종류: blog, news, cafe, kin, web. 쉼표로 여러 개를 주면 종류별로 묶어 반환한다. 기본 blog,news,web.
키(필수): NAVER_CLIENT_ID, NAVER_CLIENT_SECRET(NAVER API HUB 앱의 Client ID·Secret). 환경변수에 없으면 ~/.config/my-claude-skills/secrets.env에서 읽는다.
표준 라이브러리만 쓴다. 기본 출력은 JSON, --text는 사람이 읽는 목록.
"""
import argparse
import email.utils
import html
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

SECRETS = pathlib.Path("~/.config/my-claude-skills/secrets.env").expanduser()
# 검색 API는 developers.naver.com(openapi.naver.com)에서 NAVER API HUB로 이관됐다.
API = "https://naverapihub.apigw.ntruss.com/search/v1/%s"
TYPES = {"blog": "blog", "news": "news", "cafe": "cafearticle", "kin": "kin", "web": "webkr"}
# 웹문서는 정렬 옵션을 받지 않고, 평점순(point)은 지식iN만 지원한다.
NO_SORT = {"web"}


class ApiError(Exception):
    pass


def secret(name):
    """환경변수를 먼저 보고, 없으면 secrets.env의 NAME=값 줄을 읽는다(파일을 실행하지 않는다)."""
    value = os.environ.get(name)
    if value:
        return value
    try:
        lines = SECRETS.read_text().splitlines()
    except OSError:
        return None
    for line in reversed(lines):
        m = re.match(r"\s*(?:export\s+)?%s=(.*)$" % re.escape(name), line)
        if m:
            v = m.group(1).strip()
            if len(v) >= 2 and v[0] == v[-1] and v[0] in "'\"":
                v = v[1:-1]
            return v or None
    return None


def clean(s):
    """응답에 섞인 <b> 강조 태그와 HTML 엔티티를 지운다."""
    return html.unescape(re.sub(r"</?b>", "", s or "")).strip() or None


def iso_date(item):
    if item.get("pubDate"):
        try:
            return email.utils.parsedate_to_datetime(item["pubDate"]).isoformat()
        except (TypeError, ValueError):
            return item["pubDate"]
    d = item.get("postdate") or ""
    return "%s-%s-%s" % (d[:4], d[4:6], d[6:8]) if re.fullmatch(r"\d{8}", d) else None


def record(kind, item):
    return {
        "type": kind,
        "title": clean(item.get("title")),
        "link": item.get("link"),
        "original_link": item.get("originallink") or None,
        "description": clean(item.get("description")),
        "date": iso_date(item),
        "source": item.get("bloggername") or item.get("cafename") or None,
    }


def call(kind, query, limit, start, sort, cid, csecret):
    params = {"query": query, "display": limit, "start": start, "format": "json"}
    if sort == "point" and kind != "kin":
        sort = "sim"
    if kind not in NO_SORT:
        params["sort"] = sort
    url = API % TYPES[kind] + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"X-NCP-APIGW-API-KEY-ID": cid, "X-NCP-APIGW-API-KEY": csecret})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read()[:300].decode("utf-8", "replace")
        # 인증 실패 같은 게이트웨이 오류는 error 객체로, 검색 파라미터 오류는 평면 구조로 온다.
        try:
            err = json.loads(body)
            gw = err.get("error") or {}
            if gw:
                body = "%s %s" % (gw.get("errorCode", ""), gw.get("message") or gw.get("details") or body)
            else:
                body = "%s %s" % (err.get("errorCode", ""), err.get("errorMessage", body))
        except (ValueError, AttributeError):
            pass
        raise ApiError("%s 검색 실패 (HTTP %d): %s" % (kind, e.code, body.strip()))
    except (urllib.error.URLError, TimeoutError, ValueError) as e:
        raise ApiError("%s 검색 실패: %s" % (kind, e))
    return {"type": kind, "total": data.get("total"), "results": [record(kind, i) for i in data.get("items") or []]}


def render_text(groups):
    out = []
    for g in groups:
        out.append("[%s] 총 %s건 중 %d건" % (g["type"], g["total"], len(g["results"])))
        for i, r in enumerate(g["results"], 1):
            meta = ", ".join(x for x in [r["date"], r["source"]] if x)
            lines = ["%d. %s" % (i, r["title"]), meta, r["original_link"] or r["link"], r["description"]]
            out.append("\n   ".join(x for x in lines if x))
    return "\n\n".join(out)


def main(argv):
    ap = argparse.ArgumentParser(description="네이버 검색 API (NAVER API HUB)")
    ap.add_argument("query")
    ap.add_argument("--type", default="blog,news,web", help="blog, news, cafe, kin, web 중 쉼표로 여러 개")
    ap.add_argument("--limit", type=int, default=10, help="종류별 건수(1~100)")
    ap.add_argument("--start", type=int, default=1, help="시작 위치(1~1000)")
    ap.add_argument("--sort", choices=["sim", "date", "point"], default="sim", help="sim 정확도순, date 최신순, point 평점순(지식iN만)")
    ap.add_argument("--text", action="store_true", help="사람이 읽는 형식으로 출력")
    args = ap.parse_args(argv)

    kinds = [k.strip() for k in args.type.split(",") if k.strip()]
    bad = [k for k in kinds if k not in TYPES]
    if bad or not kinds:
        ap.error("알 수 없는 종류: %s (가능: %s)" % (", ".join(bad) or "-", ", ".join(TYPES)))
    cid, csecret = secret("NAVER_CLIENT_ID"), secret("NAVER_CLIENT_SECRET")
    if not (cid and csecret):
        print("Error: NAVER_CLIENT_ID와 NAVER_CLIENT_SECRET이 필요합니다. my-claude-skills 레포 .env에 넣고 ./install.sh를 실행하세요.", file=sys.stderr)
        return 1

    limit = max(1, min(args.limit, 100))
    start = max(1, min(args.start, 1000))
    try:
        groups = [call(k, args.query, limit, start, args.sort, cid, csecret) for k in kinds]
    except ApiError as e:
        print("Error: %s" % e, file=sys.stderr)
        return 1
    print(render_text(groups) if args.text else json.dumps({"query": args.query, "groups": groups}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
