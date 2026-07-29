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
    ///
    /// 매일 여는 화면이라 같은 문장이 반복되면 안내판처럼 읽힌다. 뜻은 그대로
    /// 두고 말만 바꾼다. 고르는 방식은 `Phrasing` 참고 — 같은 날엔 같은 말이 나온다.
    var headline: String {
        switch kind {
        case .noGoalYet:
            Phrasing.pick([
                "무엇을 향해 가고 있는지 아직 못 들었어요.",
                "아직 어디로 가는 중인지 못 들었어요.",
                "향하는 곳을 아직 못 들었네요."
            ], seed: Phrasing.today())

        case .neverAttempted(let goal):
            Phrasing.pick([
                "'\(goal)'\(goal.particle("을", "를")) 적어두고 아직 돌아본 적은 없네요.",
                "'\(goal)'\(goal.particle("은", "는")) 적어두기만 하고 아직이에요.",
                "'\(goal)'\(goal.particle("을", "를")) 적어둔 뒤로는 아직 조용해요."
            ], seed: Phrasing.today(with: goal))

        case .reached(let goal, let daysAgo):
            daysAgo == 0
                ? Phrasing.pick([
                    "오늘 '\(goal)'에 닿았네요.",
                    "오늘 '\(goal)', 해내셨네요.",
                    "'\(goal)'에 닿은 하루였네요."
                ], seed: Phrasing.today(with: goal))
                : Phrasing.pick([
                    "\(Self.dayPhrase(daysAgo)) '\(goal)'에 닿았어요.",
                    "\(Self.dayPhrase(daysAgo)) '\(goal)'\(goal.particle("을", "를")) 해내셨죠.",
                    "'\(goal)'에 닿은 게 \(Self.dayPhrase(daysAgo))였어요."
                ], seed: Phrasing.today(with: goal))

        case .notReached(let goal, let daysAgo):
            daysAgo <= 1
                ? Phrasing.pick([
                    "'\(goal)'\(goal.particle("은", "는")) 오늘 아직 닿지 않았네요.",
                    "'\(goal)', 오늘은 아직이네요.",
                    "오늘 '\(goal)'\(goal.particle("은", "는")) 아직 소식이 없어요."
                ], seed: Phrasing.today(with: goal))
                : Phrasing.pick([
                    "'\(goal)'\(goal.particle("을", "를")) 돌아본 지 \(daysAgo)일 됐어요.",
                    "'\(goal)'\(goal.particle("은", "는")) \(daysAgo)일째 조용하네요.",
                    "'\(goal)' 얘기를 나눈 지 \(daysAgo)일이 지났어요."
                ], seed: Phrasing.today(with: goal))

        case .quiet:
            Phrasing.pick([
                "오늘은 그냥 옆에 있을게요.",
                "오늘은 조용히 있을게요.",
                "딱히 할 말은 없어요. 그냥 여기 있어요."
            ], seed: Phrasing.today())
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
        case .notReached(let goal, _):
            Phrasing.pick([
                "무슨 일이 있었는지 얘기하기",
                "그때 얘기 해볼래요",
                "잠깐 얘기해요"
            ], seed: Phrasing.today(with: goal))
        case .reached(let goal, _):
            Phrasing.pick([
                "어떻게 됐는지 남기기",
                "뭐가 통했는지 적어두기",
                "잊기 전에 적어둘래요"
            ], seed: Phrasing.today(with: goal))
        case .neverAttempted(let goal):
            Phrasing.pick([
                "지금 얘기해보기",
                "여기서부터 얘기해요"
            ], seed: Phrasing.today(with: goal))
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
        return Phrasing.pick([
            "\(when)에는 '\(goal)'\(goal.particle("을", "를")) 해내셨어요.",
            "\(when)에 '\(goal)'\(goal.particle("은", "는")) 해내셨잖아요.",
            "\(when)에는 '\(goal)'에 닿으셨고요."
        ], seed: Phrasing.today(with: goal))
    }
}

// MARK: - 지난번에 적은 것

