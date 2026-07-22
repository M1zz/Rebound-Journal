//
//  SuccessFromReboundCelebration.swift
//  Rebound Journal
//
//  Created by Claude on 11/14/25.
//

import SwiftUI

/// 리바운드를 극복한 성공 축하 화면
struct SuccessFromReboundCelebration: View {
    let rebound: JournalData
    let onDismiss: () -> Void

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

    var daysBetween: Int {
        guard let date = rebound.date else { return 0 }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }

    var body: some View {
        ZStack {
            // 배경
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // 축하 카드
            VStack(spacing: 20) {
                // 이모지 & 타이틀
                VStack(spacing: 8) {
                    Text("🎉")
                        .font(.system(size: 60))
                        .scaleEffect(animationScale)
                        .onAppear {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                                animationScale = 1.2
                            }
                        }

                    Text("대단해요!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.primary)
                }

                // 실패 → 성공 타임라인
                VStack(spacing: 12) {
                    // 실패
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("[\(daysAgo)] 실패 😢")
                                .font(.system(size: 22, weight: .semibold))
                            if !rebound.nextPlanUnwrapped.isEmpty {
                                Text("대안: \(rebound.nextPlanUnwrapped)")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                    }

                    // 화살표
                    HStack {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.green)
                        Spacer()
                    }
                    .padding(.leading, 3)

                    // 성공
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("[오늘] 성공! 🎉")
                                .font(.system(size: 22, weight: .semibold))
                        }
                        Spacer()
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                // 메시지
                VStack(spacing: 6) {
                    if daysBetween > 0 {
                        Text("\(daysBetween)일 전 실패를 극복했어요!")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    }

                    Text("이게 진짜 성장이에요 ⭐")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // 닫기 버튼
                Button(action: onDismiss) {
                    Text("확인")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color("TextColor"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(.horizontal, 24)
        }
    }

    @State private var animationScale: CGFloat = 0.5
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
        subGoal: "야식 참기"
    )

    SuccessFromReboundCelebration(rebound: sampleRebound, onDismiss: {})
}
