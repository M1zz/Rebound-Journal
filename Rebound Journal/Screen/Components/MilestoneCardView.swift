//
//  MilestoneCardView.swift
//  Rebound Journal
//
//  Created by Claude on 11/17/25.
//

import SwiftUI

/// 달성한 마일스톤 카드
struct AchievedMilestoneCardView: View {
    let milestone: AchievedMilestone
    let isNew: Bool

    init(milestone: AchievedMilestone, isNew: Bool = false) {
        self.milestone = milestone
        self.isNew = isNew
    }

    var body: some View {
        VStack(spacing: 0) {
            // 배지 섹션
            ZStack {
                // 배경 그라데이션
                LinearGradient(
                    colors: [rarityColor.opacity(0.3), rarityColor.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 8) {
                    // 이모지
                    Text(milestone.type.emoji)
                        .font(.system(size: 60))

                    // 희귀도 배지
                    Text(milestone.type.rarity.title)
                        .font(.system(size: 12).bold())
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(rarityColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.vertical, 20)

                // 새 배지
                if isNew {
                    VStack {
                        HStack {
                            Spacer()
                            Text("NEW")
                                .font(.system(size: 10).bold())
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .padding(12)
                        }
                        Spacer()
                    }
                }
            }

            // 정보 섹션
            VStack(alignment: .leading, spacing: 8) {
                Text(milestone.type.title)
                    .font(.system(size: 20).bold())
                    .foregroundStyle(Color("Default"))

                Text(milestone.type.description)
                    .font(.system(size: 14))
                    .foregroundStyle(Color("Description"))
                    .lineSpacing(4)

                if let goal = milestone.goal {
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.blue)

                        Text(goal)
                            .font(.system(size: 13))
                            .foregroundStyle(Color("Default"))
                    }
                    .padding(.top, 4)
                }

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("Description"))

                    Text(milestone.achievedDate, style: .date)
                        .font(.system(size: 12))
                        .foregroundStyle(Color("Description"))
                }
                .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cellColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(rarityColor.opacity(0.5), lineWidth: 2)
        )
        .shadow(color: rarityColor.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    private var rarityColor: Color {
        switch milestone.type.rarity {
        case .common: return Color.gray
        case .uncommon: return Color.green
        case .rare: return Color.blue
        case .epic: return Color.purple
        case .legendary: return Color.orange
        }
    }
}

/// 마일스톤 진행 상황 카드
struct MilestoneProgressCardView: View {
    let progress: MilestoneProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Text(progress.type.emoji)
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 4) {
                    Text(progress.type.title)
                        .font(.system(size: 16).bold())
                        .foregroundStyle(Color("Default"))

                    Text("\(progress.currentProgress) / \(progress.requiredProgress)")
                        .font(.system(size: 14))
                        .foregroundStyle(Color("Description"))
                }

                Spacer()

                // 달성 여부
                if progress.isAchieved {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.green)
                }
            }

            // 프로그레스 바
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 배경
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.backgroundColor)
                        .frame(height: 8)

                    // 진행도
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [progressColor, progressColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress.progressPercent, height: 8)
                }
            }
            .frame(height: 8)

            // 퍼센트 표시
            HStack {
                Spacer()
                Text("\(progress.progressPercentInt)%")
                    .font(.system(size: 13).bold())
                    .foregroundStyle(progressColor)
            }
        }
        .padding(16)
        .background(Color.cellColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color("Description").opacity(0.2), lineWidth: 1)
        )
    }

    private var progressColor: Color {
        if progress.isAchieved {
            return Color.green
        } else if progress.progressPercent >= 0.7 {
            return Color.blue
        } else if progress.progressPercent >= 0.4 {
            return Color.orange
        } else {
            return Color.gray
        }
    }
}

