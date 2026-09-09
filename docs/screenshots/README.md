# 앱스토어 스크린샷

기기: iPhone 17 Pro Max 시뮬레이터 (6.9")
캡처 원본 1320×2868 → 제출 규격 **1242×2688** 로 변환
(`ffmpeg -i in.png -vf "scale=1242:2699,crop=1242:2688" out.png`)

버전 2.0.1 / 라이트 모드 / 샘플 데이터

## ko/ — 한국어 (제출 가능)

| 파일 | 화면 | 무엇을 보여주나 |
|---|---|---|
| 01-greeting.png | 첫 만남 | 조약돌이 먼저 말을 건다 |
| 02-conversation.png | 대화 | 지난 기록을 기억하고 이어서 묻는다 |
| 03-conversation-flow.png | 대화 (이어짐) | 재촉하지 않는 말투, 답을 고르는 방식 |
| 04-stone-bridge.png | 지나온 길 | 한 주가 징검다리로, 밟지 않은 돌도 남는다 |
| 05-records.png | 남긴 것들 | 날짜순 원본, 감정 태그, 대안 |
| 06-settings.png | 설정 | 말투(존댓말/반말), 소리·진동 |

## en/ — 영어 (⚠️ 제출 불가, 현재 상태 증거)

영어 리스팅용으로 쓸 수 없다. **아래 두 장은 스크린샷이 아니라 근거 자료다.**

| 파일 | 무엇을 보여주나 |
|---|---|
| 01-main-still-korean.png | 기기 언어를 영어로 두고 `-AppleLanguages "(en)"` 로 실행해도 메인 화면이 전부 한국어 |
| 02-settings-mixed.png | 같은 화면에서 위쪽(리디자인 섹션)은 한국어, 아래쪽(현지화된 섹션)은 영어 — 섞여 있다 |

### 왜 안 되나

조약돌 대화 문구가 String Catalog 를 거치지 않는다.
`Redesign/Conversation/ConversationScript.swift`, `Phrasing.swift`,
`Redesign/Home/HomeGreeting.swift` 가 한국어 조사 처리
(`goal.particle("을","를")`)로 문장을 조립하기 때문에
번역을 채워 넣을 키 자체가 만들어지지 않는다.

### 영어 스크린샷을 만들려면

1. 위 세 파일의 문장 생성 방식을 언어별로 갈라지게 바꾼다
   (조사 처리는 한국어 경로에만 두고, 영어는 별도 문장 템플릿을 쓴다)
2. 새로 생기는 키를 카탈로그에 채운다
3. 이 문서의 ko 목록과 같은 순서로 다시 캡처한다

## 다시 찍는 법

1. 깨끗한 시뮬레이터에 설치 (다른 앱이 전면으로 올라오면 캡처가 방해받는다)
2. 라이트 모드: `xcrun simctl ui <UDID> appearance light`
3. 알림·추적 권한 팝업을 먼저 닫는다
4. 우측 상단 `···` ▸ 개발용 ▸ 샘플 데이터 생성
5. `xcrun simctl io <UDID> screenshot <파일>` 로 저장 후 1242×2688 로 변환
