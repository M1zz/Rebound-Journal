//
//  JournalAnalyzer.swift
//  Rebound Journal
//
//  Created by Claude on 11/14/25.
//

import Foundation
import SwiftData

/// 과거 성공 패턴을 분석하기 위한 데이터 구조
struct SuccessPattern {
    let failureDate: Date
    let successDate: Date
    let failureReason: String
    let suggestedPlan: String
    let successReview: String
    let daysBetween: Int

    var formattedFailureDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: failureDate)
    }

    var formattedSuccessDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: successDate)
    }
}

/// JournalData를 분석하는 헬퍼 클래스
class JournalAnalyzer {

    /// 동일한 목표에 대한 과거 성공 패턴 찾기
    /// - Parameters:
    ///   - subGoal: 분석할 목표
    ///   - journals: 전체 저널 데이터
    /// - Returns: 찾은 성공 패턴들 (최신순)
    static func findSuccessPatterns(for subGoal: String, in journals: [JournalData]) -> [SuccessPattern] {
        // 1. 동일 목표의 기록만 필터링 (삭제되지 않은 것만)
        let relevantJournals = journals
            .filter { $0.subGoalUnwrapped == subGoal && !$0.hasDeletedUnwrapped }
            .sorted { ($0.date ?? Date()) < ($1.date ?? Date()) } // 시간순 정렬

        guard relevantJournals.count >= 2 else { return [] }

        var patterns: [SuccessPattern] = []

        // 2. 실패 → 성공 패턴 찾기
        for i in 0..<(relevantJournals.count - 1) {
            let current = relevantJournals[i]

            // 현재가 실패(리바운드)인 경우
            if current.isGoalInUnwrapped == false {
                // 다음 기록들 중 성공을 찾기
                for j in (i + 1)..<relevantJournals.count {
                    let next = relevantJournals[j]

                    // 성공을 찾았을 때
                    if next.isGoalInUnwrapped == true {
                        let daysBetween = Calendar.current.dateComponents(
                            [.day],
                            from: current.dateUnwrapped,
                            to: next.dateUnwrapped
                        ).day ?? 0

                        let pattern = SuccessPattern(
                            failureDate: current.dateUnwrapped,
                            successDate: next.dateUnwrapped,
                            failureReason: current.reviewUnwrapped,
                            suggestedPlan: current.nextPlanUnwrapped,
                            successReview: next.reviewUnwrapped,
                            daysBetween: daysBetween
                        )
                        patterns.append(pattern)
                        break // 가장 가까운 성공만 연결
                    }
                }
            }
        }

        // 3. 최신순으로 정렬해서 반환
        return patterns.sorted { $0.successDate > $1.successDate }
    }

    /// 가장 최근의 성공 패턴 가져오기
    static func getMostRecentSuccessPattern(for subGoal: String, in journals: [JournalData]) -> SuccessPattern? {
        return findSuccessPatterns(for: subGoal, in: journals).first
    }

    /// 여러 성공 패턴에서 공통 키워드 추출
    static func extractCommonKeywords(from patterns: [SuccessPattern]) -> [String] {
        guard !patterns.isEmpty else { return [] }

        // 모든 대안에서 키워드 추출 (간단한 버전)
        let allPlans = patterns.map { $0.suggestedPlan }
        var keywordCount: [String: Int] = [:]

        for plan in allPlans {
            let words = plan.components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 1 } // 한 글자 제외

            for word in words {
                keywordCount[word, default: 0] += 1
            }
        }

        // 빈도순으로 정렬
        return keywordCount
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }

    /// 활성 리바운드(해결되지 않은 실패) 가져오기
    static func getActiveRebounds(from journals: [JournalData]) -> [JournalData] {
        return journals
            .filter { $0.isActiveRebound }
            .sorted { ($0.date ?? Date()) > ($1.date ?? Date()) } // 최신순
    }

    /// 특정 목표의 활성 리바운드 가져오기
    static func getActiveRebounds(for subGoal: String, in journals: [JournalData]) -> [JournalData] {
        return journals
            .filter { $0.isActiveRebound && $0.subGoalUnwrapped == subGoal }
            .sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
    }

    /// 리바운드 극복 (성공 기록과 연결)
    static func resolveRebound(_ rebound: JournalData, with success: JournalData) {
        rebound.isResolved = true
        rebound.resolvedDate = success.date
        success.linkedReboundId = rebound.id
    }
}
