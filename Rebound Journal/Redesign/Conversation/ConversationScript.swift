//
//  ConversationScript.swift
//  Rebound Journal
//
//  질문 시퀀스. 설계 고찰 §11의 남은 과제 3("몇 개, 어떤 순서, 언제 멈출지")에 대한 답이다.
//
//  지켜야 할 규칙:
//   1. 사용자가 스스로 "실패했다"고 말하게 하지 않는다 — 앱이 먼저 관찰한다 (§5-A).
//   2. 상황과 감정을 **서로 다른 턴**에서 묻는다 (§5-B). 한 화면에 같이 두면 섞인다.
//   3. 앱이 목표를 쪼개주지 않는다. 질문만 던지고 사용자가 쪼갠다 (§6).
//   4. 감정이 바닥일 때는 분석을 요구하지 않고 대화를 끝낸다 (§5 주의).
//   5. 어느 턴에서든 빠져나갈 수 있다. 빠져나가는 선택지가 항상 화면에 있다.
//
//  화면에 나가는 문구에는 "실패", "슛", "골인", "리바운드"가 없다 (§4).
//

import Foundation

// MARK: - 대화의 마디

enum Beat: String, Equatable {
    /// 앱이 관찰한 사실을 중립적으로 전한다.
    case observation
    /// 그 관찰이 맞는지 확인한다. 앱이 틀렸을 수 있다는 걸 인정하는 자리.
    case confirm
    /// 상황을 묻는다. 사실만.
    case facts
    /// 감정을 묻는다. 사실과 분리된 자리.
    case emotion
    /// 앱이 둘을 나눠서 되짚어 준다. "나는 능력이 없다"를 "상황이 막혔다"로 옮기는 지점.
    case separation
    /// 예전에 해낸 일을 떠올린다.
    case recall
    /// 더 작게 만드는 질문. 답을 주지 않는다.
    case smaller
    /// 마무리.
    case close
}

// MARK: - 응답 방식

enum ResponseKind: Equatable {
    case choices([Choice])
    /// 자유 응답. 음성과 텍스트를 함께 받는다 (§7).
    case freeform(placeholder: String)
    /// 0(힘듦) ~ 4(좋음). 기존 저장 형식과 같은 눈금을 쓴다.
    case emotionScale
    /// 조약돌만 말하고 넘어간다.
    case acknowledgement(String)
}

struct Choice: Equatable, Identifiable {
    let id: String
    let label: String
    let outcome: Outcome

    enum Outcome: Equatable {
        /// 관찰이 맞다 — 이야기를 이어간다.
        case confirmObservation
        /// 앱이 틀렸다. 사실은 해냈다.
        case correctToReached
        /// 지금은 말하고 싶지 않다. 즉시, 아무 대가 없이 끝낸다.
        case leave
        case advance
    }
}

// MARK: - 스크립트

enum ConversationScript {

    /// 감정 눈금이 이 값 이하면 더 캐묻지 않는다.
    ///
    /// §5의 "실패 직후에는 감정이 낮아 객관적 분석이 어렵습니다. 사용자에게 분석을
    /// 강요하지 말고" — 이 한 줄이 이 상수의 근거다. 이 아래에서는 쪼개기 질문(§6)을
    /// 통째로 건너뛰고 대화를 닫는다.
    static let tooLowToAnalyze = 1

    /// 언제나 화면에 있는 퇴장 선택지.
    static let leaveChoice = Choice(
        id: "leave",
        label: "지금은 그냥 둘래요",
        outcome: .leave
    )

    // MARK: 관찰 확인

    static func confirmChoices(goal: String) -> [Choice] {
        [
            Choice(id: "yes", label: "맞아요, 못 했어요", outcome: .confirmObservation),
            Choice(id: "actually", label: "했는데 남기질 못했어요", outcome: .correctToReached),
            leaveChoice
        ]
    }

    // MARK: 질문 문구

