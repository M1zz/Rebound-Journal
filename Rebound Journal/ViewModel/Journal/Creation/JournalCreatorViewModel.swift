//
//  JournalCreateViewModel.swift
//  Rebound Journal
//
//  Created by 황석현 on 3/21/25.
//

import Foundation
import SwiftData

class JournalCreatorViewModel: ObservableObject {

    // UI State
    @Published var isSliderEditing: Bool = false

    // Data
    @Published var goalType: Bool? = nil // 골인 || 리바운드
    @Published var emotionValue: Double? = nil // 슬라이더 값(0~3)
    @Published var emotionText: [String]? = nil // 감정태그(EmotionText)
    @Published var reviewText: String? = nil // 슛하고 느낀 점
    @Published var nextPlanText: String? = nil // 향후 계획
    @Published var purpose: String? = nil
    @Published var mainGoal: String? = nil
    @Published var subGoal: String? = nil

    // 과거 성공 패턴
    @Published var suggestedPattern: SuccessPattern? = nil

    // 재도전 중인 리바운드
    @Published var retryingRebound: JournalData? = nil

    // 축하 메시지 표시 플래그
    @Published var showSuccessFromReboundCelebration: Bool = false
    
    /// SwiftData로 저장하는 로직
    func saveJournal(context: ModelContext) {
        debugPrint("Save Journal To SwiftData")

        // 성공 시 재도전 중인 리바운드 연결
        var linkedReboundId: String? = nil
        if goalType == true, let rebound = retryingRebound {
            linkedReboundId = rebound.id
            // 리바운드를 해결됨으로 표시
            rebound.isResolved = true
            rebound.resolvedDate = Date()
        }

        let journal = JournalData(id: UUID().uuidString,
                                  date: Date(),
                                  hasDeleted: false,
                                  isGoalIn: goalType,
                                  emotionValue: Int(emotionValue ?? 0.0),
                                  emotionText: emotionText?.first,
                                  review: reviewText,
                                  nextPlan: nextPlanText,
                                  isRebounded: false,
                                  purpose: purpose,
                                  mainGoal: mainGoal,
                                  subGoal: subGoal,
                                  linkedReboundId: linkedReboundId,
                                  isResolved: goalType == false ? false : nil // 실패일 때만 false
        )
        context.insert(journal) // 데이터 저장

        // 성공 시 축하 메시지 표시 플래그
        if goalType == true && retryingRebound != nil {
            showSuccessFromReboundCelebration = true
        }

        debugPrint("""
        저장된 Journal:
        - ID: \(String(describing: journal.id))
        - Date: \(String(describing: journal.date))
        - hasDeleted: \(String(describing: journal.hasDeleted))
        - isGoalIn: \(String(describing: journal.isGoalIn))
        - Emotion Value: \(String(describing: journal.emotionValue))
        - Emotion Text: \(journal.emotionText ?? "nil")
        - Review: \(journal.review ?? "nil")
        - Next Plan: \(journal.nextPlan ?? "nil")
        - isRebounded: \(String(describing: journal.isRebounded))
        - Purpose: \(journal.purpose ?? "nil")
        - Main Goal: \(journal.mainGoal ?? "nil")
        - Sub Goal: \(journal.subGoal ?? "nil")
        - Linked Rebound: \(journal.linkedReboundId ?? "nil")
        - Is Resolved: \(String(describing: journal.isResolved))
        """)
    }
    
    func saveSubGoal(context: ModelContext) {
        debugPrint("Save SubGoal To SwiftData")

        let subGoalData = SubGoalData(id: UUID().uuidString,
                                      date: Date(),
                                      goalText: subGoal)
        context.insert(subGoalData)
        debugPrint("저장된 SubGoal: \(String(describing: subGoalData.goalText))")
    }

    /// 과거 성공 패턴 로드
    func loadPastSuccessPattern(context: ModelContext) {
        guard let currentSubGoal = subGoal else {
            debugPrint("목표가 선택되지 않았습니다.")
            return
        }

        // 모든 저널 데이터 가져오기
        do {
            let allJournals = try context.fetch(FetchDescriptor<JournalData>())
            debugPrint("전체 저널 개수: \(allJournals.count)")

            // 과거 성공 패턴 찾기
            let pattern = JournalAnalyzer.getMostRecentSuccessPattern(
                for: currentSubGoal,
                in: allJournals
            )

            if let pattern = pattern {
                debugPrint("""
                과거 성공 패턴 발견:
                - 실패 날짜: \(pattern.formattedFailureDate)
                - 성공 날짜: \(pattern.formattedSuccessDate)
                - 대안: \(pattern.suggestedPlan)
                """)
                self.suggestedPattern = pattern
            } else {
                debugPrint("과거 성공 패턴을 찾을 수 없습니다.")
                self.suggestedPattern = nil
            }
        } catch {
            debugPrint("데이터 로드 실패: \(error)")
            self.suggestedPattern = nil
        }
    }
}
