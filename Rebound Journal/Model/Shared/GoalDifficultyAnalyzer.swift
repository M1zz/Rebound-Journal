//
//  GoalDifficultyAnalyzer.swift
//  Rebound Journal
//
//  Created by Claude on 11/17/25.
//

import Foundation

/// 목표 난이도 평가 결과
struct GoalDifficulty {
    let goal: String
    let totalAttempts: Int
    let successCount: Int
    let successRate: Double
    let difficultyLevel: DifficultyLevel
    let recommendation: String
    let shouldAdjust: Bool

    var successRatePercent: Int {
        Int(successRate * 100)
    }
}

/// 난이도 레벨
enum DifficultyLevel {
    case tooEasy        // 성공률 80% 이상
    case appropriate    // 성공률 40-80%
    case challenging    // 성공률 20-40%
    case tooHard        // 성공률 20% 미만

    var emoji: String {
        switch self {
        case .tooEasy: return "😴"
        case .appropriate: return "✅"
        case .challenging: return "💪"
        case .tooHard: return "🔥"
        }
    }

    var title: String {
        switch self {
        case .tooEasy: return "너무 쉬워요"
        case .appropriate: return "적절해요"
        case .challenging: return "도전적이에요"
        case .tooHard: return "너무 어려워요"
        }
    }

    var color: String {
        switch self {
        case .tooEasy: return "blue"
        case .appropriate: return "green"
        case .challenging: return "orange"
        case .tooHard: return "red"
        }
    }
}

/// 목표 난이도 분석기
class GoalDifficultyAnalyzer {

    /// 모든 목표의 난이도 분석
    static func analyzeAllGoals(in journals: [JournalData]) -> [GoalDifficulty] {
        // 고유 목표 추출
        let uniqueGoals = Set(journals.compactMap { $0.subGoal })

        return uniqueGoals.compactMap { goal in
            analyzeGoalDifficulty(for: goal, in: journals)
        }
        .filter { $0.totalAttempts >= 3 } // 최소 3회 이상 시도한 목표만
        .sorted { $0.successRate < $1.successRate } // 어려운 것부터
    }

    /// 특정 목표의 난이도 분석
    static func analyzeGoalDifficulty(
        for goal: String,
        in journals: [JournalData]
    ) -> GoalDifficulty? {

        // 해당 목표의 모든 기록 (삭제되지 않은 것만)
        let goalJournals = journals
            .filter {
                $0.subGoalUnwrapped == goal &&
                !$0.hasDeletedUnwrapped
            }
            .sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }

        guard !goalJournals.isEmpty else { return nil }

        let totalAttempts = goalJournals.count
        let successCount = goalJournals.filter { $0.isGoalInUnwrapped }.count
        let successRate = Double(successCount) / Double(totalAttempts)

        // 난이도 레벨 결정
        let level: DifficultyLevel
        switch successRate {
        case 0.8...:
            level = .tooEasy
        case 0.4..<0.8:
            level = .appropriate
        case 0.2..<0.4:
            level = .challenging
        default:
            level = .tooHard
        }

        // 추천 메시지 생성
        let recommendation = generateRecommendation(
            for: goal,
            level: level,
            successRate: successRate,
            totalAttempts: totalAttempts
        )

        // 조정이 필요한지 판단 (너무 쉽거나 너무 어려운 경우)
        let shouldAdjust = level == .tooEasy || level == .tooHard