    /// 상황을 묻는다. "왜 안 했어요?"가 아니라 "뭐가 막혔어요?"다.
    /// 원인을 사람이 아니라 상황에 둔다.
    static func factsPrompt(goal: String) -> String {
        "'\(goal)'을 하려던 때로 돌아가 볼게요. 뭐가 막혔어요?"
    }

    static let factsPlaceholder = "짧아도 괜찮아요. 그때 무슨 일이 있었는지만."

    /// 감정은 반드시 별도의 턴에서 묻는다 (§5-B).
    static let emotionPrompt = "그건 상황 얘기였고요. 지금 기분은 어때요?"

    /// 성공했을 때의 질문. 성공도 사실과 감정을 나눠 묻는다 — 나중에 되짚어 주려면
    /// 무엇이 통했는지가 기록으로 남아 있어야 한다 (§5).
    static func whatWorkedPrompt(goal: String) -> String {
        "'\(goal)'에 닿았네요. 뭐가 도움이 됐어요?"
    }

    static let whatWorkedPlaceholder = "다음에 또 쓸 수 있게 적어둘게요."

    /// 쪼개기 질문 (§6). 앱이 쪼갠 결과를 제시하지 않는다는 점이 중요하다.
    /// SMART를 다시 들이미는 대신, 사용자가 스스로 계획하는 근육을 쓰게 한다.
    static let smallerPrompt = "그럼 이건 어때요. 내일 바로 해낼 수 있을 만큼 작게 만든다면, 뭐가 될까요?"

    static let smallerPlaceholder = "작을수록 좋아요. 5분짜리여도 괜찮아요."

    // MARK: 되짚기

    /// 사실과 감정을 갈라서 돌려준다 (§5-B).
    ///
    /// 이 문장 하나가 "나는 능력이 없다"를 "나는 노력했는데 상황이 막혔다"로 옮긴다.
    /// 그래서 상황을 먼저, 감정을 나중에 놓고 사이에 선을 긋는다.
    static func separation(facts: String, emotion: String) -> String {
        let situation = condensed(facts)
        return """
        정리해 볼게요.
        막힌 건 '\(situation)'였고,
        지금 기분은 '\(emotion)'이에요.

        이 둘은 다른 얘기예요.
        """
    }

    /// 감정이 바닥일 때의 마무리. 아무것도 더 묻지 않는다.
    static let gentleClose = """
        오늘은 여기까지 해요.
        지금은 답을 찾는 것보다 쉬는 게 나아요.
        적어두었으니까 없어지지 않아요.
        """

    static let analyticClose = "적어뒀어요. 내일 이만큼만 해봐요."

    static let reachedClose = "잘 기록해 뒀어요. 다음에 막힐 때 이걸 꺼내 볼게요."

    static let leaveClose = "네, 그냥 둘게요. 여기 있을게요."

    // MARK: 감정 눈금

    /// 0 ~ 4. 기존 저장 값과 같은 방향(0이 힘듦)을 유지한다.
    static let emotionSteps: [(value: Int, label: String)] = [
        (0, "많이 힘들어요"),
        (1, "가라앉았어요"),
        (2, "그저 그래요"),
        (3, "괜찮아요"),
        (4, "좋아요")
    ]

    /// 눈금에 붙일 낱말. 기존 `Constants.ContentText`의 어휘를 그대로 쓴다.
    static func emotionWords(for value: Int) -> [String] {
        let text = Constants.ContentText()
        return switch value {
        case 0: text.getEmotions(for: .level3)
        case 1: text.getEmotions(for: .level2)
        case 2: text.getEmotions(for: .level1)
        default: text.getEmotions(for: .level0)
        }
    }

    // MARK: 보조

    /// 되짚어 줄 때 사용자의 문장이 너무 길면 앞부분만 인용한다.
    /// 통째로 되돌려주면 반성문처럼 읽힌다.
    private static func condensed(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 28 else { return trimmed }
        let cut = trimmed.prefix(28).trimmingCharacters(in: .whitespacesAndNewlines)
        return cut + "…"
    }
}
