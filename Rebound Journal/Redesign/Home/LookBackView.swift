//
//  LookBackView.swift
//  Rebound Journal
//
//  지나온 길. 주간 징검다리와 지금 향하는 곳을 모아 둔 화면.
//
//  홈에서 이걸 떼어낸 이유는, 앱을 열자마자 목록과 달력이 보이면 대화가 아니라
//  대시보드가 되기 때문이다. 이 앱에서 먼저 일어나야 하는 일은 조약돌이 말을
//  거는 것이고, 지나온 기록은 보고 싶을 때 찾아오면 된다.
//
//  여기서 목표를 고르면 화면이 닫히고 조약돌이 그 목표 얘기를 시작한다.
//  기록을 보다가 "이거 얘기해야겠다" 싶을 때 바로 이어지도록.
//

import SwiftUI
import SwiftData

struct LookBackView: View {

    @Environment(\.dismiss) private var dismiss
    @Query private var journals: [JournalData]
    @Query private var goals: [SubGoalData]

    /// 목표를 골라 대화로 넘어갈 때.
    var onPickGoal: (String) -> Void

    @State private var weekStart: Date = WeekStones.startOfWeek(containing: Date())
    @State private var selectedDay: Date?
    @State private var expandedGoal: String?
    @State private var isAddingGoal = false

    private static let visibleNotes = 4

