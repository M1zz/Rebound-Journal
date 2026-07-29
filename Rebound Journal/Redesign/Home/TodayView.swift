//
//  TodayView.swift
//  Rebound Journal
//
//  첫 화면. 조약돌과 나누는 대화만 둔다.
//
//  목록도, 달력도, 통계도 여기 없다. 열자마자 그런 게 보이면 대화가 아니라
//  대시보드가 되고, 사용자는 읽을 거리부터 훑게 된다. 이 앱에서 먼저 일어나야
//  하는 일은 조약돌이 말을 거는 것이다.
//
//  지나온 기록은 `LookBackView`에 모아 두고 보고 싶을 때 찾아가게 했다.
//  거기서 목표를 고르면 화면이 닫히고 조약돌이 그 목표 얘기를 시작한다.
//
//  화면에 "실패", "슛", "골인", "리바운드"라는 낱말이 없다 (§4).
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
    @State private var isLookingBack = false

    /// 지금 조약돌이 얘기하는 목표. nil이면 앱이 알아서 고른다.
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
    /// 첫 만남에서 "나중에요"라고 했는지. 같은 권유를 다시 띄우지 않는다.
    @State private var didDeferIntro = false

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

                // 조약돌은 스크롤 밖에 둔다. 대화 상대가 화면에서 밀려 나가면
                // 혼잣말하는 화면이 된다. 말풍선만 그 아래에서 흐른다.
                VStack(spacing: 0) {
                    companionArea
                        .padding(.bottom, 18)
                    conversationArea
                }
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
            resetGreeting()
        } content: { observation in
            ConversationView(observation: observation, journals: journals)
        }
        .sheet(isPresented: $isAddingGoal, onDismiss: resetGreeting) {
            AddGoalView()
        }
        .sheet(isPresented: $isLookingBack) {
            LookBackView { goal in
                selectedGoal = goal
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }

    // MARK: - 조약돌

    private var companionArea: some View {
        PebbleView(mood: observation.pebbleMood, size: 140)
            .padding(.top, 8)
    }

    // MARK: - 대화

    /// §5-A. 앱이 먼저, 중립적으로 말한다. 사용자는 아무것도 선언하지 않아도 된다.
    ///
    /// 매듭짓지 못한 기록이 있으면 그것부터 묻고, 없으면 오늘 상태를 전한다.
    private var conversationArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    GreetingView(
                        lines: greeting,
                        choices: choices,
                        onSelect: handle(choice:),
                        // 글자가 늘어나는 동안에도 따라 내려간다. 새 말이 시작할 때만
                        // 맞추면 긴 말풍선이 자라면서 화면 아래로 빠져나간다.
                        onProgress: { scrollToLatest(proxy, animated: false) },
                        shown: $shownGreetings
                    )
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchor)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            // 위에 붙여 둔다. 아래에 붙이면 대화가 한두 마디일 때 조약돌과
            // 첫 말풍선 사이가 통째로 빈다.
            .onAppear { buildGreetingIfNeeded() }
            .onChange(of: greeting.count) { _, _ in scrollToLatest(proxy, animated: true) }
            // 목표가 바뀌면 주제가 바뀐다. 다시 찍어서 바뀌었다는 걸 눈에 보이게 한다.
            .onChange(of: selectedGoal) { _, _ in rebuildForSelection() }
        }
    }

    private static let bottomAnchor = "bottom"

    /// 마지막 말이 화면에 남도록 맞춘다.
    ///
    /// 내용이 화면보다 짧으면 스크롤할 것이 없어 아무 일도 일어나지 않는다.
    /// 그래서 말이 적을 때는 조약돌 바로 아래에 붙어 있고, 길어질 때만 따라간다.
    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.28)) {
                proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
        }
    }

    /// 아직 아무 기록도 목표도 없는 상태. 조약돌과 처음 만나는 자리다.
    private var isFirstMeeting: Bool {
        goals.isEmpty && journals.isEmpty
    }

    /// 지금 할 수 있는 답들.
    private var choices: [ReplyChoice] {
        if followUp != nil {
            return [
                ReplyChoice(id: "done", label: "해냈어요"),
                ReplyChoice(id: "notYet", label: "아직이에요"),
                ReplyChoice(id: "later", label: "지금은 그냥 둘래요")
            ]
        }
        if didDeferIntro { return [] }
        if isFirstMeeting {
            // 처음부터 빠져나갈 길을 함께 둔다. 첫 화면에서 요구만 남으면 닫게 된다 (§5).
            return [
                ReplyChoice(id: "start", label: "적어볼게요", isPrimary: true),
                ReplyChoice(id: "notNow", label: "나중에요")
            ]
        }
        if let invitation = observation.invitation {
            return [ReplyChoice(id: "talk", label: invitation, isPrimary: true)]
        }
        if case .noGoalYet = observation.kind {
            return [ReplyChoice(id: "addGoal", label: "목표 하나 적어두기", isPrimary: true)]
        }
        return []
    }

    private func handle(choice: ReplyChoice) {
        switch choice.id {
        case "done": handle(answer: .done)
        case "notYet": handle(answer: .notYet)
        case "later": handle(answer: .later)
        case "start", "addGoal": isAddingGoal = true
        case "notNow":
            didDeferIntro = true
            greeting.append(GreetingLine(text: HomeGreeting.introDeferred))
        default: conversation = observation
        }
    }

    /// 인사말은 상태로 들고 간다.
    ///
    /// 매번 다시 계산하면 답한 순간 질문 말풍선이 목록에서 빠져 화면에서 사라진다.
    /// 방금 나눈 말이 없어지면 대화가 아니라 공지처럼 읽힌다.
    private func buildGreetingIfNeeded() {
        guard greeting.isEmpty else { return }

        // 처음 만나는 자리에서는 관찰부터 들이밀지 않고 인사부터 한다.
        guard !isFirstMeeting else {
            greeting = HomeGreeting.introduction()
            return
        }

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

    /// 기록이 바뀌었으니 처음부터 다시 말을 걸게 한다.
    private func resetGreeting() {
        greeting = []
        shownGreetings = []
        followUp = nil
        buildGreetingIfNeeded()
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

    // MARK: - 도구 모음

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            // 지나온 길. 이어진 점들이 징검다리를 그대로 닮았다.
            Button {
                isLookingBack = true
            } label: {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(PebbleTheme.inkSoft)
            }
            .accessibilityLabel("지나온 길")
        }

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
                        resetGreeting()
                    } label: {
                        Label("샘플 데이터 생성", systemImage: "cylinder.fill")
                    }
                    Button(role: .destructive) {
                        SampleDataGenerator.clearAllData(context: modelContext)
                        resetGreeting()
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
