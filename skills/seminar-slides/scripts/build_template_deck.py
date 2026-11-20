"""마크다운 명세(## Slide N.)를 개인 템플릿(lecture-template.pptx)으로 옮긴다.

사용: python build_template_deck.py <템플릿.pptx> <명세.md> <출력.pptx>

명세 형식은 build_deck.py와 같다(제목, 헤드라인, 불릿, 표 1개, 뒤따르는 평문 줄,
'> 발표 멘트:'·'> 확인 메모:', '출처:'·'하단 서지:', '이미지: 경로 | 캡션').
추가로 장마다 '레이아웃: SECTION'처럼 레이아웃을 직접 지정할 수 있다.

레이아웃 선택(지정이 없을 때):
- 1번 장: COVER (헤드라인=부제, 뒤따르는 평문=발표자·날짜)
- 제목이 '부록'으로 시작: APPENDIX
- 그림만 있고 불릿·표가 없음: IMAGE
- 그림이 있음: TEXT_IMAGE (그림은 오른쪽 판 안에 비율을 지켜 넣음)
- 그 외: CONTENT (표는 불릿 아래에 배치)
템플릿의 견본 슬라이드는 모두 지우고 레이아웃만 쓴다.
"""
import io
import os
import re
import sys
import zipfile

from pptx import Presentation
from pptx.util import Emu, Pt
from pptx.dml.color import RGBColor
from PIL import Image

RED = RGBColor(0xC0, 0x00, 0x00)
CHECK = re.compile(r'(\[확인[^\]]*\])')
IN = 914400


def clean(s):
    return s.replace('**', '').replace('`', '')


def parse(md_path):
    slides, cur = [], None
    for raw in open(md_path, encoding='utf-8').read().splitlines():
        m = re.match(r'## Slide (\d+)\. (.*)', raw)
        if m:
            cur = dict(n=int(m.group(1)), title=m.group(2).strip(), headline='', bullets=[],
                       table=[], tail=[], notes='', memo=[], cite='', image=None, layout=None,
                       in_code=False)
            slides.append(cur)
            continue
        if cur is None:
            continue
        line = raw.rstrip()
        if line.startswith('```'):
            cur['in_code'] = not cur['in_code']
            continue
        if cur['in_code']:
            if line.strip():
                cur['tail'].append(line.strip())
            continue
        if line.strip() in ('', '---'):
            continue
        if line.startswith('레이아웃:'):
            cur['layout'] = line.split(':', 1)[1].strip()
        elif line.startswith('하단 서지:'):
            cur['cite'] = line[len('하단 서지:'):].strip()
        elif line.startswith('출처:'):
            cur['cite'] = cur['cite'] or line[3:].strip()
        elif line.startswith('> 발표 멘트:'):
            cur['notes'] = line[len('> 발표 멘트:'):].strip()
        elif line.startswith('> 확인 메모:'):
            cur['memo'].append(line[len('> 확인 메모:'):].strip())
        elif line.startswith('>'):
            continue
        elif line.startswith('이미지:'):
            p, _, cap = line[len('이미지:'):].partition('|')
            cur['image'] = (p.strip(), cap.strip())
        elif line.startswith('|'):
            cells = [clean(c.strip()) for c in line.strip('|').split('|')]
            if not all(set(c) <= set('-: ') for c in cells):
                cur['table'].append(cells)
        elif line.startswith('  - '):
            cur['bullets'].append((1, clean(line[4:])))
        elif line.startswith('- '):
            cur['bullets'].append((0, clean(line[2:])))
        else:
            text = clean(line)
            if not cur['headline'] and not cur['bullets'] and not cur['table']:
                cur['headline'] = text
            else:
                cur['tail'].append(text)
    return slides


def link_text(s):
    # 마크다운 링크 [글](주소) → 글(주소)
    return re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'\1 (\2)', s)


def add_runs(par, text, size=None, bold=None, color=None):
    for seg in CHECK.split(link_text(text)):
        if not seg:
            continue
        r = par.add_run()
        r.text = seg
        if size:
            r.font.size = Pt(size)
        if bold is not None:
            r.font.bold = bold
        if CHECK.fullmatch(seg):
            r.font.color.rgb = RED
        elif color is not None:
            r.font.color.rgb = color


# 레이아웃별 자리표시자 이름. make_template.js의 정의 순서와 같아야 한다(파일에는 번호만 남는다).
PH_ORDER = {
    'COVER': ['kicker', 'title', 'subtitle', 'presenter'],
    'SECTION': ['kicker', 'title', 'body', 'footer', 'cite'],
    'CONTENT': ['title', 'headline', 'body', 'footer', 'cite'],
    'TEXT_IMAGE': ['title', 'headline', 'body', 'caption', 'footer', 'cite'],
    'IMAGE': ['title', 'caption', 'footer', 'cite'],
    'APPENDIX': ['title', 'body', 'footer', 'cite'],
    'END': ['title', 'body'],
}
_IDX = {}


