//
//  AddGoalView.swift
//  Rebound Journal
//
//  목표 만들기 — 설계 고찰 §6의 직접 구현.
//
//  SMART도, 마일스톤 분해도 쓰지 않는다. 이미 목표를 높게 잡아 무너진 사람에게
//  "이번엔 제대로 계획하라"는 요구는 압박이고 역효과다.
//
//  대신 질문 하나만 던진다.
//
//      "내일 바로 해낼 수 있을 만큼 작게 만든다면, 뭐가 될까요?"
//
//  앱이 쪼개주지 않는다. 쪼개는 건 사용자가 한다. 그래야 계획을 세우는 능력 자체가
//  자라고, 실패 → 계획 못 세움 → 실패의 악순환에서 나올 수 있다.
//

import SwiftUI
import SwiftData
import LeeoKit

struct AddGoalView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LeeoStore
    @Query private var goals: [SubGoalData]

    private enum Step { case full, direction, smaller }

    @State private var step: Step = .direction
    /// 이번에 적는 목표가 무료로 적을 수 있는 마지막 것인지. 열 때 한 번 정한다 —
    /// 저장하는 순간 개수가 늘어 닫히는 화면이 '가득 참'으로 바뀌면 안 된다.
    @State private var isLastFreeGoal = false
    @State private var isShowingPaywall = false
    @State private var direction: String = ""
    @State private var smallest: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            PebbleTheme.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 26) {
                HStack {
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

                InteractivePebble(mood: step == .direction ? .resting : .thinking, size: 96)
                    .frame(maxWidth: .infinity)

                Text(question)
                    .font(PebbleTheme.companionFont(21))
                    .foregroundStyle(PebbleTheme.ink)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.easeInOut(duration: 0.25), value: step)

                if step == .full {
                    fullNotice
                } else {
                    writingArea
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onAppear(perform: checkRoom)
        // 여기서 산 경우. 막혔던 자리에서 곧바로 이어 쓴다.
        .onChange(of: store.hasPro) { _, hasPro in
            if hasPro && step == .full {
                withAnimation(.easeInOut(duration: 0.25)) { step = .direction }
                isFocused = true
            }
        }
        .proPaywall(isPresented: $isShowingPaywall, feature: .moreGoals)
    }

    // MARK: 적는 자리

    @ViewBuilder
    private var writingArea: some View {
        SoftCard {
            TextField(placeholder, text: binding, axis: .vertical)
                .font(PebbleTheme.body(17))
                .foregroundStyle(PebbleTheme.ink)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isFocused)
                .submitLabel(.done)
        }

        if step == .smaller {
            // 쪼개기를 강요하지 않는다. 지금 못 쪼개는 상태일 수도 있다.
            Text(Phrasing.say(
                "떠오르지 않으면 비워둬도 돼요. 나중에 같이 찾아요.",
                "떠오르지 않으면 비워둬도 돼. 나중에 같이 찾자."
            ))
                .font(PebbleTheme.label(13))
                .foregroundStyle(PebbleTheme.inkFaint)
        }

        if isLastFreeGoal && step == .direction {
            // 막기 전에 미리 알린다. 부딪히고 나서 아는 것보다 덜 서운하다.
            // ('세 개'는 ProFeature.freeGoalLimit 과 같이 바꾼다)
            Text(Phrasing.say(
                "무료로는 목표를 세 개까지 품을 수 있어요. 이게 세 번째예요.",
                "무료로는 목표를 세 개까지 품을 수 있어. 이게 세 번째야."
            ))
            .font(PebbleTheme.label(12))
            .foregroundStyle(PebbleTheme.inkFaint)
        }

        Spacer()

        // 다른 화면과 같은 말투. 여기도 조약돌이 묻고 내가 답하는 자리다.
        if step == .direction && trimmed(direction).isEmpty {
            EmptyView()
        } else {
            ReplyOptions(choices: [
                ReplyChoice(id: "next", label: primaryLabel, isPrimary: true)
            ]) { _ in
                advance()
            }
        }
    }

    // MARK: 가득 찼을 때
    //
    // 페이월부터 들이밀지 않는다. 조약돌이 지금 상태를 먼저 말하고, 무료로 할 수
    // 있는 길(하나 내려놓기)을 같이 알려 준다. 프로는 그중 하나의 길일 뿐이다.

    private var fullNotice: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(Phrasing.say(
                "'지나온 길'에서 목표 하나를 내려놓으면 새로 적을 수 있어요.",
                "'지나온 길'에서 목표 하나를 내려놓으면 새로 적을 수 있어."
            ))
            .font(PebbleTheme.body(15))
            .foregroundStyle(PebbleTheme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

            Spacer()

            ReplyOptions(choices: [
                ReplyChoice(id: "pro", label: Phrasing.say("프로로 더 적을래요", "프로로 더 적을래"), isPrimary: true),
                ReplyChoice(id: "later", label: Phrasing.say("지금은 그냥 둘게요", "지금은 그냥 둘게"))
            ]) { choice in
                if choice.id == "pro" {
                    isShowingPaywall = true
                } else {
                    dismiss()
                }
            }
        }
    }

    private func checkRoom() {
        switch store.evaluate(.moreGoals, current: goals.count) {
        case .blocked:
            step = .full
            LeeoAnalyticsCenter.track(.gateBlocked(key: ProFeature.moreGoals.rawValue))
        case .allowedNearLimit(let remaining):
            isLastFreeGoal = remaining == 0
            isFocused = true
        case .allowed:
            isFocused = true
        }
    }

    // MARK: 문구

    private var question: String {
        switch step {
        case .full:
            Phrasing.say(
                String(localized: "지금 향하는 곳이 벌써 \(goals.count)개예요."),
                String(localized: "지금 향하는 곳이 벌써 \(goals.count)개야.")
            )
        case .direction:
            Phrasing.say("무엇을 향해 가고 있어요?", "무엇을 향해 가고 있어?")
        case .smaller:
            Phrasing.say(
                String(localized: "그럼 '\(trimmed(direction))'\(trimmed(direction).particle("을", "를")) 향해서,\n내일 바로 해낼 수 있을 만큼 작은 일 하나는 뭘까요?"),
                String(localized: "그럼 '\(trimmed(direction))'\(trimmed(direction).particle("을", "를")) 향해서,\n내일 바로 해낼 수 있을 만큼 작은 일 하나는 뭘까?")
            )
        }
    }

    private var placeholder: String {
        switch step {
        case .full: ""
        case .direction: Phrasing.say("크게 적어도 괜찮아요.", "크게 적어도 괜찮아.")
        case .smaller: Phrasing.say("작을수록 좋아요. 5분짜리여도 괜찮아요.", "작을수록 좋아. 5분짜리여도 괜찮아.")
        }
    }

    private var primaryLabel: String {
        switch step {
        case .full: ""
        case .direction: String(localized: "다음")
        case .smaller: trimmed(smallest).isEmpty
            ? Phrasing.say("이대로 둘게요", "이대로 둘게")
            : Phrasing.say("이걸로 시작할게요", "이걸로 시작할게")
        }
    }

    private var binding: Binding<String> {
        step == .direction ? $direction : $smallest
    }

    // MARK: 동작

    private func advance() {
        switch step {
        case .full:
            break

        case .direction:
            withAnimation(.easeInOut(duration: 0.25)) { step = .smaller }
            isFocused = true

        case .smaller:
            // 추적 대상은 **쪼갠 것**이다. 쪼개지 못했으면 큰 목표를 그대로 둔다.
            // 큰 목표만 남아도 대화에서 다시 쪼개기 질문을 받게 된다.
            let tracked = trimmed(smallest).isEmpty ? trimmed(direction) : trimmed(smallest)
            guard !tracked.isEmpty else { dismiss(); return }

            modelContext.insert(SubGoalData(
                id: UUID().uuidString,
                date: Date(),
                goalText: tracked
            ))
            UsageReporting.log(.goalCreated)
            dismiss()
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
