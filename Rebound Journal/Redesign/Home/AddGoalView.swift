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

struct AddGoalView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private enum Step { case direction, smaller }

    @State private var step: Step = .direction
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

                PebbleView(mood: step == .smaller ? .thinking : .resting, size: 96)
                    .frame(maxWidth: .infinity)

                Text(question)
                    .font(PebbleTheme.companionFont(21))
                    .foregroundStyle(PebbleTheme.ink)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.easeInOut(duration: 0.25), value: step)

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
                    Text("떠오르지 않으면 비워둬도 돼요. 나중에 같이 찾아요.")
                        .font(PebbleTheme.label(13))
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
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onAppear { isFocused = true }
    }

    // MARK: 문구

    private var question: String {
        switch step {
        case .direction:
            "무엇을 향해 가고 있어요?"
        case .smaller:
            "그럼 '\(trimmed(direction))'\(trimmed(direction).particle("을", "를")) 향해서,\n내일 바로 해낼 수 있을 만큼 작은 일 하나는 뭘까요?"
        }
    }

    private var placeholder: String {
        switch step {
        case .direction: "크게 적어도 괜찮아요."
        case .smaller: "작을수록 좋아요. 5분짜리여도 괜찮아요."
        }
    }

    private var primaryLabel: String {
        switch step {
        case .direction: "다음"
        case .smaller: trimmed(smallest).isEmpty ? "이대로 둘게요" : "이걸로 시작할게요"
        }
    }

    private var binding: Binding<String> {
        step == .direction ? $direction : $smallest
    }

    // MARK: 동작

    private func advance() {
        switch step {
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
            dismiss()
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
