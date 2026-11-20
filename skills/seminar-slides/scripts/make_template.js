// 개인 강의·세미나 템플릿 생성기 (pptxgenjs)
// 사용: NODE_PATH=<pptxgenjs가 설치된 node_modules> node make_template.js <출력.pptx>
// 출력.pptx(견본 7장 포함)와 같은 이름의 .potx(PowerPoint 서식 파일)를 함께 만든다.
// 레이아웃 이름은 build_deck.py가 그대로 찾으므로 바꾸면 스크립트도 함께 고친다.
const path = require("path");
const pptxgen = require("pptxgenjs");
const fs = require("fs");
const JSZip = require("jszip"); // pptxgenjs가 함께 설치한다

// pptxgenjs는 테마 색을 쓰지 못하므로, 저장한 뒤 theme1.xml의 색 구성표만 바꾼다
const SLOTS = ["dk1", "lt1", "dk2", "lt2", "accent1", "accent2", "accent3", "accent4", "accent5", "accent6", "hlink", "folHlink"];
async function applyTheme(file, theme) {
  const zip = await JSZip.loadAsync(fs.readFileSync(file));
  const part = "ppt/theme/theme1.xml";
  const xml = await zip.file(part).async("string");
  const scheme = `<a:clrScheme name="${theme.name}">` +
    SLOTS.map((k) => `<a:${k}><a:srgbClr val="${theme.colors[k]}"/></a:${k}>`).join("") + "</a:clrScheme>";
  const out = xml.replace(/<a:clrScheme\b[\s\S]*?<\/a:clrScheme>/, scheme)
    .replace(/(<a:(?:theme|fontScheme)\b[^>]*?\bname=")[^"]*"/g, (_, h) => `${h}${theme.name}"`);
  if (!out.includes(scheme)) throw new Error("theme1.xml에 clrScheme이 없습니다");
  zip.file(part, out);
  fs.writeFileSync(file, await zip.generateAsync({ type: "nodebuffer", compression: "DEFLATE" }));
}

// .potx(서식 파일): 본문 파트의 콘텐츠 형식만 template으로 바꾼다
async function toPotx(src, dst) {
  const zip = await JSZip.loadAsync(fs.readFileSync(src));
  const ct = await zip.file("[Content_Types].xml").async("string");
  zip.file("[Content_Types].xml", ct.replace(
    "application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml",
    "application/vnd.openxmlformats-officedocument.presentationml.template.main+xml"));
  fs.writeFileSync(dst, await zip.generateAsync({ type: "nodebuffer", compression: "DEFLATE" }));
}

// 색은 강의 그림(GPT 이미지)에서 뽑은 남색·청록·주황 계열
const THEME = {
  name: "Lecture Teal",
  headFontFace: "Pretendard",
  bodyFontFace: "Pretendard",
  colors: {
    dk1: "0B1F45", // 본문·제목 남색
    lt1: "FFFFFF",
    dk2: "0B1F45",
    lt2: "EAF7F4", // 그림 판 배경(옅은 청록)
    accent1: "0F7C8C", // 청록(흰 바탕 글자용으로 어둡게)
    accent2: "F28C28", // 주황 강조(장당 한 곳)
    accent3: "C6EDE6", // 옅은 청록 채움
    accent4: "5A6475", // 보조 글자(회색 남색)
    accent5: "48C0D0", // 밝은 청록
    accent6: "9AA3AF",
    hlink: "0F7C8C",
    folHlink: "5A6475",
  },
};

const out = process.argv[2] || "harness-template.pptx";
const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13.333 x 7.5 in
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
pres.author = "";
pres.title = "Lecture Template";
const C = pres.SchemeColor;

const W = 13.333, H = 7.5, M = 0.6; // 여백 0.6in
const footerY = 7.0;

// 공통 바닥글: 왼쪽 강의명(자리표시자), 오른쪽 쪽 번호, 가운데 하단 서지(자리표시자)
function footer(dark) {
  const ink = dark ? C.background1 : C.accent4;
  return [
    { placeholder: { options: { name: "footer", type: "body", x: M, y: footerY, w: 4.2, h: 0.3,
        fontSize: 10, color: ink, valign: "middle", margin: 0 }, text: "강의명" } },
    { placeholder: { options: { name: "cite", type: "body", x: 4.9, y: footerY, w: 6.6, h: 0.3,
        fontSize: 9, color: ink, align: "center", valign: "middle", margin: 0 }, text: "" } },
  ];
}
const slideNumber = (dark) => ({ x: W - M - 0.8, y: footerY, w: 0.8, h: 0.3, fontSize: 10,
  color: dark ? "FFFFFF" : "5A6475", align: "right", fontFace: "Pretendard" });

// pptxgenjs가 옵션 객체를 제자리에서 바꾸므로 레이아웃마다 새 객체를 만든다
const titleOpts = () => ({ name: "title", type: "body", x: M, y: 0.45, w: W - 2 * M, h: 0.8,
  fontSize: 30, bold: true, color: C.text1, valign: "middle", align: "left", margin: 0 });
const headlineOpts = (w) => ({ name: "headline", type: "body", x: M, y: 1.3, w, h: 0.5,
  fontSize: 18, color: C.accent1, valign: "top", margin: 0 });

// 1. 표지: 남색 바탕
pres.defineSlideMaster({
  title: "COVER",
  background: { color: THEME.colors.dk1 },
  objects: [
    { placeholder: { options: { name: "kicker", type: "body", x: M + 0.2, y: 2.0, w: 9, h: 0.4,
        fontSize: 16, color: C.accent2, bold: true, margin: 0 }, text: "강의 · 세미나" } },
    { placeholder: { options: { name: "title", type: "body", x: M + 0.2, y: 2.5, w: 11, h: 1.6,
        fontSize: 44, bold: true, color: C.background1, valign: "top", align: "left", margin: 0 }, text: "제목" } },
    { placeholder: { options: { name: "subtitle", type: "body", x: M + 0.2, y: 4.2, w: 11, h: 0.6,
        fontSize: 20, color: C.accent3, margin: 0 }, text: "부제" } },
    { placeholder: { options: { name: "presenter", type: "body", x: M + 0.2, y: 5.7, w: 8, h: 0.8,
        fontSize: 14, color: C.background1, margin: 0 }, text: "발표자 · 날짜" } },
  ],
});

// 2. 파트 구분: 남색 바탕, 큰 제목
pres.defineSlideMaster({
  title: "SECTION",
  background: { color: THEME.colors.dk1 },
  objects: [
    { placeholder: { options: { name: "kicker", type: "body", x: M + 0.2, y: 2.6, w: 9, h: 0.5,
        fontSize: 18, color: C.accent2, bold: true, margin: 0 }, text: "Part" } },
    { placeholder: { options: { name: "title", type: "body", x: M + 0.2, y: 3.1, w: 11.5, h: 1.4,
        fontSize: 40, bold: true, color: C.background1, valign: "top", align: "left", margin: 0 }, text: "파트 제목" } },
    { placeholder: { options: { name: "body", type: "body", x: M + 0.2, y: 4.6, w: 11, h: 1.2,
        fontSize: 18, color: C.accent3, margin: 0 }, text: "이 파트에서 다룰 것" } },
    ...footer(true),
  ],
  slideNumber: slideNumber(true),
});

// 3. 본문: 제목 + 헤드라인 + 불릿(표가 오면 같은 영역 아래쪽에 스크립트가 배치)
pres.defineSlideMaster({
  title: "CONTENT",
  background: { color: THEME.colors.lt1 },
  margin: [0.5, M, 0.6, M],
  objects: [
    { placeholder: { options: titleOpts(), text: "제목" } },
    { placeholder: { options: headlineOpts(W - 2 * M), text: "헤드라인 한 줄" } },
    { placeholder: { options: { name: "body", type: "body", x: M, y: 2.0, w: W - 2 * M, h: 4.7,
        fontSize: 18, color: C.text1, valign: "top", margin: 0, paraSpaceAfter: 6 },
        text: "불릿" } },
    ...footer(false),
  ],
  slideNumber: slideNumber(false),
});

// 4. 글 + 그림: 왼쪽 글, 오른쪽 옅은 청록 판 위 그림(둥근 판이 이 템플릿의 시각 모티프)
const panel = { x: 6.95, y: 1.3, w: 5.8, h: 5.4 };
pres.defineSlideMaster({
  title: "TEXT_IMAGE",
  background: { color: THEME.colors.lt1 },
  objects: [
    { text: { text: "", options: { shape: pres.ShapeType.roundRect, x: panel.x, y: panel.y, w: panel.w, h: panel.h,
        rectRadius: 0.25, fill: { color: THEME.colors.lt2 }, line: { color: THEME.colors.lt2 } } } },
    { placeholder: { options: titleOpts(), text: "제목" } },
    { placeholder: { options: headlineOpts(5.9), text: "헤드라인 한 줄" } },
    { placeholder: { options: { name: "body", type: "body", x: M, y: 2.0, w: 5.9, h: 4.7,
        fontSize: 18, color: C.text1, valign: "top", margin: 0, paraSpaceAfter: 6 },
        text: "불릿" } },
    { placeholder: { options: { name: "caption", type: "body", x: panel.x + 0.3, y: panel.y + panel.h - 0.45,
        w: panel.w - 0.6, h: 0.3, fontSize: 10, color: C.accent4, align: "center", margin: 0 }, text: "그림 설명" } },
    ...footer(false),
  ],
  slideNumber: slideNumber(false),
});

// 5. 큰 그림: 제목 + 넓은 그림 판
pres.defineSlideMaster({
  title: "IMAGE",
  background: { color: THEME.colors.lt1 },
  objects: [
    { text: { text: "", options: { shape: pres.ShapeType.roundRect, x: M, y: 1.3, w: W - 2 * M, h: 5.4,
        rectRadius: 0.25, fill: { color: THEME.colors.lt2 }, line: { color: THEME.colors.lt2 } } } },
    { placeholder: { options: titleOpts(), text: "제목" } },
    { placeholder: { options: { name: "caption", type: "body", x: M + 0.3, y: 6.25, w: W - 2 * M - 0.6, h: 0.3,
        fontSize: 10, color: C.accent4, align: "center", margin: 0 }, text: "그림 설명" } },
    ...footer(false),
  ],
  slideNumber: slideNumber(false),
});

// 6. 부록·참고 문헌: 작은 글씨 본문
pres.defineSlideMaster({
  title: "APPENDIX",
  background: { color: THEME.colors.lt1 },
  objects: [
    { placeholder: { options: { ...titleOpts(), fontSize: 24 }, text: "부록" } },
    { placeholder: { options: { name: "body", type: "body", x: M, y: 1.4, w: W - 2 * M, h: 5.3,
        fontSize: 12, color: C.text1, valign: "top", margin: 0 }, text: "참고 문헌" } },
    ...footer(false),
  ],
  slideNumber: slideNumber(false),
});

// 7. 마지막 장
pres.defineSlideMaster({
  title: "END",
  background: { color: THEME.colors.dk1 },
  objects: [
    { placeholder: { options: { name: "title", type: "body", x: M + 0.2, y: 2.8, w: 11.5, h: 1.2,
        fontSize: 40, bold: true, color: C.background1, align: "left", margin: 0 }, text: "감사합니다" } },
    { placeholder: { options: { name: "body", type: "body", x: M + 0.2, y: 4.1, w: 11, h: 1.4,
        fontSize: 16, color: C.accent3, margin: 0 }, text: "질문 · 연락처 · 링크" } },
  ],
});

// 견본 슬라이드: 레이아웃마다 한 장씩, 어떻게 보이는지 확인용
const S = (name) => pres.addSlide({ masterName: name });
let s = S("COVER");
s.addText("강의 · 세미나", { placeholder: "kicker" });
s.addText("발표 제목", { placeholder: "title" });
s.addText("부제: 이 발표에서 전할 한 줄", { placeholder: "subtitle" });
s.addText("발표자 · 날짜", { placeholder: "presenter" });

s = S("SECTION");
s.addText("Part A", { placeholder: "kicker" });
s.addText("파트 제목", { placeholder: "title" });
s.addText("이 파트에서 다룰 내용 한 줄", { placeholder: "body" });
s.addText("발표 제목", { placeholder: "footer" });

s = S("CONTENT");
s.addText("CONTENT: 본문 장", { placeholder: "title" });
s.addText("헤드라인: 이 장의 주장 한 줄", { placeholder: "headline" });
s.addText([
  { text: "불릿은 4개 이하, 25자 안팎", options: { bullet: true, breakLine: true } },
  { text: "라벨: 설명 형식이면 라벨이 굵게", options: { bullet: true, breakLine: true } },
  { text: "표는 불릿 아래에 놓인다", options: { bullet: true, breakLine: true } },
  { text: "발표 멘트는 슬라이드 노트로", options: { bullet: true } },
], { placeholder: "body" });
s.addText("발표 제목", { placeholder: "footer" });

s = S("TEXT_IMAGE");
s.addText("TEXT_IMAGE: 글과 그림", { placeholder: "title" });
s.addText("헤드라인: 왼쪽 글, 오른쪽 그림 판", { placeholder: "headline" });
s.addText([
  { text: "그림은 판 안에 비율을 지켜 배치", options: { bullet: true, breakLine: true } },
  { text: "그림과 함께 놓는 표는 6행 이내", options: { bullet: true, breakLine: true } },
  { text: "캡션은 판 아래쪽 가운데", options: { bullet: true } },
], { placeholder: "body" });
s.addText("그림 설명(출처·생성 방법)", { placeholder: "caption" });
s.addText("하단 서지: 저자, 제목, 발표처, 연도", { placeholder: "cite" });
s.addText("발표 제목", { placeholder: "footer" });

s = S("IMAGE");
s.addText("IMAGE: 큰 그림·구조도", { placeholder: "title" });
s.addText("그림 설명", { placeholder: "caption" });
s.addText("발표 제목", { placeholder: "footer" });

s = S("APPENDIX");
s.addText("APPENDIX: 부록·참고 문헌", { placeholder: "title" });
s.addText("작은 글씨 본문과 표(장당 10행 이내)", { placeholder: "body" });
s.addText("발표 제목", { placeholder: "footer" });

s = S("END");
s.addText("감사합니다", { placeholder: "title" });
s.addText("질문 · 연락처 · 링크", { placeholder: "body" });

(async () => {
  await pres.writeFile({ fileName: out });
  await applyTheme(out, THEME);
  const potx = out.replace(/\.pptx$/, ".potx");
  await toPotx(out, potx);
  console.log("saved", out, potx);
})();
