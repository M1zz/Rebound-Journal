//
//  SampleDataGenerator.swift
//  Rebound Journal
//
//  Created by Claude on 11/15/25.
//

import Foundation
import SwiftData

/// 개발용 샘플 데이터 생성 유틸리티
class SampleDataGenerator {

    /// 샘플 목표들 생성
    static func generateSampleGoals(context: ModelContext) {
        let goals = [
            "야식 참기",
            "운동하기",
            "아침 일찍 일어나기",
            "독서하기",
            "영어 공부하기"
        ]

        for goal in goals {
            let subGoal = SubGoalData(goalText: goal)
            context.insert(subGoal)
        }

        try? context.save()
    }

    /// 샘플 저널 데이터 생성 (성공, 실패, 해결된 실패 등 다양한 시나리오)
    static func generateSampleJournals(context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()

        // 1. 오늘의 성공
        let todaySuccess = JournalData(
            id: UUID().uuidString,
            date: now,
            hasDeleted: false,
            isGoalIn: true,
            emotionValue: 4,
            emotionText: "뿌듯한",
            review: "아침 일찍 일어나서 하루를 알차게 보냈어요!",
            nextPlan: "",
            isRebounded: false,
            purpose: "건강",
            mainGoal: "규칙적인 생활",
            subGoal: "아침 일찍 일어나기"
        )
        context.insert(todaySuccess)

        // 2. 3일 전 실패 (활성 리바운드)
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now)!
        let activeRebound1 = JournalData(
            id: UUID().uuidString,
            date: threeDaysAgo,
            hasDeleted: false,
            isGoalIn: false,
            emotionValue: 2,
            emotionText: "실망스러운",
            review: "야식을 참지 못했어요. 배고파서 라면을 먹었습니다.",
            nextPlan: "물을 많이 마시고 일찍 자기",
            isRebounded: false,
            purpose: "건강",
            mainGoal: "다이어트",
            subGoal: "야식 참기",
            linkedReboundId: nil,
            isResolved: false
        )
        context.insert(activeRebound1)

        // 3. 1주일 전 실패 (활성 리바운드)
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let activeRebound2 = JournalData(
            id: UUID().uuidString,
            date: oneWeekAgo,
            hasDeleted: false,
            isGoalIn: false,
            emotionValue: 1,
            emotionText: "자책하는",
            review: "운동하러 갔다가 중간에 포기하고 왔어요.",
            nextPlan: "가벼운 스트레칭부터 시작하기",
            isRebounded: false,
            purpose: "건강",
            mainGoal: "체력 기르기",
            subGoal: "운동하기",
            linkedReboundId: nil,
            isResolved: false
        )
        context.insert(activeRebound2)

        // 4. 2주 전 실패 → 어제 성공으로 극복 (해결된 리바운드)
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)!
        let resolvedRebound = JournalData(
            id: UUID().uuidString,
            date: twoWeeksAgo,
            hasDeleted: false,
            isGoalIn: false,
            emotionValue: 2,
            emotionText: "아쉬운",
            review: "영어 공부를 하려다가 미루고 말았어요.",
            nextPlan: "매일 10분씩 영어 팟캐스트 듣기",
            isRebounded: false,
            purpose: "자기계발",
            mainGoal: "영어 실력 향상",
            subGoal: "영어 공부하기",
            linkedReboundId: nil,
            isResolved: true,
            resolvedDate: calendar.date(byAdding: .day, value: -1, to: now)
        )
        context.insert(resolvedRebound)

        // 5. 어제의 성공 (위의 실패를 극복)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let successFromRebound = JournalData(
            id: UUID().uuidString,
            date: yesterday,
            hasDeleted: false,
            isGoalIn: true,
            emotionValue: 5,
            emotionText: "뿌듯한",
            review: "영어 팟캐스트를 들으면서 출근했어요! 생각보다 재미있었습니다.",
            nextPlan: "",
            isRebounded: false,
            purpose: "자기계발",
            mainGoal: "영어 실력 향상",
            subGoal: "영어 공부하기",
            linkedReboundId: resolvedRebound.id,
            isResolved: false
        )
        context.insert(successFromRebound)

        // 6. 5일 전 성공
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: now)!
        let pastSuccess = JournalData(
            id: UUID().uuidString,
            date: fiveDaysAgo,
            hasDeleted: false,
            isGoalIn: true,
            emotionValue: 4,
            emotionText: "만족스러운",
            review: "책을 30분 읽었어요. 집중이 잘 됐습니다.",
            nextPlan: "",
            isRebounded: false,
            purpose: "자기계발",
            mainGoal: "독서 습관 만들기",
            subGoal: "독서하기"
        )
        context.insert(pastSuccess)

        // 7. 2일 전 활성 리바운드 (최근)
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        let recentRebound = JournalData(
            id: UUID().uuidString,
            date: twoDaysAgo,
            hasDeleted: false,
            isGoalIn: false,
            emotionValue: 2,
            emotionText: "아쉬운",
            review: "아침에 일어나지 못하고 늦잠 잤어요.",
            nextPlan: "밤 11시에 알람 설정하고 핸드폰 멀리 두기",
            isRebounded: false,
            purpose: "건강",
            mainGoal: "규칙적인 생활",
            subGoal: "아침 일찍 일어나기",
            linkedReboundId: nil,
            isResolved: false
        )
        context.insert(recentRebound)

        try? context.save()
    }

    /// 모든 샘플 데이터 생성
    static func generateAllSampleData(context: ModelContext) {
        generateSampleGoals(context: context)
        generateSampleJournals(context: context)
    }

    /// 모든 데이터 삭제 (개발용)
    static func clearAllData(context: ModelContext) {
        // 모든 저널 삭제
        let journalDescriptor = FetchDescriptor<JournalData>()
        if let journals = try? context.fetch(journalDescriptor) {
            for journal in journals {
                context.delete(journal)
            }
        }

        // 모든 목표 삭제
        let goalDescriptor = FetchDescriptor<SubGoalData>()
        if let goals = try? context.fetch(goalDescriptor) {
            for goal in goals {
                context.delete(goal)
            }
        }

        try? context.save()
    }
}
