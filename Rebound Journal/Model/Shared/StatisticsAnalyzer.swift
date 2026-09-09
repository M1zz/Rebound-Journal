//
//  StatisticsAnalyzer.swift
//  Rebound Journal
//
//  Created by Claude on 11/20/25.
//

import Foundation

/// 통계 분석 결과
struct StatisticsInsight {
    let successRate: Double // 성공률 (0-100)
    let totalAttempts: Int // 전체 시도
    let activeRebounds: Int // 현재 도전 중
    let recoveryRate: Double // 극복률 (리바운드 -> 성공 전환율)
    let topChallenge: String? // 가장 어려운 목표
    let improvementTrend: String // 개선 추세 메시지
    let goalPerformances: [GoalPerformance] // 목표별 성과
}

/// 목표별 성과
struct GoalPerformance: Identifiable {
    let id = UUID()
    let goalName: String
    let successCount: Int
    let failureCount: Int
    let successRate: Double
    let totalAttempts: Int
}

/// 통계 분석기
class StatisticsAnalyzer {

    /// 전체 통계 분석
    static func analyze(journals: [JournalData], selectedDate: Date) -> StatisticsInsight {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)

        // 선택된 월의 저널만 필터링
        let filteredJournals = journals.filter {
            !$0.hasDeletedUnwrapped &&
            calendar.component(.year, from: $0.dateUnwrapped) == year &&
            calendar.component(.month, from: $0.dateUnwrapped) == month
        }

        // 기본 통계
        let totalAttempts = filteredJournals.count
        let successCount = filteredJournals.filter { $0.isGoalInUnwrapped }.count
        let failureCount = filteredJournals.filter { !$0.isGoalInUnwrapped }.count
        let successRate = totalAttempts > 0 ? (Double(successCount) / Double(totalAttempts)) * 100 : 0

        // 활성 리바운드
        let activeRebounds = JournalAnalyzer.getActiveRebounds(from: journals).count

        // 극복률 계산 (리바운드 후 성공한 비율)
        let reboundedSuccesses = filteredJournals.filter {
            $0.isGoalInUnwrapped && $0.isReboundedUnwrapped
        }.count
        let recoveryRate = failureCount > 0 ? (Double(reboundedSuccesses) / Double(failureCount)) * 100 : 0

        // 목표별 성과
        let goalPerformances = calculateGoalPerformances(journals: filteredJournals)

        // 가장 어려운 목표 (실패율이 가장 높은)
        let topChallenge = goalPerformances
            .filter { $0.totalAttempts >= 3 } // 최소 3회 시도
            .sorted { $0.successRate < $1.successRate }
            .first?.goalName

        // 개선 추세 분석
        let improvementTrend = analyzeImprovementTrend(journals: journals, currentMonth: selectedDate)

        return StatisticsInsight(
            successRate: successRate,
            totalAttempts: totalAttempts,
            activeRebounds: activeRebounds,
            recoveryRate: recoveryRate,
            topChallenge: topChallenge,
            improvementTrend: improvementTrend,
            goalPerformances: goalPerformances
        )
    }

    /// 목표별 성과 계산
    private static func calculateGoalPerformances(journals: [JournalData]) -> [GoalPerformance] {
        // 목표별로 그룹화
        let grouped = Dictionary(grouping: journals) { journal -> String in
            if let goal = journal.subGoal, !goal.isEmpty {
                return goal
            }
            return DataSentinel.noGoal
        }

        // 각 목표의 성과 계산
        return grouped.map { goalName, entries in
            let successCount = entries.filter { $0.isGoalInUnwrapped }.count
            let failureCount = entries.filter { !$0.isGoalInUnwrapped }.count
            let total = entries.count
            let successRate = total > 0 ? (Double(successCount) / Double(total)) * 100 : 0

            return GoalPerformance(
                goalName: goalName,
                successCount: successCount,
                failureCount: failureCount,
                successRate: successRate,
                totalAttempts: total
            )
        }
        .sorted { $0.totalAttempts > $1.totalAttempts } // 시도 횟수 순으로 정렬
    }

    /// 개선 추세 분석
    private static func analyzeImprovementTrend(journals: [JournalData], currentMonth: Date) -> String {
        let calendar = Calendar.current

        // 현재 월
        let currentYear = calendar.component(.year, from: currentMonth)
        let currentMonthNum = calendar.component(.month, from: currentMonth)

        // 이전 월
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) else {
            return String(localized: "계속 도전하세요! 🌱")
        }
        let previousYear = calendar.component(.year, from: previousMonth)
        let previousMonthNum = calendar.component(.month, from: previousMonth)

        // 현재 월 데이터
        let currentData = journals.filter {
            !$0.hasDeletedUnwrapped &&
            calendar.component(.year, from: $0.dateUnwrapped) == currentYear &&
            calendar.component(.month, from: $0.dateUnwrapped) == currentMonthNum
        }

        // 이전 월 데이터
        let previousData = journals.filter {
            !$0.hasDeletedUnwrapped &&
            calendar.component(.year, from: $0.dateUnwrapped) == previousYear &&
            calendar.component(.month, from: $0.dateUnwrapped) == previousMonthNum
        }

        guard !currentData.isEmpty, !previousData.isEmpty else {
            return String(localized: "기록을 쌓아가고 있어요 💪")
        }

        let currentSuccessRate = Double(currentData.filter { $0.isGoalInUnwrapped }.count) / Double(currentData.count) * 100
        let previousSuccessRate = Double(previousData.filter { $0.isGoalInUnwrapped }.count) / Double(previousData.count) * 100

        let difference = currentSuccessRate - previousSuccessRate

        if difference > 10 {
            return String(localized: "성공률이 \(Int(difference))% 증가했어요! 🚀")
        } else if difference > 0 {
            return String(localized: "꾸준히 성장하고 있어요 📈")
        } else if difference > -10 {
            return String(localized: "조금 어려웠지만 괜찮아요 💪")
        } else {
            return String(localized: "다시 일어설 수 있어요! 🌱")
        }
    }
}
