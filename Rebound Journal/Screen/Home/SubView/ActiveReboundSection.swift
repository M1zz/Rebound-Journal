//
//  ActiveReboundSection.swift
//  Rebound Journal
//
//  Created by Claude on 11/14/25.
//

import SwiftUI
import SwiftData

/// 활성 리바운드(해결되지 않은 실패) 섹션 - 가로 스크롤
struct ActiveReboundSection: View {
    let activeRebounds: [JournalData]
    let onRetry: (JournalData) -> Void

    var body: some View {
        if !activeRebounds.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // 헤더
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                    Text("해결하고 싶은 실패 (\(activeRebounds.count))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)

                // 가로 스크롤 카드들
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(activeRebounds, id: \.id) { rebound in
                            ActiveReboundCard(rebound: rebound, onRetry: {
                                onRetry(rebound)
                            })
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
    }
}

/// 개별 활성 리바운드 카드
struct ActiveReboundCard: View {
    let rebound: JournalData
    let onRetry: () -> Void

    var daysAgo: String {
        guard let date = rebound.date else { return "" }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 {
            return "오늘"
        } else if days == 1 {
            return "어제"
        } else {
            return "\(days)일 전"
        }
    }

    var freshnessColor: Color {
        guard let date = rebound.date else { return .red }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 3 {
            return .red // 신선
        } else if days < 7 {
            return .orange // 주의
        } else {
            return .gray // 오래됨
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 목표 & 날짜
            HStack(spacing: 6) {
                Circle()
                    .fill(freshnessColor)
                    .frame(width: 6, height: 6)
                Text(rebound.subGoalUnwrapped)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Text(daysAgo)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // 대안 (인라인)
            if !rebound.nextPlanUnwrapped.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Text("💡")
                        .font(.system(size: 12))
                    Text(rebound.nextPlanUnwrapped)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            // 다시 도전하기 버튼 (컴팩트)
            Button(action: onRetry) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("도전")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(freshnessColor)
                .cornerRadius(6)
            }
        }
        .frame(width: 200)
        .padding(10)
        .background(Color.red.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(freshnessColor.opacity(0.3), lineWidth: 1.5)
        )
    }
}

#Preview {
    let sampleRebound = JournalData(
        id: "1",
        date: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
        hasDeleted: false,
        isGoalIn: false,
        emotionValue: 2,
        emotionText: "실망스러운",
        review: "야식을 참지 못했어요",
        nextPlan: "물을 많이 마시고 일찍 자기",
        isRebounded: false,
        purpose: "건강",
        mainGoal: "다이어트",
        subGoal: "야식 참기",
        linkedReboundId: nil,
        isResolved: false
    )

    ActiveReboundSection(activeRebounds: [sampleRebound], onRetry: { _ in })
        .padding()
}
