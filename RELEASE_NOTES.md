# 릴리즈 노트

DeployBar 가 배포할 때 이 파일의 최신 버전 절을 읽어
App Store Connect 의 "이 버전의 새로운 기능" 칸에 올린다.
스토어에 나가는 글은 스토어 표시가 붙은 `###` 절에만 쓴다.

## 2.0.1

2.0.0(징검돌 리디자인) 위에 영어를 얹은 판.

### 앱스토어 (한국어)

영어를 지원합니다.
날짜 표기가 기기 언어를 따릅니다.
비밀번호 화면의 숫자 버튼이 보이지 않던 문제를 고쳤습니다.

### App Store (English)

ZinggumDol now speaks English.
Dates follow your device language.
Fixed the blank passcode keypad.

### 개발 메모 (노출 안 함)

- Localizable 559키 전부 ko/en. 조약돌 대화까지 영어로 나온다.
  - `Phrasing.say` / `pick` 이 한국어가 아닐 때 존댓말 원문을 키로 삼아
    `AppLanguage.localized` 로 번역문을 찾는다 (런타임 조회라 카탈로그에 수기 등록)
  - `String.particle` 은 한국어가 아니면 빈 문자열 — 영어 문장에 조사가 남지 않는다
  - 보간이 든 문구 74개는 `String(localized:)` 로 감싸 형식 문자열 키로 뽑았다
  - 말투(존댓말/반말) 칸은 영어에서 감춘다. 그 구분이 없는 언어라서.
  - ko_KR 로 고정돼 있던 DateFormatter·요일 기호·받아쓰기 로캘을 사용자 로캘로
  - `SampleDataGenerator` 도 현지화 — 영어 스크린샷에 한국어 데이터가 안 나온다
- 저장·비교용 값은 DataSentinel 로 원문 고정, 표시만 번역해 기존 기록 보존
- FeedbackHub 사용 통계(UsageSnapshot/UsageEvent) + 개발자 대시보드
  ⚠️ CloudKit Console 에서 두 레코드 타입을 Production 에 배포해야 실제로 쌓인다
