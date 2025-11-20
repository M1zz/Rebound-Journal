//
//  SelectTargetView.swift
//  Rebound Journal
//
//  Created by 황석현 on 5/5/25.
//

import SwiftUI
import SwiftData

struct SelectTargetView: View {
    // Shared Dependencies
    @ObservedObject var viewModel: JournalCreatorViewModel
    // UI State
    @State var subGoals: [SubGoalData]
    @State private var selectedGoal: SubGoalData?
    @Binding var path: NavigationPath
    
    var body: some View {
        VStack {
            // 질문
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("어떤 슛을 남겨볼까요?")
                        .font(.system(size: 25).bold())
                        .foregroundStyle(Color("Default"))
                    Spacer()
                }
                HStack {
                    Text("목표에 대한 슛인가요?")
                        .font(.system(size: 18))
                        .foregroundStyle(Color("Description"))
                    Spacer()
                }
            }
            .padding(.vertical)
            
            // 목표 리스트
            VStack(alignment: .leading, spacing: 8) {
                ForEach(subGoals, id: \.self) { item in
                    if let text = item.goalText {
                        HStack {
                            Text(text)
                                .padding()
                                .foregroundStyle(Color("Default"))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.cellColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedGoal == item ? Color.accentColor : .clear, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            if selectedGoal == item {
                                // 이미 선택된 목표를 다시 탭하면 선택 해제
                                selectedGoal = nil
                                viewModel.subGoal = nil
                            } else {
                                // 다른 목표를 탭하면 새로 선택
                                selectedGoal = item
                                viewModel.subGoal = item.goalText
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            StepControlView(
                hasBackButton: false,
                canGoNext: true,
                onNext: {
                    onNextTapped()
                },
                nextButtonText: selectedGoal != nil ? "다음으로" : "건너뛰기"
            )
        }
        .padding()
        .onAppear {
            debugPrint("TargetCount : \(subGoals.count)")
        }
    }
    
    private func onNextTapped() {
        if selectedGoal != nil {
            // 목표를 선택한 경우: 선택된 목표 유지하고 다음으로
            debugPrint("목표 선택됨: \(viewModel.subGoal ?? "없음")")
            path.append(JournalCreationState.shoot)
        } else {
            // 건너뛰기: 목표 선택 없이 다음으로
            debugPrint("목표 선택 건너뛰기")
            viewModel.subGoal = nil
            path.append(JournalCreationState.shoot)
        }
    }
}

#Preview {
    SelectTargetView(viewModel: JournalCreatorViewModel(), subGoals: [], path: .constant(NavigationPath()))
}
