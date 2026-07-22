//
//  FailurePatternAlertView.swift
//  Rebound Journal
//
//  Created by Claude on 11/17/25.
//

import SwiftUI

struct FailurePatternAlertView: View {
    let pattern: FailurePattern
    let onDismiss: (() -> Void)?
    let onViewSuggestions: (() -> Void)?

    init(
        pattern: FailurePattern,
        onDismiss: (() -> Void)? = nil,
        onViewSuggestions: (() -> Void)? = nil
    ) {
        self.pattern = pattern
        self.onDismiss = onDismiss
        self.onViewSuggestions = onViewSuggestions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 헤더
            HStack {
                Text(pattern.interventionLevel.emoji)
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 4) {
                    Text(pattern.interventionLevel.title)
                        .font(.system(size: 20).bold())
                        .foregroundStyle(Color("Default"))

                    Text("\(pattern.goal)")
                        .font(.system(size: 16))
                        .foregroundStyle(Color("Description"))
                }

                Spacer()

                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color("Description"))
                    }
                }
            }

            // 통계
            HStack(spacing: 20) {
                StatItem(
                    title: "연속 실패",
                    value: "\(pattern.consecutiveFailures)회",
                    color: interventionColor
                )

                if let commonCause = pattern.commonCause {
                    StatItem(
                        title: "주요 원인",
                        value: commonCause,
                        color: Color.orange
                    )
                }
            }

            // 구분선
            Divider()
                .background(Color("Description").opacity(0.3))

            // 제안 메시지들
            VStack(alignment: .leading, spacing: 10) {
                Text("제안")
                    .font(.system(size: 16).bold())
                    .foregroundStyle(Color("Default"))

                ForEach(FailurePatternDetector.generateSuggestions(for: pattern), id: \.self) { suggestion in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.green)

                        Text(suggestion)
                            .font(.system(size: 15))
                            .foregroundStyle(Color("Default"))
                            .lineSpacing(4)
                    }
                }
            }

            // 액션 버튼
            if let onViewSuggestions = onViewSuggestions {
                Button(action: onViewSuggestions) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 16))

                        Text("스마트 제안 보기")
                            .font(.system(size: 16).bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(interventionColor)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
        .background(Color.cellColor)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(interventionColor.opacity(0.5), lineWidth: 2)
        )
        .shadow(color: interventionColor.opacity(0.2), radius: 10, x: 0, y: 4)
    }

    private var interventionColor: Color {
        switch pattern.interventionLevel {
        case .gentle:
            return Color.green
        case .moderate:
            return Color.orange
        case .urgent:
            return Color.red
        }
    }
}

/// 통계 아이템
struct StatItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Color("Description"))

            Text(value)
                .font(.system(size: 18).bold())
                .foregroundStyle(color)
        }
    }
}

/// 배너 스타일 경고 (간단한 버전)
struct FailurePatternBannerView: View {
    let pattern: FailurePattern
    let onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Text(pattern.interventionLevel.emoji)
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: 4) {
                Text(pattern.interventionLevel.title)
                    .font(.system(size: 16).bold())
                    .foregroundStyle(Color("Default"))

                Text("\(pattern.goal) - \(pattern.consecutiveFailures)회 연속 실패")
                    .font(.system(size: 14))
                    .foregroundStyle(Color("Description"))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(Color("Description"))
        }
        .padding(16)
        .background(Color.cellColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(interventionColor.opacity(0.3), lineWidth: 1.5)
        )
        .onTapGesture {
            onTap?()
        }
    }

    private var interventionColor: Color {
        switch pattern.interventionLevel {
        case .gentle: return Color.green
        case .moderate: return Color.orange
        case .urgent: return Color.red
        }
    }
}

#Preview {
    let samplePattern = FailurePattern(
        goal: "아침 운동하기",
        consecutiveFailures: 5,
        failureReasons: ["시간이 없어서", "피곤해서", "날씨가 안 좋아서"],
        commonCause: "시간",
        interventionLevel: .moderate,
        mostRecentFailureDate: Date()
    )

    return VStack(spacing: 20) {
        FailurePatternBannerView(pattern: samplePattern) {
            print("Tapped")
        }

        FailurePatternAlertView(
            pattern: samplePattern,
            onDismiss: { print("Dismissed") },
            onViewSuggestions: { print("View suggestions") }
        )
    }
    .padding()
    .background(Color.backgroundColor)
}