- ⚠️ 액센트 색이 둘이다 — 리디자인 화면은 PebbleTheme.key(#5F8F93),
  설정·잠금 등 옛 화면은 AccentColor 에셋(#2F9E44). 하나로 맞춰야 한다.
- ⚠️ 말풍선 전환 애니메이션 중 같은 말풍선이 겹쳐 그려지는 프레임이 있다.

## 2.0.0

이름과 화면이 통째로 바뀌었다. 그래서 2.0.0이다.

---


### App Store Connect "이번 버전의 새로운 기능" — 한국어

아래 선 사이를 그대로 복사해서 붙여넣는다.

────────────────────────────────────────

리바운드 저널이 징검돌이 되었습니다.

앱을 열면 화면 가운데 작은 조약돌이 앉아 있습니다. 목록도 그래프도 먼저 보여주지 않습니다. 무엇에 닿았고 무엇이 조용했는지 조약돌이 먼저 보고, 먼저 말을 겁니다.

적어두기에서, 이야기 나누기로
· 조약돌과 말풍선을 주고받으며 돌아봅니다. 말로도 글로도 답할 수 있어요.
· 무슨 일이 있었는지와 지금 마음은 따로 묻습니다. 둘은 다른 얘기니까요.
· 답하기 힘든 날에는 더 묻지 않고 거기서 멈춥니다.

지나온 길
· 한 주가 징검다리로 놓입니다. 밟지 않은 돌도 지우지 않고 그 자리에 그대로 둡니다.
· '남긴 것들'에서 지금까지 적은 것을 날짜순으로 훑어보고, 고치거나 지울 수 있습니다.

말투를 고를 수 있어요
· 조약돌이 존댓말을 쓸지 반말을 쓸지 설정에서 정합니다. 언제든 다시 바꿀 수 있어요.

위젯
· 홈 화면과 잠금 화면에 조약돌을 놓을 수 있습니다. 눌러서 바로 오늘 이야기를 남기러 올 수 있어요.

그밖에
· 조약돌이 말할 때 나는 작은 소리와 진동. 설정에서 끌 수 있습니다.
· 새 아이콘과 새 색.

이전에 남긴 기록은 그대로 있습니다. 앱 비밀번호와 매일 알림도 그대로예요.

이번 버전에는 그래프와 통계 화면이 없습니다.

────────────────────────────────────────

---

### App Store Connect "What's New in This Version" — English

영어 현지화 칸에 붙여넣는다. 한국어를 옮긴 게 아니라 영어로 다시 썼다.
직역하면 "무엇에 닿았고"나 "징검다리" 같은 말이 설명이 필요한 낱말이 된다.

────────────────────────────────────────

Rebound Journal is now ZinggumDol.

Open the app and a small pebble is there, waiting. No lists, no charts up front. The pebble looks at what you reached and what has gone quiet, and it speaks first.

From writing things down to talking them through
· Reflect by trading speech bubbles with the pebble. Answer out loud or by typing.
· What happened and how you feel are asked in separate turns. They are different things.
· On a day when answering is hard, the pebble stops there and asks nothing more.

Where you have been
· Your week is laid out as stepping stones across a stream. Stones you did not step on stay right where they are.
· Look back through everything you have written, by date, and edit or delete any of it.

Choose how the pebble speaks
· Polite or casual. Set it in Settings, and change it back whenever you like.

Widgets
· Put the pebble on your Home Screen or Lock Screen. Tap it to come and leave today's note.

Also
· A small sound and a light tap as the pebble speaks. Each can be turned off.
· A new icon and new colors.

Everything you wrote before is still here. Your passcode and daily reminder are unchanged.

This version does not include the chart and statistics screens.

────────────────────────────────────────

옮기면서 바꾼 것

"무엇에 닿았고 무엇이 조용했는지"를 그대로 옮기면 영어에서는 뜻이 서지 않는다.
what you reached / what has gone quiet으로 풀었다. 닿았다는 말은 살리고,
조용하다는 말은 원문 그대로 뒀다 — 이 앱이 "안 했다"고 말하지 않는 자리라
missed나 skipped로 바꾸면 §4를 어긴다.

존댓말/반말은 영어에 없다. Polite or casual로 적었다. 말투를 고른다는 행위
자체는 전달되고, 실제로 무엇이 바뀌는지는 설정에서 예문을 들려주니 거기서 안다.

'남긴 것들' 같은 화면 이름은 따옴표로 인용하지 않았다. 영어 사용자에게는
그 화면 이름이 한국어로 보이므로, 영어 이름을 인용하면 화면에서 찾을 수 없다.
대신 그 화면이 하는 일로 적었다.

---

### 이 글을 이렇게 쓴 이유

첫 줄이 이름 이야기여야 한다. 업데이트를 받은 사람은 어제까지 쓰던 앱을 열었는데 이름도 아이콘도 화면도 다르다. 그 사람이 가장 먼저 확인하고 싶은 건 "내가 잘못 눌렀나"이고, 그 다음이 "내 기록은 어디 갔나"다. 기능 목록은 그 두 개를 해결한 다음에야 읽힌다. 그래서 이름이 첫 줄, 기록 보존이 마지막 줄이다.

"실패", "재도전", "리바운드"를 쓰지 않았다 (설계 고찰 §4). 앱 안에서 안 쓰기로 한 낱말을 앱 소개에서 쓰면 스토어에서 읽고 들어온 사람의 기대와 실제 화면이 어긋난다. 이름이 바뀐 이유도 여기 있어서, 릴리즈 노트가 그 규칙을 먼저 어기면 안 된다.

기능이 아니라 그 기능이 하는 일로 적었다. "감정과 사실 분리 입력"이 아니라 "무슨 일이 있었는지와 지금 마음은 따로 묻습니다"로 쓴다. 이 앱을 쓰는 사람이 알고 싶은 건 화면 구성이 아니라 앱이 자기를 어떻게 대할지다.

통계 화면이 없다는 걸 적었다. 없어진 것을 안 적으면 찾다가 고장으로 여긴다. 다시 넣을 계획이라면 이 줄은 빼도 된다 — 다만 뺀 채로 내보내면 문의가 온다.

---

### 실제로 바뀐 것 (내부 기록)

화면의 뼈대
- 첫 화면이 대시보드에서 대화로 바뀌었다. 목록·달력·통계를 열자마자 보여주면 대화가 아니라 읽을 거리가 된다.
- 기록은 '지나온 길'(주간 징검다리 + 목표별 펼쳐보기)과 '남긴 것들'(날짜순 원본)로 나눠 옮겼다.
- 답하는 자리를 전부 말풍선으로 통일했다. 버튼과 말풍선이 섞이면 대화 상대가 둘로 보인다.

조약돌
- 이미지 에셋 없이 코드로 그린다. 표정·크기·색이 상태에 따라 바뀐다.
- 글자가 한 자씩 찍히고, 자마다 소리(Animalese, §9)와 촉감이 난다. 소리·진동은 각각 끌 수 있다.
- 같은 뜻을 여러 표현으로 말한다. 같은 날엔 같은 말이 나오고 날이 바뀌면 달라진다.

대화의 규칙 (설계 고찰 §5·§6)
- 사용자가 먼저 "못 했다"고 선언하지 않는다. 앱이 관찰하고, 그 관찰이 틀렸을 수 있다고 인정한다.
- 상황과 감정을 서로 다른 턴에서 묻고, 마지막에 둘을 갈라서 되짚어 준다.
- 감정이 바닥이면 쪼개기 질문을 통째로 건너뛰고 대화를 닫는다.
- 앱이 목표를 쪼개주지 않는다. 질문만 하고 사용자가 쪼갠다.

말투
- 존댓말/반말. 두 벌을 손으로 다 적었다 — 기계로 "요"만 떼면 어색한 문장이 섞인다.
- 조약돌의 말과 사용자의 답풍선이 함께 바뀐다. 한쪽만 반말이면 하대가 된다.

위젯
- 홈(작은·넓은), 잠금(사각·원형·인라인).
- 숫자와 진행률을 넣지 않았다. 홈 화면은 하루에 수십 번 스치는 자리라 압박을 놓기엔 최악이다.
- 문장은 전부 앱이 만들어 넘긴다. 위젯이 직접 관찰하면 앱과 다른 말을 하게 되고, 말투 설정도 어긋난다.
- 적어둔 날이 오늘이 아니면 관찰을 지우고 물러선다.

이름
- 기기 언어에 따라 갈린다. 한국어 '징검돌', 영어 'ZinggumDol'.
- 표시 이름과 짧은 이름을 둘 다 맞췄다. 하나만 바꾸면 시스템 어딘가에서 옛 이름이 튀어나온다.

색과 아이콘
- 키 컬러: 앰버 → 개울 물빛(#5F8F93). 바탕: 크림 → 물안개(#EFF3F3).
- 조약돌의 후광만 따뜻하게 남겼다. 여기까지 차갑게 하면 "햇빛에 달궈진 조약돌"(§10)이라는 설정이 사라진다.
- 아이콘을 조약돌로 교체.

그대로 둔 것
- 저장 형식(SwiftData 스키마). 예전 기록이 그대로 열린다.
- 번들 ID com.leeo.ReboundJournal. 바꾸면 업데이트가 끊긴다.
- 앱 비밀번호, 매일 알림.

---

### 올리기 전에 해야 할 것

- [ ] App Store Connect에서 스토어 이름을 바꾼다. 한국어 '징검돌', 영어 'ZinggumDol'.
      기기에 뜨는 이름은 코드로 언어별로 맞춰 뒀지만(InfoPlist.xcstrings), 스토어에
      노출되는 이름은 별개라 App Store Connect에서 현지화별로 따로 넣어야 한다.
- [ ] App Group group.com.leeo.ReboundJournal 을 등록한다. Identifiers에 만들고 앱과
      위젯 두 App ID에 체크. 없으면 위젯 서명이 실패한다. 시뮬레이터에서는 자동으로
      만들어져 안 걸리고 넘어간다.
- [ ] 영어 현지화를 열면 앱이 영어를 지원한다고 읽힌다. 이름만 영어일 뿐 화면 안의
      말은 전부 한국어다. 영어 릴리즈 노트를 올린다면 스토어의 지원 언어 표기와
      설명글에서 그 점이 어긋나지 않는지 같이 본다.
- [ ] 스크린샷을 새로 찍는다. 화면이 통째로 달라져서 지금 올라가 있는 것과 아무 관계가 없다.
- [ ] 빌드 번호(CURRENT_PROJECT_VERSION)는 1 그대로다. 같은 버전으로 두 번 올리면 그때 올려야 한다.

### 아직 남은 것

- 앱 아이콘 배경이 앰버라 첫 화면(물안개)과 온도가 반대다. 아이콘과 앱을 열었을 때의 인상이 갈린다.
- 예전 화면들(DashboardContentView, HomeView, InteractiveJournalCreator 등)이 닿을 수 없는 채로 빌드에 남아 있다. 지울지는 판단이 필요하다.
