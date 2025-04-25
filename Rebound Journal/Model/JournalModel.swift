//
//  JournalModel.swift
//  Rebound Journal
//
//  Created by 황석현 on 4/16/25.
//

import Foundation

struct JournalModel: Identifiable {
    let id: String
    let date: Date
    let hasDeleted: Bool
    let isGoalIn: Bool
    let emotionValue: Int
    let emotionText: String
    let review: String
    let nextPlan: String
}

extension JournalModel {
    
    static func convertToJournalModel(entries: [JournalEntry]) -> [JournalModel] {
        return entries.map { item in
            guard let id = item.id,
                  let date = item.date,
                  let isGoalIn = (item.moodLevel == 1) ? true : false,
                  let emotionText = item.moodText,
                  let review = item.reasons,
                  let nextPlan = item.reboundText
            else {
                return JournalModel(id: "", date: Date(), hasDeleted: false, isGoalIn: false, emotionValue: 0, emotionText: "", review: "", nextPlan: "")
            }
            return JournalModel(id: id, date: date, hasDeleted: item.hasDeleted, isGoalIn: isGoalIn, emotionValue: 0, emotionText: emotionText, review: review, nextPlan: nextPlan)
        }
    }
    
    /// 더미데이터 생성
    static func mockData() -> [JournalModel] {
        let emotionTexts = ["행복해요", "조금 우울해요", "최고의 하루!", "짜증났어요", "평범했어요"]
        let reviews = ["좋은 하루였어요.", "기분이 썩 좋진 않았어요.", "완벽했어요.", "좀 아쉬웠어요.", "그럭저럭 괜찮았어요."]
        let plans = ["운동하기", "일찍 자기", "계속 유지하기", "책 읽기", "산책하기"]

        return (1...10).map { _ in
            let randomDayOffset = Int.random(in: -6...0)
            let randomDate = Calendar.current.date(byAdding: .day, value: randomDayOffset, to: Date())!
            let isGoalIn = Bool.random()
            let emotionValue = Int.random(in: 1...5)

            return JournalModel(
                id: UUID().uuidString,
                date: randomDate,
                hasDeleted: Bool.random(),
                isGoalIn: isGoalIn,
                emotionValue: emotionValue,
                emotionText: emotionTexts.randomElement()!,
                review: reviews.randomElement()!,
                nextPlan: plans.randomElement()!
            )
        }
    }
}
