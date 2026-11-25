//
//  MenuBarPebble.swift
//  Mochimo
//
//  맥: 메뉴 막대에 사는 모찌.
//
//  일하다가 앱을 열지 않고 한 줄 남긴다. 누르면 작은 창이 떨어지고, 거기서 모찌가 오늘 할 말을
//  하고(홈 화면 위젯과 같은 말), 목표 하나를 골라 했는지 아직인지만 누르면 끝난다.
//
//  하루 끝에 말 걸기: 설정의 '매일 알림'이 켜져 있고 그 시각이 지났는데 오늘 남긴 게 없으면
//  모찌가 메뉴 막대에서 톡톡 튄다. 알림은 한 번 오고 사라지지만 모찌는 남긴 뒤에야 가라앉는다.
//  새 설정을 따로 두지 않는다. 언제 물을지는 이미 사용자가 정해 두었다.
//
//  비밀번호를 걸어 두었으면 목표 이름도 보이지 않고 '모찌모 열기'만 있다.
//

#if os(macOS)
import SwiftUI
import SwiftData
import AppKit

/// 메뉴 막대의 그림. 물을 때가 되면 톡톡 튄다.
struct MenuBarPebbleLabel: View {
    @Query private var journals: [JournalData]
    @AppStorage("enableReminders") private var enableReminders = false
    @AppStorage("reminderTime") private var reminderTime = "9:00 AM"

    /// 1분마다 다시 본다. 물을 시각이 지나는 순간을 놓치지 않으려는 것이다.
    @State private var now = Date()

    var body: some View {
        let asking = MenuBarPebble.isAsking(now: now, enabled: enableReminders, time: reminderTime, journals: journals)
        Image(systemName: asking ? "cat.fill" : "cat")
            .symbolEffect(.bounce, options: .repeat(.periodic(delay: 3)), isActive: asking)
            .accessibilityLabel(Text("모찌모"))
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    now = Date()
                }
            }
    }
}

enum MenuBarPebble {
    /// 오늘 물을 시각이 지났고 아직 아무것도 남기지 않았는지.
    static func isAsking(now: Date, enabled: Bool, time: String, journals: [JournalData]) -> Bool {
        guard enabled else { return false }
        let calendar = Calendar.current
        let parts = time.dateComponents
        guard let hour = parts.hour,
              let askAt = calendar.date(bySettingHour: hour, minute: parts.minute ?? 0, second: 0, of: now),
              now >= askAt else { return false }
        return !journals.contains { $0.isValidForDisplay && calendar.isDate($0.dateUnwrapped, inSameDayAs: now) }
    }
}

/// 메뉴 막대에서 떨어지는 작은 창.
struct QuickNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var manager: DataManager
    @Query private var journals: [JournalData]
    @Query private var goals: [SubGoalData]
    @AppStorage("enableReminders") private var enableReminders = false
    @AppStorage("reminderTime") private var reminderTime = "9:00 AM"

    @State private var goal: String?
    @State private var note = ""
    @State private var justSaved = false
    @FocusState private var isNoteFocused: Bool

    private var goalTexts: [String] {
        goals.compactMap(\.goalText).filter { !$0.isEmpty }
    }

    private var isLocked: Bool { manager.savedPasscode.count == 4 }

    private var asking: Bool {
        MenuBarPebble.isAsking(now: Date(), enabled: enableReminders, time: reminderTime, journals: journals)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isLocked {
                header(Phrasing.say("열어서 얘기해요.", "열어서 얘기하자."), mood: .resting)
            } else if justSaved {
                header(Phrasing.say("남겼어요. 오늘도 한 걸음이에요.", "남겼어. 오늘도 한 걸음이야."), mood: .warm)
            } else if goalTexts.isEmpty {
                header(Phrasing.say("아직 하려는 걸 못 들었네요.", "아직 하려는 걸 못 들었네."), mood: .resting)
            } else {
                let observation = ProgressObserver.primaryObservation(goals: goals, journals: journals)
                header(
                    asking ? String(localized: "오늘 어땠는지, 잠깐 같이 볼까요?") : observation.headline,
                    mood: observation.pebbleMood
                )
                composer
            }

            Divider()

            HStack {
                Button(String(localized: "모찌모 열기")) { openApp() }
                Spacer()
                Button(String(localized: "끝내기")) { NSApp.terminate(nil) }
                    .foregroundStyle(PebbleTheme.inkFaint)
            }
            .buttonStyle(.plain)
            .font(PebbleTheme.label(13))
            .foregroundStyle(PebbleTheme.inkSoft)
        }
        .padding(18)
        .frame(width: 320)
        .background(PebbleTheme.canvas)
        .onAppear {
            justSaved = false
            if goal == nil || !goalTexts.contains(goal ?? "") {
                goal = ProgressObserver.primaryObservation(goals: goals, journals: journals).goal ?? goalTexts.first
            }
            isNoteFocused = true
        }
    }

    private func header(_ line: String, mood: PebbleMood) -> some View {
        HStack(alignment: .center, spacing: 12) {
            PebbleView(mood: mood, size: 40)
                .frame(width: 54, height: 54)
                .accessibilityHidden(true)
            Text(line)
                .font(PebbleTheme.companionFont(15))
                .foregroundStyle(PebbleTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(selection: $goal) {
                ForEach(goalTexts, id: \.self) { Text($0).tag(Optional($0)) }
            } label: {
                Text("목표")
            }
            .labelsHidden()

            TextField(Phrasing.say("한 줄 남겨요", "한 줄 남겨 줘"), text: $note, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.plain)
                .font(PebbleTheme.body(14))
                .focused($isNoteFocused)
                .padding(10)
                .background(PebbleTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(PebbleTheme.hairline, lineWidth: 1)
                }

            HStack {
                Spacer()
                Button(Phrasing.say("아직이에요", "아직이야")) { save(reached: false) }
                Button(Phrasing.say("했어요", "했어")) { save(reached: true) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(PebbleTheme.key)
            }
            .disabled(goal == nil)
        }
    }

    /// 대화에서 남기는 기록과 같은 모양으로 남긴다. 지나온 길 · 위젯이 그대로 읽는다.
    private func save(reached: Bool) {
        guard let goal else { return }
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(JournalData(
            id: UUID().uuidString,
            date: Date(),
            hasDeleted: false,
            isGoalIn: reached,
            review: text.isEmpty ? nil : text,
            isRebounded: false,
            mainGoal: LifeGoalLink.lifeGoalTitle(forGoal: goal, in: modelContext),
            subGoal: goal,
            // 미해결 상태는 닿지 못한 기록에만 둔다(기존 스키마 규약).
            isResolved: reached ? nil : false
        ))
        // 메뉴 막대에서는 적자마자 '끝내기' 를 누르기 쉽다. 자동 저장을 기다리지 않고 바로 내린다.
        modelContext.saveNow()
        UsageReporting.logShot(isGoalIn: reached, resolvedRebound: false)
        note = ""
        withAnimation(.easeOut(duration: 0.2)) { justSaved = true }
    }

    private func openApp() {
        NSApp.activate()
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix(MochimoWindow.main) == true }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: MochimoWindow.main)
        }
    }
}
#endif

/// 창 이름. 메뉴 막대에서 '모찌모 열기'로 다시 찾는다.
enum MochimoWindow {
    static let main = "main"
}
