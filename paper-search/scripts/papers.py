#!/usr/bin/env python3
"""논문 검색과 원문 내려받기. Semantic Scholar를 먼저 쓰고, 한도 초과(429)면 OpenAlex로 넘긴다.

사용:
  papers.py search "<검색어>" [--limit N] [--year 2023-] [--oa-only] [--source auto|s2|openalex] [--text]
  papers.py paper <ID> [--text]        ID: DOI:10.x/..., ARXIV:2005.11401, S2 paperId, OpenAlex W...
  papers.py fetch <ID> [--out DIR]     오픈 액세스 원문을 파일로 저장하고 경로를 출력한다(원문이 없으면 종료 코드 3)

키(선택): S2_API_KEY, OPENALEX_API_KEY. 환경변수에 없으면 ~/.config/my-claude-skills/secrets.env에서 읽는다.
표준 라이브러리만 쓴다. 기본 출력은 JSON, --text는 사람이 읽는 목록.
"""
import argparse
import html.parser
import json
import os
import pathlib
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

SECRETS = pathlib.Path("~/.config/my-claude-skills/secrets.env").expanduser()
S2 = "https://api.semanticscholar.org/graph/v1"
OPENALEX = "https://api.openalex.org"
S2_FIELDS = "paperId,title,year,venue,authors,citationCount,externalIds,openAccessPdf,url"
S2_DETAIL_FIELDS = S2_FIELDS + ",abstract,tldr,publicationDate"
UA = "my-claude-skills/paper-search"
DEFAULT_OUT = pathlib.Path(os.environ.get("XDG_CACHE_HOME") or "~/.cache").expanduser() / "my-claude-skills" / "papers"


class RateLimited(Exception):
    pass


class ApiError(Exception):
    pass


class NotFound(ApiError):
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


