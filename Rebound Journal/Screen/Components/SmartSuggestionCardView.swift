//
//  SmartSuggestionCardView.swift
//  Rebound Journal
//
//  Created by Claude on 11/17/25.
//

import SwiftUI

struct SmartSuggestionCardView: View {
    let suggestion: SmartSuggestion
    let onTap: (() -> Void)?

    init(suggestion: SmartSuggestion, onTap: (() -> Void)? = nil) {
        self.suggestion = suggestion
        self.onTap = onTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더: 카테고리와 신뢰도
            HStack {
                // 카테고리
                HStack(spacing: 4) {
                    Text(suggestion.category.emoji)
                        .font(.system(size: 16))
                    Text(suggestion.category.title)
                        .font(.system(size: 14))
                        .foregroundStyle(Color("Description"))
                }

                Spacer()

                // 신뢰도 표시
                HStack(spacing: 4) {
                    Text(suggestion.confidenceEmoji)
                        .font(.system(size: 14))
                    Text("\(suggestion.probabilityPercent)%")
                        .font(.system(size: 14).bold())
                        .foregroundStyle(suggestionColor)
                }
            }

            // 제안 내용
            Text(suggestion.suggestion)
                .font(.system(size: 18))
                .foregroundStyle(Color("Default"))
                .lineSpacing(4)

            // 근거 데이터
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("Description"))

                Text(suggestion.basedOnData)
                    .font(.system(size: 14))
                    .foregroundStyle(Color("Description"))

                Spacer()

                // 난이도 태그
                Text(suggestion.difficultyLevel)
                    .font(.system(size: 12).bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(difficultyColor.opacity(0.2))
                    .foregroundStyle(difficultyColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color.cellColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(suggestionColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.primary.opacity(0.05), radius: 4, x: 0, y: 2)
        .onTapGesture {
            onTap?()
        }
    }

    private var suggestionColor: Color {
        if suggestion.successProbability >= 0.7 {
            return Color.green
        } else if suggestion.successProbability >= 0.5 {
            return Color.orange
        } else {
            return Color.gray
        }
    }

    private var difficultyColor: Color {
        if suggestion.successProbability >= 0.8 {
            return Color.green
        } else if suggestion.successProbability >= 0.5 {
            return Color.orange
        } else {
            return Color.red
        }
    }
}

/// 여러 제안을 표시하는 리스트 뷰
struct SmartSuggestionListView: View {
    let suggestions: [SmartSuggestion]
    let onSuggestionTap: ((SmartSuggestion) -> Void)?

    init(
        suggestions: [SmartSuggestion],
        onSuggestionTap: ((SmartSuggestion) -> Void)? = nil
    ) {
        self.suggestions = suggestions
        self.onSuggestionTap = onSuggestionTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 타이틀
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.yellow)

                Text("스마트 제안")
                    .font(.system(size: 24).bold())
                    .foregroundStyle(Color("Default"))

                Spacer()
            }
            .padding(.horizontal, 4)

            if suggestions.isEmpty {
                // 빈 상태
                VStack(spacing: 12) {
                    Image(systemName: "lightbulb.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(Color("Description"))

                    Text("아직 충분한 데이터가 없어요")
                        .font(.system(size: 16))
                        .foregroundStyle(Color("Description"))

                    Text("계속 기록하면 더 나은 제안을 드릴게요!")
                        .font(.system(size: 14))
                        .foregroundStyle(Color("Description"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // 제안 카드들
                ForEach(suggestions) { suggestion in
                    SmartSuggestionCardView(suggestion: suggestion) {
                        onSuggestionTap?(suggestion)
                    }
                }
            }
        }
    }
}

#Preview {
    let sampleSuggestion = SmartSuggestion(
        suggestion: "목표 시간을 30분으로 줄여보세요",
        successProbability: 0.75,
        basedOnData: "과거 10번 중 8번 성공",
        category: .timeAdjustment,
        totalAttempts: 10,
        successCount: 8
    )

    return VStack(spacing: 20) {
        SmartSuggestionCardView(suggestion: sampleSuggestion)

        SmartSuggestionListView(suggestions: [sampleSuggestion, sampleSuggestion])
    }
    .padding()
    .background(Color.backgroundColor)
}
