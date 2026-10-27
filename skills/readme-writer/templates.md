# 프로젝트 유형별 README 뼈대

맞는 뼈대 하나를 복사해 저장소에서 확인한 내용으로 `<...>`를 채운다. 해당 없는 섹션은 지우고,
확인하지 못한 값은 추측하지 않고 빈칸으로 둔다. 제목 언어는 기존 README를 따른다.

## A. 라이브러리 / CLI

standard-readme의 설치·사용 흐름을 따른 간단형이다. 라이브러리면 사용 예시를 import와 호출 코드로 바꾼다.

````markdown
# <프로젝트명>

<무엇을 하고 왜 유용한지 한 줄 설명>

## 설치

요구사항: <런타임·버전·수동 설치 의존성>

```sh
<확인한 설치 명령>
```

## 사용법

```sh
<복사해 실행할 수 있는 최소 사용 예시>
```

기대 출력:

```text
<확인한 출력>
```

자세한 사용법·API: [문서](<문서 경로 또는 URL>)

## 개발

```sh
<확인한 테스트 명령>
<확인한 린트 명령>
```

## 기여

<문의 경로·PR 수락 여부·기여 조건 또는 확인한 기여 문서 링크>

## 라이선스

<SPDX 식별자> © <저작권자>. [라이선스 전문](<라이선스 파일 경로>)
````

**standard-readme를 엄격히 따라야 할 때**는 위 뼈대에 더해 다음을 지킨다.

- 순서: Title → Banner → Badges → Short Description → Long Description → Table of Contents →
  Security → Background → Install → Usage → (추가 섹션) → API → Maintainers → Thanks → Contributing → License
- 한 줄 설명은 120자 미만, 기여 섹션은 필수, 라이선스는 SPDX 식별자와 저작권자를 적어 마지막에 둔다.
- 100줄 이상이면 목차를 넣는다. 그 밖의 조건은 [원문 명세](https://github.com/RichardLitt/standard-readme/blob/main/spec.md)를 확인한다.

## B. 앱 / 서비스

처음 실행하는 순서를 Getting Started에 모은다. 환경변수 표는 `.env.example`이 있을 때 그 내용으로 채운다.

````markdown
# <프로젝트명>

<무엇을 하는 앱/서비스인지 한 줄 설명>

## Getting Started

요구사항: <런타임·버전·외부 서비스>

### 설치

```sh
<확인한 설치 명령>
```

### 환경변수

[환경변수 예제](<확인한 .env.example 상대 경로>)를 참고해 설정한다.

```sh
<확인한 환경 설정 명령>
```

| 변수 | 용도 | 필수 / 기본값 |
| --- | --- | --- |
| <확인한 변수명> | <용도> | <필수 여부 / 확인한 기본값> |

### 실행

```sh
<확인한 실행 명령>
```

<확인한 접속 주소 또는 기대 동작>

## 사용법

```sh
<확인한 최소 사용 예시>
```

<확인한 기대 출력 또는 화면 동작>

## 개발

```sh
<확인한 테스트 명령>
<확인한 린트 명령>
```

자세한 운영·설계: [문서](<문서 경로 또는 URL>)

## 라이선스

<확인한 라이선스>. [전문](<라이선스 파일 경로>)
````

## C. 내부 패키지 / 모노레포 하위 디렉터리

Google 가이드처럼 용도, 상태, 연락처, 사용법, 문서 링크를 중심으로 쓴다. 명령을 어디서 실행하는지 밝힌다.

````markdown
# <패키지명>

<패키지의 내용과 쓰임새 한 줄 설명>

상태: <사용 가능 범위·내부 전용·deprecated 여부 등 확인한 상태>
연락처: <담당 팀·관리자·문의 경로>

## 사용법

실행 위치: <저장소 루트 또는 패키지 디렉터리>

```sh
<확인한 복사 가능한 명령 또는 샘플 코드>
```

<확인한 기대 결과>

## 관련 문서

- [사용자 / 팀 문서](<상대 경로 또는 URL>)
- [루트 README](<루트 README 상대 경로>)

## 라이선스

<확인한 적용 라이선스>. [전문](<루트 또는 패키지 라이선스 상대 경로>)
````

## D. 도구 · 설정 모음 저장소

설치와 구성 목록 표를 중심으로 쓰고, 항목별 상세 사용법은 각 문서로 링크한다.

````markdown
# <저장소명>

<어떤 도구·설정을 누구에게 제공하는지 한 줄 설명>

## 설치

요구사항: <필요한 도구·지원 환경>

```sh
<확인한 설치 명령>
```

## 사용법

```sh
<설치 후 확인한 최소 사용 예시>
```

<확인한 기대 동작>

## 구성 목록

| 항목 | 용도 | 문서 |
| --- | --- | --- |
| <실제 항목명> | <확인한 용도> | [사용법](<항목 문서 상대 경로>) |

## 라이선스

<확인한 라이선스>. [전문](<라이선스 파일 경로>)
````

## 출처

| 양식 | 가져온 것 |
| --- | --- |
| [standard-readme](https://github.com/RichardLitt/standard-readme/blob/main/spec.md) | 섹션 순서, 설치·사용 코드 블록, 라이선스를 마지막에 두기 (A) |
| [Make a README](https://www.makeareadme.com/) | 프로젝트에 맞는 섹션만 고르기, 기대 출력이 있는 작은 예시 |
| [GitHub Docs](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes) | 시작과 기여에 필요한 정보만 담고 긴 문서는 링크 |
| [Google 스타일 가이드](https://google.github.io/styleguide/docguide/READMEs.html) | 용도·상태·연락처·문서 링크 (C) |
| [Best-README-Template](https://github.com/othneildrew/Best-README-Template) | Getting Started 구성 (B). 배지·로고·목차가 많은 전체 양식은 간단형에 넣지 않음 |
