# 징검돌 — 리디자인 작업

> 앱 이름: 리바운드 저널 → **징검돌** (2026-07-27)
> 큰 목표는 넓은 개울, 쪼개기(§6)는 돌 하나 놓기, 헛디뎌도 개울에 빠진 건 아니다.
> 메타포를 설명하지 않아도 이름만으로 읽히므로 §4를 지킨다.
> 번들 ID(`com.leeo.ReboundJournal`)와 Xcode 타깃명은 그대로 둔다 — 바꾸면 기존
> 사용자에게 별개 앱이 되고 CloudKit 컨테이너·entitlements가 끊긴다.

설계 근거: `회고-앱-설계-고찰.md`, `회고-앱-설계-대화-전문_1.md` (2026-07-25)

## 8. 익명 사용 통계 · 제출 준비 (2026-09-26, 09-28 갱신)
- [x] 익명 사용 통계 — 기본 켬, 설정 ▸ 사용 통계에서 끔 (`Services/UsageReporting.swift`)
  - 브랜치의 `Telemetry.swift` 는 main 의 `UsageReporting`·LeeoKit 3.12 자동 app_open 과 겹쳐
    그쪽에 합쳤다. 끄기 키 `usage.optOut` 그대로. 끄면 스냅샷·이벤트·app_open·결제 퍼널 모두 멈춤
  - conversation_finished 하루 한 건
- [x] 개인정보 처리방침: https://m1zz.github.io/Rebound-Journal/privacy.html (App Store Connect 반영)
- [ ] App Store 개인정보 라벨: 사용 데이터(제품 상호작용) · 식별자 없음으로 갱신 (웹에서)
- [ ] 스크린샷: 화면이 통째로 바뀌었으니 새로 찍어야 함
  - [x] 5.5인치(1242×2208) 한국어 6장 — iPhone SE(3세대) 시뮬레이터에서 찍어 확대. `~/Desktop/징검돌-스크린샷-5.5inch`
  - [x] DEBUG 전용 `-shot <화면>` 실행 인자 (`Services/ScreenshotMode.swift`) — 데이터 심고 화면 바로 열기
  - [ ] App Store Connect 미디어 관리자에서 5.5인치 교체 (영어 현지화에 옛 5.5인치가 있으면 그것도)
  - [ ] 영어판 UI 번역 안 됨 (165개 중 3개) — 영어 스크린샷도 UI는 한국어로 나옴

## 9. 2.1.0 (8) 리젝 대응 (2026-09-30)
- [x] 2.3.3 — 5.5인치 스크린샷 새로 찍음 (위 §8)
- [x] 5.1.2(i) — 추적 안 함. 쓰지도 않는 ATT 요청(`AppDelegate`)과 `NSUserTrackingUsageDescription` 제거
- [x] 빌드 9 로 올림 (`Config/Version.xcconfig`) — ASC 가 '바이너리에 `NSUserTrackingUsageDescription` 있음'이라며 '추적 안 함' 라벨을 막는다. main 소스엔 빌드 8 전에 이미 키가 없었지만(61e8dde) 빌드 8 아카이브가 로컬에 없어 실제 바이너리는 확인 못 함 → 깨끗한 새 빌드로 덮는다
- [ ] 빌드 9 아카이브 · 업로드 → 심사 중인 빌드를 9로 교체
- [ ] App Store Connect 개인정보 라벨: '추적에 사용' 전부 해제 (기타 데이터 유형 · 기타 사용자 콘텐츠 포함)
- [ ] 리뷰 답장: 추적하지 않음, 라벨 고쳤음
- [ ] 최소 iOS 26.0 — 1.x 사용자 중 iOS 26 미만은 업데이트를 못 받음. 이대로 갈지 결정
- [x] `redesign/pebble-conversation` → main 합치기 (2026-09-28)

## 0. 브랜치 정리
- [x] `feature/1.0.11`(전 브랜치의 상위집합)을 `main`으로 fast-forward
- [x] `origin/main` 푸시 (385bd43 → d81ec62, 220 커밋)
- [x] 병합 완료된 원격 브랜치 12개 삭제

## 1. 프로젝트 설정
- [x] 배포 타깃 17.6 → 26.0 (SpeechAnalyzer / FoundationModels)
- [x] 마이크·음성인식 사용 설명 Info.plist 키 추가
- [x] 신규 파일 pbxproj 등록 스크립트 (`Scripts/add_sources_to_pbxproj.py`)

## 2. 설계 원칙 → 구현 매핑

