//
//  FailurePatternDetector.swift
//  Rebound Journal
//
//  Created by Claude on 11/17/25.
//

import Foundation

/// 실패 패턴을 나타내는 데이터 구조
struct FailurePattern {
    let goal: String
    let consecutiveFailures: Int
    let failureReasons: [String]
    let commonCause: String?
    let interventionLevel: InterventionLevel
    let mostRecentFailureDate: Date
}

/// 개입 수준
enum InterventionLevel {
    case gentle      // 2-3회 실패: 격려 메시지
    case moderate    // 4-5회 실패: 목표 조정 제안
    case urgent      // 6회+ 실패: 목표 재설정 권장

    var title: String {
        switch self {
        case .gentle:
            return "괜찮아요, 계속 도전해봐요"
        case .moderate:
            return "같은 실패가 반복되고 있어요"
        case .urgent:
            return "목표를 다시 생각해볼까요?"
        }
    }

    var emoji: String {
        switch self {
        case .gentle: return "💪"
        case .moderate: return "🔴"
        case .urgent: return "⚠️"
        }
    }
}

/// 반복 실패 패턴 감지기
class FailurePatternDetector {

    /// 특정 목표의 반복 실패 패턴 감지
    static func detectRepeatingFailure(
        for goal: String,
        in journals: [JournalData]
    ) -> FailurePattern? {

        // 1. 해당 목표의 최근 실패들만 필터링 (삭제되지 않은 것만)
        let failures = journals
            .filter {
                $0.subGoalUnwrapped == goal &&
                !$0.isGoalInUnwrapped &&
                !$0.hasDeletedUnwrapped
            }
            .sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }

        // 2. 최소 2번 이상 실패해야 패턴으로 감지
        guard failures.count >= 2 else { return nil }

        // 3. 최근 연속 실패 횟수 계산
        let consecutiveFailures = countConsecutiveFailures(for: goal, in: journals)

        // 4. 연속 실패가 없으면 nil 반환
        guard consecutiveFailures >= 2 else { return nil }

        // 5. 최근 실패 분석 (최대 5개)
        let recentFailures = Array(failures.prefix(5))
        let reasons = recentFailures.compactMap { $0.review }

        // 6. 공통 원인 찾기
        let commonCause = findCommonCause(in: reasons)

        // 7. 개입 레벨 결정
        let level: InterventionLevel
        switch consecutiveFailures {
        case 2...3:
            level = .gentle
        case 4...5:
            level = .moderate
        default:
            level = .urgent
        }

        return FailurePattern(
            goal: goal,
            consecutiveFailures: consecutiveFailures,
            failureReasons: reasons,
            commonCause: commonCause,
            interventionLevel: level,
            mostRecentFailureDate: failures.first?.dateUnwrapped ?? Date()
        )
    }

    /// 모든 목표의 실패 패턴 감지
    static func detectAllFailurePatterns(in journals: [JournalData]) -> [FailurePattern] {
        // 모든 고유 목표 추출
        let uniqueGoals = Set(journals.compactMap { $0.subGoal })

        return uniqueGoals.compactMap { goal in
            detectRepeatingFailure(for: goal, in: journals)
        }
        .sorted { $0.consecutiveFailures > $1.consecutiveFailures }
    }

    /// 연속 실패 횟수 계산
    private static func countConsecutiveFailures(
        for goal: String,
        in journals: [JournalData]
    ) -> Int {
        let goalJournals = journals
            .filter { $0.subGoalUnwrapped == goal && !$0.hasDeletedUnwrapped }
            .sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }

        var count = 0
        for journal in goalJournals {
            if journal.isGoalInUnwrapped {
                break // 성공을 만나면 중단
            }
            count += 1
        }

        return count
    }

    /// 공통 원인 키워드 찾기
    private static func findCommonCause(in reasons: [String]) -> String? {
        guard !reasons.isEmpty else { return nil }

        // 자주 등장하는 키워드들
        let commonKeywords = [
            "시간", "바빠", "늦게", "일찍", "피곤", "졸려",
            "깜빡", "잊어버", "까먹",
            "의지", "하기 싫", "귀찮",
            "날씨", "추워", "더워",
            "아파", "몸이", "건강"
        ]

        var keywordCount: [String: Int] = [:]

        for reason in reasons {
            for keyword in commonKeywords {
                if reason.contains(keyword) {
                    keywordCount[keyword, default: 0] += 1
                }
            }
        }

        // 가장 많이 나온 키워드
        if let mostCommon = keywordCount.max(by: { $0.value < $1.value }),
           mostCommon.value >= 2 {
            return mostCommon.key
        }

        return nil
    }

    /// 제안 메시지 생성
    static func generateSuggestions(for pattern: FailurePattern) -> [String] {
        var suggestions: [String] = []

        switch pattern.interventionLevel {
        case .gentle:
            suggestions.append("조금만 더 힘내봐요! 곧 성공할 수 있어요")
            suggestions.append("실패는 성공의 어머니예요")

        case .moderate:
            suggestions.append("목표를 더 작게 나눠볼까요?")
            suggestions.append("시간대를 바꿔보는 건 어떨까요?")

            if let cause = pattern.commonCause {
                if cause.contains("시간") || cause.contains("바빠") {
                    suggestions.append("더 짧은 시간으로 시작해보세요")
                } else if cause.contains("피곤") || cause.contains("졸려") {
                    suggestions.append("다른 시간대에 시도해보세요")
                } else if cause.contains("깜빡") || cause.contains("잊어버") {
                    suggestions.append("알람을 설정해보세요")
                }
            }

        case .urgent:
            suggestions.append("현재 목표가 너무 도전적일 수 있어요")
            suggestions.append("더 작은 단계부터 시작하는 게 어떨까요?")
            suggestions.append("잠시 쉬어가도 괜찮아요")

            if let cause = pattern.commonCause {
                suggestions.append("'\(cause)' 문제를 먼저 해결해볼까요?")
            }
        }

        return suggestions
    }
}
