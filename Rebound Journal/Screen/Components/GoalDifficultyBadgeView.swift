//
//  GoalDifficultyBadgeView.swift
//  Rebound Journal
//
//  Created by Claude on 11/17/25.
//

import SwiftUI

struct GoalDifficultyBadgeView: View {
    let difficulty: GoalDifficulty
    let compact: Bool

    init(difficulty: GoalDifficulty, compact: Bool = false) {
        self.difficulty = difficulty
        self.compact = compact
    }

    var body: some View {
        if compact {
            compactView
        } else {
            fullView
        }
    }

    // 간단한 배지 뷰
    private var compactView: some View {
        HStack(spacing: 6) {
            Text(difficulty.difficultyLevel.emoji)
                .font(.system(size: 14))

            Text(difficulty.difficultyLevel.title)
                .font(.system(size: 13).bold())
                .foregroundStyle(difficultyColor)

            Text("\(difficulty.successRatePercent)%")
                .font(.system(size: 12))
                .foregroundStyle(Color("Description"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(difficultyColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // 전체 카드 뷰
    private var fullView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(difficulty.goal)
                        .font(.system(size: 18).bold())
                        .foregroundStyle(Color("Default"))

                    HStack(spacing: 6) {
                        Text(difficulty.difficultyLevel.emoji)
                            .font(.system(size: 16))

                        Text(difficulty.difficultyLevel.title)
                            .font(.system(size: 15).bold())
                            .foregroundStyle(difficultyColor)
                    }
                }

                Spacer()

                // 성공률 원형 표시
                ZStack {
                    Circle()
                        .stroke(difficultyColor.opacity(0.2), lineWidth: 6)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: difficulty.successRate)
                        .stroke(difficultyColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(difficulty.successRatePercent)%")
                        .font(.system(size: 14).bold())
                        .foregroundStyle(difficultyColor)
                }
            }

            // 통계
            HStack(spacing: 16) {
                StatPill(
                    icon: "checkmark.circle.fill",
                    label: "성공",
                    value: "\(difficulty.successCount)회",
                    color: Color.green
                )

                StatPill(
                    icon: "target",
                    label: "총 시도",
                    value: "\(difficulty.totalAttempts)회",
                    color: Color.blue
                )
            }

            // 추천 메시지
            if difficulty.shouldAdjust {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Color("Description").opacity(0.3))

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(difficultyColor)

                        Text(difficulty.recommendation)
                            .font(.system(size: 14))
                            .foregroundStyle(Color("Default"))
                            .lineSpacing(4)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.cellColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(difficultyColor.opacity(0.3), lineWidth: 2)
        )
    }

    private var difficultyColor: Color {
        switch difficulty.difficultyLevel {
        case .tooEasy:
            return Color.blue
        case .appropriate:
            return Color.green
        case .challenging:
            return Color.orange
        case .tooHard:
            return Color.red
        }
    }
}

/// 통계 필
struct StatPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Color("Description"))

                Text(value)
                    .font(.system(size: 13).bold())
                    .foregroundStyle(Color("Default"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// 목표 난이도 리스트 뷰
struct GoalDifficultyListView: View {
    let difficulties: [GoalDifficulty]
    let showOnlyProblematic: Bool

    init(difficulties: [GoalDifficulty], showOnlyProblematic: Bool = false) {
        self.difficulties = difficulties
        self.showOnlyProblematic = showOnlyProblematic
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 타이틀
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.blue)

                Text(showOnlyProblematic ? "주의가 필요한 목표" : "목표 난이도 분석")
                    .font(.system(size: 24).bold())
                    .foregroundStyle(Color("Default"))

                Spacer()
            }
            .padding(.horizontal, 4)

            let filteredDifficulties = showOnlyProblematic
                ? difficulties.filter { $0.shouldAdjust }
                : difficulties

            if filteredDifficulties.isEmpty {
                emptyState
            } else {
                ForEach(filteredDifficulties, id: \.goal) { difficulty in
                    GoalDifficultyBadgeView(difficulty: difficulty)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: showOnlyProblematic ? "checkmark.circle.fill" : "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(showOnlyProblematic ? Color.green : Color("Description"))

            Text(showOnlyProblematic ? "모든 목표가 적절해요!" : "아직 분석할 데이터가 없어요")
                .font(.system(size: 16))
                .foregroundStyle(Color("Description"))

            if !showOnlyProblematic {
                Text("최소 3회 이상 시도한 목표부터 분석됩니다")
                    .font(.system(size: 14))
                    .foregroundStyle(Color("Description"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    let sampleDifficulty = GoalDifficulty(
        goal: "아침 운동하기",
        totalAttempts: 15,
        successCount: 3,
        successRate: 0.2,
        difficultyLevel: .tooHard,
        recommendation: "이 목표가 너무 어려울 수 있어요. 더 작은 단계로 나누거나, 목표를 조정하는 걸 고려해보세요.",
        shouldAdjust: true
    )

    return ScrollView {
        VStack(spacing: 20) {
            GoalDifficultyBadgeView(difficulty: sampleDifficulty, compact: true)

            GoalDifficultyBadgeView(difficulty: sampleDifficulty, compact: false)

            GoalDifficultyListView(difficulties: [sampleDifficulty])
        }
        .padding()
    }
    .background(Color.backgroundColor)
}
