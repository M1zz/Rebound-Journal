# 앱스토어 스크린샷

언어 24개(deploy.env 의 LOCALES) 모두 그 언어 화면으로 찍는다. 폴더 이름은 스토어 로케일이다(`en` → `en-US`).

```
raw/<로케일>/0N-*.png        원본 캡처 1320×2868 (iPhone 17 Pro Max 시뮬레이터). 올라가지 않는다
marketing/<로케일>/0N-*.png  제출본 1242×2688. DeployBar 가 이 폴더를 스토어에 올린다
creative/<로케일>/header.png 제품 페이지 헤더 3840×1646
creative/<로케일>/search.png 검색 결과 3840×2560
```

| 장 | 원본 | `-shot` | 화면 |
|---|---|---|---|
| 01 | 01-home | home | 조약돌이 먼저 말을 건다 (지난 기록을 기억한다) |
| 02 | 02-conversation | conversation | 해낸 날을 함께 기뻐하는 대화 |
| 03 | 03-path | lookBack | 지나온 길 — 한 주가 징검돌 한 줄로 |
| 04 | 04-records | records | 남긴 것들 — 날짜순 기록과 다음에 해볼 것 |
| 05 | 05-pebbles | settings | 설정 — 징검돌 프로, 조약돌 결 고르기 |

샘플 기록은 그 언어로 심는다(`ZinggumDol/Services/ScreenshotMode.swift` 의 `samples`).

## 다시 만드는 법

1. DEBUG 로 빌드해 설치한다. 라이트 모드, 상태 막대는 `xcrun simctl status_bar <기기> override --time 9:41 …`
2. 언어마다, 화면마다 실행 인자로 연다 (기기 언어를 바꾸지 않아도 된다):
   `xcrun simctl launch <기기> com.leeo.ReboundJournal -shot home -AppleLanguages "(de)" -AppleLocale de_DE`
   말풍선 타이핑이 끝날 때까지 기다린다(홈 약 14초, 대화 약 25초). 중간에 찍으면 말풍선이 덜 그려진다
3. `xcrun simctl io <기기> screenshot raw/<로케일>/0N-….png`
4. `python3 Scripts/make_marketing_screenshots.py [로케일 …]` — 문구는 `Scripts/marketing_captions.json`
5. `python3 Scripts/make_creative_assets.py [언어 …]` — 헤더 · 검색 결과 (1장 헤드라인과 같은 이야기)
6. `DeployBar --shotplan 징검돌` 로 언어마다 5장 · 헤더 · 검색 결과가 잡히는지 확인한다

## 한국어와 다른 점

말투(존댓말/반말) 설정은 한국어에만 있다. 다른 언어에서는 설정에서 감춰서 05 장의 모습이 조금 다르다.
