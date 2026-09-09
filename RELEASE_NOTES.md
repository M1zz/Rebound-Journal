# 릴리즈 노트

DeployBar 가 배포할 때 이 파일의 최신 버전 절을 읽어
App Store Connect 의 "이 버전의 새로운 기능" 칸에 올린다.
스토어에 나가는 글은 `### 앱스토어 (언어)` 절에만 쓴다.

## 2.0.1

### 앱스토어 (한국어)

영어를 지원합니다.
앱 색상이 초록으로 바뀌었습니다.
날짜 표기가 기기 언어를 따릅니다.
비밀번호 화면의 숫자 버튼이 보이지 않던 문제를 고쳤습니다.

### App Store (English)

Rebound Journal now speaks English.
The app has a fresh green look.
Dates now follow your device language.
Fixed the blank passcode keypad.

### 개발 메모 (노출 안 함)

- 한국어 문자열 310개를 String Catalog 로 옮기고 영어 번역 추가
- 저장·비교용 값은 DataSentinel 로 원문 고정, 표시만 번역해 기존 기록 보존
- 무드 컬러 오렌지/피치 → 그린, OnAccent 색상 신설
- FeedbackHub 사용 통계 수집(UsageSnapshot/UsageEvent) 및 개발자 대시보드 추가
  ⚠️ CloudKit Console 에서 두 레코드 타입을 Production 에 배포해야 실제로 쌓인다