def http_get(url, headers=None, timeout=30):
    req = urllib.request.Request(url, headers={"User-Agent": UA, **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read(), resp.headers.get("Content-Type", "")
    except urllib.error.HTTPError as e:
        if e.code == 429:
            raise RateLimited(url)
        body = e.read()[:300].decode("utf-8", "replace")
        raise (NotFound if e.code == 404 else ApiError)("HTTP %d: %s" % (e.code, body))
    except (urllib.error.URLError, TimeoutError) as e:
        raise ApiError("요청 실패: %s" % e)


def get_json(url, headers=None):
    body, _ = http_get(url, headers)
    try:
        return json.loads(body)
    except ValueError:
        raise ApiError("JSON이 아닌 응답: %s" % body[:200])


# --- Semantic Scholar ---

def s2_get(path, params):
    key = secret("S2_API_KEY")
    headers = {"x-api-key": key} if key else {}
    url = "%s%s?%s" % (S2, path, urllib.parse.urlencode(params))
    # 키가 있으면 일시적인 429일 가능성이 커서 짧게 두 번 더 시도한다.
    # 키가 없으면 공용 한도가 막힌 경우가 많아 기다리지 않고 바로 OpenAlex로 넘긴다.
    for wait in (0, 2, 5) if key else (0,):
        if wait:
            time.sleep(wait)
        try:
            return get_json(url, headers)
        except RateLimited:
            continue
    raise RateLimited(url)


def s2_record(p):
    ext = p.get("externalIds") or {}
    tldr = p.get("tldr") or {}
    return {
        "source": "s2",
        "id": p.get("paperId"),
        "title": p.get("title"),
        "year": p.get("year"),
        "venue": p.get("venue") or None,
        "authors": [a.get("name") for a in (p.get("authors") or [])][:6],
        "citations": p.get("citationCount"),
        "doi": ext.get("DOI"),
        "arxiv": ext.get("ArXiv"),
        "oa_pdf": (p.get("openAccessPdf") or {}).get("url") or None,
        "url": p.get("url"),
        "tldr": tldr.get("text"),
        "abstract": p.get("abstract"),
    }


def s2_search(query, limit, year, oa_only):
    params = {"query": query, "limit": limit, "fields": S2_FIELDS}
    if year:
        params["year"] = year
    if oa_only:
        params["openAccessPdf"] = ""
    data = s2_get("/paper/search", params)
    return [s2_record(p) for p in data.get("data") or []], data.get("total")


def s2_paper(pid):
    return s2_record(s2_get("/paper/" + urllib.parse.quote(pid, safe=":/"), {"fields": S2_DETAIL_FIELDS}))


# --- OpenAlex ---

def oa_get(path, params):
    key = secret("OPENALEX_API_KEY")
    if key:
        params = dict(params, api_key=key)
    return get_json("%s%s?%s" % (OPENALEX, path, urllib.parse.urlencode(params)))


def oa_abstract(inv):
    if not inv:
        return None
    words = sorted((pos, w) for w, positions in inv.items() for pos in positions)
    return " ".join(w for _, w in words)


def oa_record(w):
    ids = w.get("ids") or {}
    doi = (w.get("doi") or "").replace("https://doi.org/", "") or None
    arxiv = None
    for loc in w.get("locations") or []:
        m = re.search(r"arxiv\.org/(?:abs|pdf)/([0-9]{4}\.[0-9]{4,5})", loc.get("landing_page_url") or "")
        if m:
            arxiv = m.group(1)
            break
    best = w.get("best_oa_location") or {}
    venue = ((w.get("primary_location") or {}).get("source") or {}).get("display_name")
    return {
        "source": "openalex",
        "id": (ids.get("openalex") or w.get("id") or "").rsplit("/", 1)[-1] or None,
        "title": w.get("title"),
        "year": w.get("publication_year"),
        "venue": venue,
        "authors": [(a.get("author") or {}).get("display_name") for a in (w.get("authorships") or [])][:6],
        "citations": w.get("cited_by_count"),
        "doi": doi,
        "arxiv": arxiv,
        "oa_pdf": best.get("pdf_url"),
        "url": w.get("id"),
        "tldr": None,
        "abstract": oa_abstract(w.get("abstract_inverted_index")),
    }


def oa_year_filter(year):
    m = re.fullmatch(r"(\d{4})?(-)?(\d{4})?", year or "")
    if not m or not (m.group(1) or m.group(3)):
        return None
    lo, dash, hi = m.groups()
    if not dash:
        return "publication_year:%s" % lo
    parts = []
    if lo:
        parts.append("from_publication_date:%s-01-01" % lo)
    if hi:
        parts.append("to_publication_date:%s-12-31" % hi)
    return ",".join(parts)


def oa_search(query, limit, year, oa_only):
    params = {"search": query, "per-page": limit}
    filters = [f for f in (oa_year_filter(year), "is_oa:true" if oa_only else None) if f]
    if filters:
        params["filter"] = ",".join(filters)
    data = oa_get("/works", params)
    return [oa_record(w) for w in data.get("results") or []], (data.get("meta") or {}).get("count")


def oa_paper(pid):
    if pid.upper().startswith("DOI:"):
        path = "/works/https://doi.org/" + pid[4:]
    elif pid.upper().startswith("ARXIV:"):
        path = "/works/https://doi.org/10.48550/arXiv." + pid[6:]
    else:
        path = "/works/" + pid
    return oa_record(oa_get(path, {}))


# --- 공통 흐름 ---

def search(args):
    note = None
    if args.source in ("auto", "s2"):
        try:
            results, total = s2_search(args.query, args.limit, args.year, args.oa_only)
            return {"source": "s2", "total": total, "results": results, "note": note}
        except RateLimited:
            if args.source == "s2":
                raise
            note = "Semantic Scholar 한도 초과(429)로 OpenAlex 결과를 대신 반환했다"
    results, total = oa_search(args.query, args.limit, args.year, args.oa_only)
    return {"source": "openalex", "total": total, "results": results, "note": note}


def paper(pid, source="auto"):
    if source in ("auto", "s2") and not re.fullmatch(r"W\d+", pid):
        try:
            return s2_paper(pid)
        except (RateLimited, NotFound):
            # S2에 없는 논문(일부 학회 DOI 등)도 OpenAlex에는 있는 경우가 있다.
            if source == "s2":
                raise
    return oa_paper(pid)


class TextExtractor(html.parser.HTMLParser):
    """arXiv HTML을 Read로 읽기 좋은 텍스트로 바꾼다. 표는 행마다 ' | '로 셀을 이어 남긴다."""

    SKIP = {"script", "style", "nav", "header", "footer", "button"}
    BLOCK = {"p", "div", "section", "li", "figcaption", "caption", "br", "h1", "h2", "h3", "h4", "h5", "h6", "tr"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out, self.skip, self.row = [], 0, None

    def handle_starttag(self, tag, attrs):
        if tag in self.SKIP:
            self.skip += 1
        elif tag == "math":
            alt = dict(attrs).get("alttext")
            if alt and not self.skip:
                self._text(" %s " % alt)
            self.skip += 1
        elif tag == "tr":
            self.row = []
        elif tag in ("td", "th") and self.row is not None:
            self.row.append("")
        elif tag in self.BLOCK:
            self.out.append("\n")
            if tag[0] == "h" and tag[1:].isdigit():
                self.out.append("#" * int(tag[1:]) + " ")

    def handle_endtag(self, tag):
        if tag in self.SKIP or tag == "math":
            self.skip = max(0, self.skip - 1)
        elif tag == "tr" and self.row is not None:
            self.out.append("\n| " + " | ".join(c.strip() for c in self.row) + " |")
            self.row = None
        elif tag in self.BLOCK:
            self.out.append("\n")

    def handle_data(self, data):
        if not self.skip:
            self._text(data)

    def _text(self, data):
        data = re.sub(r"\s+", " ", data)
        if self.row is not None and self.row:
            self.row[-1] += data
        elif self.row is None:
            self.out.append(data)

    def text(self):
        return re.sub(r"\n\s*\n+", "\n\n", "".join(self.out)).strip() + "\n"


def safe_name(s):
    return re.sub(r"[^A-Za-z0-9._-]+", "_", s).strip("_")[:80] or "paper"


def fetch(args):
    out = pathlib.Path(args.out).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    rec = paper(args.id)
    arxiv = rec.get("arxiv") or (args.id[6:] if args.id.upper().startswith("ARXIV:") else None)
    tried = []

    # arXiv HTML판이 표를 가장 정확하게 담는다. 오래된 논문은 HTML판이 없어 PDF로 넘어간다.
    if arxiv:
        url = "https://arxiv.org/html/" + arxiv
        try:
            body, ctype = http_get(url, timeout=60)
            if "html" in ctype:
                parser = TextExtractor()
                parser.feed(body.decode("utf-8", "replace"))
                path = out / ("arxiv-%s.txt" % safe_name(arxiv))
                path.write_text(parser.text())
                return {"result": "ok", "format": "text", "path": str(path), "from": url, "paper": rec}
        except (ApiError, RateLimited) as e:
            tried.append("%s (%s)" % (url, e))

    for url in [("https://arxiv.org/pdf/" + arxiv) if arxiv else None, rec.get("oa_pdf")]:
        if not url:
            continue
        try:
            body, ctype = http_get(url, timeout=120)
        except (ApiError, RateLimited) as e:
            tried.append("%s (%s)" % (url, e))
            continue
        if body[:5] != b"%PDF-":
            tried.append("%s (PDF가 아닌 응답: %s)" % (url, ctype))
            continue
        path = out / ("%s.pdf" % safe_name(arxiv or rec.get("doi") or rec.get("id") or args.id))
        path.write_bytes(body)
        return {"result": "ok", "format": "pdf", "path": str(path), "from": url, "paper": rec}

    return {"result": "no_open_access", "tried": tried, "paper": rec,
            "note": "오픈 액세스 원문을 받지 못했다. 근거는 초록뿐임을 밝히고, 필요하면 url을 사용자에게 안내한다"}


def render_text(cmd, data):
    def line(r, i=None):
        head = "%s%s (%s)" % ("%d. " % i if i else "", r.get("title"), r.get("year") or "?")
        meta = ", ".join(x for x in [
            r.get("venue"),
            "인용 %s" % r["citations"] if r.get("citations") is not None else None,
            "arXiv:%s" % r["arxiv"] if r.get("arxiv") else None,
            "DOI:%s" % r["doi"] if r.get("doi") else None,
            "PDF 있음" if r.get("oa_pdf") else None,
        ] if x)
        ident = "id: %s" % (("ARXIV:" + r["arxiv"]) if r.get("arxiv") else ("DOI:" + r["doi"]) if r.get("doi") else r.get("id"))
        return "\n   ".join(x for x in [head, ", ".join((r.get("authors") or [])[:3]), meta, ident, r.get("tldr")] if x)

    if cmd == "search":
        lines = ["[%s] 총 %s건 중 %d건" % (data["source"], data.get("total"), len(data["results"]))]
        if data.get("note"):
            lines.append("참고: " + data["note"])
        lines += [line(r, i) for i, r in enumerate(data["results"], 1)]
        return "\n\n".join(lines)
    if cmd == "paper":
        return line(data) + ("\n\n" + data["abstract"] if data.get("abstract") else "")
    if data["result"] == "ok":
        return "저장: %s (%s, 출처 %s)" % (data["path"], data["format"], data["from"])
    return "원문 없음: %s\n시도: %s" % (data["paper"].get("title"), "; ".join(data["tried"]) or "-")


def main(argv):
    ap = argparse.ArgumentParser(description="논문 검색과 오픈 액세스 원문 내려받기")
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("search")
    s.add_argument("query")
    s.add_argument("--limit", type=int, default=10)
    s.add_argument("--year", help="2023, 2020-2024, 2023- 형식")
    s.add_argument("--oa-only", action="store_true", help="오픈 액세스 원문이 있는 논문만")
    s.add_argument("--source", choices=["auto", "s2", "openalex"], default="auto")
    p = sub.add_parser("paper")
    p.add_argument("id")
    p.add_argument("--source", choices=["auto", "s2", "openalex"], default="auto")
    f = sub.add_parser("fetch")
    f.add_argument("id")
    f.add_argument("--out", default=str(DEFAULT_OUT))
    for x in (s, p, f):
        x.add_argument("--text", action="store_true", help="사람이 읽는 형식으로 출력")
    args = ap.parse_args(argv)
    args.limit = max(1, min(getattr(args, "limit", 10), 100))

    try:
        if args.cmd == "search":
            data = search(args)
        elif args.cmd == "paper":
            data = paper(args.id, args.source)
        else:
            data = fetch(args)
    except RateLimited:
        hint = "키 한도(초당 1회)를 넘었을 수 있습니다" if secret("S2_API_KEY") else "S2_API_KEY를 설정하면 한도가 늘어납니다"
        print("Error: 호출 한도 초과(429). 잠시 뒤 다시 하세요. %s." % hint, file=sys.stderr)
        return 1
    except NotFound:
        print("Error: 논문을 찾지 못했습니다: %s" % getattr(args, "id", getattr(args, "query", "")), file=sys.stderr)
        return 1
    except ApiError as e:
        print("Error: %s" % e, file=sys.stderr)
        return 1

    print(render_text(args.cmd, data) if args.text else json.dumps(data, ensure_ascii=False, indent=2))
    return 0 if args.cmd != "fetch" or data["result"] == "ok" else 3


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
