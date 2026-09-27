//
//  JournalSummary.swift
//  Rebound Journal
//
//  Created by 황석현 on 4/20/25.
//

import Foundation

/// 조회된 Journal의 현황(hasDeleted 제외)
struct JournalSummary {
    let entries: [JournalData]
    
    /// 연속 일수
    var streak: Int { return entries.calculateStreak() }
    /// 전체 갯수
    var total: Int { return entries.filter{ !$0.hasDeletedUnwrapped }.count }
    /// 골인 갯수
    var goals: Int { return entries.filter{ !$0.hasDeletedUnwrapped && $0.isGoalInUnwrapped }.count }
    /// 리바운드 갯수
    var rebounds: Int { return entries.filter{ !$0.hasDeletedUnwrapped && !$0.isGoalInUnwrapped }.count }
}

private extension Array where Element == JournalData {
    
    /// 연속 기록일수를 계산하는 함수
    func calculateStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 날짜 기준으로 정렬된 데이터
        let sorted = self
            .filter { !$0.hasDeletedUnwrapped }
            .sorted { $0.dateUnwrapped > $1.dateUnwrapped }

        var streak = 0
        var expectedDate = today

        for journal in sorted {
            let journalDate = calendar.startOfDay(for: journal.dateUnwrapped)

            if journalDate == expectedDate {
                streak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
            } else if journalDate < expectedDate {
                // 기록이 연속되지 않았으므로 종료
                break
            }
        }
        return streak
    }
}
