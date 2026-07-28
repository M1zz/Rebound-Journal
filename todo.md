# 징검돌 — 리디자인 작업

> 앱 이름: 리바운드 저널 → **징검돌** (2026-07-27)
> 큰 목표는 넓은 개울, 쪼개기(§6)는 돌 하나 놓기, 헛디뎌도 개울에 빠진 건 아니다.
> 메타포를 설명하지 않아도 이름만으로 읽히므로 §4를 지킨다.
> 번들 ID(`com.leeo.ReboundJournal`)와 Xcode 타깃명은 그대로 둔다 — 바꾸면 기존
> 사용자에게 별개 앱이 되고 CloudKit 컨테이너·entitlements가 끊긴다.

설계 근거: `회고-앱-설계-고찰.md`, `회고-앱-설계-대화-전문_1.md` (2026-07-25)

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
- [x] 디자인 시스템 (따뜻한 흙색 팔레트) — `Redesign/DesignSystem/PebbleTheme.swift`
- [x] 조약돌 캐릭터 뷰 + 표정/호흡 — `Redesign/Companion/PebbleView.swift`
- [x] 조약돌 보이스 (Animalese) — `Redesign/Companion/PebbleVoice.swift`
- [x] 관찰 계층 (앱이 먼저 인식) — `Redesign/Observation/ProgressObserver.swift`
- [x] 대화 스크립트 + 엔진 — `Redesign/Conversation/`
- [x] FoundationModels 패러프레이즈 재확인 — `Redesign/Intelligence/Paraphraser.swift`
- [x] SpeechAnalyzer 음성 입력 — `Redesign/Voice/SpeechCapture.swift`
- [x] 새 홈 화면 + 앱 진입점 교체 — `Redesign/Home/`
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

## 7. 남은 판단 (사용자 결정 필요)
- 옛 흐름 화면들이 컴파일 대상에 그대로 남아 있다 (`DashboardContentView`,
  `HomeView`, `InteractiveJournalCreator`, `SinglePageJournalCreator`,
  `SelectShootTypeView` 등). 진입 경로는 끊었지만 파일은 지우지 않았다.
  차트·타임라인·설정은 계속 쓰이므로 한꺼번에 지우면 안 되고, 어디까지 정리할지는
  직접 고르는 게 맞다고 판단.

## 4. 유지 결정
- SwiftData 스키마(`JournalData`/`SubGoalData`)는 **변경하지 않음** — 기존 사용자 데이터 보존.
  메타포는 저장 계층 내부 이름으로만 남고 화면에는 노출하지 않음.

## 5. 문서상 남은 과제 (§11)
- [ ] 캐릭터 시리즈 확장 방법
- [x] 질문 시퀀스 설계 (몇 개·순서·중단 시점) → `ConversationScript`
- [ ] 관찰형 회고 앱과의 전환 안내 시점
