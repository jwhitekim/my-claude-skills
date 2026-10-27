# README 문장·링크·시각 자료 기준

초안과 다듬기에 적용한다. 읽는 사람이 시작에 필요한 정보를 쉽게 찾는지가 기준이다.

## 문장과 문단

- 한 문장에는 생각 하나만 담는다. 조건이 겹치면 문장을 나누거나 목록으로 푼다.
- 한 문단에는 주제 하나만 담는다. 핵심을 먼저 쓰고, 다른 주제는 문단을 나눈다.
- 표 셀에는 짧은 용도를 쓴다. 상세 설명과 예외는 별도 문서나 섹션으로 링크한다.
- 복사해 실행할 명령은 문장 안에 넣지 않고 코드 블록으로 분리한다.

아래 수치는 영어 개발자 문서 지침이다. 합격 조건이 아니라 **검토 신호**로만 쓰고,
한국어에 고정 단어 수나 문장 수를 만들지 않는다.
수치를 맞추려고 문장을 늘이거나 한 주제를 억지로 쪼개지 않는다.

- 문장 26단어 미만 ([Google 접근성 가이드](https://developers.google.com/style/accessibility#ease-of-reading))
- 문단이 5~6문장을 넘으면 정보가 과한지 검토. 한 주제라면 더 길어도 된다 ([Google 문단 구조 가이드](https://developers.google.com/style/paragraph-structure))

문장을 나누는 기준은 [Google의 짧은 문장 지침](https://developers.google.com/tech-writing/one/short-sentences)을 참고한다.
코드를 표에 넣지 않는 이유는 [Google 표 작성 지침](https://developers.google.com/style/tables#places-not-to-use-tables)에서 확인할 수 있다.

## 링크와 목차

- 저장소 내부 문서는 현재 README 위치를 기준으로 상대 링크를 쓴다.
- 링크 텍스트만 읽어도 목적지를 알 수 있게 쓴다. `여기`, `문서` 같은 이름은 쓰지 않는다.
  예를 들어 `환경변수 설정 안내`, `API 참조`, `배포 절차`처럼 구체적으로 적는다.
- 제목 앵커는 GitHub에서 렌더링된 제목의 링크로 확인한다.
  제목을 바꾸면 목차와 해당 제목을 가리키는 링크도 갱신한다.
- 일반 README의 목차는 섹션 수와 탐색 필요성으로 판단한다. GitHub 자동 Outline도 고려한다.
  짧아도 자주 찾아갈 섹션이 있으면 목차를 둘 수 있다.
- standard-readme 엄격 준수 요청이 있을 때만 명세의 줄 수 기준을 적용한다.
  목차는 100줄 이상이면 필수이고, 100줄 미만이면 선택이다.

근거: [GitHub README의 상대 링크·제목 앵커·자동 목차](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes),
[Google의 의미 있는 링크 텍스트 지침](https://developers.google.com/style/accessibility#links),
[standard-readme 목차 명세](https://github.com/RichardLitt/standard-readme/blob/main/spec.md#table-of-contents-1).

## 시각 자료 선택

시각 자료는 목적에 따라 고른다. 없다는 것 자체를 결함으로 보지 않는다.
이 스킬은 다음 기준을 적용한다.

- UI: 사용 결과를 이해하는 데 도움이 되는 화면 스크린샷을 고른다.
- CLI: 복사할 수 있는 코드와 출력 텍스트를 우선한다.
- 구성 요소 관계·흐름: GitHub에서 지원하는 Mermaid를 쓴다.
- 배지: 빌드 상태나 지원 버전처럼 사용 판단에 필요한 상태만 보여 준다.
- 시연: GIF는 필수가 아니다. 긴 시연은 영상 링크와 텍스트 요약을 함께 둔다.

[GitHub Mermaid 안내](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams)처럼
`mermaid` 코드 블록을 사용한다. 그림 없이도 흐름을 이해할 수 있도록 본문 설명을 붙인다.
Mermaid에는 [`accTitle`과 `accDescr`](https://mermaid.js.org/config/accessibility.html)로 대체 설명도 제공한다.

## 이미지와 대체 설명

- 이미지는 저장소 안의 기존 자산 폴더에 둔다. 적절한 폴더가 없으면 `docs/images/`를 쓴다.
  README에서는 현재 파일 기준의 상대 경로로 연결한다.
- 이미지에는 alt가 필수다. Markdown은 `![핵심 정보](상대 경로)`, HTML은 `alt` 속성을 쓴다.
  장식용 이미지는 `alt=""`로 둔다. 링크로 쓰는 이미지는 목적지를 설명한다.
- 복잡한 그림에는 짧은 alt와 본문 설명을 함께 둔다. 관계·흐름·결과를 텍스트로도 전달한다.
  긴 설명을 alt에 모두 밀어 넣지 않는다.

근거: [W3C 이미지 대체 텍스트 안내](https://www.w3.org/WAI/tutorials/images/),
[W3C 복잡한 그림의 설명 지침](https://www.w3.org/WAI/tutorials/images/complex/).

다크 모드에서 구분이 어려우면 `<picture>`와 `prefers-color-scheme`으로 이미지를 바꾼다.
아래는 루트 README용 예시다. 실제 파일 경로와 화면 설명으로 바꿔 쓴다.
기본 이미지는 `img`의 `src`에 둔다.

```html
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/result-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="docs/images/result-light.png">
  <img src="docs/images/result-light.png" alt="검색 결과 목록과 선택한 항목의 상세 화면">
</picture>
```

근거: [GitHub의 밝은 모드·다크 모드 이미지 예시](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/quickstart-for-writing-on-github#adding-an-image-to-suit-your-visitors).

## 렌더링 확인

이미지·Mermaid·표를 썼으면 GitHub 미리보기나 렌더링된 파일에서 확인한다.
이미지 경로와 alt, 그림의 밝은 모드·다크 모드 가독성, Mermaid 오류, 표의 줄바꿈을 점검한다.
로컬 미리보기만으로 GitHub 렌더링까지 확인했다고 하지 않는다.
확인하지 못했으면 제시 단계에서 대상과 한계를 밝힌다.
예: `상대 경로는 확인했지만 GitHub에서 이미지·표 렌더링은 확인하지 못했습니다.`
