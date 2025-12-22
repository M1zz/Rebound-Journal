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
    @State private var selectedRebound: JournalData?

    var body: some View {
        if !activeRebounds.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // 헤더
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Text("성장의 실마리 (\(activeRebounds.count))")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)

                // 가로 스크롤 카드들
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(activeRebounds, id: \.id) { rebound in
                            ActiveReboundCard(
                                rebound: rebound,
                                onRetry: { onRetry(rebound) },
                                onTap: { selectedRebound = rebound }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
            .sheet(item: $selectedRebound) { rebound in
                ReboundDetailView(rebound: rebound, onRetry: {
                    selectedRebound = nil
                    onRetry(rebound)
                })
                .presentationDetents([.medium, .large])
            }
        }
    }
}

/// 개별 활성 리바운드 카드
struct ActiveReboundCard: View {
    let rebound: JournalData
    let onRetry: () -> Void
    let onTap: () -> Void

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
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(.plain)
    }

    var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 목표 & 날짜
            HStack(spacing: 6) {
                Circle()
                    .fill(freshnessColor)
                    .frame(width: 6, height: 6)
                Text(rebound.subGoalUnwrapped)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Text(daysAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 대안 (인라인)
            if !rebound.nextPlanUnwrapped.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Text("💡")
                        .font(.caption)
                    Text(rebound.nextPlanUnwrapped)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            // 다시 도전하기 버튼 (컴팩트)
            Button(action: {
                onRetry()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("도전")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color("TextColor"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(freshnessColor)
                .cornerRadius(6)
            }
            .buttonStyle(.borderless)
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

// MARK: - Rebound Detail View

/// 리바운드 상세 정보 뷰
struct ReboundDetailView: View {
    let rebound: JournalData
    let onRetry: () -> Void
    @Environment(\.dismiss) private var dismiss

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
            return .red
        } else if days < 7 {
            return .orange
        } else {
            return .gray
        }
    }

    var dateString: String {
        guard let date = rebound.date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 상태 배너
                    HStack {
                        Circle()
                            .fill(freshnessColor)
                            .frame(width: 8, height: 8)

                        Text("\(daysAgo) • 성장의 실마리")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(freshnessColor)

                        Spacer()
                    }
                    .padding()
                    .background(freshnessColor.opacity(0.1))
                    .cornerRadius(12)

                    // 목표 정보
                    VStack(alignment: .leading, spacing: 12) {
                        Label("목표", systemImage: "target")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            if !rebound.purposeUnwrapped.isEmpty {
                                Text("목적: \(rebound.purposeUnwrapped)")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }

                            if !rebound.mainGoalUnwrapped.isEmpty {
                                Text("주요 목표: \(rebound.mainGoalUnwrapped)")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }

                            Text("세부 목표: \(rebound.subGoalUnwrapped)")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // 날짜
                    VStack(alignment: .leading, spacing: 8) {
                        Label("날짜", systemImage: "calendar")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Text(dateString)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }

                    // 감정
                    if let emotionText = rebound.emotionText {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("감정", systemImage: "heart.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            Text(emotionText)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }

                    // 회고
                    if !rebound.reviewUnwrapped.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("무슨 일이 있었나요?", systemImage: "doc.text.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            Text(rebound.reviewUnwrapped)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }

                    // 다음 계획
                    if !rebound.nextPlanUnwrapped.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("성장을 위한 대안", systemImage: "lightbulb.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)

                            Text(rebound.nextPlanUnwrapped)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
                                )
                        }
                    }

                    // 다시 도전하기 버튼
                    Button(action: onRetry) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("지금 다시 도전하기")
                        }
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(freshnessColor)
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)

                    // 하단 여백
                    Color.clear.frame(height: 20)
                }
                .padding()
            }
            .navigationTitle("성장의 실마리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
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
