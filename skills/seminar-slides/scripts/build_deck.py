"""마크다운 명세(## Slide N.)를 월간세미나 템플릿 pptx로 옮긴다.

사용: python build_deck.py <템플릿.pptx> <명세.md> <출력.pptx>
- 템플릿의 1~3번 슬라이드(표지, 그림 포함 본문 2장)를 재사용하고 마지막 빈 장은 지운다.
- 명세 한 장의 구성: 제목, 헤드라인(평문 한 줄), 불릿, 표(최대 1개), 뒤에 오는 평문 줄,
  '> 발표 멘트:'와 '> 확인 메모:'는 슬라이드 노트, '출처:'/'하단 서지:'는 하단 인용.
"""
import copy, re, sys
from pptx import Presentation
from pptx.util import Emu, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN

A = '{http://schemas.openxmlformats.org/drawingml/2006/main}'
RED = RGBColor(0xC0, 0x00, 0x00)
CHECK = re.compile(r'(\[확인[^\]]*\])')


def clean(s):
    return s.replace('**', '').replace('`', '')


def parse(md_path):
    slides, cur = [], None
    for raw in open(md_path, encoding='utf-8').read().splitlines():
        if raw.startswith('## 예상 질문'):
            break
        m = re.match(r'## Slide (\d+)\. (.*)', raw)
        if m:
            cur = dict(n=int(m.group(1)), title=m.group(2).strip(), headline='', bullets=[],
                       table=[], tail=[], notes='', memo=[], cite_short='', cite_full='', image=None)
            slides.append(cur)
            continue
        if cur is None or raw.strip() in ('', '---'):
            continue
        line = raw.rstrip()
        if re.match(r'PRML 세미나 \d+ 페이지', line):
            continue
        if line.startswith('출처:'):
            cur['cite_short'] = line[3:].strip()
        elif line.startswith('하단 서지:'):
            cur['cite_full'] = line[len('하단 서지:'):].strip()
        elif line.startswith('> 발표 멘트:'):
            cur['notes'] = line[len('> 발표 멘트:'):].strip()
        elif line.startswith('이미지:'):
            path, _, cap = line[len('이미지:'):].partition('|')
            cur['image'] = (path.strip(), cap.strip())
        elif line.startswith('> 확인 메모:'):
            cur['memo'].append(line[len('> 확인 메모:'):].strip())
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


def no_bullet(par):
    pPr = par._p.get_or_add_pPr()
    for tag in ('buChar', 'buAutoNum', 'buNone'):
        for e in pPr.findall(A + tag):
            pPr.remove(e)
    pPr.append(pPr.makeelement(A + 'buNone', {}))
    pPr.set('marL', '0')
    pPr.set('indent', '0')


def add_runs(par, text, size, bold=False):
    for seg in CHECK.split(text):
        if not seg:
            continue
        r = par.add_run()
        r.text = seg
        r.font.size = Pt(size)
        r.font.bold = bold or None
        if CHECK.fullmatch(seg):
            r.font.color.rgb = RED
        elif re.fullmatch(r'\(.*\)', seg.strip()):
            r.font.color.rgb = RGBColor(0x80, 0x80, 0x80)
            r.font.italic = True


def fill_body(tf, d, head_size, size, with_tail):
    tf.word_wrap = True
    for p in list(tf.paragraphs)[1:]:
        p._p.getparent().remove(p._p)
    first = tf.paragraphs[0]
    for r in list(first.runs):
        r._r.getparent().remove(r._r)
    items = []
    if d['headline']:
        items.append(('head', 0, d['headline']))
    items += [('bullet', lvl, t) for lvl, t in d['bullets']]
    if with_tail:
        items += [('tail', 0, t) for t in d['tail']]
    for i, (kind, lvl, text) in enumerate(items):
        par = first if i == 0 else tf.add_paragraph()
        par.level = lvl if kind == 'bullet' else 0
        if kind == 'head':
            no_bullet(par)
            add_runs(par, text, head_size, bold=True)
            par.space_after = Pt(10)
        elif kind == 'tail':
            no_bullet(par)
            add_runs(par, text, size - 2)
            par.space_before = Pt(8)
        else:
            m = re.match(r'^([^:：\[]{1,16}): (.*)$', text)
            if m and '(' not in m.group(1):
                add_runs(par, m.group(1) + ':', size - (2 if lvl else 0), bold=True)
                add_runs(par, ' ' + m.group(2), size - (2 if lvl else 0))
            else:
                add_runs(par, text, size - (2 if lvl else 0))
            par.space_after = Pt(4)
    return len(items)


def add_table(slide, rows, left, top, width, font):
    nrows, ncols = len(rows), len(rows[0])
    row_h = int(font * 12700 * 2.6)
    gs = slide.shapes.add_table(nrows, ncols, Emu(left), Emu(top), Emu(width), Emu(row_h * nrows))
    tbl = gs.table
    first_w = 0.28 if ncols == 2 and rows[0][0] in ('단계', '조건', '규약') else (1 / ncols if ncols > 2 else 0.4)
    for ci in range(ncols):
        w = width * (first_w if ci == 0 else (1 - first_w) / (ncols - 1))
        tbl.columns[ci].width = Emu(int(w))
    for r in tbl.rows:
        r.height = Emu(row_h)
    for ri, row in enumerate(rows):
        for ci, val in enumerate(row):
            cell = tbl.cell(ri, ci)
            cell.text = ''
            add_runs(cell.text_frame.paragraphs[0], val, font, bold=(ri == 0))
    return top + row_h * nrows