    var body: some View {
        ZStack {
            PebbleTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 30) {
                        bridgeArea
                        goalsArea
                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)
            }
        }
        .sheet(isPresented: $isAddingGoal) {
            AddGoalView()
        }
    }

    private var header: some View {
        HStack {
            Text("지나온 길")
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
    }

    // MARK: - 징검다리

    /// 한 주를 돌 일곱 개로 본다. 돌 하나를 누르면 그날 남긴 게 아래에 열린다.
    private var bridgeArea: some View {
        let days = WeekStones.days(weekStarting: weekStart, journals: journals)

        return VStack(spacing: 10) {
            StoneBridgeView(
                days: days,
                title: WeekStones.title(for: weekStart),
                canGoForward: WeekStones.canGoForward(from: weekStart),
                onPrevious: { moveWeek(-1) },
                onNext: { moveWeek(1) },
                onSelect: selectDay,
                selected: selectedDay
            )

            if let selectedDay {
                dayNotes(for: selectedDay)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func moveWeek(_ delta: Int) {
        guard delta < 0 || WeekStones.canGoForward(from: weekStart) else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            weekStart = WeekStones.week(weekStart, movedBy: delta)
            selectedDay = nil
        }
    }

    private func selectDay(_ day: StoneDay) {
        guard day.state != .ahead else { return }
        TypingFeedback.shared.tap()
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedDay = (selectedDay.map { Calendar.current.isDate($0, inSameDayAs: day.date) } ?? false)
                ? nil
                : day.date
        }
    }

    /// 그날 밟은 돌에 무엇이 있었는지.
    @ViewBuilder
    private func dayNotes(for day: Date) -> some View {
        let entries = ProgressObserver.notes(on: day, journals: journals)

        SoftCard(background: PebbleTheme.surfaceMuted) {
            VStack(alignment: .leading, spacing: 14) {
                Text(dayTitle(day))
                    .font(PebbleTheme.label(12))
                    .foregroundStyle(PebbleTheme.inkFaint)

                if entries.isEmpty {
                    // 빈 날을 나무라지 않는다. 돌은 그대로 거기 있다.
                    Text("이날은 지나갔어요. 그래도 돌은 그대로 있어요.")
                        .font(PebbleTheme.body(15))
                        .foregroundStyle(PebbleTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(entry.note.reached
                                          ? PebbleTheme.sunlight
                                          : PebbleTheme.inkFaint.opacity(0.4))
                                    .frame(width: 6, height: 6)
                                Text(entry.goal)
                                    .font(PebbleTheme.label(13))
                                    .foregroundStyle(PebbleTheme.inkSoft)
                            }
                            if let review = entry.note.review {
                                Text(review)
                                    .font(PebbleTheme.body(15))
                                    .foregroundStyle(PebbleTheme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let plan = entry.note.plan {
                                planRow(plan)
                            }
                        }
                    }
                }
            }
        }
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "오늘" }
        if calendar.isDateInYesterday(day) { return "어제" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: day)
    }

    // MARK: - 목표

    private var goalsArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("지금 향하는 곳")
                    .font(PebbleTheme.label(14))
                    .foregroundStyle(PebbleTheme.inkFaint)
                Spacer()
                Button {
                    isAddingGoal = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PebbleTheme.inkFaint)
                }
            }
            .padding(.horizontal, 4)

            if goals.isEmpty {
                Text("아직 향하는 곳이 없어요.")
                    .font(PebbleTheme.body(15))
                    .foregroundStyle(PebbleTheme.inkFaint)
                    .padding(.horizontal, 4)
            }

            // `\.persistentModelID`로 묶는다. `SubGoalData`에는 자체 `id: String?`가
            // 있어서 Identifiable의 ID가 그쪽으로 잡히는데, 이 값이 nil인 행이
            // 섞여 있으면 ForEach가 전부 같은 항목으로 보고 첫 줄만 반복해서 그린다.
            ForEach(goals, id: \.persistentModelID) { goal in
                VStack(spacing: 0) {
                    goalRow(goal)
                    if expandedGoal == (goal.goalText ?? "") {
                        notes(for: goal.goalText ?? "")
                    }
                }
            }
        }
    }

    private func goalRow(_ goal: SubGoalData) -> some View {
        let text = goal.goalText ?? ""
        let lastTouched = journals
            .filter { $0.isValidForDisplay && $0.subGoalUnwrapped == text }
            .map(\.dateUnwrapped)
            .max()
        let isExpanded = expandedGoal == text

        return Button {
            expand(text)
        } label: {
            HStack(spacing: 14) {
                // 최근에 해냈으면 따뜻한 점, 아니면 조용한 점. 색으로만 알린다.
                Circle()
                    .fill(dotColor(for: text))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 3) {
                    Text(text)
                        .font(PebbleTheme.body(16))
                        .foregroundStyle(PebbleTheme.ink)
                    if let lastTouched {
                        Text(relative(lastTouched))
                            .font(PebbleTheme.label(12))
                            .foregroundStyle(PebbleTheme.inkFaint)
                    } else {
                        Text("아직 기록 없음")
                            .font(PebbleTheme.label(12))
                            .foregroundStyle(PebbleTheme.inkFaint)
                    }
                }
                Spacer()

                // 펼친 목표에만 표식을 둔다. 나머지에 아무 표시가 없어야 목록이
                // "밀린 일 목록"으로 읽히지 않는다.
                if isExpanded {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PebbleTheme.sunlight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PebbleTheme.gutter)
            .background(isExpanded ? PebbleTheme.sunlight.opacity(0.10) : PebbleTheme.surface)
            // 펼쳐지면 아래로 기록이 붙으므로 아랫모서리를 각지게 둔다.
            .clipShape(
                .rect(
                    topLeadingRadius: PebbleTheme.cardRadius,
                    bottomLeadingRadius: isExpanded ? 0 : PebbleTheme.cardRadius,
                    bottomTrailingRadius: isExpanded ? 0 : PebbleTheme.cardRadius,
                    topTrailingRadius: PebbleTheme.cardRadius,
                    style: .continuous
                )
            )
            .overlay {
                UnevenRoundedRectangle(
                    topLeadingRadius: PebbleTheme.cardRadius,
                    bottomLeadingRadius: isExpanded ? 0 : PebbleTheme.cardRadius,
                    bottomTrailingRadius: isExpanded ? 0 : PebbleTheme.cardRadius,
                    topTrailingRadius: PebbleTheme.cardRadius,
                    style: .continuous
                )
                .strokeBorder(
                    isExpanded ? PebbleTheme.sunlight : PebbleTheme.hairline,
                    lineWidth: isExpanded ? 1.5 : 1
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isExpanded ? [.isSelected] : [])
    }

    /// 고른 목표의 기록을 펼친다.
    ///
    /// 성적표가 아니라 **내가 쓴 이야기**로 보여야 한다. 그래서 횟수·달성률·연속
    /// 일수를 두지 않고, 언제 무엇이 막혔고 다음에 뭘 해보기로 했는지만 적는다.
    /// 닿았는지 여부도 글자가 아니라 점의 색으로만 알린다 (§4·§6).
    @ViewBuilder
    private func notes(for goal: String) -> some View {
        let entries = ProgressObserver.notes(for: goal, journals: journals)

        VStack(alignment: .leading, spacing: 0) {
            if entries.isEmpty {
                Text("아직 남긴 이야기가 없어요.")
                    .font(PebbleTheme.label(13))
                    .foregroundStyle(PebbleTheme.inkFaint)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
            } else {
                // 최근 것부터 몇 개만. 전부 늘어놓으면 그 자체로 밀린 목록이 된다.
                ForEach(Array(entries.prefix(Self.visibleNotes).enumerated()), id: \.offset) { _, note in
                    noteRow(note)
                }
                if entries.count > Self.visibleNotes {
                    Text("이전 이야기 \(entries.count - Self.visibleNotes)개는 접어뒀어요.")
                        .font(PebbleTheme.label(12))
                        .foregroundStyle(PebbleTheme.inkFaint)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 10)
                }
            }

            // 보다가 얘기하고 싶어지는 자리. 여기서 바로 대화로 넘어간다.
            ReplyOptions(choices: [
                ReplyChoice(id: "talk", label: "이 얘기 할래요", isPrimary: true)
            ]) { _ in
                onPickGoal(goal)
                dismiss()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .padding(.top, entries.isEmpty ? 0 : 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PebbleTheme.surfaceMuted)
        .clipShape(
            .rect(
                topLeadingRadius: 0,
                bottomLeadingRadius: PebbleTheme.cardRadius,
                bottomTrailingRadius: PebbleTheme.cardRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
        .padding(.horizontal, 10)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func noteRow(_ note: PreviousNote) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(note.reached ? PebbleTheme.sunlight : PebbleTheme.inkFaint.opacity(0.4))
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(relative(note.date))
                    .font(PebbleTheme.label(11))
                    .foregroundStyle(PebbleTheme.inkFaint)

                if let review = note.review {
                    Text(review)
                        .font(PebbleTheme.body(15))
                        .foregroundStyle(PebbleTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let plan = note.plan {
                    planRow(plan)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }

    /// 그때 스스로 정한 다음 걸음. 앱이 정해준 게 아니라는 게 중요하다 (§6).
    private func planRow(_ plan: String) -> some View {
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

    private func expand(_ goal: String) {
        withAnimation(.easeInOut(duration: 0.28)) {
            expandedGoal = (expandedGoal == goal) ? nil : goal
        }
    }

    private func dotColor(for goal: String) -> Color {
        let latest = journals
            .filter { $0.isValidForDisplay && $0.subGoalUnwrapped == goal }
            .max { $0.dateUnwrapped < $1.dateUnwrapped }
        guard let latest else { return PebbleTheme.hairline }
        // 닿지 못한 기록도 회색일 뿐, 붉은색을 쓰지 않는다. 경고가 아니라 상태다.
        return latest.isGoalInUnwrapped ? PebbleTheme.sunlight : PebbleTheme.inkFaint.opacity(0.45)
    }

    /// `RelativeDateTimeFormatter`를 그대로 쓰면 방금 만든 기록이 "0초 후에"로 나온다.
    /// 날짜 단위로 끊어서 사람이 말하듯 적는다.
    private func relative(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "오늘 남김" }
        if calendar.isDateInYesterday(date) { return "어제 남김" }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0

        return switch days {
        case ..<0: "오늘 남김"
        case 0..<7: "\(days)일 전에 남김"
        case 7..<30: "\(days / 7)주 전에 남김"
        default: "오래전에 남김"
        }
    }
}
