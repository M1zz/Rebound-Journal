//
//  SmartSuggestionEngine.swift
//  Rebound Journal
//
//  Created by Claude on 11/17/25.
//

import Foundation

/// 스마트 대안 추천
struct SmartSuggestion: Identifiable {
    let id = UUID()
    let suggestion: String
    let successProbability: Double  // 0.0 ~ 1.0
    let basedOnData: String
    let category: SuggestionCategory
    let totalAttempts: Int
    let successCount: Int

    var probabilityPercent: Int {
        Int(successProbability * 100)
    }

    var difficultyLevel: String {
        if successProbability >= 0.8 {
            return "쉬움"
        } else if successProbability >= 0.5 {
            return "중간"
        } else {
            return "어려움"
        }
    }

    var confidenceEmoji: String {
        if successProbability >= 0.8 {
            return "⭐"
        } else if successProbability >= 0.6 {
            return "✓"
        } else {
            return "○"
        }
    }
}

/// 제안 카테고리
enum SuggestionCategory {
    case pastSuccess        // 과거 성공 경험
    case timeAdjustment     // 시간 조정
    case goalReduction      // 목표 축소
    case environmentChange  // 환경 변경
    case habitStacking      // 습관 연결
    case reminder           // 리마인더 설정

    var emoji: String {
        switch self {
        case .pastSuccess: return "🎯"
        case .timeAdjustment: return "⏰"
        case .goalReduction: return "📉"
        case .environmentChange: return "🌍"
        case .habitStacking: return "🔗"
        case .reminder: return "🔔"
        }
    }

    var title: String {
        switch self {
        case .pastSuccess: return "과거 성공 경험"
        case .timeAdjustment: return "시간 조정"
        case .goalReduction: return "목표 축소"
        case .environmentChange: return "환경 변경"
        case .habitStacking: return "습관 연결"
        case .reminder: return "리마인더"
        }
    }
}

/// 스마트 추천 엔진
class SmartSuggestionEngine {

    /// 과거 데이터 기반 대안 추천
    static func generateSuggestions(
        for goal: String,
        currentFailureReason: String? = nil,
        in journals: [JournalData]
    ) -> [SmartSuggestion] {

        var suggestions: [SmartSuggestion] = []

        // 1. 과거 성공한 대안들 (가장 신뢰도 높음)
        let successBasedSuggestions = generateSuccessBasedSuggestions(
            for: goal,
            in: journals
        )
        suggestions.append(contentsOf: successBasedSuggestions)

        // 2. 규칙 기반 추천
        if let reason = currentFailureReason {
            let ruleBasedSuggestions = generateRuleBasedSuggestions(
                for: goal,
                failureReason: reason
            )
            suggestions.append(contentsOf: ruleBasedSuggestions)
        }

        // 3. 일반적인 추천 (데이터 부족시)
        if suggestions.isEmpty {
            suggestions.append(contentsOf: generateGenericSuggestions(for: goal))
        }

        // 성공률 순으로 정렬
        return suggestions
            .sorted { $0.successProbability > $1.successProbability }
            .prefix(5)
            .map { $0 }
    }

    /// 과거 성공 패턴 기반 추천
    private static func generateSuccessBasedSuggestions(
        for goal: String,
        in journals: [JournalData]
    ) -> [SmartSuggestion] {

        let patterns = JournalAnalyzer.findSuccessPatterns(for: goal, in: journals)
        var suggestions: [SmartSuggestion] = []
        var seenPlans = Set<String>()

        for pattern in patterns {
            let plan = pattern.suggestedPlan

            // 중복 제거
            guard !seenPlans.contains(plan) else { continue }
            seenPlans.insert(plan)

            // 이 대안으로 시도한 모든 기록 찾기
            let (successCount, totalAttempts) = calculateSuccessRate(
                plan: plan,
                for: goal,
                in: journals
            )

            guard totalAttempts > 0 else { continue }

            let probability = Double(successCount) / Double(totalAttempts)

            suggestions.append(SmartSuggestion(
                suggestion: plan,
                successProbability: probability,
                basedOnData: "과거 \(totalAttempts)번 중 \(successCount)번 성공",
                category: .pastSuccess,
                totalAttempts: totalAttempts,
                successCount: successCount
            ))
        }

        return suggestions
    }

