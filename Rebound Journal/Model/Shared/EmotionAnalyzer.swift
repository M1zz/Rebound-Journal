//
//  EmotionAnalyzer.swift
//  Rebound Journal
//
//  Created by Claude on 11/17/25.
//

import Foundation

/// 감정 상태
enum EmotionState: String, CaseIterable {
    case veryPositive = "매우 긍정적"
    case positive = "긍정적"
    case neutral = "중립적"
    case negative = "부정적"
    case veryNegative = "매우 부정적"

    var emoji: String {
        switch self {
        case .veryPositive: return "😄"
        case .positive: return "🙂"
        case .neutral: return "😐"
        case .negative: return "😔"
        case .veryNegative: return "😞"
        }
    }

    var color: String {
        switch self {
        case .veryPositive: return "green"
        case .positive: return "lightGreen"
        case .neutral: return "gray"
        case .negative: return "orange"
        case .veryNegative: return "red"
        }
    }

    var score: Int {
        switch self {
        case .veryPositive: return 2
        case .positive: return 1
        case .neutral: return 0
        case .negative: return -1
        case .veryNegative: return -2
        }
    }
}

/// 감정 분석 결과
struct EmotionAnalysis {
    let date: Date
    let emotion: EmotionState
    let text: String
    let isSuccess: Bool
}

/// 감정 트렌드
struct EmotionTrend {
    let recentEmotions: [EmotionAnalysis]
    let averageScore: Double
    let overallMood: EmotionState
    let burnoutRisk: BurnoutRisk
    let recommendation: String
}

/// 번아웃 위험도
enum BurnoutRisk {
    case none       // 위험 없음
    case low        // 낮은 위험
    case moderate   // 중간 위험
    case high       // 높은 위험
    case critical   // 심각한 위험

    var emoji: String {
        switch self {
        case .none: return "💚"
        case .low: return "💛"
        case .moderate: return "🧡"
        case .high: return "❤️"
        case .critical: return "🚨"
        }
    }

    var title: String {
        switch self {
        case .none: return "정서적으로 안정적이에요"
        case .low: return "조금 피곤해 보여요"
        case .moderate: return "휴식이 필요해 보여요"
        case .high: return "번아웃 위험이 있어요"
        case .critical: return "긴급: 휴식이 필수예요"
        }
    }

    var color: String {
        switch self {
        case .none: return "green"
        case .low: return "yellow"
        case .moderate: return "orange"
        case .high: return "red"
        case .critical: return "darkRed"
        }
    }
}

/// 감정 분석기
class EmotionAnalyzer {

    // MARK: - 감정 키워드 사전

    private static let veryPositiveKeywords = [
        "최고", "완벽", "행복", "뿌듯", "신나", "기쁘", "즐거", "좋았어",
        "성공", "해냈", "이뤘", "달성", "만족", "감사", "축하"
    ]

    private static let positiveKeywords = [
        "좋아", "괜찮", "나쁘지 않", "할만", "괜찮았", "잘했", "노력",
        "발전", "개선", "나아", "도움", "효과"
    ]

    private static let negativeKeywords = [
        "힘들", "어려", "지쳐", "피곤", "졸려", "귀찮", "싫어",
        "안돼", "실패", "못했", "아쉬", "후회", "포기하고 싶"
    ]

    private static let veryNegativeKeywords = [
        "우울", "절망", "무기력", "번아웃", "스트레스", "불안", "두려",
        "포기", "그만두", "더 이상", "소용없", "의미없", "지옥"
    ]

    private static let burnoutSignals = [
        "지쳐", "번아웃", "무기력", "포기", "그만두고 싶", "의미없",
        "더 이상", "계속할 수 없", "한계", "지옥", "끝이 없"
    ]

    // MARK: - 감정 분석

    /// 텍스트에서 감정 분석
    static func analyzeEmotion(from text: String) -> EmotionState {
        let lowercased = text

        // 매우 부정적 감정 체크 (우선순위 높음)
        for keyword in veryNegativeKeywords {
            if lowercased.contains(keyword) {
                return .veryNegative
            }
        }

        // 매우 긍정적 감정 체크
        for keyword in veryPositiveKeywords {
            if lowercased.contains(keyword) {
                return .veryPositive
            }
        }

        // 부정적 감정 체크
        var negativeCount = 0
        for keyword in negativeKeywords {
            if lowercased.contains(keyword) {
                negativeCount += 1
            }
        }

        // 긍정적 감정 체크
        var positiveCount = 0
        for keyword in positiveKeywords {
            if lowercased.contains(keyword) {
                positiveCount += 1
            }
        }

        // 점수 계산
        let score = positiveCount - negativeCount

        if score >= 2 {
            return .positive
        } else if score <= -2 {
            return .negative
        } else if score > 0 {
            return .positive
        } else if score < 0 {
            return .negative
        } else {
            return .neutral
        }
    }

