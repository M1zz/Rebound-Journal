//
//  ReviewPlanView.swift
//  Rebound Journal
//
//  Created by 황석현 on 3/19/25.
//

import SwiftUI

struct ReviewPlanView: View {
    /// 텍스트 필드를 구분하기 위한 열거형
    private enum Field {
        case review
        case plan
    }
    // Shared Dependencies
    @ObservedObject var viewModel: JournalCreatorViewModel
    @EnvironmentObject var manager: DataManager
    @Environment(\.modelContext) private var modelContext
    
    // UI State
    @FocusState private var currentField: Field?
    @State var reviewText: String = ""
    @State var planText: String = ""
    var canSave: Bool { return !reviewText.isEmpty && !planText.isEmpty }
    var isReviewed: Bool {!reviewText.isEmpty || currentField == .review}
    var isPlaned: Bool {!planText.isEmpty || currentField == .plan}
    @Binding var path: NavigationPath
    @State private var showCelebration: Bool = false
    
    // etc
    let text = Constants.ContentText()
    let systemText = Constants.SystemText()
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(viewModel.emotionText?.first ?? "감정태그")
                .font(.system(size: 16))
                .foregroundStyle(Color("Default"))
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .background {
                    Capsule()
                        .fill(.unselectedTagBackground)
                }

            // 과거 성공 패턴 제안 (리바운드일 때만)
            if viewModel.goalType == false, let pattern = viewModel.suggestedPattern {
                PastSuccessPatternCard(pattern: pattern, onApply: {
                    applyPastPattern(pattern)
                })
                .padding(.vertical, 8)
            }

            // Reviewing Shoot
            if (currentField == .review) || (currentField == .none) {
                Text(text.reviewShooting)
                    .font(.system(size: 25))
                    .fontWeight(.semibold)
                    .padding(.bottom, 3)
                    .foregroundStyle(currentField == .review ? .default : .gray)
                TextEditor(text: $reviewText)
                    .onChange(of: reviewText) { _, newValue in
                        viewModel.reviewText = newValue
                    }
                    .focused($currentField, equals: .review)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(alignment: .topLeading)
                    .padding()
                    .scrollContentBackground(.hidden)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(.rect(cornerRadius: 18))
                    .overlay(alignment: .topLeading) {
                        Text(text.reviewShootingField)
                            .foregroundStyle(isReviewed ? .clear : .gray)
                            .padding()
                    }
            }
            
            if (currentField == .plan) || (currentField == .none) {
                // Get NextPlan
                Text(text.whatNextPlan)
                    .font(.system(size: 25))
                    .fontWeight(.semibold)
                    .padding(.bottom, 3)
                    .foregroundStyle(currentField == .plan ? .default : .gray)
                TextEditor(text: $planText)
                    .onChange(of: planText) { _, newValue in
                        viewModel.nextPlanText = newValue
                    }
                    .focused($currentField, equals: .plan)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(alignment: .topLeading)
                    .padding()
                    .scrollContentBackground(.hidden)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(.rect(cornerRadius: 18))
                    .overlay(alignment: .topLeading) {
                        Text(text.whatNextPlanField)
                            .foregroundStyle(isPlaned ? .clear : .gray)
                            .padding()
                    }
            }
            
            // StepControll
            StepControlView(
                hasBackButton: true,
                canGoNext: canSave,
                onPrevious: {
                    onPreviousTapped()
                },
                onNext: {
                    onNextTapped()
                },
                nextButtonText: (viewModel.subGoal != nil) ? systemText.saveButton : systemText.nextButton
            )
        }
        .onTapGesture {
            currentField = .none
        }
        .onAppear() {
            reviewText = viewModel.reviewText ?? ""
            planText = viewModel.nextPlanText ?? ""

            // 리바운드일 때만 과거 패턴 로드
            if viewModel.goalType == false {
                viewModel.loadPastSuccessPattern(context: modelContext)
            }
        }
        .overlay {
            // 축하 화면
            if showCelebration, let rebound = viewModel.retryingRebound {
                SuccessFromReboundCelebration(rebound: rebound) {
                    showCelebration = false
                    viewModel.showSuccessFromReboundCelebration = false
                    manager.fullScreenMode = nil
                }
            }
        }
        .onChange(of: viewModel.showSuccessFromReboundCelebration) { _, newValue in
            if newValue {
                showCelebration = true
            }
        }
        .padding()
    }

    /// 과거 패턴 적용
    private func applyPastPattern(_ pattern: SuccessPattern) {
        planText = pattern.suggestedPlan
        viewModel.nextPlanText = pattern.suggestedPlan
    }
    
    private func onPreviousTapped() {
        path.removeLast()
    }
    
    private func onNextTapped() {
        // 선택된 목표가 있을 시
        if viewModel.subGoal != nil {
            viewModel.saveJournal(context: modelContext)
            manager.fullScreenMode = nil
        }
        // 목표가 없을 시
        else {
            path.append(JournalCreationState.createSubGoal)
        }
    }
}

/// 과거 성공 패턴 카드
struct PastSuccessPatternCard: View {
    let pattern: SuccessPattern
    let onApply: () -> Void
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("💡 과거의 나는 이렇게 했어요")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.gray)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // 날짜 정보
                    HStack(spacing: 4) {
                        Text("[\(pattern.formattedFailureDate)]")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                        Text("비슷한 실패")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }

                    // 대안 내용
                    VStack(alignment: .leading, spacing: 4) {
                        Text("대안:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("\"\(pattern.suggestedPlan)\"")
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // 성공 결과
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                        Text("다음 시도에서 성공했어요!")
                            .font(.system(size: 13))
                            .foregroundStyle(.green)
                    }

                    // 적용 버튼
                    Button(action: onApply) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("이 대안 적용하기")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color("TextColor"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                    }

                    // 새로 생각하기 텍스트
                    Text("또는 새로운 대안을 생각해보세요")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    let mockViewModel = {
        let vm = JournalCreatorViewModel()
        vm.goalType = true
        vm.emotionValue = 1
        vm.emotionText = ["기분이 좋은"]
        return vm
    }()
    ReviewPlanView(viewModel: mockViewModel, path: .constant(NavigationPath()))
}
