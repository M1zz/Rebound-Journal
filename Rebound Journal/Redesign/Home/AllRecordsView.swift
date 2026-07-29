//
//  AllRecordsView.swift
//  Rebound Journal
//
//  남긴 기록 전부. 날짜순으로, 손대지 않고.
//
//  `지나온 길`은 주간 징검다리와 목표별로 **정리된** 화면이다. 정리는 보기 좋지만
//  "지금까지 내가 뭘 적었지?"를 훑는 데는 맞지 않는다. 앱이 골라서 보여주는 순간
//  훑는다는 행위 자체가 안 되기 때문이다.
//
//  그래서 여기서는 아무것도 솎아내지 않는다. 접어두지도, 최근 몇 개만 보여주지도
//  않는다. 다만 숫자로 세지는 않는다 — 몇 개 썼는지는 이 화면의 쓸모가 아니고,
//  그 순간 점수판이 된다 (§6).
//

import SwiftUI
import SwiftData

struct AllRecordsView: View {

    @Environment(\.dismiss) private var dismiss
    @Query private var journals: [JournalData]

    private var days: [RecordedDay] {
        ProgressObserver.allDays(journals: journals)
    }

    var body: some View {
        ZStack {
            PebbleTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if days.isEmpty {
                    empty
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 26, pinnedViews: [.sectionHeaders]) {
                            ForEach(days) { day in
                                Section {
                                    VStack(spacing: 10) {
                                        ForEach(day.notes) { note in
                                            row(note)
                                        }
                                    }
                                } header: {
                                    dayHeader(day.day)
                                }
                            }
                            Color.clear.frame(height: 24)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 8)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("남긴 것들")
                .font(PebbleTheme.title(20))
                .foregroundStyle(PebbleTheme.ink)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PebbleTheme.inkFaint)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Spacer()
            PebbleView(mood: .resting, size: 110)
            Text("아직 남긴 게 없어요.")
                .font(PebbleTheme.body(16))
                .foregroundStyle(PebbleTheme.inkFaint)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// 날짜 머리. 스크롤 중에도 지금 보는 날이 어디인지 남아 있어야 한다.
    private func dayHeader(_ day: Date) -> some View {
        HStack {
            Text(title(for: day))
                .font(PebbleTheme.label(13))
                .foregroundStyle(PebbleTheme.inkSoft)
            Spacer()
        }
        .padding(.vertical, 6)
        .background(PebbleTheme.canvas)
    }

    private func row(_ entry: DayNote) -> some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    // 닿았는지는 점의 색으로만. 여기서도 붉은색을 쓰지 않는다 (§4).
                    Circle()
                        .fill(entry.note.reached
                              ? PebbleTheme.sunlight
                              : PebbleTheme.inkFaint.opacity(0.4))
                        .frame(width: 7, height: 7)

                    Text(entry.goal)
                        .font(PebbleTheme.label(14))
                        .foregroundStyle(PebbleTheme.inkSoft)

                    Spacer()

                    if let emotion = entry.emotion {
                        Text(emotion)
                            .font(PebbleTheme.label(12))
                            .foregroundStyle(PebbleTheme.inkFaint)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(PebbleTheme.surfaceMuted)
                            .clipShape(Capsule())
                    }
                }

                if let review = entry.note.review {
                    Text(review)
                        .font(PebbleTheme.body(16))
                        .foregroundStyle(PebbleTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let plan = entry.note.plan {
                    // 그때 스스로 정한 다음 걸음 (§6).
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 10))
                            .foregroundStyle(PebbleTheme.sunlight)
                            .padding(.top, 3)
                        Text(plan)
                            .font(PebbleTheme.body(14))
                            .foregroundStyle(PebbleTheme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // 적힌 말이 하나도 없는 기록도 지우지 않는다. 그날 뭔가 있었다는
                // 사실 자체가 기록이다.
                if entry.note.review == nil && entry.note.plan == nil {
                    Text(entry.note.reached ? "닿았다고만 남겼어요." : "남긴 말은 없어요.")
                        .font(PebbleTheme.body(15))
                        .foregroundStyle(PebbleTheme.inkFaint)
                }
            }
        }
    }

    private func title(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "오늘" }
        if calendar.isDateInYesterday(day) { return "어제" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = calendar.isDate(day, equalTo: Date(), toGranularity: .year)
            ? "M월 d일 EEEE"
            : "yyyy년 M월 d일"
        return formatter.string(from: day)
    }
}
