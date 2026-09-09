//
//  RecordFeelingView.swift
//  Rebound Journal
//
//  Created by 황석현 on 3/19/25.
//

import SwiftUI

/// 감정 도형, 감정 태그를 만드는 화면
struct EmotionInputView: View {
    
    // Shared Dependencies
    @ObservedObject var viewModel: JournalCreatorViewModel
    // UI State
    @State private var sliderValue: Double = 0.5
    var canGoNext: Bool {
        viewModel.emotionValue != nil && (viewModel.emotionText != [] && viewModel.emotionText != nil)
    }
    @Binding var path: NavigationPath
    // etc
    var text = Constants.ContentText()
    
    var body: some View {
        VStack {
            if let type = viewModel.goalType {
                ShootCreationHeader(
                    title: type ? text.EmotionInPutGoalIn :
                        text.EmotionInPutRebound,
                    image: type ? .goalIn : .rebound)
            }
            EmotionTracker(viewModel: viewModel)
                .frame(maxWidth: .infinity)
                .padding()
            Spacer()
            StepControlView(
                hasBackButton: true,
                canGoNext: canGoNext,
                onPrevious: {
                  onPreviousTapped()
                },
                onNext: {
                    onNextTapped()
                },
                nextButtonText: String(localized: "다음으로")
            )
            .padding()
        }
    }
    private func onPreviousTapped() {
        path.removeLast()
    }
    private func onNextTapped() {
        path.append(JournalCreationState.review)
    }
}

#Preview("EmotionInputView: GoalIn") {
    let viewModel: JournalCreatorViewModel = {
        let vm = JournalCreatorViewModel()
        vm.goalType = true
        return vm
    }()
    EmotionInputView(viewModel: viewModel, path: .constant(NavigationPath()))
}

#Preview("EmotionInputView: Rebound") {
    let viewModel: JournalCreatorViewModel = {
        let vm = JournalCreatorViewModel()
        vm.goalType = false
        return vm
    }()
    EmotionInputView(viewModel: viewModel, path: .constant(NavigationPath()))
}
