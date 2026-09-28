//
//  InteractivePebble.swift
//  Rebound Journal
//
//  만질 수 있는 조약돌.
//
//  조약돌은 말을 걸기만 하는 존재가 아니라 **손에 쥘 수 있는 돌**이어야 한다 (§10).
//  할 말이 없는 날에도 앱을 열어 돌을 한 번 톡 건드리고 닫을 수 있으면, 그것만으로
//  이 앱을 여는 이유가 된다. 그래서 반응은 전부 짧고, 아무것도 요구하지 않는다.
//
//   - 톡      말랑하게 눌렸다 튀어 오르며 잠깐 웃는다. 작게 "응" 한다.
//   - 쓰다듬기 문지르면 눈을 지그시 감고 손가락 쪽으로 기운다. 햇빛이 조금 밝아진다.
//   - 톡톡톡  연달아 건드리면 어지러운 듯 빙글 흔들린다.
//
//  어떤 반응도 기록을 남기거나 화면을 옮기지 않는다. 만진 것에 대가를 매기면
//  놀이가 아니라 버튼이 된다.
//
//  `PebbleView`는 위젯과 함께 컴파일된다. 위젯에는 소리·촉감이 없으므로 만지는
//  동작은 여기, 앱 쪽에만 둔다.
//

import SwiftUI
import UIKit

struct InteractivePebble: View {
    var mood: PebbleMood = .resting
    var size: CGFloat = 140
    var isSpeaking: Bool = false

    /// 잠깐 덮어쓰는 표정. 반응이 끝나면 원래 표정(`mood`)으로 돌아간다.
    @State private var reaction: PebbleMood?
    @State private var squash: CGFloat = 1
    @State private var tilt: Double = 0
    @State private var lean: CGFloat = 0
    @State private var spin: Double = 0

    @State private var isPetting = false
    @State private var strokedDistance: CGFloat = 0
    @State private var lastDragX: CGFloat = 0

    @State private var recentTaps: [Date] = []
    @State private var reactionTask: Task<Void, Never>?

    private let softHaptic = UIImpactFeedbackGenerator(style: .soft)

    var body: some View {
        PebbleView(mood: reaction ?? mood, size: size, isSpeaking: isSpeaking)
            // 눌리면 옆으로 퍼지고 위아래로 납작해진다. 바닥에 붙어 있는 돌이라 아래를 축으로.
            .scaleEffect(x: 1 + (1 - squash) * 0.6, y: squash, anchor: .bottom)
            .rotationEffect(.degrees(tilt + spin), anchor: .bottom)
            .offset(x: lean)
            .contentShape(Rectangle())
            .onTapGesture(perform: poke)
            .simultaneousGesture(petting)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("톡 건드리거나 문질러 쓰다듬을 수 있어요"))
            .accessibilityAction(named: Text("쓰다듬기")) { pet() }
            .onDisappear { reactionTask?.cancel() }
    }

    // MARK: - 톡

    private func poke() {
        let now = Date()
        recentTaps = recentTaps.filter { now.timeIntervalSince($0) < 1.6 } + [now]

        if recentTaps.count >= 5 {
            recentTaps = []
            dizzy()
            return
        }

        feel(intensity: 0.7)
        PebbleVoice.shared.chirp("응")

        withAnimation(.easeOut(duration: 0.08)) { squash = 0.86 }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.42).delay(0.08)) { squash = 1 }
        react(.warm, for: 1.1)
    }

    // MARK: - 쓰다듬기

    /// 조금만 움직여도 쓰다듬기로 친다. 톡과 구분할 만큼만 거리를 둔다.
    private var petting: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if !isPetting {
                    isPetting = true
                    lastDragX = value.translation.width
                    reactionTask?.cancel()
                    withAnimation(.easeInOut(duration: 0.25)) { reaction = .warm }
                }

                // 손가락 쪽으로 살짝 기운다. 끌려가지는 않는다 — 돌은 무겁다.
                let pull = max(-1, min(1, value.translation.width / (size * 0.9)))
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                    tilt = pull * 7
                    lean = pull * size * 0.05
                }

                // 문지른 거리만큼 부드럽게 톡톡. 매 프레임 울리면 진동이 뭉개진다.
                strokedDistance += abs(value.translation.width - lastDragX)
                lastDragX = value.translation.width
                if strokedDistance > size * 0.35 {
                    strokedDistance = 0
                    feel(intensity: 0.35)
                }
            }
            .onEnded { _ in
                isPetting = false
                strokedDistance = 0
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                    tilt = 0
                    lean = 0
                }
                PebbleVoice.shared.chirp("음")
                react(.warm, for: 0.9)
            }
    }

    /// VoiceOver 로 쓰다듬을 때. 손가락이 없으니 기울기 없이 표정과 소리만.
    private func pet() {
        feel(intensity: 0.4)
        PebbleVoice.shared.chirp("음")
        react(.warm, for: 1.4)
    }

    // MARK: - 톡톡톡

    /// 너무 많이 건드리면 어지러워한다. 혼내지 않고, 잠깐 빙글 돌고 만다.
    private func dizzy() {
        feel(intensity: 0.5)
        PebbleVoice.shared.chirp("어어")
        reactionTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) { reaction = .thinking }

        let swings: [Double] = [-10, 9, -6, 4, 0]
        for (index, angle) in swings.enumerated() {
            withAnimation(.easeInOut(duration: 0.16).delay(Double(index) * 0.16)) {
                spin = angle
            }
        }
        react(.thinking, for: Double(swings.count) * 0.16 + 0.5)
    }

    // MARK: - 보조

    /// 표정을 잠깐 바꿨다가 원래대로 돌린다. 겹쳐 부르면 마지막 것만 남는다.
    private func react(_ mood: PebbleMood, for seconds: Double) {
        reactionTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) { reaction = mood }
        reactionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, !isPetting else { return }
            withAnimation(.easeInOut(duration: 0.35)) { reaction = nil }
        }
    }

    private func feel(intensity: CGFloat) {
        // 설정의 "말할 때 진동"을 따른다. 끈 사람에게는 만져도 떨리지 않는다.
        guard TypingFeedback.shared.isHapticEnabled else { return }
        softHaptic.impactOccurred(intensity: intensity)
        softHaptic.prepare()
    }
}

#Preview {
    InteractivePebble(mood: .resting, size: 160)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PebbleTheme.canvas)
}
