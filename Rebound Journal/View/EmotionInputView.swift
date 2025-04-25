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
        viewModel.emotionValue != nil && (viewModel.emotionText != [] && viewModel.emotionText != nil)}
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
            StepControlView(onPrevious: {
                viewModel.currentStep = .shoot
            }, onNext: {
                viewModel.currentStep = .review
            }, canGoNext: canGoNext,
            nextButtonText: "다음으로")
        }
    }
    
    /// 세로형 슬라이더
    private var verticalSlider: some View {
        VStack {
            Text("부정")
            ZStack {
                Color.clear
                    .frame(width: 30, height: 400)
                    .overlay(
                        Slider(value: $sliderValue, in: 0...3, step: 1)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 400, height: 30))
            }
            .animation(.easeIn(duration: 0.3), value: sliderValue)
            Text("긍정")
        }
    }
}

#Preview("EmotionInputView: GoalIn") {
    let viewModel: JournalCreatorViewModel = {
           let vm = JournalCreatorViewModel()
           vm.goalType = true
           return vm
       }()
    EmotionInputView(viewModel: viewModel)
}

#Preview("EmotionInputView: Rebound") {
    let viewModel: JournalCreatorViewModel = {
           let vm = JournalCreatorViewModel()
           vm.goalType = false
           return vm
       }()
    EmotionInputView(viewModel: viewModel)
}
