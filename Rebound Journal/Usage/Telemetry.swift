//
//  Telemetry.swift
//  Rebound Journal (징검돌)
//
//  **얼마나 쓰이는지를 익명으로 세는 자리.** 가는 곳은 피드백과 같은 허브다 —
//  `iCloud.com.Ysoup.FeedbackHub` 의 공개 DB, 앱 구분은 `ReboundJournalSpec.feedback`.
//
//  두 종류가 올라간다:
//    · `UsageSnapshot` — 설치마다 **한 줄**, 켤 때 덮어쓴다(LeeoKit 이 12시간에 한 번으로 막는다).
//      앱 고유 숫자는 **개수뿐**이다: 기록 수 · 목표 수 · 해낸 목표 수.
//    · `UsageEvent` — 하루 한 건씩: 앱을 연 날(`app_open`), 조약돌과 대화를 끝낸 날.
//
//  ⚠️ **적은 내용은 한 글자도 안 나간다.** 목표 이름 · 느낀 점 · 감정 태그 · 대화는 전부
//     기기와 사용자의 iCloud 에만 있다. 붙는 것은 설치할 때 만든 무작위 UUID 하나뿐이다.
//
//  ⚠️ **기본은 보냄, 설정에서 끌 수 있다.** 끈 사람에게는 스냅샷도 이벤트도 안 나간다.
//
//  ⚠️ `app_open` 이 있어야 허브의 DAU · 잔존 · "며칠 왔나"가 맞다. 그게 없으면 무언가를
//     한 날만 잡혀서, 조약돌 인사만 보고 닫은 날이 '안 온 날'이 된다.
//

import Foundation
import SwiftData
import LeeoKit

enum Telemetry {

    /// 키가 '끄기'인 이유: `UserDefaults.bool` 의 기본값이 false 라, '보내기'로 두면
    /// 설정을 한 번도 안 연 사람이 전부 '끔'이 된다. '끄기'로 두면 끈 사람만 true 다.
    static let optOutKey = "usage.optOut"

    static var isEnabled: Bool { !UserDefaults.standard.bool(forKey: optOutKey) }

    private static let reporter = LeeoUsageReporter(config: ReboundJournalSpec.feedback,
                                                    appName: ReboundJournalSpec.appName)

    /// 허브가 알아보는 이벤트 이름. 다른 앱과 같은 말이어야 한다.
    enum Event: String {
        case appOpen = "app_open"
        case conversationFinished = "conversation_finished"
    }

    // MARK: 설치 스냅샷

    @MainActor
    static func reportSnapshot(in context: ModelContext) {
        guard isEnabled else { return }
        let journals = ((try? context.fetch(FetchDescriptor<JournalData>())) ?? [])
            .filter { $0.hasDeleted != true }
        let goals = (try? context.fetch(FetchDescriptor<SubGoalData>())) ?? []
        reporter.reportInBackground(metrics: [
            "journals": Double(journals.count),
            "goals": Double(goals.count),
            "goalsReached": Double(journals.filter { $0.isGoalIn == true }.count),
        ])
    }

    // MARK: 하루 한 건

    /// 앱을 연 날. 켤 때와 앞으로 돌아올 때 부른다 — 며칠 켜 둔 채 돌아온 날도 연 날이다.
    /// 행동이 아니라서 `registerSignificantEvent()` 는 부르지 않는다(리뷰 요청이 당겨진다).
    static func recordOpen() {
        send(.appOpen)
    }

    /// 조약돌과 대화를 한 번 끝냈다 — 이 앱이 가치를 주는 자리.
    static func recordConversationFinished() {
        send(.conversationFinished)
    }

    private static func send(_ event: Event) {
        guard isEnabled, firstTimeToday(event.rawValue) else { return }
        reporter.logEventInBackground(event.rawValue)
    }

    private static func firstTimeToday(_ name: String) -> Bool {
        let key = "usage.lastEvent.\(name)"
        let today = Calendar.current.startOfDay(for: Date())
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           Calendar.current.startOfDay(for: last) >= today { return false }
        UserDefaults.standard.set(Date(), forKey: key)
        return true
    }
}
