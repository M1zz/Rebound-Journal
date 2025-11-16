//
//  JournalData.swift
//  Rebound Journal
//
//  Created by 황석현 on 5/11/25.
//

import Foundation
import SwiftData

@Model
final class JournalData {

    var id: String? // 식별값
    var date: Date? // 생성 일자
    var hasDeleted: Bool? // 삭제 여부
    var isGoalIn: Bool? // 골인여부
    var emotionValue: Int? // 감정 수치
    var emotionText: String? // 감정 태그
    var review: String? // 느낀 점
    var nextPlan: String? // 향후 계획
    var isRebounded: Bool? // 리바운드 여부
    
    var purpose: String? // 목적
    var mainGoal: String? // 큰 목표
    var subGoal: String? // 작은 목표

    // 실패-성공 연결 관계
    var linkedReboundId: String? // 이 성공이 극복한 리바운드(실패) ID
    var isResolved: Bool? // 리바운드가 해결되었는지
    var resolvedDate: Date? // 해결된 날짜
    var retryCount: Int? // 재시도 횟수

    init(id: String? = nil,
         date: Date? = nil,
         hasDeleted: Bool = false,
         isGoalIn: Bool? = nil,
         emotionValue: Int? = nil,
         emotionText: String? = nil,
         review: String? = nil,
         nextPlan: String? = nil,
         isRebounded: Bool? = nil,
         purpose: String? = nil,
         mainGoal: String? = nil,
         subGoal: String? = nil,
         linkedReboundId: String? = nil,
         isResolved: Bool? = nil,
         resolvedDate: Date? = nil,
         retryCount: Int? = nil) {
        self.id = id
        self.date = date
        self.hasDeleted = hasDeleted
        self.isGoalIn = isGoalIn
        self.emotionValue = emotionValue
        self.emotionText = emotionText
        self.review = review
        self.nextPlan = nextPlan
        self.isRebounded = isRebounded
        self.purpose = purpose
        self.mainGoal = mainGoal
        self.subGoal = subGoal
        self.linkedReboundId = linkedReboundId
        self.isResolved = isResolved
        self.resolvedDate = resolvedDate
        self.retryCount = retryCount
    }
}

extension JournalData {
    var isGoalInUnwrapped: Bool {
        return isGoalIn ?? false
    }

    var dateUnwrapped: Date {
        return date ?? Date()
    }

    var isReboundedUnwrapped: Bool {
        return isRebounded ?? false
    }

    var hasDeletedUnwrapped: Bool {
        return hasDeleted ?? false
    }

    var emotionValueUnwrapped: Int {
        return emotionValue ?? 0
    }

    var emotionTextUnwrapped: String {
        return emotionText ?? ""
    }

    var reviewUnwrapped: String {
        return review ?? ""
    }

    var nextPlanUnwrapped: String {
        return nextPlan ?? ""
    }

    var purposeUnwrapped: String {
        return purpose ?? ""
    }

    var mainGoalUnwrapped: String {
        return mainGoal ?? ""
    }

    var subGoalUnwrapped: String {
        return subGoal ?? ""
    }

    var hasValidDate: Bool {
        return date != nil
    }

    func isSameDay(as other: Date) -> Bool {
        guard let selfDate = self.date else { return false }
        return Calendar.current.isDate(selfDate, inSameDayAs: other)
    }

    var isValidForDisplay: Bool {
        return !(hasDeleted ?? false) && date != nil
    }

    var linkedReboundIdUnwrapped: String {
        return linkedReboundId ?? ""
    }

    var isResolvedUnwrapped: Bool {
        return isResolved ?? false
    }

    var retryCountUnwrapped: Int {
        return retryCount ?? 0
    }

    /// 활성 리바운드인지 (실패이면서 아직 해결되지 않음)
    var isActiveRebound: Bool {
        return isGoalIn == false && !(isResolved ?? false) && !hasDeletedUnwrapped
    }
}
