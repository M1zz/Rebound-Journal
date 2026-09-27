//
//  EmotionVocabulary.swift
//  Rebound Journal
//
//  감정 눈금마다 붙일 낱말. 1.x 기록 흐름에서 쓰던 어휘를 그대로 이어받았다.
//  대화(`ConversationScript.emotionWords`)가 고른 눈금에 맞는 묶음을 꺼내 쓴다.
//

import Foundation

enum EmotionVocabulary {

    /// 좋아요 · 괜찮아요
    static var positive: [String] {
        [
            String(localized: "기분이 좋은"),
            String(localized: "신나는"),
            String(localized: "자랑스러운"),
            String(localized: "의욕적인"),
            String(localized: "뿌듯한"),
            String(localized: "상쾌한"),
            String(localized: "설레는"),
            String(localized: "감사한"),
            String(localized: "행복한"),
            String(localized: "자신감이 생긴"),
            String(localized: "편안한"),
            String(localized: "만족한"),
            String(localized: "열정적인"),
            String(localized: "기대되는"),
            String(localized: "용기있는")
        ]
    }

    /// 그저 그래요
    static var neutral: [String] {
        [
            String(localized: "평범한"),
            String(localized: "일상적인"),
            String(localized: "중립적인"),
            String(localized: "무난한"),
            String(localized: "일반적인"),
            String(localized: "보통의"),
            String(localized: "냉정한"),
            String(localized: "무감각한"),
            String(localized: "무관심한"),
            String(localized: "무표정한")
        ]
    }

    /// 가라앉았어요
    static var low: [String] {
        [
            String(localized: "실망스러운"),
            String(localized: "지루한"),
            String(localized: "어수선한"),
            String(localized: "괴로운"),
            String(localized: "불만족스러운"),
            String(localized: "피곤한"),
            String(localized: "짜증나는"),
            String(localized: "슬픈"),
            String(localized: "불안한")
        ]
    }

    /// 많이 힘들어요
    static var veryLow: [String] {
        [
            String(localized: "절망적인"),
            String(localized: "끔찍한"),
            String(localized: "비참한"),
            String(localized: "혐오스러운"),
            String(localized: "무서운"),
            String(localized: "파괴적인"),
            String(localized: "쓸쓸한"),
            String(localized: "분노스러운"),
            String(localized: "좌절스러운"),
            String(localized: "무력한")
        ]
    }
}
