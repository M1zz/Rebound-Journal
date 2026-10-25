//
//  InteractivePebble.swift
//  ZinggumDol
//
//  만질 수 있는 조약돌.
//
//  조약돌은 말을 걸기만 하는 존재가 아니라 **손에 쥘 수 있는 돌**이어야 한다 (§10).
//  할 말이 없는 날에도 앱을 열어 돌을 한 번 톡 건드리고 닫을 수 있으면, 그것만으로
//  이 앱을 여는 이유가 된다. 그래서 반응은 전부 짧고, 아무것도 요구하지 않는다.
//
//   - 톡        여러 반응 중 하나. 직전과 같은 것은 연달아 나오지 않는다.
//                 웃기 · 폴짝 뛰기 · 고개 갸웃 · 데굴 구르기 · 깜짝 놀라기 · 하트
//                 누른 쪽의 반대로 살짝 밀린다. 같은 톡이어도 어디를 눌렀는지가 보인다.
//   - 톡톡(2~4)  간지러워서 부르르 떨며 크게 웃는다. "히히, 간지러워요!"
//   - 꾹 누르기   납작하게 눌렸다가 손을 떼듯 높이 튀어 오른다.
//   - 쓰다듬기    문지르면 눈을 지그시 감고 기댄다. 손을 떼면 기분 좋게 한 번 부르르.
//   - 톡×5 이상  어지러워서 빙글 흔들린다.
//
//  한 가지 반응만 되풀이하면 몇 번 만에 기계 장치처럼 읽힌다. 매번 조금씩 달라야
//  "이번엔 뭘 하려나" 하고 한 번 더 건드려 보게 된다.
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
    /// 뛰어오른 높이. 음수가 위다.
    @State private var hop: CGFloat = 0
    /// 누른 쪽의 반대로 살짝 밀리는 각도.
    @State private var nudge: Double = 0
    /// 돌 위로 떠오르는 하트·반짝이.
    @State private var floaters: [Floater] = []
    /// 직전 톡 반응. 같은 것이 연달아 나오지 않게 한다.
    @State private var lastTap: TapReaction?
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            .rotationEffect(.degrees(tilt + spin + nudge), anchor: .bottom)
            .offset(x: lean, y: hop)
            .overlay(alignment: .top) { floaterLayer }
            .overlay(alignment: .topTrailing) { remarkBubble }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in poke(at: location) }
            .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 10) { squeeze() }
            .simultaneousGesture(petting)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("톡 건드리거나 문질러 쓰다듬을 수 있어요"))
            .accessibilityAction(named: Text("톡 건드리기")) { poke(at: nil) }
            .accessibilityAction(named: Text("쓰다듬기")) { pet() }
            .onDisappear {
                reactionTask?.cancel()
                remarkTask?.cancel()
            }
            #if DEBUG
            // 확인·스크린샷용: 실행 인자 `-debug.pebble poke|hop|tilt|roll|startle|heart|squeeze|tickle|pet|dizzy`
            .task { await playDebugReaction() }
            #endif
    }

    // MARK: - 톡

    /// 한 번 톡 했을 때 고를 수 있는 반응들.
    private enum TapReaction: CaseIterable {
        case smile, hop, tiltHead, roll, startle, heart
    }

    private func poke(at location: CGPoint?) {
        let now = Date()
        recentTaps = recentTaps.filter { now.timeIntervalSince($0) < 1.4 } + [now]

        switch recentTaps.count {
        case 5...:
            recentTaps = []
            dizzy()
        case 2...4:
            tickle()
        default:
            if let location { push(from: location) }
            playTap(nextTapReaction())
        }
    }

    /// 직전과 다른 반응 하나. 동작 줄이기를 켠 사람에게는 크게 움직이는 것을 뺀다.
    private func nextTapReaction() -> TapReaction {
        var pool = TapReaction.allCases.filter { $0 != lastTap }
        if reduceMotion { pool.removeAll { $0 == .roll || $0 == .hop } }
        let picked = pool.randomElement() ?? .smile
        lastTap = picked
        return picked
    }

    private func playTap(_ reaction: TapReaction) {
        switch reaction {
        case .smile: smile()
        case .hop: hopUp()
        case .tiltHead: tiltHead()
        case .roll: roll()
        case .startle: startle()
        case .heart: heart()
        }
    }

    /// 누른 쪽의 반대로 살짝 밀렸다 돌아온다. 가운데를 누르면 거의 안 밀린다.
    private func push(from location: CGPoint) {
        let offCenter = max(-1, min(1, (location.x - size / 2) / (size / 2)))
        withAnimation(.easeOut(duration: 0.08)) { nudge = -offCenter * 5 }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.45).delay(0.08)) { nudge = 0 }
    }

    /// 웃으며 말랑하게 눌렸다 튀어 오른다.
    private func smile() {
        feel(.soft, intensity: 0.7)
        PebbleVoice.shared.chirp("헤헤")
        say(Self.pokeLines)
        emit("sparkle", count: 2)

        withAnimation(.easeOut(duration: 0.08)) { squash = 0.86 }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.42).delay(0.08)) { squash = 1 }
        react(.warm, for: 1.3)
    }

    /// 움츠렸다가 폴짝 뛰어올라 납작하게 내려앉는다.
    private func hopUp() {
        PebbleVoice.shared.chirp("폴짝", step: 0.06)
        say(Self.hopLines)
        react(.warm, for: 1.2)

        withAnimation(.easeOut(duration: 0.09)) { squash = 0.84 }
        withAnimation(.easeOut(duration: 0.2).delay(0.09)) {
            squash = 1.08
            hop = -size * 0.3
        }
        withAnimation(.easeIn(duration: 0.17).delay(0.29)) {
            squash = 1
            hop = 0
        }
        withAnimation(.easeOut(duration: 0.06).delay(0.46)) { squash = 0.82 }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.4).delay(0.52)) { squash = 1 }

        Task { @MainActor in
            feel(.soft, intensity: 0.5)
            try? await Task.sleep(for: .milliseconds(460))
            feel(.rigid, intensity: 0.6)   // 착지
        }
    }

    /// 고개를 갸웃한다. 무슨 일이냐는 듯이.
    private func tiltHead() {
        feel(.soft, intensity: 0.4)
        PebbleVoice.shared.chirp("응?")
        say(Self.tiltLines)
        react(.listening, for: 1.2)

        let side: Double = Bool.random() ? 1 : -1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { tilt = side * 13 }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.85)) { tilt = 0 }
    }

    /// 한 바퀴 데굴 구른다.
    private func roll() {
        feel(.soft, intensity: 0.6)
        PebbleVoice.shared.chirp("데구르르", step: 0.05)
        say(Self.rollLines)
        react(.warm, for: 1.1)

        let side: Double = Bool.random() ? 1 : -1
        withAnimation(.easeOut(duration: 0.1)) { squash = 0.9 }
        withAnimation(.easeInOut(duration: 0.62).delay(0.08)) {
            spin = side * 360
            squash = 1
        } completion: {
            // 한 바퀴 돈 자리는 처음과 같다. 움직임 없이 0으로 되돌린다.
            var quiet = Transaction()
            quiet.disablesAnimations = true
            withTransaction(quiet) { spin = 0 }
            feel(.soft, intensity: 0.4)
        }
    }

    /// 깜짝 놀라 길쭉해지며 살짝 튄다.
    private func startle() {
        feel(.rigid, intensity: 0.7)
        PebbleVoice.shared.chirp("앗", step: 0.05)
        say(Self.startleLines)
        react(.listening, for: 0.9)
        emit("exclamationmark", count: 1)

        withAnimation(.easeOut(duration: 0.07)) {
            squash = 1.14
            hop = -size * 0.08
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.45).delay(0.12)) {
            squash = 1
            hop = 0
        }
    }

    /// 하트가 몽글몽글 떠오른다.
    private func heart() {
        feel(.soft, intensity: 0.5)
        PebbleVoice.shared.chirp("헤헤")
        say(Self.heartLines)
        react(.warm, for: 1.6)
        emit("heart.fill", count: 3)

        withAnimation(.easeOut(duration: 0.1)) { squash = 0.92 }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1)) { squash = 1 }
    }

    // MARK: - 꾹 누르기

    /// 꾹 누르면 납작하게 눌렸다가 손을 떼듯 높이 튀어 오른다.
    private func squeeze() {
        recentTaps = []
        feel(.rigid, intensity: 0.4)
        PebbleVoice.shared.chirp("으읏", step: 0.09)
        say(Self.squeezeLines)
        reactionTask?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) { reaction = .thinking }
        withAnimation(.easeIn(duration: 0.3)) { squash = 0.7 }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            feel(.rigid, intensity: 0.8)
            PebbleVoice.shared.chirp("뿅")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { remark = Phrasing.say("뿅!", "뿅!") }
            withAnimation(.easeOut(duration: 0.18)) {
                squash = 1.12
                hop = reduceMotion ? 0 : -size * 0.4
            }
            withAnimation(.easeIn(duration: 0.2).delay(0.18)) {
                squash = 1
                hop = 0
            }
            withAnimation(.easeOut(duration: 0.06).delay(0.38)) { squash = 0.84 }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.38).delay(0.44)) { squash = 1 }
            emit("sparkle", count: 3)
            react(.warm, for: 1.4)
        }
    }

    /// 톡톡. 간지러워서 부르르 떨며 크게 웃는다.
    private func tickle() {
        shiver += 1
        buzz(times: 4)
        PebbleVoice.shared.chirp("히히히", step: 0.06)
        say(Self.tickleLines)
        emit("music.note", count: 2)

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
                emit("heart.fill", count: 1)
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

    // MARK: - 떠오르는 것

    /// 하트·반짝이·음표 하나.
    private struct Floater: Identifiable {
        let id = UUID()
        let symbol: String
        /// 가운데에서 좌우로 벗어난 정도 (-1...1).
        let spread: CGFloat
        let delay: Double
    }

    private var floaterLayer: some View {
        ZStack {
            ForEach(floaters) { floater in
                FloaterView(floater: floater, size: size)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 돌 머리 위로 몇 개를 띄운다. 다 떠오르면 스스로 치운다.
    private func emit(_ symbol: String, count: Int) {
        let spreads: [CGFloat] = [-0.6, 0.55, -0.15, 0.3, -0.4]
        let start = Int.random(in: 0..<spreads.count)
        let batch = (0..<count).map { index in
            Floater(
                symbol: symbol,
                spread: spreads[(start + index) % spreads.count] + .random(in: -0.1...0.1),
                delay: Double(index) * 0.12
            )
        }
        floaters.append(contentsOf: batch)
        let ids = Set(batch.map(\.id))
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            floaters.removeAll { ids.contains($0.id) }
        }
    }

    private struct FloaterView: View {
        let floater: Floater
        let size: CGFloat
        @State private var risen = false

        var body: some View {
            Image(systemName: floater.symbol)
                .font(.system(size: max(12, size * 0.13), weight: .semibold))
                .foregroundStyle(floater.symbol == "heart.fill" ? Color.pink.opacity(0.75) : PebbleTheme.sunlight)
                .scaleEffect(risen ? 1 : 0.4)
                .opacity(risen ? 0 : 1)
                .offset(
                    x: floater.spread * size * 0.45 + (risen ? floater.spread * size * 0.12 : 0),
                    y: risen ? -size * 0.45 : size * 0.1
                )
                .onAppear {
                    withAnimation(.easeOut(duration: 1.2).delay(floater.delay)) { risen = true }
                }
        }
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

    private static let hopLines: [(formal: String, casual: String)] = [
        ("폴짝!", "폴짝!"),
        ("영차!", "영차!")
    ]

    private static let tiltLines: [(formal: String, casual: String)] = [
        ("응?", "응?"),
        ("무슨 일이에요?", "무슨 일이야?"),
        ("왜요?", "왜?")
    ]

    private static let rollLines: [(formal: String, casual: String)] = [
        ("데굴데굴", "데굴데굴"),
        ("한 바퀴!", "한 바퀴!")
    ]

    private static let startleLines: [(formal: String, casual: String)] = [
        ("앗!", "앗!"),
        ("깜짝이야!", "깜짝이야!")
    ]

    private static let heartLines: [(formal: String, casual: String)] = [
        ("좋아해요", "좋아해"),
        ("반가워요", "반가워")
    ]

    private static let squeezeLines: [(formal: String, casual: String)] = [
        ("으읏…", "으읏…"),
        ("납작…", "납작…")
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
        case "hop": hopUp()
        case "tilt": tiltHead()
        case "roll": roll()
        case "startle": startle()
        case "heart": heart()
        case "squeeze": squeeze()
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
