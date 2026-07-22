//
//  EmotionTrendCardView.swift
//  Rebound Journal
//
//  Created by Claude on 11/17/25.
//

import SwiftUI

struct EmotionTrendCardView: View {
    let trend: EmotionTrend
    let onViewDetails: (() -> Void)?

    init(trend: EmotionTrend, onViewDetails: (() -> Void)? = nil) {
        self.trend = trend
        self.onViewDetails = onViewDetails
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("감정 상태")
                        .font(.system(size: 14))
                        .foregroundStyle(Color("Description"))

                    HStack(spacing: 8) {
                        Text(trend.overallMood.emoji)
                            .font(.system(size: 28))

                        Text(trend.overallMood.rawValue)
                            .font(.system(size: 20).bold())
                            .foregroundStyle(moodColor)
                    }
                }

                Spacer()

                // 번아웃 위험도
                VStack(spacing: 4) {
                    Text(trend.burnoutRisk.emoji)
                        .font(.system(size: 24))

                    Text(trend.burnoutRisk.title)
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(burnoutColor)
                        .frame(width: 80)
                }
            }

            // 감정 추이 미니 차트
            if !trend.recentEmotions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("최근 7일 추이")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("Description"))

                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(trend.recentEmotions.prefix(7).enumerated()), id: \.offset) { index, emotion in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(emotionColor(for: emotion.emotion))
                                    .frame(width: 20, height: barHeight(for: emotion.emotion))

                                Text(emotion.emotion.emoji)
                                    .font(.system(size: 10))
                            }
                        }

                        Spacer()
                    }
                    .frame(height: 80)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // 구분선
            Divider()
                .background(Color("Description").opacity(0.3))

            // 추천 메시지
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.pink)

                Text(trend.recommendation)
                    .font(.system(size: 15))
                    .foregroundStyle(Color("Default"))
                    .lineSpacing(4)
            }

            // 상세 보기 버튼
            if let onViewDetails = onViewDetails {
                Button(action: onViewDetails) {
                    HStack {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 14))

                        Text("감정 분석 상세 보기")
                            .font(.system(size: 15))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.backgroundColor)
                    .foregroundStyle(Color("Default"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(18)
        .background(Color.cellColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(moodColor.opacity(0.3), lineWidth: 2)
        )
        .shadow(color: Color.primary.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private func barHeight(for emotion: EmotionState) -> CGFloat {
        let baseHeight: CGFloat = 40
        switch emotion {
        case .veryPositive: return baseHeight + 20
        case .positive: return baseHeight + 10
        case .neutral: return baseHeight
        case .negative: return baseHeight - 10
        case .veryNegative: return baseHeight - 20
        }
    }

    private func emotionColor(for emotion: EmotionState) -> Color {
        switch emotion {
        case .veryPositive: return Color.green
        case .positive: return Color.green.opacity(0.7)
        case .neutral: return Color.gray
        case .negative: return Color.orange
        case .veryNegative: return Color.red
        }
    }

    private var moodColor: Color {
        emotionColor(for: trend.overallMood)
    }

    private var burnoutColor: Color {
        switch trend.burnoutRisk {
        case .none: return Color.green
        case .low: return Color.yellow
        case .moderate: return Color.orange
        case .high: return Color.red
        case .critical: return Color.red
        }
    }
}

/// 번아웃 경고 배너 (간단한 버전)
struct BurnoutWarningBannerView: View {
    let burnoutRisk: BurnoutRisk
    let message: String
    let onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Text(burnoutRisk.emoji)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 4) {
                Text(burnoutRisk.title)
                    .font(.system(size: 16).bold())
                    .foregroundStyle(Color("Default"))

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(Color("Description"))
                    .lineLimit(2)
            }

            Spacer()

            if onTap != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color("Description"))
            }
        }
        .padding(16)
        .background(riskColor.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(riskColor.opacity(0.5), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            onTap?()
        }
    }

    private var riskColor: Color {
        switch burnoutRisk {
        case .none: return Color.green
        case .low: return Color.yellow
        case .moderate: return Color.orange
        case .high, .critical: return Color.red
        }
    }
}

