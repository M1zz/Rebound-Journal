//
//  GoalsView.swift
//  Mochimo
//
//  내 목표 — 지금 향하는 곳들을 한눈에 보고 손보는 자리.
//
//  '지나온 길'은 돌아보는 곳이고, 여기는 **정리하는 곳**이다. 둘을 한 화면에 두면
//  돌아보다가 지우게 되고, 지우려다 지난 기록에 붙잡힌다.
//
//  여기서도 숫자는 두지 않는다. 몇 번 했는지, 몇 %인지 대신 마지막으로 남긴 때만.
//  목록이 성적표가 되면 정리하러 왔다가 자책하고 나간다 (§4·§6).
//
//   - 누르면        그 목표로 조약돌과 이야기를 시작한다
//   - 밀거나 길게    이름 고치기 · 내려놓기
//   - +            새 목표 (무료 한도는 AddGoalView 가 안내한다)
//

import SwiftUI
import SwiftData

struct GoalsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [SubGoalData]
    @Query private var journals: [JournalData]
    @Query(sort: \LifeGoalData.date) private var lifeGoals: [LifeGoalData]
    @Query private var obstacles: [ObstacleData]

    /// 목표를 골라 이야기하러 갈 때.
    var onTalk: (String) -> Void

    @State private var isAddingGoal = false
    @State private var renaming: SubGoalData?
    @State private var newName = ""
    @State private var pendingRelease: SubGoalData?
    @State private var renameConflict = false
    @State private var isAddingLifeGoal = false
    @State private var openLifeGoal: LifeGoalData?
    /// 삶의 목표 화면에서 돌을 눌렀다. 그 화면이 닫힌 뒤 이 화면도 닫고 이야기하러 간다.
    @State private var pendingTalk: String?

    var body: some View {
        ZStack {
            PebbleTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if goals.isEmpty && lifeGoals.isEmpty {
                    empty
                } else {
                    List {
                        lifeGoalSection
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 22, bottom: 5, trailing: 22))

                        sectionTitle(String(localized: "지금 해보는 것"))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 18, leading: 26, bottom: 2, trailing: 22))

                        ForEach(sortedGoals, id: \.persistentModelID) { goal in
                            row(goal)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 5, leading: 22, bottom: 5, trailing: 22))
                        }
                        if goals.isEmpty {
                            Text(Phrasing.say("아직 해보려는 게 없어요.", "아직 해보려는 게 없어."))
                                .font(PebbleTheme.body(14))
                                .foregroundStyle(PebbleTheme.inkFaint)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {
                            footer
                                .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .presentationDragIndicator(.visible)
        #if DEBUG
        // 확인용: `-debug.open lifeGoal` 이면 첫 삶의 목표를 연다.
        .task {
            if UserDefaults.standard.string(forKey: "debug.open") == "lifeGoal" {
                try? await Task.sleep(for: .seconds(0.6))
                openLifeGoal = activeLifeGoals.first ?? lifeGoals.first
            }
        }
        #endif
        .sheet(isPresented: $isAddingGoal) {
            AddGoalView()
                .arabicLayout()
        }
        .sheet(isPresented: $isAddingLifeGoal) {
            AddLifeGoalView { created in
                // 적자마자 그 목표 화면을 연다. 모찌가 바로 첫 물음을 건넨다.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { openLifeGoal = created }
            }
            .arabicLayout()
        }
        .sheet(item: $openLifeGoal.droppingGone(), onDismiss: {
            if let pendingTalk {
                self.pendingTalk = nil
                dismiss()
                onTalk(pendingTalk)
            }
        }) { life in
            LifeGoalView(lifeGoal: life) { stone in
                pendingTalk = stone
                openLifeGoal = nil
            }
            .arabicLayout()
        }
        .alert(String(localized: "이름 고치기"), isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField(String(localized: "목표"), text: $newName)
            Button(String(localized: "취소"), role: .cancel) { renaming = nil }
            Button(String(localized: "고치기")) { commitRename() }
        } message: {
            Text(Phrasing.say(
                "이 목표로 남긴 기록도 새 이름을 따라가요.",
                "이 목표로 남긴 기록도 새 이름을 따라가."
            ))
        }
        .alert(String(localized: "같은 이름의 목표가 이미 있어요"), isPresented: $renameConflict) {
            Button(String(localized: "확인"), role: .cancel) { }
        }
        .confirmationDialog(
            Phrasing.say("이 목표를 내려놓을까요?", "이 목표를 내려놓을까?"),
            isPresented: Binding(
                get: { pendingRelease != nil },
                set: { if !$0 { pendingRelease = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingRelease
        ) { goal in
            Button(String(localized: "내려놓기"), role: .destructive) {
                // 확인창이 떠 있는 사이 이미 지워진 목표면 다시 건드리지 않는다.
                if !goal.isGone { modelContext.delete(goal) }
                pendingRelease = nil
            }
            Button(String(localized: "취소"), role: .cancel) { }
        } message: { _ in
            Text(Phrasing.say(
                "남긴 기록은 그대로 둬요. 목록에서만 빠져요.",
                "남긴 기록은 그대로 둘게. 목록에서만 빠져."
            ))
        }
    }

    // MARK: - 머리

    private var header: some View {
        HStack {
            Text("내 목표")
                .font(PebbleTheme.title(20))
                .foregroundStyle(PebbleTheme.ink)
            Spacer()
            Menu {
                Button {
                    isAddingLifeGoal = true
                } label: {
                    Label(String(localized: "삶의 목표 적기"), systemImage: "sparkles")
                }
                Button {
                    isAddingGoal = true
                } label: {
                    Label(String(localized: "지금 해볼 목표 적기"), systemImage: "flag")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PebbleTheme.key)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel(Text("목표 추가"))
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PebbleTheme.inkFaint)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel(Text("닫기"))
        }
        .padding(.horizontal, 18)
        .padding(.top, PebbleTheme.sheetHeaderTop)
        .padding(.bottom, 8)
    }

    // MARK: - 목록

    /// 최근에 다룬 것부터. 한 번도 기록하지 않은 건 적어 둔 순서대로 뒤에.
    private var sortedGoals: [SubGoalData] {
        goals.sorted { lhs, rhs in
            switch (lastTouched(lhs), lastTouched(rhs)) {
            case let (l?, r?): return l > r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return (lhs.date ?? .distantPast) > (rhs.date ?? .distantPast)
            }
        }
    }

    private func lastTouched(_ goal: SubGoalData) -> Date? {
        let text = goal.goalText ?? ""
        return journals
            .filter { $0.isValidForDisplay && ($0.subGoalUnwrapped == text || $0.mainGoalUnwrapped == text) }
            .map(\.dateUnwrapped)
            .max()
    }

    private func row(_ goal: SubGoalData) -> some View {
        let text = goal.goalText ?? ""
        let touched = lastTouched(goal)

        return Button {
            dismiss()
            onTalk(text)
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(touched == nil ? PebbleTheme.hairline : PebbleTheme.key)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 3) {
                    Text(text)
                        .font(PebbleTheme.body(16))
                        .foregroundStyle(PebbleTheme.ink)
                        .multilineTextAlignment(.leading)
                    Text(touched.map { LeftAgo.label(for: $0) } ?? String(localized: "아직 기록 없음"))
                        .font(PebbleTheme.label(12))
                        .foregroundStyle(PebbleTheme.inkFaint)
                    if let life = lifeGoals.first(where: { $0.id != nil && $0.id == goal.lifeGoalID }) {
                        Label(life.titleUnwrapped, systemImage: "sparkles")
                            .font(PebbleTheme.label(12))
                            .foregroundStyle(PebbleTheme.key)
                            .lineLimit(1)
                    }
                    // 이 목표의 이번 주. 밝은 돌이 닿은 날이다.
                    WeekStoneStrip(
                        days: WeekStones.thisWeek(journals: journals, goal: text),
                        stoneWidth: 24
                    )
                    .frame(maxWidth: 190)
                    .padding(.top, 6)
                }
                Spacer(minLength: 8)
                Image(systemName: "bubble.left")
                    .font(.system(size: 13))
                    .foregroundStyle(PebbleTheme.inkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PebbleTheme.gutter)
            .background(PebbleTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: PebbleTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PebbleTheme.cardRadius, style: .continuous)
                    .strokeBorder(PebbleTheme.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("이 목표로 이야기해요"))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingRelease = goal
            } label: {
                Label(String(localized: "내려놓기"), systemImage: "hand.raised.slash")
            }
            Button {
                startRename(goal)
            } label: {
                Label(String(localized: "이름 고치기"), systemImage: "pencil")
            }
            .tint(PebbleTheme.key)
        }
        .contextMenu {
            Button {
                startRename(goal)
            } label: {
                Label(String(localized: "이름 고치기"), systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingRelease = goal
            } label: {
                Label(String(localized: "내려놓기"), systemImage: "hand.raised.slash")
            }
        }
    }

    private var footer: some View {
        Text(Phrasing.say(
            "밀거나 길게 누르면 이름을 고치거나 내려놓을 수 있어요.",
            "밀거나 길게 누르면 이름을 고치거나 내려놓을 수 있어."
        ))
        .font(PebbleTheme.label(12))
        .foregroundStyle(PebbleTheme.inkFaint)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
    }

    private var empty: some View {
        VStack(spacing: 18) {
            Spacer()
            InteractivePebble(mood: .resting, size: 96)
            Text(Phrasing.say("아직 해보려는 게 없어요.", "아직 해보려는 게 없어."))
                .font(PebbleTheme.companionFont(18))
                .foregroundStyle(PebbleTheme.inkSoft)
            ReplyOptions(choices: [
                ReplyChoice(id: "add", label: String(localized: "목표 하나 적어두기"), isPrimary: true),
                ReplyChoice(id: "life", label: String(localized: "삶의 목표 적기"))
            ]) { choice in
                if choice.id == "life" { isAddingLifeGoal = true } else { isAddingGoal = true }
            }
            .frame(maxWidth: 260)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 내 삶의 목표
    //
    // 언젠가 꼭 이루고 싶은 것들. 개수 제한 없이 무료로 적는다 — 버킷리스트는 원래 여러 개다.
    // 매일 묻지는 않는다. 그 아래 놓은 돌(지금 해보는 것)을 조약돌이 묻는다.

    private var activeLifeGoals: [LifeGoalData] { lifeGoals.filter(\.isActive) }

    @ViewBuilder
    private var lifeGoalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle(String(localized: "내 삶의 목표"))
                Spacer()
                Button {
                    isAddingLifeGoal = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 17))
                        .foregroundStyle(PebbleTheme.key)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("삶의 목표 적기"))
            }
            .padding(.horizontal, 4)

            if activeLifeGoals.isEmpty {
                Button {
                    isAddingLifeGoal = true
                } label: {
                    Text(Phrasing.say(
                        "언젠가 꼭 해보고 싶은 게 있어요? 적어 두면 가로막는 것부터 같이 치워 봐요.",
                        "언젠가 꼭 해보고 싶은 게 있어? 적어 두면 가로막는 것부터 같이 치워 보자."
                    ))
                    .font(PebbleTheme.body(14))
                    .foregroundStyle(PebbleTheme.inkSoft)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(PebbleTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            ForEach(activeLifeGoals, id: \.persistentModelID) { life in
                lifeGoalRow(life)
            }

            let reached = lifeGoals.filter(\.isReached)
            let resting = lifeGoals.filter(\.isResting)
            if !reached.isEmpty || !resting.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(reached + resting, id: \.persistentModelID) { life in
                            Button {
                                openLifeGoal = life
                            } label: {
                                Label(life.titleUnwrapped, systemImage: life.isReached ? "sparkles" : "moon.zzz")
                                    .font(PebbleTheme.label(12))
                                    .foregroundStyle(life.isReached ? PebbleTheme.key : PebbleTheme.inkFaint)
                                    .lineLimit(1)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(PebbleTheme.surface)
                                    .clipShape(Capsule())
                                    .overlay { Capsule().strokeBorder(PebbleTheme.hairline, lineWidth: 1) }
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(life.isReached ? Text("이룬 목표") : Text("잠시 내려놓은 목표"))
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func lifeGoalRow(_ life: LifeGoalData) -> some View {
        let blocking = obstacles.filter { $0.lifeGoalID == life.id && !$0.isCleared }
        let caption: String = if let first = blocking.first {
            String(localized: "가로막는 것: \(first.textUnwrapped)", locale: AppLanguage.locale)
        } else if life.nextQuestion != nil {
            Phrasing.say("모찌가 물어볼 게 있어요", "모찌가 물어볼 게 있어")
        } else {
            Phrasing.say("가로막는 것을 적어 봐요", "가로막는 것을 적어 봐")
        }

        return Button {
            openLifeGoal = life
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(PebbleTheme.sunlight)
                VStack(alignment: .leading, spacing: 3) {
                    Text(life.titleUnwrapped)
                        .font(PebbleTheme.body(16))
                        .foregroundStyle(PebbleTheme.ink)
                        .multilineTextAlignment(.leading)
                    Text(caption)
                        .font(PebbleTheme.label(12))
                        .foregroundStyle(PebbleTheme.inkFaint)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PebbleTheme.inkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PebbleTheme.gutter)
            .background(PebbleTheme.mochi.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: PebbleTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PebbleTheme.cardRadius, style: .continuous)
                    .strokeBorder(PebbleTheme.mochiEdge.opacity(0.5), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(PebbleTheme.label(13))
            .foregroundStyle(PebbleTheme.inkFaint)
    }

    // MARK: - 이름 고치기

    private func startRename(_ goal: SubGoalData) {
        newName = goal.goalText ?? ""
        renaming = goal
    }

    /// 목표 이름을 바꾸고, 그 이름으로 남긴 기록도 함께 옮긴다.
    ///
    /// 기록은 목표를 **이름(문자열)**으로 가리킨다 (기존 스키마 그대로). 목표만 바꾸면
    /// 지난 기록이 새 이름과 끊겨 '지나온 길'에서 사라진 것처럼 보인다.
    private func commitRename() {
        guard let goal = renaming else { return }
        defer { renaming = nil }
        // 이름을 적는 사이 지워진 목표면(다른 창 · 동기화) 읽지 않는다. 읽으면 앱이 죽는다.
        guard !goal.isGone else { return }

        let old = goal.goalText ?? ""
        let new = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !new.isEmpty, new != old else { return }

        if goals.contains(where: { $0.goalText == new }) {
            renameConflict = true
            return
        }

        goal.goalText = new
        for journal in journals {
            if journal.subGoal == old { journal.subGoal = new }
            if journal.mainGoal == old { journal.mainGoal = new }
        }
        // 목표와 지난 기록의 이름이 반만 바뀐 채 꺼지면 기록이 목표와 끊긴다. 한 번에 내린다.
        modelContext.saveNow()
    }
}