def ph(slide, name):
    lay = slide.slide_layout
    if lay.name not in _IDX:
        idxs = sorted(sh.placeholder_format.idx for sh in lay.placeholders
                      if sh.placeholder_format.idx != 4294967295)
        _IDX[lay.name] = dict(zip(PH_ORDER[lay.name], idxs))
    idx = _IDX[lay.name].get(name)
    if idx is None:
        return None
    for sh in slide.placeholders:
        if sh.placeholder_format.idx == idx:
            return sh
    return None


def set_text(shape, text, **kw):
    tf = shape.text_frame
    tf.clear()
    add_runs(tf.paragraphs[0], text, **kw)


def fill_bullets(shape, d, size, with_tail):
    tf = shape.text_frame
    tf.clear()
    tf.word_wrap = True
    items = [('b', lvl, t) for lvl, t in d['bullets']]
    if with_tail:
        items += [('t', 0, t) for t in d['tail']]
    for i, (kind, lvl, text) in enumerate(items):
        par = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        par.level = lvl
        par.space_after = Pt(6)
        m = re.match(r'^([^:：\[]{1,16}): (.*)$', text)
        s = size - (2 if lvl or kind == 't' else 0)
        if kind == 'b' and m and '(' not in m.group(1):
            add_runs(par, m.group(1) + ':', s, bold=True)
            add_runs(par, ' ' + m.group(2), s)
        else:
            add_runs(par, text, s)
        if kind == 't':
            pPr = par._p.get_or_add_pPr()
            for e in list(pPr):
                if e.tag.endswith('}buChar') or e.tag.endswith('}buAutoNum'):
                    pPr.remove(e)
            pPr.append(pPr.makeelement('{http://schemas.openxmlformats.org/drawingml/2006/main}buNone', {}))
    return len(items)


