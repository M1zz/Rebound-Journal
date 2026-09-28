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
//   - 톡        말랑하게 눌렸다 튀어 오르며 웃는다. "헤헤" 하고 한마디.
//   - 톡톡(2~4)  간지러워서 부르르 떨며 크게 웃는다. "히히, 간지러워요!"
//   - 쓰다듬기    문지르면 눈을 지그시 감고 기댄다. 손을 떼면 기분 좋게 한 번 부르르.
//   - 톡×5 이상  어지러워서 빙글 흔들린다.
//
//  말은 돌 옆의 작은 말풍선으로 잠깐 떴다 사라진다. 대화에 끼어들지 않고, 기록을
//  남기거나 화면을 옮기지 않는다. 만진 것에 대가를 매기면 놀이가 아니라 버튼이 된다.
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
    /// 올릴 때마다 한 번 부르르 떤다.
    @State private var shiver = 0
    /// 돌 옆에 잠깐 뜨는 한마디.
    @State private var remark: String?

    @State private var isPetting = false
    @State private var strokedDistance: CGFloat = 0
    @State private var lastDragX: CGFloat = 0

    @State private var recentTaps: [Date] = []
    @State private var reactionTask: Task<Void, Never>?
    @State private var remarkTask: Task<Void, Never>?

    private let softHaptic = UIImpactFeedbackGenerator(style: .soft)
    private let rigidHaptic = UIImpactFeedbackGenerator(style: .rigid)

    var body: some View {
        PebbleView(mood: reaction ?? mood, size: size, isSpeaking: isSpeaking)
            // 부르르 — 좌우로 잘게 떨린다. 크게 흔들면 겁먹은 것처럼 보여서 몇 pt 만.
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: shiver) { content, dx in
                content.offset(x: dx)
            } keyframes: { _ in
                KeyframeTrack {
                    for (index, dx) in Self.shiverPath(size: size).enumerated() {
                        LinearKeyframe(dx, duration: index == 0 ? 0.03 : 0.045)
                    }
                    SpringKeyframe(0, duration: 0.2)
                }
            }
            // 눌리면 옆으로 퍼지고 위아래로 납작해진다. 바닥에 붙어 있는 돌이라 아래를 축으로.
            .scaleEffect(x: 1 + (1 - squash) * 0.6, y: squash, anchor: .bottom)
            .rotationEffect(.degrees(tilt + spin), anchor: .bottom)
            .offset(x: lean)
            .overlay(alignment: .topTrailing) { remarkBubble }
            .contentShape(Rectangle())
            .onTapGesture(perform: poke)
            .simultaneousGesture(petting)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("톡 건드리거나 문질러 쓰다듬을 수 있어요"))
            .accessibilityAction(named: Text("쓰다듬기")) { pet() }
            .onDisappear {
                reactionTask?.cancel()
                remarkTask?.cancel()
            }
            #if DEBUG
            // 확인·스크린샷용: 실행 인자 `-debug.pebble poke|tickle|pet|dizzy`
            .task { await playDebugReaction() }
            #endif
    }

    // MARK: - 톡

    private func poke() {
        let now = Date()
        recentTaps = recentTaps.filter { now.timeIntervalSince($0) < 1.4 } + [now]

        switch recentTaps.count {
        case 5...:
            recentTaps = []
            dizzy()
        case 2...4:
            tickle()
        default:
            smile()
        }
    }

    /// 한 번 톡. 웃으며 튀어 오른다.
    private func smile() {
        feel(.soft, intensity: 0.7)
        PebbleVoice.shared.chirp("헤헤")
        say(Self.pokeLines)

        withAnimation(.easeOut(duration: 0.08)) { squash = 0.86 }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.42).delay(0.08)) { squash = 1 }
        react(.warm, for: 1.3)
    }

    /// 톡톡. 간지러워서 부르르 떨며 크게 웃는다.
    private func tickle() {
        shiver += 1
        buzz(times: 4)
        PebbleVoice.shared.chirp("히히히", step: 0.06)
        say(Self.tickleLines)

        withAnimation(.easeOut(duration: 0.06)) { squash = 0.9 }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.35).delay(0.06)) { squash = 1 }
        react(.warm, for: 1.6)
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
                    say(Self.petLines)
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
                    feel(.soft, intensity: 0.35)
                }
            }
            .onEnded { _ in
                isPetting = false
                strokedDistance = 0
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                    tilt = 0
                    lean = 0
                }
                // 기분 좋게 한 번 부르르.
                shiver += 1
                buzz(times: 2, intensity: 0.4)
                PebbleVoice.shared.chirp("음")
                react(.warm, for: 1.0)
            }
    }

    /// VoiceOver 로 쓰다듬을 때. 손가락이 없으니 기울기 없이 표정·떨림·소리만.
    private func pet() {
        say(Self.petLines)
        shiver += 1
        buzz(times: 2, intensity: 0.4)
        PebbleVoice.shared.chirp("음")
        react(.warm, for: 1.4)
    }

    // MARK: - 톡×5

    /// 너무 많이 건드리면 어지러워한다. 혼내지 않고, 잠깐 빙글 돌고 만다.
    private func dizzy() {
        feel(.rigid, intensity: 0.5)
        PebbleVoice.shared.chirp("어어")
        say(Self.dizzyLines)
        reactionTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) { reaction = .thinking }

        let swings: [Double] = [-10, 9, -6, 4, 0]
        for (index, angle) in swings.enumerated() {
            withAnimation(.easeInOut(duration: 0.16).delay(Double(index) * 0.16)) {
                spin = angle
            }
        }
        react(.thinking, for: Double(swings.count) * 0.16 + 0.6)
    }

    // MARK: - 한마디

    /// 돌의 오른쪽 위에 잠깐 뜨는 말풍선. 대화 말풍선과 헷갈리지 않게 작고 흐리게.
    @ViewBuilder
    private var remarkBubble: some View {
        if let remark {
            Text(remark)
                .font(PebbleTheme.companionFont(max(13, size * 0.11)))
                .foregroundStyle(PebbleTheme.ink)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(PebbleTheme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(PebbleTheme.hairline, lineWidth: 1))
                .offset(x: size * 0.18, y: -size * 0.12)
                .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// 한마디를 고른다. 반응은 매번 조금씩 달라야 살아 있는 것처럼 느껴져서 무작위로 고른다.
    /// (홈 인사와 달리 화면을 다시 그릴 때 바뀌는 자리가 아니라서 흔들려도 된다)
    private func say(_ lines: [(formal: String, casual: String)]) {
        guard let line = lines.randomElement() else { return }
        remarkTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            remark = Phrasing.say(line.formal, line.casual)
        }
        remarkTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { remark = nil }
        }
    }

    private static let pokeLines: [(formal: String, casual: String)] = [
        ("헤헤", "헤헤"),
        ("응?", "응?"),
        ("여기 있어요", "여기 있어"),
        ("불렀어요?", "불렀어?")
    ]

    private static let tickleLines: [(formal: String, casual: String)] = [
        ("히히, 간지러워요!", "히히, 간지러워!"),
        ("간질간질해요", "간질간질해"),
        ("그만, 히히", "그만, 히히")
    ]

    private static let petLines: [(formal: String, casual: String)] = [
        ("좋아요…", "좋다…"),
        ("따뜻해요", "따뜻해"),
        ("스르르…", "스르르…")
    ]

    private static let dizzyLines: [(formal: String, casual: String)] = [
        ("어지러워요…", "어지러워…"),
        ("빙글빙글…", "빙글빙글…")
    ]

    // MARK: - 보조

    /// 부르르 떨 때 좌우로 오가는 길. 점점 잦아든다.
    private static func shiverPath(size: CGFloat) -> [CGFloat] {
        let amplitude = max(2.5, size * 0.035)
        return [1, -1, 0.85, -0.85, 0.65, -0.65, 0.4, -0.4].map { $0 * amplitude }
    }

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

    private enum Feel { case soft, rigid }

    private func feel(_ feel: Feel, intensity: CGFloat) {
        // 설정의 "말할 때 진동"을 따른다. 끈 사람에게는 만져도 떨리지 않는다.
        guard TypingFeedback.shared.isHapticEnabled else { return }
        let generator = feel == .soft ? softHaptic : rigidHaptic
        generator.impactOccurred(intensity: intensity)
        generator.prepare()
    }

    /// 부르르 떨 때 손에도 떨림이 오게 잘게 여러 번.
    private func buzz(times: Int, intensity: CGFloat = 0.55) {
        Task { @MainActor in
            for index in 0..<times {
                feel(.rigid, intensity: intensity * (1 - CGFloat(index) * 0.15))
                try? await Task.sleep(for: .milliseconds(55))
            }
        }
    }

    #if DEBUG
    private func playDebugReaction() async {
        guard let name = UserDefaults.standard.string(forKey: "debug.pebble") else { return }
        try? await Task.sleep(for: .seconds(2))
        switch name {
        case "poke": smile()
        case "tickle": tickle()
        case "pet": pet()
        case "dizzy": dizzy()
        default: break
        }
    }
    #endif
}

#Preview {
    InteractivePebble(mood: .resting, size: 160)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PebbleTheme.canvas)
}