| 문서 | 원칙 | 구현 |
|---|---|---|
| §4 | "리바운드" 메타포 비노출 | 사용자 문구에서 슛/골인/리바운드 제거 |
| §5-A | 사용자가 실패를 선언하지 않음 | `ProgressObserver`가 데이터로 먼저 중립 관찰 |
| §5-B | 사실과 감정 분리 | 대화에서 별개 턴 + 분리 되짚기 |
| §5 | 실패 직후 분석 강요 금지 | 감정 최하위면 쪼개기 질문 건너뛰고 종료 |
| §5 | 과거 성공 상기 | `ProgressObserver.recentSuccess` |
| §6 | SMART 금지, 질문으로 쪼개기 | 앱이 쪼개주지 않고 질문만 던짐 |
| §7 | 대화형 + 음성/텍스트 병행 | `ConversationView` |
| §7 | **"다시 말씀해 주세요" 금지** | 저신뢰도 → 패러프레이즈 재확인 |
| §9 | Animalese 캐릭터 보이스 | `PebbleVoice` (AVAudioUnitTimePitch) |
| §10 | 햇빛에 달궈진 조약돌 | `PebbleView` (SwiftUI 드로잉) |

## 3. 구현
- [x] 디자인 시스템 (따뜻한 흙색 팔레트) — `Features/DesignSystem/PebbleTheme.swift`
- [x] 조약돌 캐릭터 뷰 + 표정/호흡 — `Features/Companion/PebbleView.swift`
- [x] 조약돌 보이스 (Animalese) — `Features/Companion/PebbleVoice.swift`
- [x] 관찰 계층 (앱이 먼저 인식) — `Features/Observation/ProgressObserver.swift`
- [x] 대화 스크립트 + 엔진 — `Features/Conversation/`
- [x] FoundationModels 패러프레이즈 재확인 — `Features/Intelligence/Paraphraser.swift`
- [x] SpeechAnalyzer 음성 입력 — `Features/Voice/SpeechCapture.swift`
- [x] 새 홈 화면 + 앱 진입점 교체 — `Features/Home/`
- [x] 빌드 + 시뮬레이터 실행 검증

### 검증 중 고친 것
- `SubGoalData`가 자체 `id: String?`를 들고 있어 `PersistentModel.id`를 가린다.
  이 값이 nil인 행(샘플 데이터·구버전 기록)이 섞이면 `ForEach`가 전부 같은 항목으로
  보고 **첫 줄만 반복 출력**한다. `\.persistentModelID`로 묶어 해결.
- 조약돌 후광이 레이아웃 프레임을 넘어 그려져 바로 아래 글자와 겹쳤다.
- 얼굴 호의 곡률 부호가 뒤집혀 있어 조약돌이 **찡그린 표정**으로 나왔다.

## 6. 리디자인 이후 이어서 한 것
- [x] 목표 선택 → 조약돌이 그 목표에 대해 말하기
- [x] 말풍선 대화 + 사람 속도 타이핑 + 커서
- [x] 글자마다 Animalese 소리 + CoreHaptics 촉감 (§9)
- [x] 한국어 조사 처리 (`String.particle`)
- [x] 기록 보기 — 목표별 펼쳐보기 + 대화 중 지난 기록 회상
- [x] 홈에서 조약돌이 먼저 말 걸기, 매듭짓지 못한 것 후속 질문
- [x] 답하는 자리를 전부 말풍선으로 통일 (`ReplyChip`)
- [x] 주간 징검다리 시각화 (`WeekStones` / `StoneBridgeView`)

### 징검다리가 지켜야 할 것
빈 날을 실패로 보이게 하면 안 된다. 달력 격자는 빈칸을 만들고 빈칸은 못 지킨
날로 읽히므로, 돌을 어긋나게 놓아 개울을 건너는 그림으로 만든다. 밟지 않은
돌도 지우지 않고 윤곽만 남긴다. 숫자(며칠/몇 %)는 어디에도 두지 않는다.

## 7. 옛 흐름 정리 (2026-09-27 완료)
- 리디자인 이후 진입 경로가 끊겼던 옛 화면(대시보드·슛 기록·통계·타임라인·목표 선택 등)을
  전부 지웠다. 프로젝트에 등록조차 안 돼 있던 파일 16개, 컴파일만 되던 파일 약 40개.
- 폴더를 역할별로: `App/` `Model/` `Services/` `Extensions/` `Features/`(옛 `Redesign/`).
- 쓰지 않던 에셋(농구공 일러스트·옛 색) 정리, 광고가 없는데 묻던 추적 권한(ATT) 제거.
- CoreData 모델(`Model/Database.xcdatamodeld`)은 1.x 기록 이관 때문에 남긴다.

## 4. 유지 결정
- SwiftData 스키마(`JournalData`/`SubGoalData`)는 **변경하지 않음** — 기존 사용자 데이터 보존.
  메타포는 저장 계층 내부 이름으로만 남고 화면에는 노출하지 않음.

## 5. 문서상 남은 과제 (§11)
- [ ] 캐릭터 시리즈 확장 방법
- [x] 질문 시퀀스 설계 (몇 개·순서·중단 시점) → `ConversationScript`
- [ ] 관찰형 회고 앱과의 전환 안내 시점