def text_height(shape_w, items, size):
    """대략적인 줄 수로 본문 높이를 잰다(한글 한 글자 ≈ 글자 크기 폭)."""
    chars_per_line = max(10, int(shape_w / (size * 12700)))
    lines = sum(1 + len(t) // chars_per_line for t in items)
    return int(lines * size * 12700 * 1.55)


def add_table(slide, rows, left, top, width, font):
    nrows, ncols = len(rows), len(rows[0])
    row_h = int(font * 12700 * 2.3)
    gs = slide.shapes.add_table(nrows, ncols, Emu(left), Emu(top), Emu(width), Emu(row_h * nrows))
    tbl = gs.table
    first = 0.3 if ncols == 2 else (1 / ncols)
    for ci in range(ncols):
        w = width * (first if ci == 0 else (1 - first) / (ncols - 1))
        tbl.columns[ci].width = Emu(int(w))
    # 칸이 좁으면 글이 접혀 행이 길어진다. 접힐 줄 수를 어림해 행 높이를 정한다
    # (한글 한 글자 폭 ≈ 글자 크기, 영문·숫자 ≈ 0.55배).
    import math
    widths = [tbl.columns[ci].width - 140000 for ci in range(ncols)]
    line_h = font * 12700 * 1.3
    total = 0
    for ri, row in enumerate(rows):
        lines = 1
        for ci in range(ncols):
            t = link_text(row[ci] if ci < len(row) else '')
            units = sum(1.0 if ord(ch) > 0x2E80 else 0.55 for ch in t)
            per = max(1, widths[ci] / (font * 12700))
            lines = max(lines, math.ceil(units / per) if units else 1)
        h = int(max(row_h, lines * line_h + 120000))
        tbl.rows[ri].height = Emu(h)
        total += h
    for ri, row in enumerate(rows):
        for ci in range(ncols):
            cell = tbl.cell(ri, ci)
            cell.text = ''
            val = row[ci] if ci < len(row) else ''
            add_runs(cell.text_frame.paragraphs[0], val, font, bold=(ri == 0))
            cell.margin_left = cell.margin_right = Emu(70000)
    return top + total


def place_image(slide, path, box, caption_shape, caption):
    x, y, w, h = box
    im = Image.open(path).convert('RGB')
    if im.width > 1400:
        im = im.resize((1400, round(im.height * 1400 / im.width)), Image.LANCZOS)
    im = im.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    buf = io.BytesIO()
    im.save(buf, 'PNG', optimize=True)
    buf.seek(0)
    ratio = im.width / im.height
    pw, phh = w, int(w / ratio)
    if phh > h:
        phh, pw = h, int(h * ratio)
    slide.shapes.add_picture(buf, Emu(x + (w - pw) // 2), Emu(y + (h - phh) // 2), Emu(pw), Emu(phh))
    if caption_shape is not None:
        if caption:
            set_text(caption_shape, caption, size=10)
        else:
            caption_shape._element.getparent().remove(caption_shape._element)


def drop_unused(slide, names):
    for n in names:
        sh = ph(slide, n)
        if sh is not None and not sh.text_frame.text.strip():
            sh._element.getparent().remove(sh._element)


def choose(d):
    if d['layout']:
        return d['layout']
    if d['n'] == 1:
        return 'COVER'
    if d['title'].startswith('부록'):
        return 'APPENDIX'
    if d['image'] and not d['bullets'] and not d['table']:
        return 'IMAGE'
    if d['image']:
        return 'TEXT_IMAGE'
    return 'CONTENT'


def main():
    tmpl, spec, out = sys.argv[1:4]
    md_dir = os.path.dirname(os.path.abspath(spec))
    slides = parse(spec)
    prs = Presentation(tmpl)
    layouts = {l.name: l for l in prs.slide_layouts}
    sld = prs.slides._sldIdLst
    for s in list(sld):
        prs.part.drop_rel(s.rId)
        sld.remove(s)
    deck_title = slides[0]['title'] if slides else ''

    for d in slides:
        name = choose(d)
        s = prs.slides.add_slide(layouts[name])
        set_text(ph(s, 'title'), d['title'])
        if ph(s, 'footer') is not None:
            set_text(ph(s, 'footer'), deck_title)
        if ph(s, 'cite') is not None and d['cite']:
            set_text(ph(s, 'cite'), d['cite'], size=9)

        if name == 'COVER':
            set_text(ph(s, 'kicker'), '강의')
            if d['headline']:
                set_text(ph(s, 'subtitle'), d['headline'])
            if d['tail']:
                set_text(ph(s, 'presenter'), ' · '.join(d['tail']))
            drop_unused(s, ['subtitle', 'presenter'])
        elif name in ('SECTION', 'END'):
            if ph(s, 'kicker') is not None:
                set_text(ph(s, 'kicker'), d['headline'] or '')
            body = ph(s, 'body')
            if body is not None:
                fill_bullets(body, d, 18, with_tail=True)
            drop_unused(s, ['kicker', 'body', 'cite'])
        else:
            head = ph(s, 'headline')
            if head is not None and d['headline']:
                set_text(head, d['headline'])
            body = ph(s, 'body')
            size = 12 if name == 'APPENDIX' else (16 if d['table'] else 18)
            if body is not None:
                # 레이아웃에서 물려받은 위치·크기를 먼저 읽는다. 크기를 하나만 바꾸면 나머지가 0이 된다.
                bl, bt, bw = body.left, body.top, body.width
                n_items = fill_bullets(body, d, size, with_tail=not d['table'])
                if d['table']:
                    # 표는 불릿 바로 아래
                    texts = [t for _, t in d['bullets']]
                    hgt = text_height(bw, texts, size) if texts else 0
                    body.left, body.top, body.width, body.height = bl, bt, bw, Emu(max(hgt, 1))
                    top = bt + hgt + (int(0.15 * IN) if texts else 0)
                    font = 11 if name == 'APPENDIX' else (12 if len(d['table']) > 6 else 13)
                    y = add_table(s, d['table'], bl, top, bw, font)
                    if d['tail']:
                        tb = s.shapes.add_textbox(bl, Emu(y + int(0.12 * IN)), bw, Emu(int(0.5 * IN)))
                        tb.text_frame.word_wrap = True
                        for i, t in enumerate(d['tail']):
                            par = tb.text_frame.paragraphs[0] if i == 0 else tb.text_frame.add_paragraph()
                            add_runs(par, t, 13)
                if not n_items and not d['table']:
                    body._element.getparent().remove(body._element)
            if d['image']:
                img, cap = d['image']
                if not os.path.isabs(img):
                    img = os.path.join(md_dir, img)
                if name == 'IMAGE':
                    box = (int(0.9 * IN), int(1.5 * IN), int(11.53 * IN), int(4.6 * IN))
                else:
                    box = (int(7.15 * IN), int(1.5 * IN), int(5.4 * IN), int(4.5 * IN))
                place_image(s, img, box, ph(s, 'caption'), cap)
            drop_unused(s, ['headline', 'caption', 'cite'])

        note = d['notes']
        if d['memo']:
            note += '\n\n[확인 메모]\n' + '\n'.join('- ' + m for m in d['memo'])
        if note.strip():
            s.notes_slide.notes_text_frame.text = note.strip()

    raw = io.BytesIO()
    prs.save(raw)
    # 문서 정보의 장 수를 실제에 맞춘다
    zin = zipfile.ZipFile(raw)
    zout = zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED)
    for item in zin.infolist():
        data = zin.read(item.filename)
        if item.filename == 'docProps/app.xml':
            data = re.sub(rb'<Slides>\d+</Slides>', b'<Slides>%d</Slides>' % len(prs.slides), data)
        zout.writestr(item, data)
    zout.close()
    print('saved', out, 'slides', len(prs.slides))


if __name__ == '__main__':
    main()
