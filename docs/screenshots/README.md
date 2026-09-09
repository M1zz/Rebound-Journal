# 앱스토어 스크린샷

기기: iPhone 17 Pro Max 시뮬레이터 (6.9")
캡처 원본 1320×2868 → 제출 규격 **1242×2688** 로 변환
(`ffmpeg -i in.png -vf "scale=1242:2699,crop=1242:2688" out.png`)

버전 2.0.1 / 라이트 모드 / 샘플 데이터

## 두 언어 모두 제출 가능

| | ko/ | en/ | 화면 |
|---|---|---|---|
| 01 | 첫 만남 | Greeting | 조약돌이 먼저 말을 건다 |
| 02 | 대화 | Conversation | 지난 기록을 기억하고 이어서 묻는다 |
| 03 | 대화 이어짐 | Conversation flow | 재촉하지 않는 말투, 답을 고르는 방식 |
| 04 | 지나온 길 | The way you've come | 한 주가 징검다리로, 밟지 않은 돌도 남는다 |
| 05 | 남긴 것들 | What you've left | 날짜순 원본, 감정 태그, 대안 |
| 06 | 설정 | Settings | 소리·진동, 비밀번호, 알림 |

영어 화면은 샘플 데이터까지 영어다(`SampleDataGenerator` 현지화).

## 영어 화면이 한국어와 다른 점

**말투(존댓말/반말) 설정이 없다.** 영어에는 그 구분이 없어서
`AppLanguage.isKorean` 이 아닐 때 설정에서 통째로 감춘다.
그래서 ko/06 에는 있는 "말투" 칸이 en/06 에는 없다.

조약돌 문구는 존댓말 원문을 키로 삼아 번역문을 찾는다
(`Phrasing.say` / `pick` → `AppLanguage.localized`).
한국어 조사(`String.particle`)는 다른 언어에서 빈 문자열을 돌려준다.

## 다시 찍는 법

1. 깨끗한 시뮬레이터에 설치 — 다른 앱이 전면으로 올라오면 캡처가 방해받는다
2. 라이트 모드: `xcrun simctl ui <UDID> appearance light`
3. 언어: `xcrun simctl spawn <UDID> defaults write "Apple Global Domain" AppleLanguages -array en-US`
   (한국어는 `ko-KR`). 바꾼 뒤 앱을 지웠다 다시 설치해야 확실히 붙는다
4. 알림·추적 권한 팝업을 먼저 닫는다
5. 우측 상단 `···` ▸ 개발용 ▸ 샘플 데이터 생성
6. 말풍선 타이핑 애니메이션이 끝날 때까지 기다린다 —
   전환 중에 찍으면 같은 말풍선이 겹쳐 나온다
7. `xcrun simctl io <UDID> screenshot <파일>` 로 저장 후 1242×2688 로 변환
