//
//  InteractiveJournalCreator.swift
//  Rebound Journal
//
//  Created by Claude on 11/20/25.
//

import SwiftUI
import SwiftData

/// 인터랙티브 저널 작성 화면 - 질문에 답하면 위에서 새 질문이 나타남
struct InteractiveJournalCreator: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var manager: DataManager
    @ObservedObject var viewModel: JournalCreatorViewModel
    @Query private var subGoals: [SubGoalData]
    @Query(sort: \JournalData.date, order: .reverse) private var journals: [JournalData]

    // Question flow state
    @State private var currentStep: Step = .goal
    @State private var answeredSteps: [AnsweredStep] = []

    // Success fields
    @State private var successReviewText: String = ""
    @State private var successContinuationText: String = ""  // 다음 성공을 위한 방법
    @State private var successReferenceText: String = ""     // 나중에 참고할 성공 요인

    // Failure analysis fields
    @State private var failureFactsText: String = ""       // 무슨 일이 있었나요?
    @State private var failureThoughtsText: String = ""    // 무슨 생각을 했나요?
    @State private var failureTrigger: String? = nil       // 실패 원인
    @State private var failureAlternativeText: String = "" // 대신 무엇을 할 수 있었을까요?
    @State private var failureActionPlanText: String = ""  // 다음엔 어떻게 할까요?

    @FocusState private var isTextFieldFocused: Bool
    @State private var showCelebration: Bool = false

    // Failure trigger options
    let triggerOptions = [
        String(localized: "환경 (장소, 상황)"),
        String(localized: "감정 (스트레스, 외로움)"),
        String(localized: "피로 (몸이 힘들었음)"),
        String(localized: "유혹 (보거나 냄새를 맡음)"),
        String(localized: "준비 부족 (대안이 없었음)"),
        String(localized: "습관 (무의식적으로)")
    ]

    enum Step {
        case goal
        case result
        // Success path
        case successEmotion
        case successReview
        case successContinuation  // 다음 성공을 위한 방법
        case successReference     // 나중에 참고할 성공 요인
        // Failure path (structured reflection)
        case failureFacts        // 무슨 일이 있었나요?
        case failureEmotion      // 어떤 기분이었나요?
        case failureThoughts     // 무슨 생각을 했나요?
        case failureTrigger      // 무엇이 실패를 유발했나요?
        case failureAlternative  // 대신 무엇을 할 수 있었을까요?
        case failureActionPlan   // 다음엔 어떻게 할까요?
        case complete
    }

    struct AnsweredStep: Identifiable {
        let id = UUID()
        let question: String
        let answer: String
        let step: Step  // 어떤 단계인지 저장
    }

    var canSave: Bool {
        guard viewModel.goalType != nil else { return false }
        guard viewModel.emotionValue != nil else { return false }
        guard viewModel.emotionText != nil else { return false }

        if viewModel.goalType == true {
            // Success: need review, continuation, and reference
            return !successReviewText.isEmpty &&
                   !successContinuationText.isEmpty &&
                   !successReferenceText.isEmpty
        } else {
            // Failure: need all reflection fields
            return !failureFactsText.isEmpty &&
                   !failureThoughtsText.isEmpty &&
                   failureTrigger != nil &&
                   !failureAlternativeText.isEmpty &&
                   !failureActionPlanText.isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            ModalHeaderBar(onDismiss: {
                manager.fullScreenMode = nil
            }, hasAlert: answeredSteps.isEmpty ? false : true)

            // 메인 컨텐츠
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // 현재 질문 (최상단)
                        if currentStep != .complete {
                            currentQuestionView
                                .id("currentQuestion")
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // 답변한 질문들 (아래로 쌓임)
                        ForEach(answeredSteps) { step in
                            answeredQuestionView(step: step)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // 완료 화면
                        if currentStep == .complete {
                            completionView
                                .id("completion")
                        }

                        // 하단 여백
                        Color.clear.frame(height: 100)
                    }
                    .padding()
                }
                .onChange(of: currentStep) { _, _ in
                    withAnimation {
                        if currentStep == .complete {
                            proxy.scrollTo("completion", anchor: .top)
                        } else {
                            proxy.scrollTo("currentQuestion", anchor: .top)
                        }
                    }
                }
            }
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

    // MARK: - Current Question View

    @ViewBuilder
    private var currentQuestionView: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch currentStep {
            case .goal:
                goalQuestion
            case .result:
                resultQuestion
            case .successEmotion:
                successEmotionQuestion
            case .successReview:
                successReviewQuestion
            case .successContinuation:
                successContinuationQuestion
            case .successReference:
                successReferenceQuestion
            case .failureFacts:
                failureFactsQuestion
            case .failureEmotion:
                failureEmotionQuestion
            case .failureThoughts:
                failureThoughtsQuestion
            case .failureTrigger:
                failureTriggerQuestion
            case .failureAlternative:
                failureAlternativeQuestion
            case .failureActionPlan:
                failureActionPlanQuestion
            case .complete:
                EmptyView()
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    private var goalQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("어떤 목표에 대한 기록인가요?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                // 목표 없음
                goalOptionButton(text: DataSentinel.noGoal, isSelected: viewModel.subGoal == DataSentinel.noGoal) {
                    selectGoal(DataSentinel.noGoal)
                }

                // 목표 리스트
                ForEach(subGoals, id: \.self) { item in
                    if let text = item.goalText {
                        goalOptionButton(text: text, isSelected: viewModel.subGoal == text) {
                            selectGoal(text)
                        }
                    }
                }
            }
        }
    }

    private func goalOptionButton(text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(DisplayText.goalName(text))
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private var resultQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("결과가 어떠셨나요?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            HStack(spacing: 16) {
                resultOptionButton(
                    image: .goalIn,
                    title: String(localized: "골인"),
                    isSelected: viewModel.goalType == true
                ) {
                    selectResult(true)
                }

                resultOptionButton(
                    image: .rebound,
                    title: String(localized: "리바운드"),
                    isSelected: viewModel.goalType == false
                ) {
                    selectResult(false)
                }
            }
        }
    }

    private func resultOptionButton(image: ImageResource, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 60)
                Text(title)
                    .font(.body)
                        .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }

    // MARK: - Success Path

    private var successEmotionQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("어떤 기분이셨나요?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            EmotionTracker(viewModel: viewModel)

            if viewModel.emotionText != nil {
                Button(action: {
                    moveToNextStep()
                }) {
                    Text("다음")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
        }
    }

    private var successReviewQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let emotion = viewModel.emotionText?.first {
                HStack {
                    Text(emotion)
                        .font(.callout)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                    Spacer()
                }
            }

            Text("성공 경험을 기록해주세요")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text("어떻게 성공하셨나요?")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextEditor(text: $successReviewText)
                .onChange(of: successReviewText) { _, newValue in
                    viewModel.reviewText = newValue
                }
                .focused($isTextFieldFocused)
                .frame(height: 120)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(alignment: .topLeading) {
                    if successReviewText.isEmpty {
                        Text("성공 비결을 적어보세요")
                            .foregroundStyle(.gray)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }

            if !successReviewText.isEmpty {
                Button(action: {
                    isTextFieldFocused = false
                    moveToNextStep()
                }) {
                    Text("다음")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
    }

    private var successContinuationQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("다음 성공을 위해")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text("이 성공을 계속 이어가려면 무엇을 해야 할까요?")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextEditor(text: $successContinuationText)
                .onChange(of: successContinuationText) { _, newValue in
                    viewModel.nextPlanText = newValue
                }
                .focused($isTextFieldFocused)
                .frame(height: 120)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(alignment: .topLeading) {
                    if successContinuationText.isEmpty {
                        Text("예: 같은 시간에 계속하기, 환경 유지하기 등")
                            .foregroundStyle(.gray)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }

            if !successContinuationText.isEmpty {
                Button(action: {
                    isTextFieldFocused = false
                    moveToNextStep()
                }) {
                    Text("다음")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
    }

    private var successReferenceQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("나중을 위한 기록")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text("혹시 다음에 실패한다면, 이번 성공에서 무엇을 참고하면 좋을까요?")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextEditor(text: $successReferenceText)
                .focused($isTextFieldFocused)
                .frame(height: 120)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(alignment: .topLeading) {
                    if successReferenceText.isEmpty {
                        Text("예: 이렇게 하니까 성공했어요, 이 마음가짐이 중요했어요 등")
                            .foregroundStyle(.gray)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }

            if !successReferenceText.isEmpty {
                Button(action: {
                    isTextFieldFocused = false
                    moveToNextStep()
                }) {
                    Text("완료")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Failure Path (Structured Reflection)

    private var failureFactsQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("무슨 일이 있었나요?")
                    .font(.title2)
                .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("감정을 빼고 객관적인 사실만 적어주세요")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("예시")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)

                Text("\"11시에 배가 고팠다. 냉장고를 열었다. 치킨을 먹었다.\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
            }

            TextEditor(text: $failureFactsText)
                .focused($isTextFieldFocused)
                .frame(height: 120)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(alignment: .topLeading) {
                    if failureFactsText.isEmpty {
                        Text("언제, 어디서, 무엇을 했나요?")
                            .foregroundStyle(.gray)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }

            if !failureFactsText.isEmpty {
                Button(action: {
                    isTextFieldFocused = false
                    moveToNextStep()
                }) {
                    Text("다음")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
    }

    private var failureEmotionQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("어떤 기분이었나요?")
                    .font(.title2)
                .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("그때 느낀 감정을 선택해주세요")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            EmotionTracker(viewModel: viewModel)

            if viewModel.emotionText != nil {
                Button(action: {
                    moveToNextStep()
                }) {
                    Text("다음")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
        }
    }

    private var failureThoughtsQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("그때 무슨 생각을 했나요?")
                    .font(.title2)
                .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("머릿속에 떠올랐던 생각이나 스스로에게 한 말")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("예시")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)

                Text("\"오늘 하루만 괜찮겠지\", \"내일부터 하면 돼\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
            }

            TextEditor(text: $failureThoughtsText)
                .focused($isTextFieldFocused)
                .frame(height: 120)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(alignment: .topLeading) {
                    if failureThoughtsText.isEmpty {
                        Text("어떤 생각이 들었나요?")
                            .foregroundStyle(.gray)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }

            if !failureThoughtsText.isEmpty {
                Button(action: {
                    isTextFieldFocused = false
                    moveToNextStep()
                }) {
                    Text("다음")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
    }

    private var failureTriggerQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("무엇이 실패를 유발했나요?")
                    .font(.title2)
                .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("가장 큰 원인을 선택해주세요")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(triggerOptions, id: \.self) { option in
                    triggerOptionButton(text: option, isSelected: failureTrigger == option) {
                        failureTrigger = option
                        moveToNextStep()
                    }
                }
            }
        }
    }

    private func triggerOptionButton(text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(DisplayText.goalName(text))
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private var failureAlternativeQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("대신 무엇을 할 수 있었을까요?")
                    .font(.title2)
                .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("그 순간 다른 선택지를 생각해보세요")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // 과거 패턴 제안
            if let pattern = findSuggestedPattern() {
                PastSuccessPatternCard(pattern: pattern, onApply: {
                    failureAlternativeText = pattern.suggestedPlan
                })
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("예시")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)

                Text("\"물 마시기\", \"산책하기\", \"친구에게 전화하기\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
            }

            TextEditor(text: $failureAlternativeText)
                .focused($isTextFieldFocused)
                .frame(height: 100)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(alignment: .topLeading) {
                    if failureAlternativeText.isEmpty {
                        Text("대안 행동을 적어보세요")
                            .foregroundStyle(.gray)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }

            if !failureAlternativeText.isEmpty {
                Button(action: {
                    isTextFieldFocused = false
                    moveToNextStep()
                }) {
                    Text("다음")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
    }

    private var failureActionPlanQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("다음엔 구체적으로 어떻게 할까요?")
                    .font(.title2)
                .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("\"~할 때, ~하겠다\" 형식으로 계획을 세워보세요")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("예시")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)

                Text("\"배고플 때, 먼저 물 한 잔을 마시겠다\"\n\"야식 생각이 날 때, 양치질을 하겠다\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
            }

            TextEditor(text: $failureActionPlanText)
                .focused($isTextFieldFocused)
                .frame(height: 100)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(alignment: .topLeading) {
                    if failureActionPlanText.isEmpty {
                        Text("구체적인 실행 계획을 적어보세요")
                            .foregroundStyle(.gray)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }

            if !failureActionPlanText.isEmpty {
                Button(action: {
                    isTextFieldFocused = false
                    moveToNextStep()
                }) {
                    Text("완료")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Answered Questions View

    private func answeredQuestionView(step: AnsweredStep) -> some View {
        Button {
            editAnswer(for: step)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(step.question)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(step.answer)
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.top, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("모든 질문에 답변했어요!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Button(action: saveJournal) {
                Text("저장하기")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .disabled(!canSave)
        }
        .padding(32)
    }

    // MARK: - Helper Methods

    private func selectGoal(_ goal: String) {
        viewModel.subGoal = goal
        addAnsweredStep(question: String(localized: "어떤 목표에 대한 기록인가요?"), answer: DisplayText.goalName(goal), step: .goal)
        moveToNextStep()
    }

    private func selectResult(_ isSuccess: Bool) {
        viewModel.goalType = isSuccess
        addAnsweredStep(
            question: String(localized: "결과가 어떠셨나요?"),
            answer: isSuccess ? String(localized: "골인") : String(localized: "리바운드"),
            step: .result
        )
        moveToNextStep()
    }

    private func addAnsweredStep(question: String, answer: String, step: Step) {
        withAnimation(.spring()) {
            answeredSteps.append(AnsweredStep(question: question, answer: answer, step: step))
        }
    }

    private func editAnswer(for answeredStep: AnsweredStep) {
        // 해당 단계로 돌아가기
        withAnimation(.spring()) {
            // 해당 단계 이후의 모든 답변 제거
            if let index = answeredSteps.firstIndex(where: { $0.id == answeredStep.id }) {
                answeredSteps.removeSubrange(index...)
            }

            // 해당 단계로 이동
            currentStep = answeredStep.step
        }
    }

    private func moveToNextStep() {
        withAnimation(.spring()) {
            switch currentStep {
            case .goal:
                currentStep = .result

            case .result:
                // Branch based on success/failure
                if viewModel.goalType == true {
                    currentStep = .successEmotion
                } else {
                    currentStep = .failureFacts
                }

            // Success path
            case .successEmotion:
                addAnsweredStep(
                    question: String(localized: "어떤 기분이었나요?"),
                    answer: viewModel.emotionText?.first ?? "",
                    step: .successEmotion
                )
                currentStep = .successReview

            case .successReview:
                addAnsweredStep(
                    question: String(localized: "성공 경험을 기록해주세요"),
                    answer: successReviewText,
                    step: .successReview
                )
                currentStep = .successContinuation

            case .successContinuation:
                addAnsweredStep(
                    question: String(localized: "다음 성공을 위해"),
                    answer: successContinuationText,
                    step: .successContinuation
                )
                currentStep = .successReference

            case .successReference:
                addAnsweredStep(
                    question: String(localized: "나중을 위한 기록"),
                    answer: successReferenceText,
                    step: .successReference
                )
                // Combine success review + reference as nextPlan
                viewModel.nextPlanText = String(
                    localized: """
                    [다음 성공을 위해]
                    \(successContinuationText)

                    [성공 참고사항]
                    \(successReferenceText)
                    """
                )
                currentStep = .complete

            // Failure path
            case .failureFacts:
                addAnsweredStep(
                    question: String(localized: "무슨 일이 있었나요?"),
                    answer: failureFactsText,
                    step: .failureFacts
                )
                currentStep = .failureEmotion

            case .failureEmotion:
                addAnsweredStep(
                    question: String(localized: "어떤 기분이었나요?"),
                    answer: viewModel.emotionText?.first ?? "",
                    step: .failureEmotion
                )
                currentStep = .failureThoughts

            case .failureThoughts:
                addAnsweredStep(
                    question: String(localized: "그때 무슨 생각을 했나요?"),
                    answer: failureThoughtsText,
                    step: .failureThoughts
                )
                currentStep = .failureTrigger

            case .failureTrigger:
                addAnsweredStep(
                    question: String(localized: "무엇이 실패를 유발했나요?"),
                    answer: failureTrigger ?? "",
                    step: .failureTrigger
                )
                currentStep = .failureAlternative

            case .failureAlternative:
                addAnsweredStep(
                    question: String(localized: "대신 무엇을 할 수 있었을까요?"),
                    answer: failureAlternativeText,
                    step: .failureAlternative
                )
                currentStep = .failureActionPlan

            case .failureActionPlan:
                addAnsweredStep(
                    question: String(localized: "다음엔 구체적으로 어떻게 할까요?"),
                    answer: failureActionPlanText,
                    step: .failureActionPlan
                )
                // Combine all failure reflection into viewModel
                viewModel.reviewText = String(
                    localized: """
                    사실: \(failureFactsText)

                    생각: \(failureThoughtsText)

                    원인: \(failureTrigger ?? "")
                    """
                )
                viewModel.nextPlanText = String(
                    localized: """
                    대안: \(failureAlternativeText)

                    계획: \(failureActionPlanText)
                    """
                )
                currentStep = .complete

            case .complete:
                break
            }
        }
    }

    private func findSuggestedPattern() -> SuccessPattern? {
        guard let currentGoal = viewModel.subGoal else { return nil }
        let patterns = JournalAnalyzer.findSuccessPatterns(for: currentGoal, in: Array(journals))
        return patterns.first
    }

    private func saveJournal() {
        viewModel.saveJournal(context: modelContext)

        if viewModel.goalType == true, viewModel.retryingRebound != nil {
            showCelebration = true
        } else {
            manager.fullScreenMode = nil
        }
    }
}

#Preview {
    InteractiveJournalCreator(viewModel: JournalCreatorViewModel())
        .environmentObject(DataManager())
}
