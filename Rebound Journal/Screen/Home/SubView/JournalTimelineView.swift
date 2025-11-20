//
//  JournalTimelineView.swift
//  Rebound Journal
//
//  Created by Claude on 11/14/25.
//

import SwiftUI
import SwiftData

/// 성공과 해결된 실패를 시간순으로 보여주는 타임라인
struct JournalTimelineView: View {
    @Query(sort: \JournalData.date, order: .reverse) private var journals: [JournalData]

    var timelineItems: [JournalData] {
        journals.filter { $0.isValidForDisplay }
    }

    var groupedByDate: [Date: [JournalData]] {
        Dictionary(grouping: timelineItems) { journal in
            Calendar.current.startOfDay(for: journal.dateUnwrapped)
        }
    }

    var sortedDates: [Date] {
        groupedByDate.keys.sorted(by: >)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 타임라인 아이템들
            if timelineItems.isEmpty {
                EmptyTimelineView()
            } else {
                ForEach(sortedDates, id: \.self) { date in
                    if let items = groupedByDate[date] {
                        DateSection(date: date, items: items)
                    }
                }
            }
        }
    }
}

/// 날짜별 섹션
struct DateSection: View {
    let date: Date
    let items: [JournalData]

    var dateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "오늘"
        } else if calendar.isDateInYesterday(date) {
            return "어제"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M월 d일"
            return formatter.string(from: date)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 날짜 헤더
            Text(dateLabel)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 16)
                .padding(.bottom, 8)

            // 해당 날짜의 기록들
            ForEach(items.sorted(by: { ($0.date ?? Date()) > ($1.date ?? Date()) }), id: \.id) { item in
                TimelineItemCard(journal: item)
            }
        }
    }
}

/// 타임라인 아이템 카드
struct TimelineItemCard: View {
    let journal: JournalData

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 타임라인 인디케이터
            VStack(spacing: 4) {
                Circle()
                    .fill(journal.isGoalInUnwrapped ? Color.green : Color.red)
                    .frame(width: 12, height: 12)

                if !journal.isGoalInUnwrapped && journal.isResolvedUnwrapped {
                    // 해결된 실패는 체크 표시
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                }

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 12)

            // 카드 내용
            VStack(alignment: .leading, spacing: 8) {
                // 목표 & 타입
                HStack {
                    Text(journal.subGoalUnwrapped)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    if journal.isGoalInUnwrapped {
                        Text("골인")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    } else if journal.isResolvedUnwrapped {
                        Text("해결됨")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    } else {
                        Text("리바운드")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }

                // 실패 극복 메시지
                if journal.isGoalInUnwrapped, !journal.linkedReboundIdUnwrapped.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                        Text("이전 실패를 극복한 성공!")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.green)
                }

                // 해결된 실패 → 성공 링크
                if !journal.isGoalInUnwrapped, journal.isResolvedUnwrapped {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 12))
                        Text("나중에 성공으로 극복했어요")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.green)
                }

                // 감정 & 내용
                if let emotion = journal.emotionText {
                    Text(emotion)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                if !journal.reviewUnwrapped.isEmpty {
                    Text(journal.reviewUnwrapped)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }

                // 대안 (실패일 때)
                if !journal.isGoalInUnwrapped, !journal.nextPlanUnwrapped.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("대안:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(journal.nextPlanUnwrapped)
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                            .lineLimit(2)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }

                // 시간
                if let date = journal.date {
                    Text(date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                journal.isGoalInUnwrapped && !journal.linkedReboundIdUnwrapped.isEmpty
                ? Color.green.opacity(0.05)
                : Color(.systemBackground)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

/// 빈 타임라인 뷰
struct EmptyTimelineView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("아직 기록이 없어요")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            Text("첫 슛을 쏴보세요!")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    JournalTimelineView()
}
