//
//  GreetingView.swift
//  Rebound Journal
//
//  홈에서 조약돌이 말을 거는 부분.
//
//  대화 화면과 달리 여기서는 **입력을 막지 않는다**. 홈은 차례를 주고받는 자리가
//  아니라 잠깐 들르는 자리라, 말이 끝나기를 기다리게 하면 열 때마다 붙잡히는 셈이 된다.
//  글자가 찍히는 동안에도 아래 목표 목록은 그대로 만질 수 있다.
//
//  타이핑은 앱을 연 뒤 한 번만 한다. 설정을 다녀오거나 대화를 닫고 돌아올 때마다
//  다시 찍히면 성가시다.
//

import SwiftUI

struct GreetingView: View {

    let lines: [GreetingLine]
    let followUp: FollowUp?
    let invitation: String?
    var onInvitation: () -> Void
    var onAnswer: (FollowUp.Answer) -> Void

    /// 이미 한 번 보여준 말들. 다시 들어와도 또 찍지 않는다.
    @Binding var shown: Set<UUID>

    @State private var typingID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(visible) { line in
                ChatBubble(speaker: .pebble) {
                    if line.id == typingID {
                        TypewriterText(text: line.text) {
                            shown.insert(line.id)
                            typingID = nil
                        }
                    } else {
                        Text(line.text)
                            .font(PebbleTheme.companionFont(17))
                            .foregroundStyle(PebbleTheme.ink)
                            .lineSpacing(5)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // 말이 다 끝난 뒤에 답할 자리를 연다. 질문이 찍히는 중에 선택지가 먼저
            // 떠 있으면 무엇에 답하는지 모른 채 누르게 된다.
            if isDone {
                answerArea
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: typingID)
        .animation(.easeOut(duration: 0.25), value: isDone)
        .task(id: lines.map(\.id)) { await reveal() }
        .onTapGesture { skip() }
    }

    private var visible: [GreetingLine] {
        lines.filter { shown.contains($0.id) || $0.id == typingID }
    }

    private var isDone: Bool {
        typingID == nil && lines.allSatisfy { shown.contains($0.id) }
    }

    // MARK: 답하기

    @ViewBuilder
    private var answerArea: some View {
        if let followUp {
            VStack(spacing: 8) {
                Button("해냈어요") { answer(.done, followUp) }
                    .buttonStyle(ChoiceButtonStyle())
                Button("아직이에요") { answer(.notYet, followUp) }
                    .buttonStyle(ChoiceButtonStyle())
                Button("지금은 그냥 둘래요") { answer(.later, followUp) }
                    .buttonStyle(ChoiceButtonStyle())
            }
            .padding(.top, 2)
        } else if let invitation {
            Button(invitation) {
                TypingFeedback.shared.tap()
                onInvitation()
            }
            .buttonStyle(WarmButtonStyle())
            .padding(.top, 4)
        }
    }

    private func answer(_ answer: FollowUp.Answer, _ followUp: FollowUp) {
        TypingFeedback.shared.tap()
        onAnswer(answer)
    }

    // MARK: 등장

    /// 말들을 순서대로 하나씩 내보낸다.
    private func reveal() async {
        while !Task.isCancelled {
            guard let next = lines.first(where: { !shown.contains($0.id) }) else { return }

            // 홈에서는 뜸을 짧게 준다. 열자마자 점 세 개를 오래 보고 있으면 답답하다.
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            typingID = next.id

            while !Task.isCancelled && typingID == next.id {
                try? await Task.sleep(for: .milliseconds(40))
            }
        }
    }

    private func skip() {
        guard let typingID else { return }
        TypingFeedback.shared.end()
        shown.insert(typingID)
        self.typingID = nil
    }
}