/// 같은 목표를 두고 지난번에 남긴 기록.
///
/// 대화에서 다시 묻기 전에 꺼내 보여준다. 기록이 보관함에만 쌓이면 아무 일도
/// 일어나지 않는다. 다시 막혔을 때 눈앞에 놓여야 패턴이 보이고, 그래야 §6의
/// "더 작게 쪼개기"가 지난번보다 나은 답으로 이어진다.
struct PreviousNote: Equatable {
    let date: Date
    let review: String?
    let plan: String?
    let reached: Bool

    /// 조약돌이 대화에서 꺼낼 한 줄. 비교하거나 나무라지 않고 사실만 옮긴다.
    var recall: String? {
        if let plan = PreviousNote.trimmed(plan) {
            // "…부터 시작하기"처럼 사용자가 쓴 말에 이미 조사가 들어 있는 경우가 많다.
            // 여기서 또 "부터"를 붙이면 겹치므로 목적격 조사만 쓴다.
            let short = PreviousNote.condensed(plan)
            return Phrasing.pick([
                "지난번엔 '\(short)'\(short.particle("을", "를")) 해보기로 했었어요.",
                "지난번에 '\(short)'\(short.particle("으로", "로")) 정하셨었죠.",
                "그때 '\(short)'\(short.particle("을", "를")) 해보자고 하셨어요."
            ], seed: Phrasing.today(with: short))
        }
        if let review = PreviousNote.trimmed(review) {
            let short = PreviousNote.condensed(review)
            return Phrasing.pick([
                "지난번엔 '\(short)'라고 적으셨어요.",
                "그때는 '\(short)'라고 하셨죠.",
                "지난 기록엔 '\(short)'라고 남아 있어요."
            ], seed: Phrasing.today(with: short))
        }
        return nil
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    /// 길면 앞부분만 인용한다. 통째로 되돌려주면 반성문처럼 읽힌다.
    private static func condensed(_ text: String) -> String {
        guard text.count > 24 else { return text }
        return text.prefix(24).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

/// 하루치 기록 한 줄. 어느 목표였는지가 함께 있어야 그날이 읽힌다.
struct DayNote: Identifiable, Equatable {
    let goal: String
    let note: PreviousNote
    var id: String { "\(goal)-\(note.date.timeIntervalSince1970)" }
}

/// 하루와 그날의 기록들.
///
/// 여기서는 값이 아니라 기록 자체를 들고 간다. 원본 목록에서는 고치고 지울 수
/// 있어야 하는데, 값만 뽑아 넘기면 무엇을 고쳐야 하는지 되찾을 길이 없다.
struct RecordedDay: Identifiable {
    let day: Date
    let entries: [JournalData]
    var id: Date { day }
}

// MARK: - 관찰자

enum ProgressObserver {

    /// 목표에 닿지 않은 채 이만큼 지나면 말을 건다. 매일 채근하지 않기 위한 간격이다.
    static let quietDays = 1

    /// 목표 하나를 두고 지금 상태를 말한다.
    ///
    /// 사용자가 목록에서 목표를 직접 고른 경우에도 이 함수를 쓴다. 그때는 `.quiet`을
    /// 돌려주지 않는다 — 물어봤는데 "오늘은 그냥 옆에 있을게요"라고 답하면 대화가
    /// 끊긴다. 고른 목표에 대해서는 언제나 할 말이 있어야 한다.
    static func observation(
        for goal: String,
        journals: [JournalData],
        now: Date = Date()
    ) -> GoalObservation {
        let entries = journals
            .filter { $0.isValidForDisplay && matches(journal: $0, goal: goal) }

        guard let latest = entries.max(by: { $0.dateUnwrapped < $1.dateUnwrapped }) else {
            return GoalObservation(kind: .neverAttempted(goal: goal))
        }

        let elapsed = days(from: latest.dateUnwrapped, to: now)

        // 오늘 닿았으면 그 얘기부터. 좋은 소식이 우선이다.
        if latest.isGoalInUnwrapped && elapsed == 0 {
            return GoalObservation(kind: .reached(goal: goal, daysAgo: 0))
        }

        return GoalObservation(kind: .notReached(goal: goal, daysAgo: elapsed))
    }

    /// 아무것도 고르지 않았을 때 화면에 올릴 관찰 하나를 고른다.
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

        // 오늘 이미 닿은 목표가 있으면 그걸 먼저 축하한다.
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

        // 방금 남긴 목표뿐이면 말을 걸지 않는다. 매일 채근하지 않기 위한 간격이다.
        if let elapsed = candidate.days, elapsed < quietDays {
            return GoalObservation(kind: .quiet)
        }

        return observation(for: candidate.goal, journals: live, now: now)
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

    /// 아직 매듭짓지 못한 기록 하나.
    ///
    /// 막혔다고 적어두고 그 뒤로 아무 소식이 없는 것. 여기에 앱이 다시 물어봐야
    /// 이야기가 끝난다. 묻지 않으면 "막혔다"는 기록만 남고 그 뒤가 없어서,
    /// 나중에 돌아봤을 때 실패 목록처럼 보인다.
    ///
    /// 오늘 적은 건 묻지 않는다. 적자마자 "그건 어떻게 됐어요?"라고 물으면 재촉이 된다.
    static func unresolved(journals: [JournalData], now: Date = Date()) -> JournalData? {
        journals
            .filter { $0.isActiveRebound && nonEmpty($0.subGoal) != nil }
            .filter { days(from: $0.dateUnwrapped, to: now) >= 1 }
            .max { $0.dateUnwrapped < $1.dateUnwrapped }
    }

    /// 이 목표에 대해 지난번에 남긴 기록 하나.
    static func lastNote(for goal: String, journals: [JournalData]) -> PreviousNote? {
        guard let latest = journals
            .filter({ $0.isValidForDisplay && matches(journal: $0, goal: goal) })
            .max(by: { $0.dateUnwrapped < $1.dateUnwrapped }) else { return nil }

        let note = PreviousNote(
            date: latest.dateUnwrapped,
            review: nonEmpty(latest.review),
            plan: nonEmpty(latest.nextPlan),
            reached: latest.isGoalInUnwrapped
        )
        // 적힌 내용이 없으면 꺼낼 것도 없다.
        return note.recall == nil ? nil : note
    }

    /// 그날 남긴 기록. 돌 하나를 눌렀을 때 무엇이 있었는지 보여준다.
    static func notes(on day: Date, journals: [JournalData], calendar: Calendar = .current) -> [DayNote] {
        journals
            .filter { $0.isValidForDisplay && calendar.isDate($0.dateUnwrapped, inSameDayAs: day) }
            .sorted { $0.dateUnwrapped < $1.dateUnwrapped }
            .map(dayNote(from:))
    }

    /// 남긴 기록 전부를 날짜별로 묶는다. 최근 날이 먼저.
    ///
    /// 여기서는 아무것도 솎아내지 않는다. 목표별로 모아 보여주는 자리(`지나온 길`)와
    /// 달리, 이 목록의 쓸모는 "내가 지금까지 뭘 적었지?"를 통으로 훑는 것이라
    /// 앱이 골라서 보여주면 그 쓸모가 사라진다.
    static func allDays(journals: [JournalData], calendar: Calendar = .current) -> [RecordedDay] {
        let live = journals.filter(\.isValidForDisplay)
        let grouped = Dictionary(grouping: live) { calendar.startOfDay(for: $0.dateUnwrapped) }

        return grouped
            .map { day, entries in
                RecordedDay(
                    day: day,
                    entries: entries.sorted { $0.dateUnwrapped < $1.dateUnwrapped }
                )
            }
            .sorted { $0.day > $1.day }
    }

    private static func dayNote(from journal: JournalData) -> DayNote {
        DayNote(
            goal: nonEmpty(journal.subGoal) ?? nonEmpty(journal.mainGoal) ?? "적어둔 목표 없음",
            note: PreviousNote(
                date: journal.dateUnwrapped,
                review: nonEmpty(journal.review),
                plan: nonEmpty(journal.nextPlan),
                reached: journal.isGoalInUnwrapped
            )
        )
    }

    /// 이 목표에 대한 기록 전부. 최근 것이 먼저.
    static func notes(for goal: String, journals: [JournalData]) -> [PreviousNote] {
        journals
            .filter { $0.isValidForDisplay && matches(journal: $0, goal: goal) }
            .sorted { $0.dateUnwrapped > $1.dateUnwrapped }
            .map {
                PreviousNote(
                    date: $0.dateUnwrapped,
                    review: nonEmpty($0.review),
                    plan: nonEmpty($0.nextPlan),
                    reached: $0.isGoalInUnwrapped
                )
            }
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
