//
//  ProgressObserver.swift
//  Rebound Journal
//
//  설계 고찰 §5 목표 A의 구현.
//
//  사용자에게 "실패했나요?"라고 묻지 않는다. 기록을 보고 앱이 먼저, 중립적으로
//  상태를 말한다. 그래서 이 파일의 문구에는 "실패"라는 단어가 없다. 판단하지 않고
//  관찰만 하는 것이 조약돌의 역할이다(§10).
//
//  순수 함수로만 두어 화면 없이도 검증할 수 있게 했다.
//

import Foundation

// MARK: - 관찰 결과

struct GoalObservation: Equatable, Identifiable {

    enum Kind: Equatable {
        /// 아직 목표가 없다.
        case noGoalYet
        /// 목표는 있는데 아직 한 번도 돌아본 적이 없다.
        case neverAttempted(goal: String)
        /// 최근에 이 목표에 닿았다. 축하할 일.
        case reached(goal: String, daysAgo: Int)
        /// 목표에 닿지 않은 채 시간이 지났다. 여기서만 대화를 제안한다.
        case notReached(goal: String, daysAgo: Int)
        /// 오늘은 말 걸 일이 없다.
        case quiet
    }

    let kind: Kind
    var id: String { headline }

    /// 조약돌이 화면에서 말하는 한 줄. 사실만 담고 평가하지 않는다.
    var headline: String {
        switch kind {
        case .noGoalYet:
            "무엇을 향해 가고 있는지 아직 못 들었어요."
        case .neverAttempted(let goal):
            "'\(goal)'을 적어두고 아직 돌아본 적은 없네요."
        case .reached(let goal, let daysAgo):
            daysAgo == 0
                ? "오늘 '\(goal)'에 닿았네요."
                : "\(Self.dayPhrase(daysAgo)) '\(goal)'에 닿았어요."
        case .notReached(let goal, let daysAgo):
            daysAgo <= 1
                ? "'\(goal)'은 오늘 아직 닿지 않았네요."
                : "'\(goal)'을 돌아본 지 \(daysAgo)일 됐어요."
        case .quiet:
            "오늘은 그냥 옆에 있을게요."
        }
    }

    /// 대화를 열 수 있는 관찰인지. `quiet`에서는 아무것도 권하지 않는다.
    var invitesConversation: Bool {
        switch kind {
        case .notReached, .reached, .neverAttempted: true
        case .noGoalYet, .quiet: false
        }
    }

    /// 대화 버튼 문구. 어디에도 "실패"나 "리바운드"가 없다(§4).
    var invitation: String? {
        switch kind {
        case .notReached: "무슨 일이 있었는지 얘기하기"
        case .reached: "어떻게 됐는지 남기기"
        case .neverAttempted: "지금 얘기해보기"
        case .noGoalYet, .quiet: nil
        }
    }

    var pebbleMood: PebbleMood {
        switch kind {
        case .reached: .warm
        case .notReached, .neverAttempted: .resting
        case .noGoalYet, .quiet: .resting
        }
    }

    private static func dayPhrase(_ days: Int) -> String {
        switch days {
        case 0: "오늘"
        case 1: "어제"
        case 2...6: "\(days)일 전"
        case 7...13: "지난주"
        default: "얼마 전"
        }
    }
}

// MARK: - 과거의 성공

/// §5 "지난주에는 이걸 해내셨잖아요" — 자기효능감을 지키기 위해 대화 중 꺼내 쓴다.
struct PastSuccess: Equatable {
    let goal: String
    let date: Date
    let note: String?

    var recollection: String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        let when: String = switch days {
        case 0...1: "어제"
        case 2...7: "며칠 전"
        case 8...20: "지난주쯤"
        default: "얼마 전"
        }
        return "\(when)에는 '\(goal)'을 해내셨어요."
    }
}

// MARK: - 관찰자

enum ProgressObserver {

    /// 목표에 닿지 않은 채 이만큼 지나면 말을 건다. 매일 채근하지 않기 위한 간격이다.
    static let quietDays = 1

