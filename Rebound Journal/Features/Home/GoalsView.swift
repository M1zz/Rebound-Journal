//
//  GoalsView.swift
//  Rebound Journal
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

    /// 목표를 골라 이야기하러 갈 때.
    var onTalk: (String) -> Void

    @State private var isAddingGoal = false
    @State private var renaming: SubGoalData?
    @State private var newName = ""
    @State private var pendingRelease: SubGoalData?
    @State private var renameConflict = false

    var body: some View {
        ZStack {
            PebbleTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if goals.isEmpty {
                    empty
                } else {
                    List {
                        ForEach(sortedGoals, id: \.persistentModelID) { goal in
                            row(goal)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 5, leading: 22, bottom: 5, trailing: 22))
                        }
                        footer
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isAddingGoal) {
            AddGoalView()
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
                modelContext.delete(goal)
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
            Button {
                isAddingGoal = true
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
            Text(Phrasing.say("아직 향하는 곳이 없어요.", "아직 향하는 곳이 없어."))
                .font(PebbleTheme.companionFont(18))
                .foregroundStyle(PebbleTheme.inkSoft)
            ReplyOptions(choices: [
                ReplyChoice(id: "add", label: String(localized: "목표 하나 적어두기"), isPrimary: true)
            ]) { _ in
                isAddingGoal = true
            }
            .frame(maxWidth: 260)
            Spacer()
        }
        .padding(.horizontal, 24)
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
    }
}