    /// 저널 데이터에서 감정 분석
    static func analyzeJournalEmotion(from journal: JournalData) -> EmotionAnalysis {
        // 리뷰 텍스트가 있으면 그것을 분석, 없으면 성공/실패 여부로 판단
        let text = journal.review ?? ""
        let emotion: EmotionState

        if !text.isEmpty {
            emotion = analyzeEmotion(from: text)
        } else {
            // 리뷰가 없으면 성공/실패로 기본 감정 설정
            emotion = journal.isGoalInUnwrapped ? .positive : .negative
        }

        return EmotionAnalysis(
            date: journal.dateUnwrapped,
            emotion: emotion,
            text: text,
            isSuccess: journal.isGoalInUnwrapped
        )
    }

    /// 최근 감정 트렌드 분석
    static func analyzeRecentTrend(
        in journals: [JournalData],
        recentDays: Int = 7
    ) -> EmotionTrend {

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -recentDays, to: Date()) ?? Date()

        // 최근 N일 간의 저널만 필터링
        let recentJournals = journals
            .filter {
                !$0.hasDeletedUnwrapped &&
                ($0.date ?? Date()) >= cutoffDate
            }
            .sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }

        // 각 저널의 감정 분석
        let emotions = recentJournals.map { analyzeJournalEmotion(from: $0) }

        // 평균 감정 점수 계산
        let averageScore: Double
        if !emotions.isEmpty {
            let totalScore = emotions.reduce(0) { $0 + $1.emotion.score }
            averageScore = Double(totalScore) / Double(emotions.count)
        } else {
            averageScore = 0
        }

        // 전체적인 기분 결정
        let overallMood: EmotionState
        switch averageScore {
        case 1.5...:
            overallMood = .veryPositive
        case 0.5..<1.5:
            overallMood = .positive
        case -0.5..<0.5:
            overallMood = .neutral
        case -1.5..<(-0.5):
            overallMood = .negative
        default:
            overallMood = .veryNegative
        }

        // 번아웃 위험도 분석
        let burnoutRisk = analyzeBurnoutRisk(emotions: emotions, journals: recentJournals)

        // 추천 메시지 생성
        let recommendation = generateRecommendation(
            mood: overallMood,
            burnoutRisk: burnoutRisk,
            emotions: emotions
        )

        return EmotionTrend(
            recentEmotions: emotions,
            averageScore: averageScore,
            overallMood: overallMood,
            burnoutRisk: burnoutRisk,
            recommendation: recommendation
        )
    }

    /// 번아웃 위험도 분석
    private static func analyzeBurnoutRisk(
        emotions: [EmotionAnalysis],
        journals: [JournalData]
    ) -> BurnoutRisk {

        guard !emotions.isEmpty else { return .none }

        // 1. 부정적 감정 비율
        let negativeCount = emotions.filter {
            $0.emotion == .negative || $0.emotion == .veryNegative
        }.count
        let negativeRatio = Double(negativeCount) / Double(emotions.count)

        // 2. 번아웃 시그널 키워드 체크
        let burnoutSignalCount = journals.reduce(0) { count, journal in
            let text = journal.review ?? ""
            let hasBurnoutSignal = burnoutSignals.contains { text.contains($0) }
            return count + (hasBurnoutSignal ? 1 : 0)
        }

        // 3. 연속 실패 횟수
        let consecutiveFailures = countConsecutiveFailures(in: journals)

        // 4. 매우 부정적 감정의 연속성
        let veryNegativeStreak = countVeryNegativeStreak(in: emotions)

        // 위험도 판단
        var riskScore = 0

        if negativeRatio >= 0.8 { riskScore += 3 }
        else if negativeRatio >= 0.6 { riskScore += 2 }
        else if negativeRatio >= 0.4 { riskScore += 1 }

        if burnoutSignalCount >= 3 { riskScore += 3 }
        else if burnoutSignalCount >= 2 { riskScore += 2 }
        else if burnoutSignalCount >= 1 { riskScore += 1 }

        if consecutiveFailures >= 5 { riskScore += 2 }
        else if consecutiveFailures >= 3 { riskScore += 1 }

        if veryNegativeStreak >= 3 { riskScore += 3 }
        else if veryNegativeStreak >= 2 { riskScore += 1 }

        // 최종 위험도 반환
        switch riskScore {
        case 0...1:
            return .none
        case 2...3:
            return .low
        case 4...5:
            return .moderate
        case 6...7:
            return .high
        default:
            return .critical
        }
    }

    /// 연속 실패 횟수
    private static func countConsecutiveFailures(in journals: [JournalData]) -> Int {
        var count = 0
        for journal in journals {
            if journal.isGoalInUnwrapped {
                break
            }
            count += 1
        }
        return count
    }

    /// 매우 부정적 감정 연속 횟수
    private static func countVeryNegativeStreak(in emotions: [EmotionAnalysis]) -> Int {
        var streak = 0
        for emotion in emotions {
            if emotion.emotion == .veryNegative {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    /// 추천 메시지 생성
    private static func generateRecommendation(
        mood: EmotionState,
        burnoutRisk: BurnoutRisk,
        emotions: [EmotionAnalysis]
    ) -> String {

        // 번아웃 위험이 높으면 우선 처리
        if burnoutRisk == .critical {
            return "지금은 휴식이 가장 필요한 시간입니다. 모든 목표를 잠시 내려놓고 자신을 돌봐주세요. 당신의 건강이 가장 중요해요."
        } else if burnoutRisk == .high {
            return "많이 지쳐있는 것 같아요. 목표를 줄이고 충분한 휴식을 취하세요. 완벽하지 않아도 괜찮아요."
        } else if burnoutRisk == .moderate {
            return "조금 쉬어가도 괜찮아요. 너무 무리하지 말고, 작은 성공들을 축하해주세요."
        }

        // 기분에 따른 추천
        switch mood {
        case .veryPositive:
            return "정말 잘하고 있어요! 이 긍정적인 에너지를 유지하면서 계속 나아가세요 ✨"

        case .positive:
            return "좋은 흐름이에요! 이 페이스를 유지하면서 꾸준히 도전해봐요 💪"

        case .neutral:
            let successCount = emotions.filter { $0.isSuccess }.count
            if successCount > emotions.count / 2 {
                return "성공하고 있지만 감정적으로 만족스럽지 않아 보여요. 목표에 의미를 더해보는 건 어떨까요?"
            } else {
                return "잘하고 있어요. 작은 변화들이 모여 큰 성장이 됩니다. 조금만 더 힘내봐요!"
            }

        case .negative:
            return "힘든 시기네요. 목표를 더 작게 나누거나, 잠시 쉬어가는 것도 방법이에요. 당신은 잘하고 있어요."

        case .veryNegative:
            return "많이 힘들어 보여요. 지금은 목표보다 자신을 돌보는 게 더 중요해요. 쉬어도 괜찮아요."
        }
    }

    /// 감정 변화 추이 (일별)
    static func getEmotionHistory(
        in journals: [JournalData],
        days: Int = 30
    ) -> [(date: Date, averageScore: Double)] {

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        // 날짜별로 그룹화
        let groupedByDate = Dictionary(grouping: journals.filter {
            !$0.hasDeletedUnwrapped &&
            ($0.date ?? Date()) >= startDate
        }) { journal -> Date in
            calendar.startOfDay(for: journal.dateUnwrapped)
        }

        // 각 날짜의 평균 감정 점수 계산
        return groupedByDate.map { date, journals in
            let emotions = journals.map { analyzeJournalEmotion(from: $0) }
            let averageScore = emotions.isEmpty ? 0.0 : Double(emotions.reduce(0) { $0 + $1.emotion.score }) / Double(emotions.count)
            return (date: date, averageScore: averageScore)
        }
        .sorted { $0.date < $1.date }
    }

    /// 가장 긍정적이었던 날 찾기
    static func findBestDay(in journals: [JournalData]) -> (date: Date, score: Double)? {
        let history = getEmotionHistory(in: journals, days: 90)
        return history.max { $0.averageScore < $1.averageScore }
    }

    /// 가장 힘들었던 날 찾기
    static func findWorstDay(in journals: [JournalData]) -> (date: Date, score: Double)? {
        let history = getEmotionHistory(in: journals, days: 90)
        return history.min { $0.averageScore < $1.averageScore }
    }
}
