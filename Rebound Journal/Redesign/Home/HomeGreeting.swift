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
    /// 무엇에 대한 얘기였는지 먼저 짚는 말.
    ///
    /// 인용만 던지면 "그건"이 뭘 가리키는지 알 수 없다. 사용자가 그 말을 쓴 건
    /// 며칠 전이고, 그사이 다른 목표들도 있었다. 어느 목표를 두고 한 말인지가
    /// 같이 있어야 기억이 되살아난다.
    let context: String
    let question: String

    /// "그건 어떻게 됐어요?"에 대한 답.
    ///
    /// 됐다/안 됐다로만 물으면 실제 상태가 담기지 않는다. 안 된 이유가 하나가
    /// 아니기 때문이다. **잊은 것과 미루는 것은 서로 다른 얘기다.**
    ///
    ///  - 잊었다면 눈에 띄지 않았던 것이지 하기 싫었던 게 아니다. 캐물을 게 없다.
    ///  - 자꾸 미뤄진다면 그 일이 아직 크다는 뜻이다. 여기가 §6의 쪼개기가
    ///    필요한 자리고, 그래서 이 답만 대화로 이어진다.
    ///
    /// 둘을 "아직이에요" 하나로 묶으면 이 갈림길이 사라진다.
    enum Answer {
        /// 그 뒤에 해냈다. 적어두지 못했을 뿐이다.
        case done
        /// 잊고 있었다.
        case forgot
        /// 자꾸 미루게 된다.
        case postponed
        /// 지금은 말하고 싶지 않다.
        case later
    }
}

enum HomeGreeting {

    /// 처음 만났을 때. 앱을 켜자마자 목표부터 적으라고 하지 않는다.
    ///
    /// 상대가 누구인지 모르는 채로 요구부터 받으면 그냥 닫게 된다. 이름을 대고,
    /// 무엇을 하는 사이인지 한 줄로 알린 다음, 마지막에야 묻는다.
    ///
    /// 메타포는 설명하지 않는다 (§4). 징검다리가 어떻고 실패가 어떻고를 늘어놓지
    /// 않고, 이 앱이 실제로 하는 일만 말한다 — 내가 먼저 보고 말을 건다는 것.
    static func introduction() -> [GreetingLine] {
        [
            GreetingLine(text: "안녕하세요. 저는 징검돌이에요."),
            GreetingLine(text: "무엇에 닿았고 무엇이 막혔는지, 제가 먼저 보고 말을 걸게요."),
            GreetingLine(text: "지금 향하고 있는 게 있으면 하나만 들려주실래요?")
        ]
    }

    /// 첫 만남에서 "나중에요"라고 했을 때. 붙잡지 않는다.
    static let introDeferred = "네, 그럼 그때 얘기해요. 여기 있을게요."

    /// 조약돌이 처음 건네는 말들.
    static func lines(
        observation: GoalObservation,
        followUp: FollowUp?,
        goalCount: Int
    ) -> [GreetingLine] {
        var lines: [GreetingLine] = []

        // 매듭짓지 못한 게 있으면 그게 먼저다. 오늘 얘기보다 지난 얘기의 끝맺음이 급하다.
        //
        // 무엇에 대한 얘기였는지 짚고 나서 묻는다. 한 문장에 목표와 인용과 물음을
        // 다 넣으면 말풍선이 세 줄로 늘어져 읽기가 걸린다.
        if let followUp {
            lines.append(GreetingLine(text: followUp.context))
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
        let context: String

        if let blocked = journal.review?.trimmingCharacters(in: .whitespacesAndNewlines),
           !blocked.isEmpty {
            // 어느 목표 얘기였는지 먼저 대고, 그때 사용자가 쓴 말을 그대로 인용한다.
            // 앱이 요약해 버리면 남의 말이 된다.
            context = "\(when) '\(goal)'\(goal.particle("을", "를")) 두고 '\(condensed(blocked))'라고 하셨어요."
        } else {
            context = "\(when) '\(goal)'\(goal.particle("이", "가")) 막혔다고 하셨어요."
        }

        return FollowUp(
            journalID: id,
            goal: goal,
            context: context,
            question: "그건 어떻게 됐어요?"
        )
    }

    /// 답을 듣고 조약돌이 하는 말.
    static func reply(to answer: FollowUp.Answer, goal: String) -> String {
        switch answer {
        case .done:
            "그럼 그건 끝난 얘기네요. 지금 적어둘게요."
        case .forgot:
            // 잊은 걸 나무라지 않는다. 눈에 안 띄었던 것뿐이다.
            "그럴 수 있어요. 잊었다고 없어지는 건 아니니까요."
        case .postponed:
            // 여기서는 대화가 열리므로 이 말은 쓰이지 않는다.
            "그럼 그 얘기를 해볼까요."
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
