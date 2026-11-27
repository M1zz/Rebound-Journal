//
//  ProgressObserverTests.swift
//  모찌모
//
//  모찌모가 언제 말을 걸고 언제 조용히 있는가 — 관찰 하나 고르기, 막힌 기록 다시 묻기,
//  이번 주 징검다리. 채근하지 않는다는 약속이 셈에 들어 있는지 본다.
//

import XCTest
@testable import Mochimo

final class ProgressObserverTests: XCTestCase {

    private let cal = Calendar.current
    private lazy var now = cal.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!

    private func daysAgo(_ n: Int, hour: Int = 10) -> Date {
        let day = cal.date(byAdding: .day, value: -n, to: now)!
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    private func journal(_ goal: String, daysAgo n: Int, reached: Bool, hour: Int = 10,
                         deleted: Bool = false, review: String? = nil, plan: String? = nil,
                         asked: Int? = nil, resolved: Bool? = nil) -> JournalData {
        JournalData(id: UUID().uuidString, date: daysAgo(n, hour: hour), hasDeleted: deleted, isGoalIn: reached,
                    review: review, nextPlan: plan, subGoal: goal, isResolved: resolved, retryCount: asked)
    }

    private func goals(_ texts: String...) -> [SubGoalData] {
        texts.map { SubGoalData(id: UUID().uuidString, date: now, goalText: $0) }
    }

    // MARK: - 목표 하나에 대한 관찰

    func testNeverAttemptedGoal() {
        XCTAssertEqual(ProgressObserver.observation(for: "물 마시기", journals: [], now: now).kind,
                       .neverAttempted(goal: "물 마시기"))
    }

    func testReachedTodayIsCelebrated() {
        let j = [journal("산책", daysAgo: 0, reached: true)]
        XCTAssertEqual(ProgressObserver.observation(for: "산책", journals: j, now: now).kind,
                       .reached(goal: "산책", daysAgo: 0))
    }

    func testOlderAttemptCountsDaysFromTheLatest() {
        let j = [journal("산책", daysAgo: 9, reached: true), journal("산책", daysAgo: 3, reached: false)]
        XCTAssertEqual(ProgressObserver.observation(for: "산책", journals: j, now: now).kind,
                       .notReached(goal: "산책", daysAgo: 3))
    }

    func testDeletedRecordsAreInvisible() {
        let j = [journal("산책", daysAgo: 0, reached: true, deleted: true)]
        XCTAssertEqual(ProgressObserver.observation(for: "산책", journals: j, now: now).kind,
                       .neverAttempted(goal: "산책"))
    }

    // MARK: - 화면에 올릴 관찰 하나

    func testNoGoalYet() {
        XCTAssertEqual(ProgressObserver.primaryObservation(goals: [], journals: [], now: now).kind, .noGoalYet)
        XCTAssertEqual(ProgressObserver.primaryObservation(goals: goals(""), journals: [], now: now).kind, .noGoalYet)
    }

    func testTodaysWinComesBeforeAnythingStale() {
        let j = [journal("독서", daysAgo: 0, reached: true), journal("산책", daysAgo: 20, reached: false)]
        XCTAssertEqual(ProgressObserver.primaryObservation(goals: goals("독서", "산책"), journals: j, now: now).kind,
                       .reached(goal: "독서", daysAgo: 0))
    }

    func testNeverTouchedGoalIsRaisedBeforeOneLeftAWhile() {
        let j = [journal("산책", daysAgo: 20, reached: false)]
        XCTAssertEqual(ProgressObserver.primaryObservation(goals: goals("산책", "일기"), journals: j, now: now).kind,
                       .neverAttempted(goal: "일기"))
    }

    func testMostNeglectedGoalIsTheOneRaised() {
        let j = [journal("산책", daysAgo: 2, reached: false), journal("독서", daysAgo: 6, reached: false)]
        XCTAssertEqual(ProgressObserver.primaryObservation(goals: goals("산책", "독서"), journals: j, now: now).kind,
                       .notReached(goal: "독서", daysAgo: 6))
    }

    func testStaysQuietRightAfterARecord() {
        let j = [journal("산책", daysAgo: 0, reached: false)]
        XCTAssertEqual(ProgressObserver.primaryObservation(goals: goals("산책"), journals: j, now: now).kind, .quiet,
                       "방금 남긴 목표뿐이면 말을 걸지 않는다")
    }

    // MARK: - 지난 성공

    func testRecentSuccessSkipsTheGoalThatIsStuck() {
        let j = [journal("독서", daysAgo: 1, reached: true, review: "한 장 읽음"),
                 journal("산책", daysAgo: 2, reached: true),
                 journal("독서", daysAgo: 5, reached: false)]
        XCTAssertEqual(ProgressObserver.recentSuccess(journals: j, now: now)?.goal, "독서")
        XCTAssertEqual(ProgressObserver.recentSuccess(journals: j, excluding: "독서", now: now)?.goal, "산책")
        XCTAssertNil(ProgressObserver.recentSuccess(journals: [journal("독서", daysAgo: 1, reached: false)], now: now))
    }

    // MARK: - 막힌 기록 다시 묻기

    func testDoesNotAskOnTheSameDay() {
        XCTAssertNil(ProgressObserver.unresolved(journals: [journal("산책", daysAgo: 0, reached: false)], now: now))
        XCTAssertNotNil(ProgressObserver.unresolved(journals: [journal("산책", daysAgo: 1, reached: false)], now: now))
    }

    func testDoesNotAskWhenTheStoryMovedOn() {
        let j = [journal("산책", daysAgo: 4, reached: false), journal("산책", daysAgo: 2, reached: true)]
        XCTAssertNil(ProgressObserver.unresolved(journals: j, now: now), "그 뒤 기록이 있으면 옛 기록은 묻지 않는다")
    }

    func testPostponedIsAskedAgainOnlyAfterAPause() {
        let stuck = journal("산책", daysAgo: 2, reached: false)
        ProgressObserver.postponeFollowUp(stuck)
        XCTAssertEqual(stuck.retryCount, 1)
        XCTAssertNil(ProgressObserver.unresolved(journals: [stuck], now: now), "지금은 말고 → 며칠 쉰다")
        let later = cal.date(byAdding: .day, value: 2, to: now)!
        XCTAssertTrue(ProgressObserver.unresolved(journals: [stuck], now: later) === stuck)
    }

    func testAnsweredIsNeverAskedAgain() {
        let stuck = journal("산책", daysAgo: 3, reached: false)
        ProgressObserver.closeFollowUp(stuck)
        for extra in 0..<20 {
            let day = cal.date(byAdding: .day, value: extra, to: now)!
            XCTAssertNil(ProgressObserver.unresolved(journals: [stuck], now: day))
        }
    }

    func testOldOrResolvedRecordsAreLeftAlone() {
        XCTAssertNil(ProgressObserver.unresolved(journals: [journal("산책", daysAgo: 15, reached: false)], now: now),
                     "두 주가 넘은 건 꺼내지 않는다")
        XCTAssertNil(ProgressObserver.unresolved(journals: [journal("산책", daysAgo: 3, reached: false, resolved: true)], now: now))
        XCTAssertNil(ProgressObserver.unresolved(journals: [journal("", daysAgo: 3, reached: false)], now: now))
    }

    func testNewestStuckRecordIsAskedFirst() {
        let a = journal("산책", daysAgo: 5, reached: false)
        let b = journal("독서", daysAgo: 2, reached: false)
        XCTAssertTrue(ProgressObserver.unresolved(journals: [a, b], now: now) === b)
    }

    // MARK: - 지난 기록

    func testLastNoteNeedsSomethingWritten() {
        XCTAssertNil(ProgressObserver.lastNote(for: "산책", journals: [journal("산책", daysAgo: 1, reached: false, review: "   ")]))
        let note = ProgressObserver.lastNote(for: "산책", journals: [
            journal("산책", daysAgo: 5, reached: false, plan: "옛 계획"),
            journal("산책", daysAgo: 1, reached: true, review: "좋았다")
        ])
        XCTAssertEqual(note?.review, "좋았다")
        XCTAssertEqual(note?.reached, true)
    }

    func testAllDaysGroupsByDayNewestFirstAndKeepsOrderWithinADay() {
        let j = [journal("a", daysAgo: 0, reached: false, hour: 18),
                 journal("b", daysAgo: 0, reached: true, hour: 8),
                 journal("c", daysAgo: 3, reached: false),
                 journal("d", daysAgo: 1, reached: false, deleted: true)]
        let days = ProgressObserver.allDays(journals: j)
        XCTAssertEqual(days.count, 2)
        XCTAssertEqual(days[0].entries.map(\.subGoal), ["b", "a"])
        XCTAssertEqual(days[1].entries.map(\.subGoal), ["c"])
        XCTAssertEqual(ProgressObserver.notes(for: "a", journals: j).count, 1)
    }

    // MARK: - 징검다리

    func testWeekStonesNeverCountAMissedDayAsAFailure() {
        let start = WeekStones.startOfWeek(containing: now)
        let offset = cal.dateComponents([.day], from: start, to: cal.startOfDay(for: now)).day!
        var j: [JournalData] = []
        if offset >= 2 {
            j.append(journal("산책", daysAgo: offset, reached: true))          // 주의 첫날
            j.append(journal("산책", daysAgo: offset - 1, reached: false))     // 둘째 날
        }
        let stones = WeekStones.days(weekStarting: start, journals: j, now: now)
        XCTAssertEqual(stones.count, 7)
        XCTAssertEqual(stones.filter(\.isToday).count, 1)
        XCTAssertTrue(stones[(offset + 1)...].allSatisfy { $0.state == .ahead }, "오지 않은 날은 앞으로 올 돌이다")
        if offset >= 2 {
            XCTAssertEqual(stones[0].state, .reached)
            XCTAssertEqual(stones[1].state, .recorded)
        }
        XCTAssertFalse(WeekStones.canGoForward(from: start, now: now), "이번 주 뒤로는 넘어가지 않는다")
        XCTAssertTrue(WeekStones.canGoForward(from: cal.date(byAdding: .day, value: -7, to: start)!, now: now))
    }
}