    /// 지금 화면에 올릴 관찰 하나를 고른다.
    ///
    /// 여러 목표가 밀려 있어도 **하나만** 보여준다. 밀린 목록을 한꺼번에 보여주는 건
    /// 그 자체로 압박이 되고, §5가 피하려던 바로 그 경험이 된다.
    static func primaryObservation(
        goals: [SubGoalData],
        journals: [JournalData],
        now: Date = Date()
    ) -> GoalObservation {
        let live = journals.filter(\.isValidForDisplay)
        let goalTexts = goals.compactMap(\.goalText).filter { !$0.isEmpty }

        guard !goalTexts.isEmpty else {
            return GoalObservation(kind: .noGoalYet)
        }

        // 오늘 이미 닿은 목표가 있으면 그걸 먼저 축하한다. 좋은 소식이 우선이다.
        if let todayWin = live
            .filter({ $0.isGoalInUnwrapped && Calendar.current.isDate($0.dateUnwrapped, inSameDayAs: now) })
            .max(by: { $0.dateUnwrapped < $1.dateUnwrapped }),
           let goal = nonEmpty(todayWin.subGoal) ?? nonEmpty(todayWin.mainGoal) {
            return GoalObservation(kind: .reached(goal: goal, daysAgo: 0))
        }

        // 그 다음, 가장 오래 방치된 목표 하나.
        let stale = goalTexts
            .map { goal -> (goal: String, days: Int?) in
                let last = live
                    .filter { matches(journal: $0, goal: goal) }
                    .map(\.dateUnwrapped)
                    .max()
                return (goal, last.map { days(from: $0, to: now) })
            }
            .sorted { lhs, rhs in
                // 한 번도 안 돌아본 목표가 가장 앞에 온다.
                (lhs.days ?? .max) > (rhs.days ?? .max)
            }

        guard let candidate = stale.first else { return GoalObservation(kind: .quiet) }

        guard let elapsed = candidate.days else {
            return GoalObservation(kind: .neverAttempted(goal: candidate.goal))
        }

        if elapsed >= quietDays {
            return GoalObservation(kind: .notReached(goal: candidate.goal, daysAgo: elapsed))
        }

        return GoalObservation(kind: .quiet)
    }

    /// 가장 최근에 해낸 일. 대화에서 되짚어 줄 때 쓴다.
    static func recentSuccess(
        journals: [JournalData],
        excluding goal: String? = nil,
        now: Date = Date()
    ) -> PastSuccess? {
        journals
            .filter { $0.isValidForDisplay && $0.isGoalInUnwrapped }
            .filter { journal in
                guard let goal else { return true }
                // 지금 막힌 그 목표 말고 다른 성공을 꺼내야 위로가 된다.
                return !matches(journal: journal, goal: goal)
            }
            .sorted { $0.dateUnwrapped > $1.dateUnwrapped }
            .lazy
            .compactMap { journal -> PastSuccess? in
                guard let goal = nonEmpty(journal.subGoal) ?? nonEmpty(journal.mainGoal) else { return nil }
                return PastSuccess(
                    goal: goal,
                    date: journal.dateUnwrapped,
                    note: nonEmpty(journal.review)
                )
            }
            .first
    }

    /// 이 목표를 몇 번이나 이어서 돌아봤는지. 숫자는 압박이 되기 쉬워 화면에서는
    /// "연속 실패" 같은 형태로는 절대 쓰지 않고, 대화 톤을 고르는 데만 쓴다.
    static func consecutiveMisses(goal: String, journals: [JournalData]) -> Int {
        var count = 0
        for journal in journals
            .filter({ $0.isValidForDisplay && matches(journal: $0, goal: goal) })
            .sorted(by: { $0.dateUnwrapped > $1.dateUnwrapped }) {
            if journal.isGoalInUnwrapped { break }
            count += 1
        }
        return count
    }

    // MARK: 보조

    private static func matches(journal: JournalData, goal: String) -> Bool {
        journal.subGoalUnwrapped == goal || journal.mainGoalUnwrapped == goal
    }

    private static func days(from start: Date, to end: Date) -> Int {
        let calendar = Calendar.current
        let a = calendar.startOfDay(for: start)
        let b = calendar.startOfDay(for: end)
        return max(calendar.dateComponents([.day], from: a, to: b).day ?? 0, 0)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}