/// 마일스톤 그리드 뷰 (컬렉션)
struct MilestoneCollectionView: View {
    let milestones: [AchievedMilestone]
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 타이틀
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.orange)

                Text("달성한 마일스톤")
                    .font(.system(size: 24).bold())
                    .foregroundStyle(Color("Default"))

                Spacer()

                Text("\(milestones.count)개")
                    .font(.system(size: 16))
                    .foregroundStyle(Color("Description"))
            }
            .padding(.horizontal, 4)

            if milestones.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(milestones) { milestone in
                        CompactMilestoneCard(milestone: milestone)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundStyle(Color("Description"))

            Text("아직 달성한 마일스톤이 없어요")
                .font(.system(size: 16))
                .foregroundStyle(Color("Description"))

            Text("목표를 계속 달성하면 배지를 받을 수 있어요!")
                .font(.system(size: 14))
                .foregroundStyle(Color("Description"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// 컴팩트 마일스톤 카드 (그리드용)
struct CompactMilestoneCard: View {
    let milestone: AchievedMilestone

    var body: some View {
        VStack(spacing: 10) {
            // 배지
            ZStack {
                Circle()
                    .fill(rarityColor.opacity(0.2))
                    .frame(width: 70, height: 70)

                Text(milestone.type.emoji)
                    .font(.system(size: 36))
            }

            // 타이틀
            Text(milestone.type.title)
                .font(.system(size: 14).bold())
                .foregroundStyle(Color("Default"))
                .lineLimit(1)

            // 희귀도
            Text(milestone.type.rarity.title)
                .font(.system(size: 11))
                .foregroundStyle(rarityColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.cellColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(rarityColor.opacity(0.3), lineWidth: 1.5)
        )
    }

    private var rarityColor: Color {
        switch milestone.type.rarity {
        case .common: return Color.gray
        case .uncommon: return Color.green
        case .rare: return Color.blue
        case .epic: return Color.purple
        case .legendary: return Color.orange
        }
    }
}

/// 마일스톤 축하 팝업
struct MilestoneCelebrationView: View {
    let milestone: AchievedMilestone
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // 배경 오버레이
            Color.primary.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // 축하 카드
            VStack(spacing: 20) {
                // 이모지 애니메이션
                Text(milestone.type.emoji)
                    .font(.system(size: 100))

                VStack(spacing: 8) {
                    Text("축하합니다!")
                        .font(.system(size: 28).bold())
                        .foregroundStyle(Color("Default"))

                    Text(milestone.type.title)
                        .font(.system(size: 22))
                        .foregroundStyle(rarityColor)
                }

                Text(milestone.type.description)
                    .font(.system(size: 16))
                    .foregroundStyle(Color("Description"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal)

                // 희귀도 배지
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(rarityColor)

                    Text(milestone.type.rarity.title)
                        .font(.system(size: 16).bold())
                        .foregroundStyle(rarityColor)

                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(rarityColor)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(rarityColor.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // 확인 버튼
                Button(action: onDismiss) {
                    Text("확인")
                        .font(.system(size: 18).bold())
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(rarityColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(30)
            .background(Color.cellColor)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(rarityColor.opacity(0.5), lineWidth: 3)
            )
            .shadow(color: rarityColor.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 30)
        }
    }

    private var rarityColor: Color {
        switch milestone.type.rarity {
        case .common: return Color.gray
        case .uncommon: return Color.green
        case .rare: return Color.blue
        case .epic: return Color.purple
        case .legendary: return Color.orange
        }
    }
}

#Preview {
    let sampleMilestone = AchievedMilestone(
        type: .sevenStreak,
        achievedDate: Date(),
        goal: "아침 운동하기"
    )

    let sampleProgress = MilestoneProgress(
        type: .tenSuccesses,
        currentProgress: 7,
        requiredProgress: 10,
        isAchieved: false
    )

    return ScrollView {
        VStack(spacing: 20) {
            AchievedMilestoneCardView(milestone: sampleMilestone, isNew: true)

            MilestoneProgressCardView(progress: sampleProgress)

            MilestoneCollectionView(milestones: [sampleMilestone])
        }
        .padding()
    }
    .background(Color.backgroundColor)
}