/// 감정 히스토리 차트 뷰
struct EmotionHistoryChartView: View {
    let history: [(date: Date, averageScore: Double)]
    let days: Int

    init(history: [(date: Date, averageScore: Double)], days: Int = 30) {
        self.history = history
        self.days = days
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("지난 \(days)일 감정 변화")
                .font(.system(size: 18).bold())
                .foregroundStyle(Color("Default"))

            if history.isEmpty {
                emptyState
            } else {
                chartView
            }
        }
        .padding(18)
        .background(Color.cellColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.flattrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(Color("Description"))

            Text("아직 데이터가 충분하지 않아요")
                .font(.system(size: 14))
                .foregroundStyle(Color("Description"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var chartView: some View {
        VStack(spacing: 8) {
            // 차트
            GeometryReader { geometry in
                let width = geometry.size.width
                let height: CGFloat = 150
                let maxScore: Double = 2.0
                let minScore: Double = -2.0

                ZStack(alignment: .leading) {
                    // 배경 그리드
                    VStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { _ in
                            Rectangle()
                                .fill(Color("Description").opacity(0.1))
                                .frame(height: 1)
                            Spacer()
                        }
                    }
                    .frame(height: height)

                    // 중앙선 (0점)
                    Rectangle()
                        .fill(Color("Description").opacity(0.3))
                        .frame(height: 1)
                        .offset(y: height / 2)

                    // 감정 라인
                    Path { path in
                        guard !history.isEmpty else { return }

                        let stepX = width / CGFloat(max(history.count - 1, 1))

                        for (index, point) in history.enumerated() {
                            let x = CGFloat(index) * stepX
                            let normalizedScore = (point.averageScore - minScore) / (maxScore - minScore)
                            let y = height - (CGFloat(normalizedScore) * height)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    // 데이터 포인트
                    ForEach(Array(history.enumerated()), id: \.offset) { index, point in
                        let x = CGFloat(index) * (width / CGFloat(max(history.count - 1, 1)))
                        let normalizedScore = (point.averageScore - minScore) / (maxScore - minScore)
                        let y = height - (CGFloat(normalizedScore) * height)

                        Circle()
                            .fill(scoreColor(point.averageScore))
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                }
            }
            .frame(height: 150)

            // 범례
            HStack(spacing: 16) {
                LegendItem(emoji: "😄", label: "긍정적", color: Color.green)
                LegendItem(emoji: "😐", label: "중립", color: Color.gray)
                LegendItem(emoji: "😔", label: "부정적", color: Color.orange)
            }
            .font(.system(size: 12))
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score > 0.5 {
            return Color.green
        } else if score < -0.5 {
            return Color.orange
        } else {
            return Color.gray
        }
    }
}

struct LegendItem: View {
    let emoji: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 12))

            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .foregroundStyle(Color("Description"))
        }
    }
}

#Preview {
    let sampleTrend = EmotionTrend(
        recentEmotions: [
            EmotionAnalysis(date: Date(), emotion: .positive, text: "좋았어", isSuccess: true),
            EmotionAnalysis(date: Date().addingTimeInterval(-86400), emotion: .neutral, text: "그냥 그랬어", isSuccess: true),
            EmotionAnalysis(date: Date().addingTimeInterval(-172800), emotion: .negative, text: "힘들었어", isSuccess: false),
        ],
        averageScore: 0.3,
        overallMood: .positive,
        burnoutRisk: .low,
        recommendation: "조금 쉬어가도 괜찮아요. 너무 무리하지 말고, 작은 성공들을 축하해주세요."
    )

    return ScrollView {
        VStack(spacing: 20) {
            EmotionTrendCardView(trend: sampleTrend) {
                print("View details")
            }

            BurnoutWarningBannerView(
                burnoutRisk: .moderate,
                message: "최근 부정적 감정이 많아지고 있어요. 충분한 휴식을 취하세요.",
                onTap: { print("Tapped") }
            )
        }
        .padding()
    }
    .background(Color.backgroundColor)
}
