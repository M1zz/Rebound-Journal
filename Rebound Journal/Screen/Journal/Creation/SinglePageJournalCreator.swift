//
//  SinglePageJournalCreator.swift
//  Rebound Journal
//
//  Created by Claude on 11/15/25.
//

import SwiftUI
import SwiftData

/// 한 페이지로 통합된 저널 작성 화면
struct SinglePageJournalCreator: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var manager: DataManager
    @ObservedObject var viewModel: JournalCreatorViewModel
    @Query private var subGoals: [SubGoalData]
    @Query(sort: \JournalData.date, order: .reverse) private var journals: [JournalData]

    // UI State
    @State private var selectedGoal: SubGoalData?
    @State private var reviewText: String = ""
    @State private var planText: String = ""
    @FocusState private var focusedField: FocusField?
    @State private var showCelebration: Bool = false

    enum FocusField {
        case review, plan
    }

    var canSave: Bool {
        guard viewModel.goalType != nil else { return false }
        guard viewModel.emotionValue != nil else { return false }
        guard viewModel.emotionText != nil else { return false }
        guard !reviewText.isEmpty else { return false }

        // 실패일 때는 대안 필수
        if viewModel.goalType == false {
            return !planText.isEmpty
        }

        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            ModalHeaderBar(onDismiss: {
                manager.fullScreenMode = nil
            }, hasAlert: true)

            // 스크롤 컨텐츠
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    goalSelectionSection
                    Divider()
                    resultSelectionSection
                    Divider()

                    if viewModel.goalType != nil {
                        emotionSelectionSection
                        Divider()
                    }

                    if viewModel.goalType != nil && viewModel.emotionText != nil {
                        reviewAndPlanSection
                    }

                    // 하단 여백
                    Color.clear.frame(height: 100)
                }
                .padding()
            }
            .onTapGesture {
                focusedField = nil
            }

            // 저장 버튼
            saveButton
        }
        .overlay {
            if showCelebration, let rebound = viewModel.retryingRebound {
                SuccessFromReboundCelebration(rebound: rebound) {
                    showCelebration = false
                    manager.fullScreenMode = nil
                }
            }
        }
    }

    // MARK: - View Components

    private var goalSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("어떤 목표에 대한 기록인가요?")
                .font(.system(size: 20, weight: .bold))

            // 목표 없음 옵션
            goalCell(text: "목표 없음", isSelected: viewModel.subGoal == "목표 없음") {
                if viewModel.subGoal == "목표 없음" {
                    viewModel.subGoal = nil
                    selectedGoal = nil
                } else {
                    viewModel.subGoal = "목표 없음"
                    selectedGoal = nil
                }
            }

            // 목표 리스트
            ForEach(subGoals, id: \.self) { item in
                if let text = item.goalText {
                    goalCell(text: text, isSelected: selectedGoal == item) {
                        if selectedGoal == item {
                            selectedGoal = nil
                            viewModel.subGoal = nil
                        } else {
                            selectedGoal = item
                            viewModel.subGoal = text
                        }
                    }
                }
            }
        }
    }

    private func goalCell(text: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        HStack {
            Text(text)
                .padding()
                .foregroundStyle(.black)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.cellColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onTap)
    }

    private var resultSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("결과가 어떠셨나요?")
                .font(.system(size: 20, weight: .bold))

            HStack(spacing: 16) {
                // 골인 버튼
                Button(action: {
                    viewModel.goalType = (viewModel.goalType == true) ? nil : true
                }) {
                    resultButton(image: .goalIn, title: "골인", isSelected: viewModel.goalType == true)
                }

                // 리바운드 버튼
                Button(action: {
                    viewModel.goalType = (viewModel.goalType == false) ? nil : false
                }) {
                    resultButton(image: .rebound, title: "리바운드", isSelected: viewModel.goalType == false)
                }
            }
        }
    }

    private func resultButton(image: ImageResource, title: String, isSelected: Bool) -> some View {
        VStack {
            Image(image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 60)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.shootTypeButtonBorder, lineWidth: 2)
        )
        .cornerRadius(10)
    }

    private var emotionSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("어떤 기분이셨나요?")
                .font(.system(size: 20, weight: .bold))

            EmotionTracker(viewModel: viewModel)
        }
    }

    private var reviewAndPlanSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 감정 태그
            if let emotion = viewModel.emotionText?.first {
                Text(emotion)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.unselectedTagBackground)
                    .clipShape(Capsule())
            }

            // 과거 패턴 제안 (실패일 때만)
            if viewModel.goalType == false, let pattern = findSuggestedPattern() {
                PastSuccessPatternCard(pattern: pattern, onApply: {
                    planText = pattern.suggestedPlan
                    viewModel.nextPlanText = pattern.suggestedPlan
                })
            }

            // 리뷰 입력
            Text(viewModel.goalType == true ? "성공 경험을 기록해주세요" : "무엇이 문제였나요?")
                .font(.system(size: 18, weight: .semibold))

            TextEditor(text: $reviewText)
                .onChange(of: reviewText) { _, newValue in
                    viewModel.reviewText = newValue
                }
                .focused($focusedField, equals: .review)
                .frame(height: 100)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .overlay(alignment: .topLeading) {
                    if reviewText.isEmpty {
                        Text(viewModel.goalType == true ? "어떻게 성공하셨나요?" : "어떤 어려움이 있었나요?")
                            .foregroundStyle(.gray)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }

            // 대안 입력 (실패일 때만)
            if viewModel.goalType == false {
                Text("다음엔 어떻게 할까요?")
                    .font(.system(size: 18, weight: .semibold))

                TextEditor(text: $planText)
                    .onChange(of: planText) { _, newValue in
                        viewModel.nextPlanText = newValue
                    }
                    .focused($focusedField, equals: .plan)
                    .frame(height: 100)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(alignment: .topLeading) {
                        if planText.isEmpty {
                            Text("다음 시도를 위한 대안을 적어보세요")
                                .foregroundStyle(.gray)
                                .padding(16)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
    }

    private var saveButton: some View {
        Button(action: saveJournal) {
            Text("저장")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSave ? Color.accentColor : Color.gray)
                .cornerRadius(12)
        }
        .disabled(!canSave)
        .padding()
    }

    // MARK: - Helper Methods

    private func findSuggestedPattern() -> SuccessPattern? {
        guard let currentGoal = viewModel.subGoal else { return nil }
        let patterns = JournalAnalyzer.findSuccessPatterns(for: currentGoal, in: Array(journals))
        return patterns.first
    }

    private func saveJournal() {
        viewModel.saveJournal(context: modelContext)

        // 리바운드를 극복한 성공인지 확인
        if viewModel.goalType == true, viewModel.retryingRebound != nil {
            showCelebration = true
        } else {
            manager.fullScreenMode = nil
        }
    }
}

#Preview {
    SinglePageJournalCreator(viewModel: JournalCreatorViewModel())
        .environmentObject(DataManager())
}
