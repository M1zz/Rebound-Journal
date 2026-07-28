//
//  HomeGreeting.swift
//  Rebound Journal
//
//  앱을 열었을 때 조약돌이 건네는 말.
//
//  순서를 이렇게 잡았다.
//
//   1. 매듭짓지 못한 것부터 묻는다 — "그건 어떻게 됐어요?"
//      막혔다고 적어둔 뒤 아무 소식이 없으면 기록이 실패 목록으로 굳는다.
//      물어봐야 이야기가 끝난다. 이게 이 앱이 §4에서 말한 "다음 기회를 자연스럽게
//      제시하는" 자리다. 재도전하라고 말하지 않고 어떻게 됐는지만 묻는다.
//   2. 그 다음 오늘의 상태를 전한다.
//
//  한 번에 두 마디를 넘기지 않는다. 열자마자 할 말이 쏟아지면 그 자체가 압박이다 (§5).
//

import Foundation

struct GreetingLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

/// 매듭짓지 못한 기록에 대한 물음. 답에 따라 기록이 닫히거나 대화로 이어진다.
struct FollowUp: Equatable {
    /// 물어보는 대상 기록의 식별값.
    let journalID: String
    let goal: String
    let question: String

    enum Answer {
        /// 그 뒤에 해냈다. 기록을 닫고 성공으로 남긴다.
        case done
        /// 아직이다. 얘기해볼지 물어본다.
        case notYet
        /// 지금은 말하고 싶지 않다.
        case later
    }
}

enum HomeGreeting {

    /// 조약돌이 처음 건네는 말들.
    static func lines(
        observation: GoalObservation,
        followUp: FollowUp?,
        goalCount: Int
    ) -> [GreetingLine] {
        var lines: [GreetingLine] = []

        // 매듭짓지 못한 게 있으면 그게 먼저다. 오늘 얘기보다 지난 얘기의 끝맺음이 급하다.
        if let followUp {
            lines.append(GreetingLine(text: followUp.question))
            return lines
        }

        lines.append(GreetingLine(text: observation.headline))

        // 목표가 여럿일 때만 한 줄 덧붙인다. 하나뿐이면 위에서 이미 그 얘기를 했다.
        if goalCount > 1, let extra = statusLine(observation: observation, goalCount: goalCount) {
            lines.append(GreetingLine(text: extra))
        }

        return lines
    }

    /// 목표가 여럿일 때의 현황 한 줄.
    ///
    /// 개수와 달성률을 늘어놓지 않는다. "몇 개 남았다"는 말은 곧 밀린 일 목록이고,
    /// 그건 §6이 피하려던 바로 그 압박이다.
    private static func statusLine(observation: GoalObservation, goalCount: Int) -> String? {
        switch observation.kind {
        case .reached:
            "나머지도 천천히 보면 돼요."
        case .notReached, .neverAttempted:
            "다른 것들은 그대로 두고, 이거 하나만 볼까요?"
        case .noGoalYet, .quiet:
            nil
        }
    }

    /// 매듭짓지 못한 기록에 대한 물음을 만든다.
    static func followUp(for journal: JournalData, now: Date = Date()) -> FollowUp? {
        guard let id = journal.id,
              let goal = journal.subGoal ?? journal.mainGoal,
              !goal.isEmpty else { return nil }

        let when = elapsedPhrase(from: journal.dateUnwrapped, to: now)
        let question: String

        if let blocked = journal.review?.trimmingCharacters(in: .whitespacesAndNewlines),
           !blocked.isEmpty {
            // 그때 사용자가 쓴 말을 그대로 인용한다. 앱이 요약해 버리면 남의 말이 된다.
            question = "\(when) '\(condensed(blocked))'라고 하셨죠. 그건 어떻게 됐어요?"
        } else {
            question = "\(when) '\(goal)'\(goal.particle("이", "가")) 막혔다고 하셨죠. 그건 어떻게 됐어요?"
        }

        return FollowUp(journalID: id, goal: goal, question: question)
    }

    /// 답을 듣고 조약돌이 하는 말.
    static func reply(to answer: FollowUp.Answer, goal: String) -> String {
        switch answer {
        case .done:
            "그럼 그건 끝난 얘기네요. 잘 적어둘게요."
        case .notYet:
            "네, 아직인 거죠. 그것도 그대로 둬요."
        case .later:
            "알겠어요. 여기 있을게요."
        }
    }

    // MARK: 보조

    private static func elapsedPhrase(from start: Date, to end: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: end)
        ).day ?? 0

        return switch days {
        case ...1: "어제"
        case 2...6: "며칠 전에"
        case 7...13: "지난주에"
        case 14...30: "얼마 전에"
        default: "한참 전에"
        }
    }

    /// 인용할 만큼만 잘라낸다.
    ///
    /// 끝의 마침표는 뗀다. 따옴표 안에 마침표가 남으면 "'…잤어요.'라고 하셨죠."처럼
    /// 문장부호가 겹쳐 읽기가 걸린다.
    private static func condensed(_ text: String) -> String {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = clean.last, ".!?…".contains(last) {
            clean.removeLast()
        }
        guard clean.count > 22 else { return clean }
        return clean.prefix(22).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
