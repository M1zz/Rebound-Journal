//
//  JournalList.swift
//  Rebound Journal
//
//  Created by 황석현 on 8/19/25.
//

import SwiftUI
import SwiftData

struct JournalList: View {
    
    @ObservedObject var viewModel: HomeViewModel
    
    @Query private var journals: [JournalData]
    
    var body: some View {
        ScrollView {
            let data = viewModel.fetchReboundedJournalInfo(journals: journals)
            LazyVStack {
                ForEach(data) { journal in
                    Group {
                        targetInfo(target: journal.subGoal, type: journal.isGoalIn, linkedReboundId: journal.linkedReboundId)
                        journalInfo(journal: journal.emotionText, description: journal.nextPlan, date: journal.date, linkedReboundId: journal.linkedReboundId)
                    }
                }
            }
            .padding()
        }
    }
    
    private func targetInfo(target: String?, type: Bool?, linkedReboundId: String?) -> some View {
        let title = target ?? "목표 제목"
        let isGoal = type ?? false
        let hasLinkedRebound = !(linkedReboundId ?? "").isEmpty

        return HStack {
            Text("목표")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.accentColor)
                .multilineTextAlignment(.center)

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .multilineTextAlignment(.center)

            Spacer()

            // 실패 극복 뱃지
            if isGoal && hasLinkedRebound {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 12))
                    Text("실패 극복")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }

            Text(isGoal ? "골인" : "리바운드")
                .font(.custom("Pretendard", size: 13).weight(.semibold))
                .foregroundStyle(.accent)
                .multilineTextAlignment(.center)
                .padding(10)
                .frame(height: 26, alignment: .center)
                .background(Color(red: 1, green: 0.94, blue: 0.9))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }
    private func journalInfo(journal: String?, description: String?, date: Date?, linkedReboundId: String?) -> some View {
        let title = journal ?? "저널 제목"
        let desc = description ?? "느낀 점..."
        let createdAt = date ?? Date()
        let hasLinkedRebound = !(linkedReboundId ?? "").isEmpty

        return VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
            // TODO: 색상 적용
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 실패 극복 메시지
            if hasLinkedRebound {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                    Text("이전 실패를 극복한 성공이에요!")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            Text(desc)
                .font(.system(size: 13, weight: .regular))
            // TODO: 색상 적용
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(createdAt.formatted(date: .numeric, time: .shortened))
                .font(.system(size: 13, weight: .regular))
            // TODO: 색상 적용
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(hasLinkedRebound ? Color.green.opacity(0.05) : Color.cellColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 20)
    }
}

#Preview {
    JournalList(viewModel: HomeViewModel())
}
