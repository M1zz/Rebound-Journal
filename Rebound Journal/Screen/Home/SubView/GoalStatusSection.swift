//
//  GoalStatusSection.swift
//  Rebound Journal
//
//  Created by Claude on 11/20/25.
//

import SwiftUI

/// 목표 현황 섹션 (항상 표시)
struct GoalStatusSection: View {
    let subGoals: [SubGoalData]
    let journals: [JournalData]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var manager: DataManager
    @State private var showAddGoalSheet = false
    @State private var newGoalText = ""

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    // 시도 횟수가 많은 순서로 정렬된 목표들
    var sortedGoals: [SubGoalData] {
        subGoals.sorted { goal1, goal2 in
            let count1 = journals.count(where: { $0.subGoal == goal1.goalText })
            let count2 = journals.count(where: { $0.subGoal == goal2.goalText })
            return count1 > count2
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Text("목표 현황 (\(subGoals.count))")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                // 목표 추가 버튼
                Button(action: {
                    showAddGoalSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }

            // 목표 그리드
            LazyVGrid(columns: columns, spacing: 20) {
                // 목표 없는 저널들을 위한 카테고리
                let noGoalCount = journals.count(where: { $0.subGoal == nil || $0.subGoal?.isEmpty == true })
                if noGoalCount > 0 {
                    goalCell(goalName: DataSentinel.noGoal, count: noGoalCount)
                }

                // 시도 횟수가 많은 순서로 정렬된 목표들
                ForEach(sortedGoals, id: \.self) { item in
                    let text = item.goalText ?? DataSentinel.noGoal
                    let count = journals.count(where: { $0.subGoal == item.goalText })
                    goalCell(goalName: text, count: count)
                }

                // 목표도 저널도 없는 경우에만 안내 메시지 표시
                if subGoals.isEmpty && journals.isEmpty {
                    Text("목표를 생성해주세요!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                        .frame(maxWidth: .infinity)
                        .gridCellColumns(2)
                }
            }
        }
        .padding()
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
    private func goalCell(goalName: String, count: Int) -> some View {
        var highlightColor: Color = .gray

        switch count {
        case 0..<3:
            highlightColor = .goalFreqLow
        case 3..<8:
            highlightColor = .goalFreqMid
        case 8...:
            highlightColor = .goalFreqHigh
        default:
            break
        }

        return Button {
            // 목표를 선택하고 타임라인 화면으로 이동
            manager.selectedGoal = goalName
            manager.fullScreenMode = .goalTimelineView
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // 목표 제목
                Text(DisplayText.goalName(goalName))
                    .lineLimit(1)
                    .foregroundStyle(.dashboardTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // 구분선
                Divider()
                    .background(Color.white.opacity(0.3))

                // 시도 횟수
                HStack {
                    Image(systemName: "target")
                        .font(.caption)
                        .foregroundStyle(.dashboardTitle.opacity(0.7))

                    Spacer()

                    Text("\(count)번")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundStyle(.dashboardTitle)
                }
            }
            .padding(12)
            .frame(minHeight: 90)
            .background(
                ZStack {
                    // 배경
                    RoundedRectangle(cornerRadius: 12)
                        .fill(highlightColor)

                    // 그라데이션 오버레이 (입체감)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                // 테두리
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: highlightColor.opacity(0.3), radius: 8, x: 0, y: 4)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Goal Timeline View

/// 특정 목표의 저널들을 시간순으로 보여주는 타임라인
public struct GoalTimelineView: View {
    let goalName: String
    let journals: [JournalData]
    @EnvironmentObject var manager: DataManager

    var filteredJournals: [JournalData] {
        if goalName == DataSentinel.noGoal {
            return journals.filter {
                $0.isValidForDisplay &&
                ($0.subGoal == nil || $0.subGoal?.isEmpty == true)
            }
        } else {
            return journals.filter {
                $0.isValidForDisplay &&
                $0.subGoal == goalName
            }
        }
    }

    var groupedByDate: [Date: [JournalData]] {
        Dictionary(grouping: filteredJournals) { journal in
            Calendar.current.startOfDay(for: journal.dateUnwrapped)
        }
    }

    var sortedDates: [Date] {
        groupedByDate.keys.sorted(by: >)
    }

    // 통계 계산
    var statistics: GoalStatistics {
        GoalStatistics(journals: filteredJournals)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Button {
                    manager.fullScreenMode = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text(DisplayText.goalName(goalName))
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("\(filteredJournals.count)개의 기록")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 균형을 위한 투명 버튼
                Color.clear
                    .frame(width: 32, height: 32)
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            // 타임라인
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if filteredJournals.isEmpty {
                        EmptyGoalTimelineView(goalName: goalName)
                    } else {
                        // 통계 섹션
                        GoalStatisticsView(statistics: statistics)
                            .padding(.horizontal)
                            .padding(.top, 12)

                        // 타임라인
                        ForEach(sortedDates, id: \.self) { date in
                            if let items = groupedByDate[date] {
                                DateSection(date: date, items: items)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    // 하단 여백
                    Color.clear.frame(height: 50)
                }
                .padding(.top, 8)
            }
        }
    }
}

/// 빈 목표 타임라인 뷰
struct EmptyGoalTimelineView: View {
    let goalName: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("\(DisplayText.goalName(goalName))에 대한")
                .font(.body)
                .foregroundStyle(.secondary)

            Text("기록이 없어요")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("슛-쏘기를 통해 첫 기록을 남겨보세요!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - Goal Statistics

/// 목표 통계 데이터
struct GoalStatistics {
    let totalAttempts: Int
    let successCount: Int
    let failureCount: Int
    let successRate: Double
    let recentStreak: (type: String, count: Int) // DataSentinel.success / .failure
    let recentTrend: String // DataSentinel.uptrend / .downtrend / .steady

    init(journals: [JournalData]) {
        let sorted = journals.sorted { $0.dateUnwrapped < $1.dateUnwrapped }

        self.totalAttempts = sorted.count
        self.successCount = sorted.filter { $0.isGoalIn == true }.count
        self.failureCount = sorted.filter { $0.isGoalIn == false }.count
        self.successRate = totalAttempts > 0 ? Double(successCount) / Double(totalAttempts) * 100 : 0

        // 최근 연속 기록 계산
        var streakType = ""
        var streakCount = 0
        if let lastJournal = sorted.last {
            let isSuccess = lastJournal.isGoalIn == true
            streakType = isSuccess ? DataSentinel.success : DataSentinel.failure

            for journal in sorted.reversed() {
                if (journal.isGoalIn == true) == isSuccess {
                    streakCount += 1
                } else {
                    break
                }
            }
        }
        self.recentStreak = (streakType, streakCount)

        // 최근 추세 계산 (최근 5개와 그 이전 5개 비교)
        if sorted.count >= 10 {
            let recent5 = sorted.suffix(5)
            let previous5 = sorted.dropLast(5).suffix(5)

            let recentSuccessRate = Double(recent5.filter { $0.isGoalIn == true }.count) / 5.0
            let previousSuccessRate = Double(previous5.filter { $0.isGoalIn == true }.count) / 5.0

            if recentSuccessRate > previousSuccessRate + 0.2 {
                self.recentTrend = DataSentinel.uptrend
            } else if recentSuccessRate < previousSuccessRate - 0.2 {
                self.recentTrend = DataSentinel.downtrend
            } else {
                self.recentTrend = DataSentinel.steady
            }
        } else if sorted.count >= 3 {
            let recent = sorted.suffix(3)
            let successCount = recent.filter { $0.isGoalIn == true }.count
            if successCount >= 2 {
                self.recentTrend = DataSentinel.uptrend
            } else if successCount == 0 {
                self.recentTrend = DataSentinel.downtrend
            } else {
                self.recentTrend = DataSentinel.steady
            }
        } else {
            self.recentTrend = DataSentinel.notEnoughData
        }
    }
}

/// 목표 통계 뷰
struct GoalStatisticsView: View {
    let statistics: GoalStatistics

    var trendColor: Color {
        switch statistics.recentTrend {
        case DataSentinel.uptrend: return .green
        case DataSentinel.downtrend: return .red
        default: return .orange
        }
    }

    var trendIcon: String {
        switch statistics.recentTrend {
        case DataSentinel.uptrend: return "arrow.up.right"
        case DataSentinel.downtrend: return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // 타이틀
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                Text("목표 통계")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }

            // 성공률 원형 차트
            HStack(spacing: 20) {
                // 원형 프로그레스
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: statistics.successRate / 100)
                        .stroke(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(Int(statistics.successRate))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Text("성공률")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // 통계 정보
                VStack(alignment: .leading, spacing: 12) {
                    StatRow(icon: "checkmark.circle.fill",
                           iconColor: .green,
                           label: String(localized: "성공"),
                           value: String(localized: "\(statistics.successCount)회"))

                    StatRow(icon: "xmark.circle.fill",
                           iconColor: .red,
                           label: String(localized: "실패"),
                           value: String(localized: "\(statistics.failureCount)회"))

                    StatRow(icon: "target",
                           iconColor: .blue,
                           label: String(localized: "총 시도"),
                           value: String(localized: "\(statistics.totalAttempts)회"))
                }
            }
            .padding(.vertical, 8)

            // 최근 기록 & 추세
            HStack(spacing: 12) {
                // 연속 기록
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.subheadline)
                        .foregroundStyle(statistics.recentStreak.type == DataSentinel.success ? .orange : .gray)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("연속 \(DisplayText.outcome(statistics.recentStreak.type))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(statistics.recentStreak.count)회")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // 추세
                HStack(spacing: 8) {
                    Image(systemName: trendIcon)
                        .font(.subheadline)
                        .foregroundStyle(trendColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("최근 추세")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(DisplayText.trend(statistics.recentTrend))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .padding(.bottom, 16)
    }
}

/// 통계 행 컴포넌트
struct StatRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    GoalStatusSection(
        subGoals: [],
        journals: []
    )
    .padding()
}
