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
    
    // UI State
    @FocusState private var currentField: Field?
    @State var reviewText: String = ""
    @State var planText: String = ""
    var canSave: Bool {
        guard let reviewText = viewModel.reviewText else { return false }
        guard let planText = viewModel.nextPlanText else { return false }
        return !reviewText.isEmpty && !planText.isEmpty}
    var isReviewed: Bool {!reviewText.isEmpty || currentField == .review}
    var isPlaned: Bool {!planText.isEmpty || currentField == .plan}
    
    // etc
    let text = Constants.ContentText()
    let systemText = Constants.SystemText()
    
    var body: some View {
            VStack(alignment: .leading) {
                Text(viewModel.emotionText?.first ?? "감정태그")
                    .font(.system(size: 16))
                    .fontWeight(.semibold)
                    .frame(height: 35)
                    .foregroundStyle(.default)
                    .padding(.horizontal, 10)
                    .background {
                        Capsule()
                            .fill(.accent.gradient)
                    }
                
                // Reviewing Shoot
                Text(text.reviewShooting)
                    .font(.system(size: 25))
                    .fontWeight(.semibold)
                    .padding(.bottom, 3)
                    .foregroundStyle(currentField == .review ? .default : .gray)
                TextEditor(text: $reviewText)
                    .onChange(of: reviewText) { newValue in
                        viewModel.reviewText = newValue
                    }
                    .focused($currentField, equals: .review)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200, alignment: .topLeading)
                    .padding()
                    .scrollContentBackground(.hidden)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(.rect(cornerRadius: 18))
                    .overlay(alignment: .topLeading) {
                        Text(text.reviewShootingField)
                            .foregroundStyle(isReviewed ? .clear : .gray)
                            .padding()
                    }
                
                // Get NextPlan
                Text(text.whatNextPlan)
                    .font(.system(size: 25))
                    .fontWeight(.semibold)
                    .padding(.bottom, 3)
                    .foregroundStyle(currentField == .plan ? .default : .gray)
                TextEditor(text: $planText)
                    .onChange(of: planText) { newValue in
                        viewModel.nextPlanText = newValue
                    }
                    .focused($currentField, equals: .plan)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200, alignment: .topLeading)
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
            .padding()
            
            // StepControll
            StepControlView(onPrevious: {
                viewModel.currentStep = .emotion
            }, onNext: {
                manager.fullScreenMode = nil
                viewModel.saveShooting(manager: manager)
            }, canGoNext: canSave,
                            nextButtonText: systemText.saveButton)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("키보드 내리기") {
                    currentField = .none
                }
            }
        }
    }
}

#Preview {
    let mockViewModel = {
        let vm = JournalCreatorViewModel()
        vm.goalType = true
        vm.currentStep = .review
        vm.emotionValue = 1
        vm.emotionText = ["기분이 좋은"]
        return vm
    }()
    ReviewPlanView(viewModel: mockViewModel)
}
