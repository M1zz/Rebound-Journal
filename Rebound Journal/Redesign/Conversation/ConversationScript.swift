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
        label: Phrasing.say("지금은 그냥 둘래요", "지금은 그냥 둘래"),
        outcome: .leave
    )

    // MARK: 관찰 확인

    static func confirmChoices(goal: String) -> [Choice] {
        [
            Choice(
                id: "yes",
                label: Phrasing.say("맞아요, 못 했어요", "맞아, 못 했어"),
                outcome: .confirmObservation
            ),
            Choice(
                id: "actually",
                label: Phrasing.say("했는데 남기질 못했어요", "했는데 남기질 못했어"),
                outcome: .correctToReached
            ),
            leaveChoice
        ]
    }

    // MARK: 질문 문구

    /// 상황을 묻는다. "왜 안 했어요?"가 아니라 "뭐가 막혔어요?"다.
    /// 원인을 사람이 아니라 상황에 둔다.
    ///
    /// 어떤 말로 묻든 이 원칙은 그대로다. 아래 표현들은 전부 사람이 아니라
    /// 상황에 원인을 두고 있다.
    static func factsPrompt(goal: String) -> String {
        Phrasing.pick(
            formal: [
                "'\(goal)'\(goal.particle("을", "를")) 하려던 때로 돌아가 볼게요. 뭐가 막혔어요?",
                "'\(goal)' 앞에서 뭐가 걸렸어요?",
                "그때 무슨 일이 있었어요?"
            ],
            casual: [
                "'\(goal)'\(goal.particle("을", "를")) 하려던 때로 돌아가 보자. 뭐가 막혔어?",
                "'\(goal)' 앞에서 뭐가 걸렸어?",
                "그때 무슨 일이 있었어?"
            ],
            seed: Phrasing.today(with: goal)
        )
    }

    static var factsPlaceholder: String {
        Phrasing.say(
            "짧아도 괜찮아요. 그때 무슨 일이 있었는지만.",
            "짧아도 괜찮아. 그때 무슨 일이 있었는지만."
        )
    }

    /// 감정은 반드시 별도의 턴에서 묻는다 (§5-B).
    ///
    /// 어느 표현을 쓰든 "그건 상황 얘기였다"는 선 긋기를 남긴다. 그 선이 없으면
    /// 사실과 감정이 도로 섞인다.
    static func emotionPrompt(goal: String) -> String {
        Phrasing.pick(
            formal: [
                "그건 상황 얘기였고요. 지금 기분은 어때요?",
                "여기까진 무슨 일이 있었는지였고요. 지금 마음은 어때요?",
                "상황은 알겠어요. 그래서 지금 어떤 기분이에요?"
            ],
            casual: [
                "그건 상황 얘기였고. 지금 기분은 어때?",
                "여기까진 무슨 일이 있었는지였고. 지금 마음은 어때?",
                "상황은 알겠어. 그래서 지금 어떤 기분이야?"
            ],
            seed: Phrasing.today(with: goal)
        )
    }

    /// 성공했을 때의 질문. 성공도 사실과 감정을 나눠 묻는다 — 나중에 되짚어 주려면
    /// 무엇이 통했는지가 기록으로 남아 있어야 한다 (§5).
    ///
    /// 목표 이름도 "닿았네요"도 여기서 다시 말하지 않는다. 바로 앞 말풍선이
    /// 이미 그 말을 했고, 사이에 사용자 차례가 없어서 그대로 두면 조약돌이 같은
    /// 말을 두 번 하는 것처럼 들린다.
    static func whatWorkedPrompt(goal: String) -> String {
        Phrasing.pick(
            formal: [
                "뭐가 도움이 됐어요?",
                "뭐가 통했어요?",
                "이번엔 뭐가 달랐어요?"
            ],
            casual: [
                "뭐가 도움이 됐어?",
                "뭐가 통했어?",
                "이번엔 뭐가 달랐어?"
            ],
            seed: Phrasing.today(with: goal)
        )
    }

    static var whatWorkedPlaceholder: String {
        Phrasing.say("다음에 또 쓸 수 있게 적어둘게요.", "다음에 또 쓸 수 있게 적어둘게.")
    }

    /// 쪼개기 질문 (§6). 앱이 쪼갠 결과를 제시하지 않는다는 점이 중요하다.
    /// SMART를 다시 들이미는 대신, 사용자가 스스로 계획하는 근육을 쓰게 한다.
    ///
    /// 표현을 바꿔도 이건 지킨다 — 어느 문장도 답을 먼저 내놓지 않고 묻기만 한다.
    static func smallerPrompt(goal: String) -> String {
        Phrasing.pick(
            formal: [
                "그럼 이건 어때요. 내일 바로 해낼 수 있을 만큼 작게 만든다면, 뭐가 될까요?",
                "이걸 더 작게 쪼갠다면 뭐가 될까요?",
                "내일 딱 하나만 한다면, 뭘 하시겠어요?"
            ],
            casual: [
                "그럼 이건 어때. 내일 바로 해낼 수 있을 만큼 작게 만든다면, 뭐가 될까?",
                "이걸 더 작게 쪼갠다면 뭐가 될까?",
                "내일 딱 하나만 한다면, 뭘 할래?"
            ],
            seed: Phrasing.today(with: goal)
        )
    }

    static var smallerPlaceholder: String {
        Phrasing.say("작을수록 좋아요. 5분짜리여도 괜찮아요.", "작을수록 좋아. 5분짜리여도 괜찮아.")
    }

    // MARK: 되짚기

    /// 사실과 감정을 갈라서 돌려준다 (§5-B).
    ///
    /// 이 문장 하나가 "나는 능력이 없다"를 "나는 노력했는데 상황이 막혔다"로 옮긴다.
    /// 그래서 상황을 먼저, 감정을 나중에 놓고 사이에 선을 긋는다.
    /// 표현은 바꾸되 구조는 바꾸지 않는다.
    ///
    /// 막힌 것 → 지금 기분 → 둘은 다른 얘기. 이 세 조각의 순서와 존재가 §5-B
    /// 자체다. 문장을 다듬다 마지막 선 긋기를 빼면 이 마디가 하는 일이 없어진다.
    static func separation(facts: String, emotion: String) -> String {
        let situation = condensed(facts)
        let closing = Phrasing.pick(
            formal: [
                "이 둘은 다른 얘기예요.",
                "상황이 막힌 거지, 사람이 문제인 게 아니에요.",
                "하나는 있었던 일이고, 하나는 지금 마음이에요."
            ],
            casual: [
                "이 둘은 다른 얘기야.",
                "상황이 막힌 거지, 사람이 문제인 게 아니야.",
                "하나는 있었던 일이고, 하나는 지금 마음이야."
            ],
            seed: Phrasing.today(with: situation)
        )

        // 감정 낱말이 모음으로 끝나면 "이에요"가 아니라 "예요"다. 조사를 고정해
        // 두면 눈금 낱말에 따라 "'그저 그래'이에요"처럼 어긋난다.
        let opening = Phrasing.say("정리해 볼게요.", "정리해 볼게.")
        let ending = Phrasing.say(
            emotion.particle("이에요", "예요"),
            emotion.particle("이야", "야")
        )

        return """
        \(opening)
        막힌 건 '\(situation)'였고,
        지금 기분은 '\(emotion)'\(ending).

        \(closing)
        """
    }

    /// 감정이 바닥일 때의 마무리. 아무것도 더 묻지 않는다.
    static var gentleClose: String {
        Phrasing.pick(
            formal: [
                """
                오늘은 여기까지 해요.
                지금은 답을 찾는 것보다 쉬는 게 나아요.
                적어두었으니까 없어지지 않아요.
                """,
                """
                오늘은 여기서 멈춰요.
                지금 억지로 답을 낼 필요 없어요.
                적어뒀으니 다음에 같이 봐요.
                """,
                """
                여기까지만 해요.
                지친 날에 세운 계획은 잘 안 되더라고요.
                남겨뒀으니 괜찮아요.
                """
            ],
            casual: [
                """
                오늘은 여기까지 하자.
                지금은 답을 찾는 것보다 쉬는 게 나아.
                적어뒀으니까 없어지지 않아.
                """,
                """
                오늘은 여기서 멈추자.
                지금 억지로 답을 낼 필요 없어.
                적어뒀으니 다음에 같이 보자.
                """,
                """
                여기까지만 하자.
                지친 날에 세운 계획은 잘 안 되더라고.
                남겨뒀으니 괜찮아.
                """
            ],
            seed: Phrasing.today()
        )
    }

    static var analyticClose: String {
        Phrasing.pick(
            formal: [
                "적어뒀어요. 내일 이만큼만 해봐요.",
                "적어뒀어요. 딱 이만큼이면 돼요.",
                "이걸로 적어둘게요. 내일은 여기까지만."
            ],
            casual: [
                "적어뒀어. 내일 이만큼만 해보자.",
                "적어뒀어. 딱 이만큼이면 돼.",
                "이걸로 적어둘게. 내일은 여기까지만."
            ],
            seed: Phrasing.today()
        )
    }

    static var reachedClose: String {
        Phrasing.pick(
            formal: [
                "잘 기록해 뒀어요. 다음에 막힐 때 이걸 꺼내 볼게요.",
                "적어뒀어요. 다음에 비슷한 데서 막히면 보여드릴게요.",
                "남겨뒀어요. 통했던 건 잊지 않게요."
            ],
            casual: [
                "잘 기록해 뒀어. 다음에 막힐 때 이걸 꺼내 볼게.",
                "적어뒀어. 다음에 비슷한 데서 막히면 보여줄게.",
                "남겨뒀어. 통했던 건 잊지 않게."
            ],
            seed: Phrasing.today()
        )
    }

    static var leaveClose: String {
        Phrasing.pick(
            formal: [
                "네, 그냥 둘게요. 여기 있을게요.",
                "알겠어요. 여기 있을게요.",
                "네, 그럼 다음에 얘기해요."
            ],
            casual: [
                "응, 그냥 둘게. 여기 있을게.",
                "알겠어. 여기 있을게.",
                "응, 그럼 다음에 얘기하자."
            ],
            seed: Phrasing.today()
        )
    }

    // MARK: 감정 눈금

    /// 0 ~ 4. 기존 저장 값과 같은 방향(0이 힘듦)을 유지한다.
    static var emotionSteps: [(value: Int, label: String)] {
        [
            (0, Phrasing.say("많이 힘들어요", "많이 힘들어")),
            (1, Phrasing.say("가라앉았어요", "가라앉았어")),
            (2, Phrasing.say("그저 그래요", "그저 그래")),
            (3, Phrasing.say("괜찮아요", "괜찮아")),
            (4, Phrasing.say("좋아요", "좋아"))
        ]
    }

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
