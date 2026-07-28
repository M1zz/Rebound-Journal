//
//  TodayView.swift
//  Rebound Journal
//
//  새 홈 화면.
//
//  이 화면이 지켜야 할 것은 "보여주지 않는 것"에 가깝다.
//   - 연속 실패 일수, 달성률, 남은 목표 개수 같은 숫자를 두지 않는다.
//     이미 목표를 높게 잡아 무너진 사람에게 점수판은 압박이다 (§6).
//   - 밀린 목표를 한꺼번에 늘어놓지 않는다. 조약돌은 한 번에 하나만 말한다.
//   - "실패", "슛", "골인", "리바운드"라는 낱말이 없다 (§4).
//

import SwiftUI
import SwiftData

struct TodayView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var journals: [JournalData]
    @Query private var goals: [SubGoalData]

    @State private var conversation: GoalObservation?
    @State private var isAddingGoal = false
    @State private var isShowingSettings = false
    @State private var isShowingChart = false

    /// 사용자가 목록에서 직접 고른 목표. nil이면 앱이 알아서 하나 고른다.
    ///
    /// 고르는 행위 자체는 "실패했다"는 선언이 아니다. 무엇에 대해 얘기할지만
    /// 정하는 것이고, 관찰은 여전히 조약돌이 먼저 한다 (§5-A).
    @State private var selectedGoal: String?

    /// 조약돌이 지금까지 건넨 말들. 답하면 뒤에 이어 붙는다.
    @State private var greeting: [GreetingLine] = []
    /// 이미 찍어서 보여준 인사말. 설정을 다녀와도 다시 타이핑하지 않는다.
    @State private var shownGreetings: Set<UUID> = []
    /// 지금 답을 기다리는 물음. 답하면 비운다.
    @State private var followUp: FollowUp?

    /// 징검다리에 보이는 주의 시작일.
    @State private var weekStart: Date = WeekStones.startOfWeek(containing: Date())
    /// 눌러서 펼쳐 본 돌.
    @State private var selectedDay: Date?

    private var observation: GoalObservation {
        if let selectedGoal {
            ProgressObserver.observation(for: selectedGoal, journals: journals)
        } else {
            ProgressObserver.primaryObservation(goals: goals, journals: journals)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PebbleTheme.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 30) {
                        companionArea
                        observationCard
                        bridgeArea
                        goalsArea
                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("징검돌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .toolbarBackground(PebbleTheme.canvas, for: .navigationBar)
        }
        .fullScreenCover(item: $conversation) {
            // 대화가 끝나면 선택을 놓는다. 다음에 열었을 때 조약돌이 다시 스스로
            // 고르게 두어야, 사용자가 고른 목표에 계속 매여 있지 않는다.
            selectedGoal = nil
        } content: { observation in
            ConversationView(observation: observation, journals: journals)
        }
        .sheet(isPresented: $isAddingGoal) {
            AddGoalView()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }

    // MARK: - 조약돌

    private var companionArea: some View {
        VStack(spacing: 4) {
            PebbleView(mood: observation.pebbleMood, size: 150)
                .padding(.top, 10)
        }
    }

    // MARK: - 관찰

    /// §5-A. 앱이 먼저, 중립적으로 말한다. 사용자는 아무것도 선언하지 않아도 된다.
    ///
    /// 매듭짓지 못한 기록이 있으면 그것부터 묻고, 없으면 오늘 상태를 전한다.
    private var observationCard: some View {
        GreetingView(
            lines: greeting,
            followUp: followUp,
            invitation: invitationLabel,
            onInvitation: startConversation,
            onAnswer: handle(answer:),
            shown: $shownGreetings
        )
        .padding(.horizontal, 2)
        .onAppear { buildGreetingIfNeeded() }
        // 목표를 고르면 주제가 바뀐다. 다시 찍어서 바뀌었다는 걸 눈에 보이게 한다.
        .onChange(of: selectedGoal) { _, _ in rebuildForSelection() }
    }

    /// 인사말은 상태로 들고 간다.
    ///
    /// 매번 다시 계산하면 답한 순간 질문 말풍선이 목록에서 빠져 화면에서 사라진다.
    /// 방금 나눈 말이 없어지면 대화가 아니라 공지처럼 읽힌다.
    private func buildGreetingIfNeeded() {
        guard greeting.isEmpty else { return }

        let pending = selectedGoal == nil
            ? ProgressObserver.unresolved(journals: journals)
            : nil
        followUp = pending.flatMap { HomeGreeting.followUp(for: $0) }
        greeting = HomeGreeting.lines(
            observation: observation,
            followUp: followUp,
            goalCount: goals.count
        )
    }

    private func rebuildForSelection() {
        followUp = nil
        shownGreetings = []
        greeting = HomeGreeting.lines(
            observation: observation,
            followUp: nil,
            goalCount: goals.count
        )
    }

    private var invitationLabel: String? {
        if observation.invitation != nil { return observation.invitation }
        if case .noGoalYet = observation.kind { return "목표 하나 적어두기" }
        return nil
    }

    private func startConversation() {
        if case .noGoalYet = observation.kind {
            isAddingGoal = true
        } else {
            conversation = observation
        }
    }

    // MARK: - 매듭짓기

    /// 매듭짓지 못한 기록에 대한 답을 처리한다.
    ///
    /// "해냈어요"는 그 기록을 닫고 성공으로 남긴다. 스키마에 있던
    /// `isResolved`/`linkedReboundId`가 여기서 처음으로 쓰인다 — 막힌 기록과
    /// 그걸 넘어선 기록이 이어져야 나중에 "그때 이렇게 넘겼다"를 꺼낼 수 있다.
    private func handle(answer: FollowUp.Answer) {
        guard let pending = followUp else { return }
        followUp = nil

        switch answer {
        case .done:
            resolve(pending)
            answerBack(HomeGreeting.reply(to: answer, goal: pending.goal), thenTellToday: true)

        case .notYet:
            // 재도전하라고 말하지 않는다. 얘기할 자리만 열어 둔다 (§4).
            conversation = GoalObservation(
                kind: .notReached(goal: pending.goal, daysAgo: ProgressObserver.quietDays)
            )

        case .later:
            answerBack(HomeGreeting.reply(to: answer, goal: pending.goal), thenTellToday: false)
        }
    }

    /// 조약돌의 대답을 이어 붙인다. 물음만 있고 답이 없으면 대화가 끊긴 것처럼 남는다.
    private func answerBack(_ reply: String, thenTellToday: Bool) {
        greeting.append(GreetingLine(text: reply))
        guard thenTellToday else { return }
        // 매듭이 지어졌으니 이제 오늘 얘기를 한다.
        greeting.append(contentsOf: HomeGreeting.lines(
            observation: observation,
            followUp: nil,
            goalCount: goals.count
        ))
    }

    private func resolve(_ followUp: FollowUp) {
        guard let blocked = journals.first(where: { $0.id == followUp.journalID }) else { return }

        blocked.isResolved = true
        blocked.resolvedDate = Date()

        // 넘어선 기록을 따로 남긴다. 막힌 기록을 성공으로 덮어쓰면 그때 무엇이
        // 막혔는지가 사라져서, 다음에 같은 데서 막혔을 때 꺼낼 게 없어진다.
        modelContext.insert(
            JournalData(
                id: UUID().uuidString,
                date: Date(),
                hasDeleted: false,
                isGoalIn: true,
                emotionValue: nil,
                emotionText: nil,
                review: nil,
                nextPlan: nil,
                isRebounded: true,
                purpose: nil,
                mainGoal: nil,
                subGoal: followUp.goal,
                linkedReboundId: followUp.journalID,
                isResolved: nil,
                retryCount: nil
            )
        )
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
            if !goals.isEmpty {
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

                // `\.persistentModelID`로 묶는다. `SubGoalData`에는 자체 `id: String?`가
                // 있어서 Identifiable의 ID가 그쪽으로 잡히는데, 이 값이 nil인 행이
                // 섞여 있으면 ForEach가 전부 같은 항목으로 보고 첫 줄만 반복해서 그린다.
                ForEach(goals, id: \.persistentModelID) { goal in
                    VStack(spacing: 0) {
                        goalRow(goal)
                        if selectedGoal == (goal.goalText ?? "") {
                            notes(for: goal.goalText ?? "")
                        }
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
        let isSelected = selectedGoal == text

        return Button {
            select(text)
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

                // 고른 목표에만 표식을 둔다. 고르지 않은 목표에 아무 표시가 없어야
                // 목록이 "밀린 일 목록"으로 읽히지 않는다.
                if isSelected {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PebbleTheme.sunlight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PebbleTheme.gutter)
            .background(isSelected ? PebbleTheme.sunlight.opacity(0.10) : PebbleTheme.surface)
            // 펼쳐지면 아래로 기록이 붙으므로 아랫모서리를 각지게 둔다.
            .clipShape(
                .rect(
                    topLeadingRadius: PebbleTheme.cardRadius,
                    bottomLeadingRadius: isSelected ? 0 : PebbleTheme.cardRadius,
                    bottomTrailingRadius: isSelected ? 0 : PebbleTheme.cardRadius,
                    topTrailingRadius: PebbleTheme.cardRadius,
                    style: .continuous
                )
            )
            .overlay {
                UnevenRoundedRectangle(
                    topLeadingRadius: PebbleTheme.cardRadius,
                    bottomLeadingRadius: isSelected ? 0 : PebbleTheme.cardRadius,
                    bottomTrailingRadius: isSelected ? 0 : PebbleTheme.cardRadius,
                    topTrailingRadius: PebbleTheme.cardRadius,
                    style: .continuous
                )
                .strokeBorder(
                    isSelected ? PebbleTheme.sunlight : PebbleTheme.hairline,
                    lineWidth: isSelected ? 1.5 : 1
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - 그 목표에 무슨 일이 있었나

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
                        .padding(.bottom, 14)
                }
            }
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

    private static let visibleNotes = 4

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
                    // 그때 스스로 정한 다음 걸음. 앱이 정해준 게 아니라는 게 중요하다 (§6).
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
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }

    /// 목표를 고르거나, 이미 고른 걸 다시 눌러 되돌린다.
    private func select(_ goal: String) {
        withAnimation(.easeInOut(duration: 0.28)) {
            selectedGoal = (selectedGoal == goal) ? nil : goal
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

    // MARK: - 도구 모음

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    isAddingGoal = true
                } label: {
                    Label("목표 추가", systemImage: "plus")
                }
                // 소리·진동 켜고 끄기는 설정 화면에 있다. 메뉴에도 두면
                // 같은 스위치가 두 군데 있게 되어 어느 쪽이 진짜인지 헷갈린다.
                Button {
                    isShowingSettings = true
                } label: {
                    Label("설정", systemImage: "gearshape")
                }

                #if DEBUG
                Section("개발용") {
                    Button {
                        SampleDataGenerator.generateAllSampleData(context: modelContext)
                    } label: {
                        Label("샘플 데이터 생성", systemImage: "cylinder.fill")
                    }
                    Button(role: .destructive) {
                        SampleDataGenerator.clearAllData(context: modelContext)
                    } label: {
                        Label("모든 데이터 삭제", systemImage: "trash")
                    }
                }
                #endif
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(PebbleTheme.inkSoft)
            }
        }
    }
}
