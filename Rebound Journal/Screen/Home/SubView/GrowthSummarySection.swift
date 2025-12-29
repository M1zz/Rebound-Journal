//
//  GrowthSummarySection.swift
//  Rebound Journal
//
//  Created by Claude on 11/20/25.
//

import SwiftUI

/// 성장 요약 섹션 - 전체 성공/실패/성장의 실마리/연속일수를 보여줌
struct GrowthSummarySection: View {
    let journals: [JournalData]
    @State private var selectedPeriod: Period = .monthly

    enum Period: String, CaseIterable {
        case weekly = "주간"
        case monthly = "월간"
    }

    private var filteredJournals: [JournalData] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .weekly:
            // 최근 7일
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return journals.filter { !$0.hasDeletedUnwrapped && $0.dateUnwrapped >= weekAgo }
        case .monthly:
            // 현재 월
            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)
            return journals.filter {
                !$0.hasDeletedUnwrapped &&
                calendar.component(.year, from: $0.dateUnwrapped) == year &&
                calendar.component(.month, from: $0.dateUnwrapped) == month
            }
        }
    }

    private var successCount: Int {
        filteredJournals.filter { $0.isGoalInUnwrapped }.count
    }

    private var failureCount: Int {
        filteredJournals.filter { !$0.isGoalInUnwrapped }.count
    }

    private var activeReboundsCount: Int {
        JournalAnalyzer.getActiveRebounds(from: journals).count
    }

    private var streakDays: Int {
        let summary = JournalSummary(entries: journals)
        return summary.streak
    }

    var body: some View {
        VStack(spacing: 12) {
            // 헤더 + 세그먼트
            HStack {
                Text("나의 성장")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()

                Picker("기간", selection: $selectedPeriod) {
                    ForEach(Period.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            // 요약 카드들
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                summaryCard(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    title: "성공",
                    value: "\(successCount)개"
                )

                summaryCard(
                    icon: "arrow.counterclockwise.circle.fill",
                    iconColor: .orange,
                    title: "도전",
                    value: "\(failureCount)개"
                )

                summaryCard(
                    icon: "leaf.fill",
                    iconColor: .blue,
                    title: "성장의 실마리",
                    value: "\(activeReboundsCount)개"
                )

                summaryCard(
                    icon: "flame.fill",
                    iconColor: .red,
                    title: "연속 기록",
                    value: "\(streakDays)일"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func summaryCard(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            // 아이콘과 타이틀
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 숫자
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

#Preview {
    GrowthSummarySection(journals: [])
        .padding()
}