    /// 대안의 성공률 계산
    private static func calculateSuccessRate(
        plan: String,
        for goal: String,
        in journals: [JournalData]
    ) -> (successCount: Int, totalAttempts: Int) {

        let relevantJournals = journals
            .filter { $0.subGoalUnwrapped == goal && !$0.hasDeletedUnwrapped }
            .sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }

        var successCount = 0
        var totalAttempts = 0

        // 실패 기록에서 이 대안을 사용한 경우를 찾음
        for i in 0..<relevantJournals.count {
            let journal = relevantJournals[i]

            // 실패 기록이고, 이 대안을 사용했는지 확인
            if !journal.isGoalInUnwrapped &&
               journal.nextPlanUnwrapped.contains(plan) {

                // 다음 기록이 성공인지 확인
                if i + 1 < relevantJournals.count {
                    let nextJournal = relevantJournals[i + 1]
                    totalAttempts += 1

                    if nextJournal.isGoalInUnwrapped {
                        successCount += 1
                    }
                }
            }
        }

        return (successCount, totalAttempts)
    }

    /// 규칙 기반 추천
    private static func generateRuleBasedSuggestions(
        for goal: String,
        failureReason: String
    ) -> [SmartSuggestion] {

        var suggestions: [SmartSuggestion] = []

        // 시간 관련 문제
        if failureReason.contains("시간") || failureReason.contains("바빠") {
            suggestions.append(SmartSuggestion(
                suggestion: "목표 시간을 절반으로 줄여보세요",
                successProbability: 0.7,
                basedOnData: "시간 부족 문제 해결에 효과적",
                category: .goalReduction,
                totalAttempts: 0,
                successCount: 0
            ))

            suggestions.append(SmartSuggestion(
                suggestion: "다른 시간대로 변경해보세요",
                successProbability: 0.6,
                basedOnData: "시간 조정이 도움될 수 있어요",
                category: .timeAdjustment,
                totalAttempts: 0,
                successCount: 0
            ))
        }

        // 피로 관련 문제
        if failureReason.contains("피곤") || failureReason.contains("졸려") {
            suggestions.append(SmartSuggestion(
                suggestion: "에너지가 높은 시간대로 변경하세요",
                successProbability: 0.75,
                basedOnData: "컨디션 좋을 때 시도하기",
                category: .timeAdjustment,
                totalAttempts: 0,
                successCount: 0
            ))
        }

        // 기억/리마인더 문제
        if failureReason.contains("깜빡") || failureReason.contains("잊어버") || failureReason.contains("까먹") {
            suggestions.append(SmartSuggestion(
                suggestion: "알람을 3개 설정하세요",
                successProbability: 0.8,
                basedOnData: "리마인더가 효과적이에요",
                category: .reminder,
                totalAttempts: 0,
                successCount: 0
            ))

            suggestions.append(SmartSuggestion(
                suggestion: "눈에 잘 보이는 곳에 메모 붙이기",
                successProbability: 0.65,
                basedOnData: "시각적 리마인더 활용",
                category: .environmentChange,
                totalAttempts: 0,
                successCount: 0
            ))
        }

        // 의지력 문제
        if failureReason.contains("귀찮") || failureReason.contains("하기 싫") {
            suggestions.append(SmartSuggestion(
                suggestion: "5분만 해보기로 시작하세요",
                successProbability: 0.7,
                basedOnData: "작게 시작하면 계속하기 쉬워요",
                category: .goalReduction,
                totalAttempts: 0,
                successCount: 0
            ))
        }

        return suggestions
    }

    /// 일반적인 추천 (데이터 부족시)
    private static func generateGenericSuggestions(for goal: String) -> [SmartSuggestion] {
        return [
            SmartSuggestion(
                suggestion: "더 작은 단계로 나눠보세요",
                successProbability: 0.6,
                basedOnData: "일반적으로 효과적인 방법",
                category: .goalReduction,
                totalAttempts: 0,
                successCount: 0
            ),
            SmartSuggestion(
                suggestion: "매일 같은 시간에 시도하세요",
                successProbability: 0.55,
                basedOnData: "습관 형성에 도움",
                category: .habitStacking,
                totalAttempts: 0,
                successCount: 0
            ),
            SmartSuggestion(
                suggestion: "준비물을 미리 챙겨두세요",
                successProbability: 0.5,
                basedOnData: "환경 조성이 중요해요",
                category: .environmentChange,
                totalAttempts: 0,
                successCount: 0
            )
        ]
    }
}
