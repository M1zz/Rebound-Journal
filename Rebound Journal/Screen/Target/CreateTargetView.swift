//
//  CreateTargetView.swift
//  Rebound Journal
//
//  Created by 황석현 on 5/5/25.
//

import SwiftUI
import SwiftData

struct CreateTargetView: View {
    // Shared Dependencies
    @Environment(\.modelContext)private var modelContext
    @EnvironmentObject var manager: DataManager
    @ObservedObject var viewModel: JournalCreatorViewModel
    @FocusState private var isTextEditorFocused: Bool
    // UI State
    @State var targetText: String = ""
    @Binding var path: NavigationPath
    
    var body: some View {
        // 전체
        VStack {
            // MARK: 안내문구 1
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("이번 슈팅에 대한")
                        .font(.system(size: 22))
                    Spacer()
                }
                HStack {
                    Text("목표를 생성할까요?")
                        .font(.system(size: 28).bold())
                    Spacer()
                }
            }
            .padding(.bottom)
            
            // MARK: 목표 입력
            VStack(alignment: .leading) {
                Text("목표가 눈에 보이면, 동기부여의 효과가 있어요!")
                    .font(.system(size: 17))
                HStack {
                    TextField("목표를 적어주세요", text: $targetText)
                        .font(.system(size: 17))
                        .foregroundStyle(Color("Default"))
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.leading)
                        .focused($isTextEditorFocused)
                        .onChange(of: targetText) { _, newValue in
                            if newValue.count > 30 {
                                targetText = String(newValue.prefix(30))
                            }
                        }
                    Text("\(targetText.count)/30")
                        .font(.system(size: 22))
                        .foregroundStyle(Color("Description"))
                        .padding(.horizontal, 5)
                }
                .frame(height: 65)
                .padding(5)
                .background(Color("CellColor"))
                .clipShape(.rect(cornerRadius: 12))
            }
            
            Spacer()
            
            // MARK: 안내문구 2
            VStack(alignment: .center, spacing: 4) {
                Text("다음 슈팅 때 선택할 수 있어요.")
                    .font(.system(size: 17))
                Text("언제든지 다시 확인할 수 있어요.")
                    .font(.system(size: 17))
            }
            .padding(.bottom, 40)
            
            StepControlView(
                hasBackButton: true,
                canGoNext: true,  // 건너뛰기도 가능하도록 항상 활성화
                onPrevious: {
                    onPreviousTapped()
                },
                onNext: {
                    onNextTapped()
                },
                nextButtonText: targetText.isEmpty ? "건너뛰기" : "저장하기"
            )
        }
        .padding()
        .onAppear { isTextEditorFocused = true }
        .onTapGesture { isTextEditorFocused = false }
    }
    
    private func onPreviousTapped() {
        path.removeLast()
    }
    
    private func onNextTapped() {
        if targetText.isEmpty {
            // 건너뛰기: 목표를 저장하지 않고 다음 단계로
            viewModel.subGoal = nil
            path.append(JournalCreationState.selectSubGoal)
        } else {
            // 저장하기: 목표를 저장하고 다음 단계로
            viewModel.subGoal = targetText
            path.append(JournalCreationState.selectSubGoal)
            viewModel.saveJournal(context: modelContext)
            viewModel.saveSubGoal(context: modelContext)
            manager.fullScreenMode = nil
        }
    }
}

#Preview("!targetText.isEmpty") {
    CreateTargetView(viewModel: JournalCreatorViewModel(), path: .constant(NavigationPath()))
}
#Preview("targetText.isEmpty") {
    CreateTargetView(viewModel: JournalCreatorViewModel(), path: .constant(NavigationPath()))
}
