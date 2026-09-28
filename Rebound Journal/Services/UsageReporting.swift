//
//  UsageReporting.swift
//  Rebound Journal
//
//  FeedbackHub(피드백과 같은 CloudKit 컨테이너)로 익명 사용 통계를 보내는 앱 쪽 진입점.
//
//  · 설치당 스냅샷 1개(UsageSnapshot) — 앱을 열 때 갱신, LeeoKit이 12시간 간격으로 스로틀한다.
//  · 주요 행동 이벤트(UsageEvent) — 슛 기록·목표 생성·재도전처럼 의미 있는 행동만 남긴다.
//
//  **기본은 보냄, 설정 ▸ 사용 통계에서 끌 수 있다.** 끈 사람에게는 스냅샷·이벤트·app_open·
//  결제 퍼널(`OptOutAwareAnalytics`) 모두 나가지 않는다.
//
//  개인 식별 정보는 보내지 않는다. 설치 식별은 기기·계정과 무관한 무작위 UUID(LeeoKit이 관리).
//  수집한 값은 설정 ▸ 사용 통계(개발자) 화면과 FeedbackHub에서 확인한다.
//
//  ⚠️ CloudKit Console에서 UsageSnapshot / UsageEvent 레코드 타입을 Production에 배포해야
//     실제로 쌓인다. 배포 전에는 저장이 조용히 실패한다.
//

import Foundation
import LeeoKit

enum UsageReporting {

    /// 이벤트 이름은 FeedbackHub 집계 키가 되므로 한 번 정하면 바꾸지 않는다.
    enum Event: String {
        /// 골인 기록
        case goalIn = "goal_in"
        /// 리바운드(실패) 기록
        case rebound = "rebound"
        /// 이전 리바운드를 골인으로 극복
        case reboundResolved = "rebound_resolved"
        /// 새 목표 생성
        case goalCreated = "goal_created"
        /// 리바운드 카드에서 재도전 시작
        case retryStarted = "retry_started"
        /// 조약돌과 대화를 한 번 끝냈다 — 이 앱이 가치를 주는 자리. 하루 한 건.
        case conversationFinished = "conversation_finished"
    }

    // MARK: - 끄기

    /// 키가 '끄기'인 이유: `UserDefaults.bool` 의 기본값이 false 라, '보내기'로 두면
    /// 설정을 한 번도 안 연 사람이 전부 '끔'이 된다. '끄기'로 두면 끈 사람만 true 다.
    /// ⚠️ 키 이름은 이미 끈 사용자의 설정과 맞물려 있다. 바꾸지 않는다.
    static let optOutKey = "usage.optOut"

    static var isEnabled: Bool { !UserDefaults.standard.bool(forKey: optOutKey) }

    private static var reporter: LeeoUsageReporter {
        // app_open 자동 전송도 끄기를 따른다. LeeoKit 은 끄기를 모르므로 여기서 막는다.
        LeeoUsageReporter(config: ReboundJournalSpec.feedback,
                          appName: ReboundJournalSpec.appName,
                          sendsDailyAppOpen: isEnabled)
    }

    /// 홈이 뜰 때 호출 — 설치 스냅샷을 앱 지표와 함께 갱신한다. `app_open` 도 여기서 따라 나간다.
    static func reportSnapshot(journals: [JournalData], subGoals: [SubGoalData]) {
        guard isEnabled else { return }
        reporter.reportInBackground(metrics: metrics(journals: journals, subGoals: subGoals))
    }

    /// 의미 있는 행동 1건 — 리뷰 게이트 카운트와 이벤트 스트림을 함께 올린다.
    /// 통계를 꺼도 리뷰 게이트 카운트는 센다 (기기 안에만 있는 값).
    static func log(_ event: Event) {
        _ = LeeoEngagement.shared.registerSignificantEvent()
        guard isEnabled else { return }
        reporter.logEventInBackground(event.rawValue)
    }

    /// 대화를 끝냈을 때. 하루에 여러 번 끝내도 한 건만 — 허브는 "대화한 날"을 센다.
    static func logConversationFinished() {
        guard firstTimeToday(Event.conversationFinished.rawValue) else { return }
        log(.conversationFinished)
    }

    private static func firstTimeToday(_ name: String) -> Bool {
        let key = "usage.lastEvent.\(name)"
        let calendar = Calendar.current
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           calendar.isDateInToday(last) { return false }
        UserDefaults.standard.set(Date(), forKey: key)
        return true
    }

    /// 슛 기록 1건을 결과에 맞는 이벤트로 남긴다.
    /// - Parameter resolvedRebound: 이 기록이 과거 리바운드를 극복한 성공이면 true.
    static func logShot(isGoalIn: Bool, resolvedRebound: Bool) {
        log(isGoalIn ? .goalIn : .rebound)
        if isGoalIn && resolvedRebound { log(.reboundResolved) }
    }

    /// FeedbackHub 통계 화면이 설치 평균으로 보여 줄 앱별 지표.
    private static func metrics(journals: [JournalData], subGoals: [SubGoalData]) -> [String: Double] {
        let summary = JournalSummary(entries: journals)
        let resolvedCount = journals.filter {
            !$0.hasDeletedUnwrapped && !$0.linkedReboundIdUnwrapped.isEmpty
        }.count
        let activeReboundCount = journals.filter(\.isActiveRebound).count

        return [
            "goals": Double(subGoals.count),
            "journals": Double(summary.total),
            "goalIns": Double(summary.goals),
            "rebounds": Double(summary.rebounds),
            "reboundsResolved": Double(resolvedCount),
            "reboundsActive": Double(activeReboundCount),
            "streakDays": Double(summary.streak)
        ]
    }
}

// MARK: - 결제 퍼널도 끄기를 따른다

/// LeeoKit 이 내는 페이월·구매 이벤트를 FeedbackHub 로 보내되, 통계를 끈 사람의 것은 버린다.
struct OptOutAwareAnalytics: LeeoAnalytics {
    private let inner = LeeoUsageAnalytics(spec: ReboundJournalSpec.self)

    func track(_ event: LeeoEvent) {
        guard UsageReporting.isEnabled else { return }
        inner.track(event)
    }
}