        return GoalDifficulty(
            goal: goal,
            totalAttempts: totalAttempts,
            successCount: successCount,
            successRate: successRate,
            difficultyLevel: level,
            recommendation: recommendation,
            shouldAdjust: shouldAdjust
        )
    }

    /// 난이도에 따른 추천 메시지 생성
    private static func generateRecommendation(
        for goal: String,
        level: DifficultyLevel,
        successRate: Double,
        totalAttempts: Int
    ) -> String {

        switch level {
        case .tooEasy:
            return "이 목표는 항상 성공하고 있어요! 더 도전적인 목표로 업그레이드하는 건 어떨까요?"

        case .appropriate:
            return "완벽한 난이도예요! 계속 도전하면서 성장하고 있어요 💪"

        case .challenging:
            let percent = Int(successRate * 100)
            return "도전적이지만 포기하지 마세요! \(percent)%의 성공률을 보이고 있어요. 조금만 더 힘내봐요!"

        case .tooHard:
            if totalAttempts >= 5 {
                return "이 목표가 너무 어려울 수 있어요. 더 작은 단계로 나누거나, 목표를 조정하는 걸 고려해보세요."
            } else {
                return "시작이 어려울 수 있어요. 조금만 더 시도해보고, 계속 어렵다면 목표를 조정해봐요."
            }
        }
    }

    /// 조정이 필요한 목표들만 필터링
    static func getGoalsNeedingAdjustment(in journals: [JournalData]) -> [GoalDifficulty] {
        return analyzeAllGoals(in: journals)
            .filter { $0.shouldAdjust }
    }

    /// 가장 어려운 목표 찾기
    static func findHardestGoal(in journals: [JournalData]) -> GoalDifficulty? {
        return analyzeAllGoals(in: journals)
            .filter { $0.totalAttempts >= 5 } // 충분한 시도 필요
            .min(by: { $0.successRate < $1.successRate })
    }

    /// 목표 난이도 트렌드 분석 (시간에 따라 개선되고 있는지)
    static func analyzeTrend(
        for goal: String,
        in journals: [JournalData],
        recentWindow: Int = 5
    ) -> TrendDirection? {

        let goalJournals = journals
            .filter {
                $0.subGoalUnwrapped == goal &&
                !$0.hasDeletedUnwrapped
            }
            .sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }

        guard goalJournals.count >= recentWindow * 2 else { return nil }

        // 전반부와 후반부 성공률 비교
        let firstHalf = Array(goalJournals.prefix(recentWindow))
        let secondHalf = Array(goalJournals.suffix(recentWindow))

        let firstSuccessRate = Double(firstHalf.filter { $0.isGoalInUnwrapped }.count) / Double(firstHalf.count)
        let secondSuccessRate = Double(secondHalf.filter { $0.isGoalInUnwrapped }.count) / Double(secondHalf.count)

        let improvement = secondSuccessRate - firstSuccessRate

        if improvement > 0.2 {
            return .improving
        } else if improvement < -0.2 {
            return .declining
        } else {
            return .stable
        }
    }

    /// 목표별 상세 통계
    static func getDetailedStats(
        for goal: String,
        in journals: [JournalData]
    ) -> GoalStats? {

        let goalJournals = journals
            .filter {
                $0.subGoalUnwrapped == goal &&
                !$0.hasDeletedUnwrapped
            }
            .sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }

        guard !goalJournals.isEmpty else { return nil }

        let totalAttempts = goalJournals.count
        let successCount = goalJournals.filter { $0.isGoalInUnwrapped }.count
        let currentStreak = calculateCurrentStreak(in: goalJournals)
        let longestStreak = calculateLongestStreak(in: goalJournals)
        let trend = analyzeTrend(for: goal, in: journals)

        return GoalStats(
            goal: goal,
            totalAttempts: totalAttempts,
            successCount: successCount,
            failureCount: totalAttempts - successCount,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            trend: trend,
            firstAttemptDate: goalJournals.first?.dateUnwrapped,
            lastAttemptDate: goalJournals.last?.dateUnwrapped
        )
    }

    /// 현재 연속 성공/실패 스트릭 계산
    private static func calculateCurrentStreak(in journals: [JournalData]) -> Int {
        guard !journals.isEmpty else { return 0 }

        let reversed = Array(journals.reversed())
        let firstResult = reversed[0].isGoalInUnwrapped

        var streak = 0
        for journal in reversed {
            if journal.isGoalInUnwrapped == firstResult {
                streak += 1
            } else {
                break
            }
        }

        return firstResult ? streak : -streak // 성공은 양수, 실패는 음수
    }

    /// 최장 연속 성공 스트릭 계산
    private static func calculateLongestStreak(in journals: [JournalData]) -> Int {
        var longestStreak = 0
        var currentStreak = 0

        for journal in journals {
            if journal.isGoalInUnwrapped {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }

        return longestStreak
    }
}

/// 트렌드 방향
enum TrendDirection {
    case improving   // 개선 중
    case stable      // 안정적
    case declining   // 하락 중

    var emoji: String {
        switch self {
        case .improving: return "📈"
        case .stable: return "➡️"
        case .declining: return "📉"
        }
    }

    var title: String {
        switch self {
        case .improving: return "개선 중"
        case .stable: return "안정적"
        case .declining: return "하락 중"
        }
    }
}

/// 목표 상세 통계
struct GoalStats {
    let goal: String
    let totalAttempts: Int
    let successCount: Int
    let failureCount: Int
    let currentStreak: Int  // 양수: 연속 성공, 음수: 연속 실패
    let longestStreak: Int
    let trend: TrendDirection?
    let firstAttemptDate: Date?
    let lastAttemptDate: Date?

    var successRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(successCount) / Double(totalAttempts)
    }

    var isOnSuccessStreak: Bool {
        currentStreak > 0
    }

    var streakDescription: String {
        if currentStreak > 0 {
            return "\(currentStreak)회 연속 성공 중! 🔥"
        } else if currentStreak < 0 {
            return "\(abs(currentStreak))회 연속 실패 중"
        } else {
            return "기록 없음"
        }
    }
}