def add_tail_box(slide, lines, left, top, width, size):
    tb = slide.shapes.add_textbox(Emu(left), Emu(top), Emu(width), Emu(700000))
    tb.text_frame.word_wrap = True
    for i, t in enumerate(lines):
        par = tb.text_frame.paragraphs[0] if i == 0 else tb.text_frame.add_paragraph()
        add_runs(par, t, size)
        par.space_before = Pt(6)


def set_cite(shape, text):
    tf = shape.text_frame
    runs = tf.paragraphs[0].runs
    for r in runs[1:]:
        r._r.getparent().remove(r._r)
    for extra in tf.paragraphs[1:]:
        extra._p.getparent().remove(extra._p)
    if runs:
        runs[0].text = text
        runs[0].font.size = Pt(8)
    shape.left, shape.top = Emu(1900000), Emu(6400000)
    shape.width, shape.height = Emu(8600000), Emu(450000)


def fix_number(shape, n):
    for fld in shape._element.iter(A + 'fld'):
        for t in fld.iter(A + 't'):
            t.text = str(n)


def ph(slide, idx):
    for sh in slide.placeholders:
        if sh.placeholder_format.idx == idx:
            return sh


def layout_slide(s, d, left, width, top, small):
    """본문 placeholder(헤드라인+불릿), 표, 꼬리 줄을 위에서 아래로 배치한다."""
    body = ph(s, 1)
    if d['image']:
        width = 5700000
    head_size, size, tfont = (17, 15, 12) if small else (22, 20, 14)
    if len(d['table']) > 5:
        tfont = 12
    if d['table'] and not small:
        size = 18
    body.left, body.width = Emu(left), Emu(width)
    body.top = Emu(top)
    n_head = (len(d['headline']) // (22 if small else 40)) + 1 if d['headline'] else 0
    n_items = n_head + sum(1 + len(t) // (26 if small else 55) for _, t in d['bullets'])
    n_tail = 0 if d['table'] else len(d['tail'])
    line_h = int(size * 12700 * 1.75)
    body.height = Emu(max(600000, line_h * (n_items + n_tail) + 250000))
    fill_body(body.text_frame, d, head_size, size, with_tail=not d['table'])
    y = top + body.height + 120000
    if d['table']:
        y = add_table(s, d['table'], left, y, width, tfont) + 150000
        if d['tail']:
            add_tail_box(s, d['tail'], left, y, width, size - 2)


slides = parse(sys.argv[2])
prs = Presentation(sys.argv[1])
tmpl = list(prs.slides)
foot_src = [sh for sh in tmpl[2].placeholders if sh.placeholder_format.idx in (11, 12, 4294967295)]

sld_ids = prs.slides._sldIdLst
last = sld_ids[3]
prs.part.drop_rel(last.rId)
sld_ids.remove(last)

for d in slides:
    n = d['n']
    if n == 1:
        s = tmpl[0]
        tb = s.shapes.add_textbox(Emu(1524000), Emu(3850000), Emu(9144000), Emu(900000))
        par = tb.text_frame.paragraphs[0]
        par.alignment = PP_ALIGN.CENTER
        add_runs(par, ' '.join(d['tail']), 20)
        continue
    if n in (2, 3):
        s = tmpl[n - 1]
        left, width, top, small = (6450000, 5300000, 1600000, True) if n == 2 else (6200000, 5500000, 1850000, True)
    else:
        s = prs.slides.add_slide(prs.slide_layouts[1])
        for sh in foot_src:
            s.shapes._spTree.append(copy.deepcopy(sh._element))
        left, width, top, small = 838199, 10515600, 1658283, False
    title = s.shapes.title
    title.text_frame.text = d['title']
    for r in title.text_frame.paragraphs[0].runs:
        r.font.size = Pt(32 if len(d['title']) < 28 else 28)
        r.font.bold = True
    layout_slide(s, d, left, width, top, small)
    if d['image']:
        img, cap = d['image']
        import os
        md_dir = os.path.dirname(os.path.abspath(sys.argv[2]))
        if not os.path.isabs(img):
            # 명세 폴더에서 먼저 찾고, 없으면 상위 폴더에서 찾는다
            img = next((c for c in (os.path.join(md_dir, img), os.path.join(os.path.dirname(md_dir), img)) if os.path.exists(c)), os.path.join(md_dir, img))
        pic = s.shapes.add_picture(img, Emu(6750000), Emu(1750000), width=Emu(4850000))
        tb = s.shapes.add_textbox(Emu(6750000), pic.top + pic.height + Emu(60000), Emu(4850000), Emu(500000))
        tb.text_frame.word_wrap = True
        add_runs(tb.text_frame.paragraphs[0], cap, 10)
    set_cite(ph(s, 4294967295), d['cite_full'] or d['cite_short'])
    fix_number(ph(s, 12), n)
    note = d['notes']
    if d['memo']:
        note += '\n\n[확인 메모]\n' + '\n'.join('- ' + m for m in d['memo'])
    if note:
        s.notes_slide.notes_text_frame.text = note

prs.save(sys.argv[3])
print('saved', sys.argv[3], 'slides', len(prs.slides))
