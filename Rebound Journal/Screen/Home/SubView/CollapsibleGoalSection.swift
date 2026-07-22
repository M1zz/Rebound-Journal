//
//  CollapsibleGoalSection.swift
//  Rebound Journal
//
//  Created by Claude on 11/15/25.
//

import SwiftUI

/// 접을 수 있는 목표 섹션
struct CollapsibleGoalSection: View {
    let subGoals: [SubGoalData]
    let journals: [JournalData]
    @Binding var isExpanded: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var showAddGoalSheet = false
    @State private var newGoalText = ""

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더 (토글 버튼 + 추가 버튼)
            HStack {
                Button(action: {
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundStyle(.blue)
                        Text("목표 현황 (\(subGoals.count))")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.primary)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 22, weight: .semibold))
                    }
                }

                Spacer()

                // 목표 추가 버튼
                Button(action: {
                    showAddGoalSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue)
                }
            }

            // 목표 그리드 (접혔을 때 숨김)
            if isExpanded {
                LazyVGrid(columns: columns, spacing: 16) {
                    // 목표 없는 저널들을 위한 카테고리
                    let noGoalCount = journals.count(where: { $0.subGoal == nil || $0.subGoal?.isEmpty == true })
                    if noGoalCount > 0 {
                        goalCell(["목표 없음": noGoalCount])
                    }

                    // 기존 목표들
                    ForEach(subGoals, id: \.self) { item in
                        let text = item.goalText ?? "목표 없음"
                        let count = journals.count(where: { $0.subGoal == item.goalText })
                        goalCell([text: count])
                    }

                    // 목표도 저널도 없는 경우에만 안내 메시지 표시
                    if subGoals.isEmpty && journals.isEmpty {
                        Text("목표를 생성해주세요!")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                            .padding(.top, 20)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showAddGoalSheet) {
            AddGoalSheet(newGoalText: $newGoalText, onSave: {
                saveNewGoal()
            })
            .presentationDetents([.height(250)])
        }
    }

    private func saveNewGoal() {
        guard !newGoalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let newGoal = SubGoalData(goalText: newGoalText)
        modelContext.insert(newGoal)
        try? modelContext.save()

        newGoalText = ""
        showAddGoalSheet = false
    }

    /// 목표 리스트 셀
    private func goalCell(_ data: [String: Int]) -> some View {
        var highlightColor: Color = .gray

        if let count = data.values.first {
            switch count {
            case 0..<3:
                highlightColor = Color("GoalFreqLow")
            case 3..<8:
                highlightColor = Color("GoalFreqMid")
            case 8...:
                highlightColor = Color("GoalFreqHigh")
            default:
                break
            }
        }

        return VStack(alignment: .leading, spacing: 8) {
            if let goal = data.keys.first,
               let count = data.values.first {
                Text(goal)
                    .lineLimit(1)
                    .foregroundStyle(Color("DashboardTitle"))
                    .font(.system(size: 22))
                    .minimumScaleFactor(0.7)
                HStack {
                    Spacer()
                    Text("\(count)번")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color("DashboardTitle"))
                }
            } else {
                Text("데이터 없음")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(highlightColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// 목표 추가 시트
struct AddGoalSheet: View {
    @Binding var newGoalText: String
    @Environment(\.dismiss) private var dismiss
    let onSave: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("새로운 목표")
                    .font(.system(size: 22, weight: .bold))
                    .padding(.top)

                TextField("목표를 입력하세요", text: $newGoalText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Button("취소") {
                        newGoalText = ""
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundStyle(.primary)
                    .cornerRadius(10)

                    Button("추가") {
                        onSave()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(Color("TextColor"))
                    .cornerRadius(10)
                    .disabled(newGoalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)

                Spacer()
            }
        }
    }
}

#Preview {
    @Previewable @State var isExpanded = true
    CollapsibleGoalSection(
        subGoals: [],
        journals: [],
        isExpanded: $isExpanded
    )
    .padding()
}
