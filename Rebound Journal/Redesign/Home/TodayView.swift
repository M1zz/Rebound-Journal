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
import TipKit
import WidgetKit

struct TodayView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var journals: [JournalData]
    @Query private var goals: [SubGoalData]

    @State private var conversation: GoalObservation?
    @State private var isAddingGoal = false
    @State private var isShowingSettings = false
    @State private var isLookingBack = false
    @State private var isShowingAllRecords = false

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

    /// 말투. 문구는 `SpeechStyle.current`가 알아서 읽어가지만, **바뀌었다는 걸
    /// 화면이 알아야** 이미 찍어 놓은 말풍선을 다시 쓸 수 있다.
    @AppStorage(SpeechStyle.storageKey) private var speechStyle = SpeechStyle.formal.rawValue

    private let speechStyleTip = SpeechStyleTip()

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
            .onOpenURL(perform: enter(from:))
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
            // 조약돌이 말하는 걸 한 번 겪었다. 이제 "말투를 바꿀 수 있다"는
            // 안내가 뜻을 갖는다.
            Task { await SpeechStyleTip.conversationFinished.donate() }
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
        .sheet(isPresented: $isShowingAllRecords) {
            AllRecordsView()
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
            .onAppear {
                buildGreetingIfNeeded()
                // 인사를 만드는 쪽에 두지 않는다. 그쪽은 처음 만나는 자리에서
                // 일찍 빠져나가고, 그러면 아직 아무것도 없는 사람의 홈 화면에만
                // 조약돌이 나타나지 않는다. 가장 필요한 사람에게 없는 셈이다.
                publishToWidget()
            }
            // 기록이 바뀌면 관찰도 바뀐다. 홈 화면의 조약돌도 같이 따라와야
            // 어제 얘기를 오늘까지 하고 있지 않는다.
            .onChange(of: journals.count) { _, _ in publishToWidget() }
            .onChange(of: goals.count) { _, _ in publishToWidget() }
            .onChange(of: speechStyle) { _, _ in publishToWidget() }
            .onChange(of: greeting.count) { _, _ in scrollToLatest(proxy, animated: true) }
            // 목표가 바뀌면 주제가 바뀐다. 다시 찍어서 바뀌었다는 걸 눈에 보이게 한다.
            .onChange(of: selectedGoal) { _, _ in rebuildForSelection() }
            // 말투가 바뀌면 처음부터 다시 인사한다.
            //
            // 이미 나온 말풍선의 글자만 조용히 갈아끼울 수도 있지만, 그러면
            // 방금 읽은 문장이 눈앞에서 다른 문장으로 바뀐다. 다시 인사하게
            // 두는 편이 낫다. 바뀐 말투를 곧바로 들려주는 자리도 되고,
            // 되돌리고 싶으면 그 자리에서 판단할 수 있다.
            .onChange(of: speechStyle) { _, _ in resetGreeting() }
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
            // 됐다/안 됐다로만 물으면 실제 상태가 안 담긴다. 안 된 이유가
            // 하나가 아니라서다 — 잊은 것과 미루는 것은 다른 얘기다.
            return [
                ReplyChoice(id: "done", label: Phrasing.say("했어요, 기록만 못 했고요", "했어, 기록만 못 했고")),
                ReplyChoice(id: "forgot", label: Phrasing.say("잊고 있었어요", "잊고 있었어")),
                ReplyChoice(id: "postponed", label: Phrasing.say("자꾸 미루게 돼요", "자꾸 미루게 돼")),
                ReplyChoice(id: "later", label: Phrasing.say("지금은 그냥 둘래요", "지금은 그냥 둘래"))
            ]
        }
        if isFirstMeeting {
            // "나중에요"를 따로 두지 않는다. 눌러도 조약돌이 한마디 하고 끝이라
            // 아무 일도 일어나지 않는 장식이 된다. 안 누르는 것이 이미 나중이다.
            return [ReplyChoice(id: "start", label: Phrasing.say("적어볼게요", "적어볼게"), isPrimary: true)]
        }
        if let invitation = observation.invitation {
            return [ReplyChoice(id: "talk", label: invitation, isPrimary: true)]
        }
        if case .noGoalYet = observation.kind {
            return [ReplyChoice(id: "addGoal", label: "목표 하나 적어두기", isPrimary: true)]
        }
        return []
    }

    // MARK: - 위젯

    /// 홈 화면의 조약돌이 지금 무슨 말을 걸지 적어 둔다.
    ///
    /// 문장을 여기서 만드는 이유는 `PebbleSnapshot`에 적어 뒀다 — 관찰하는 곳이
    /// 둘이면 앱과 위젯이 서로 다른 말을 하게 된다.
    ///
    /// 관찰 문장이 있으면 그걸 그대로 옮긴다. 위젯용으로 따로 짧게 줄이지 않는다.
    /// 홈 화면에서 본 말과 앱을 열었을 때의 첫마디가 같아야 이어진 것으로 읽힌다.
    private func publishToWidget() {
        let current = observation
        let snapshot = PebbleSnapshot(
            line: current.headline,
            action: Phrasing.say("오늘 남기러 가기", "오늘 남기러 가자"),
            mood: current.pebbleMood,
            updatedAt: Date()
        )
        PebbleSnapshot.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 위젯을 눌러 들어왔을 때.
    ///
    /// 홈 화면에서 "남기러 가기"를 눌렀는데 앱이 인사만 하고 가만히 있으면
    /// 한 번 더 눌러야 한다. 누른 사람은 이미 남길 마음으로 들어온 것이니
    /// 바로 그 자리로 데려간다.
    private func enter(from url: URL) {
        guard PebbleLink.isRecord(url) else { return }
        if observation.invitesConversation {
            conversation = observation
        } else {
            // 아직 향하는 곳이 없으면 적을 것부터 정해야 한다.
            isAddingGoal = true
        }
    }

    private func handle(choice: ReplyChoice) {
        switch choice.id {
        case "done": handle(answer: .done)
        case "forgot": handle(answer: .forgot)
        case "postponed": handle(answer: .postponed)
        case "later": handle(answer: .later)
        case "start", "addGoal": isAddingGoal = true
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

        case .forgot:
            // 잊은 건 캐물을 게 없다. 의지가 아니라 눈에 띄지 않았던 문제라
            // 여기서 실패 분석으로 끌고 들어가면 없는 잘못을 만드는 셈이 된다.
            answerBack(HomeGreeting.reply(to: answer, goal: pending.goal), thenTellToday: true)

        case .postponed:
            // 자꾸 미뤄진다는 건 그 일이 아직 크다는 뜻이다. 여기가 §6의
            // 쪼개기가 필요한 자리라 대화로 넘긴다.
            // 재도전하라고 말하지는 않는다. 얘기할 자리만 연다 (§4).
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
                // 정리되지 않은 원본. "지금까지 뭘 적었지?"를 훑는 자리다.
                Button {
                    isShowingAllRecords = true
                } label: {
                    Label("남긴 것들", systemImage: "list.bullet")
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
            // 설정이 이 안에 있다는 걸 같이 알려준다. 안내만 읽고 어디로
            // 가야 할지 모르면 안내가 아니라 광고가 된다.
            .popoverTip(speechStyleTip)
        }
    }
}
