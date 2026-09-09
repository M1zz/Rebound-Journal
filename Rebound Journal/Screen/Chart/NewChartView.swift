//
//  NewChartView.swift
//  Rebound Journal
//
//  Created by Claude on 11/20/25.
//

import SwiftUI
import Charts
import SwiftData

struct NewChartView: View {

    @EnvironmentObject var manager: DataManager
    @StateObject var viewModel: ChartViewModel
    @Query private var journals: [JournalData]

    @State private var statisticsInsight: StatisticsInsight?

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    ModalHeaderBar(title: String(localized: "통계")) {
                        manager.fullScreenMode = nil
                    }

                    // 날짜 선택
                    dateSelector
                        .padding(.horizontal)

                    if let insight = statisticsInsight {
                        // 핵심 지표
                        keyMetricsSection(insight: insight)
                            .padding(.horizontal)

                        // 인사이트
                        insightSection(insight: insight)
                            .padding(.horizontal)

                        // 목표별 성과
                        goalPerformanceSection(insight: insight)
                            .padding(.horizontal)

                        // 성과 차트
                        performanceChart
                            .frame(height: proxy.size.height * 0.25)
                            .padding(.horizontal)

                        // 상세 기록
                        detailedRecords
                            .padding(.horizontal)
                    } else {
                        Text("데이터를 불러오는 중...")
                            .foregroundStyle(.secondary)
                            .padding()
                    }

                    // 하단 여백
                    Color.clear.frame(height: 50)
                }
            }
        }
        .onAppear {
            loadStatistics()
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            loadStatistics()
        }
        .sheet(isPresented: $viewModel.isDatePickerShown) {
            ChartDateSelector(viewModel: viewModel)
        }
    }

    // MARK: - Components

    private var dateSelector: some View {
        Button {
            viewModel.isDatePickerShown.toggle()
        } label: {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.primary)
                Text(viewModel.selectedDate.yyyyMMdd)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }

    private func keyMetricsSection(insight: StatisticsInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("핵심 지표")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricCard(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .green,
                    title: String(localized: "성공률"),
                    value: String(format: "%.1f%%", insight.successRate)
                )

                metricCard(
                    icon: "target",
                    iconColor: .blue,
                    title: String(localized: "전체 시도"),
                    value: String(localized: "\(insight.totalAttempts)회")
                )

                metricCard(
                    icon: "flame.fill",
                    iconColor: .orange,
                    title: String(localized: "도전 중"),
                    value: String(localized: "\(insight.activeRebounds)개")
                )

                metricCard(
                    icon: "arrow.uturn.up.circle.fill",
                    iconColor: .purple,
                    title: String(localized: "극복률"),
                    value: String(format: "%.1f%%", insight.recoveryRate)
                )
            }
        }
    }

    private func metricCard(icon: String, iconColor: Color, title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private func insightSection(insight: StatisticsInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("인사이트")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                // 개선 추세
                insightRow(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .green,
                    text: insight.improvementTrend
                )

                // 가장 어려운 목표
                if let topChallenge = insight.topChallenge {
                    insightRow(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .orange,
                        text: String(localized: "가장 어려운 목표: \(DisplayText.goalName(topChallenge))")
                    )
                }

                // 성공률 기반 메시지
                if insight.successRate >= 70 {
                    insightRow(
                        icon: "star.fill",
                        iconColor: .yellow,
                        text: String(localized: "훌륭해요! 높은 성공률을 유지하고 있어요")
                    )
                } else if insight.successRate >= 50 {
                    insightRow(
                        icon: "hand.thumbsup.fill",
                        iconColor: .blue,
                        text: String(localized: "좋아요! 절반 이상 성공하고 있어요")
                    )
                } else if insight.totalAttempts > 0 {
                    insightRow(
                        icon: "leaf.fill",
                        iconColor: .green,
                        text: String(localized: "도전하는 용기가 성장의 시작이에요")
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }

    private func insightRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.primary)

            Spacer()
        }
    }

    private func goalPerformanceSection(insight: StatisticsInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("목표별 성과")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)

            if insight.goalPerformances.isEmpty {
                Text("이번 달 기록이 없어요")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            } else {
                VStack(spacing: 10) {
                    ForEach(insight.goalPerformances) { performance in
                        goalPerformanceRow(performance: performance)
                    }
                }
            }
        }
    }

    private func goalPerformanceRow(performance: GoalPerformance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(performance.goalName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(performance.totalAttempts)회")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))

                    // Success
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: geo.size.width * (performance.successRate / 100))
                }
            }
            .frame(height: 8)

            HStack {
                Label("\(performance.successCount)회", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)

                Spacer()

                Label("\(performance.failureCount)회", systemImage: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)

                Spacer()

                Text(String(format: "%.0f%%", performance.successRate))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private var performanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("월별 성과")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)

            if viewModel.journalCharts.isEmpty {
                Text("이번 달 데이터가 없어요")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            } else {
                Chart {
                    ForEach(viewModel.journalCharts) { item in
                        BarMark(
                            x: .value("Date", item.date.dayLabel),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(item.isGoalIn ? Color.green : Color.orange)
                    }
                }
                .chartLegend(.hidden)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }

    private var detailedRecords: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("상세 기록")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)

            if viewModel.groupedJournals.isEmpty {
                Text("기록이 없어요!")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            } else {
                ForEach(viewModel.groupedJournals, id: \.key) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.key)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(.leading, 5)

                        ForEach(group.value) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: item.isGoalIn ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                                        .foregroundStyle(item.isGoalIn ? .green : .orange)

                                    Text(item.isGoalIn ? String(localized: "골인") : String(localized: "리바운드"))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.primary)

                                    Text("·")
                                        .foregroundStyle(.secondary)

                                    Text(item.emotionText)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                }

                                Text(item.review)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.primary)

                                if !item.nextPlan.isEmpty {
                                    Divider()
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.yellow)
                                        Text(item.nextPlan)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadStatistics() {
        viewModel.fetch(from: Array(journals))
        statisticsInsight = StatisticsAnalyzer.analyze(
            journals: Array(journals),
            selectedDate: viewModel.selectedDate
        )
    }
}

#Preview {
    NewChartView(viewModel: ChartViewModel())
        .environmentObject(DataManager())
}
