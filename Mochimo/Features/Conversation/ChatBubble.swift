//
//  ChatBubble.swift
//  Mochimo
//
//  대화를 메신저처럼 보이게 하는 조각들.
//
//  말풍선으로 주고받는 형태를 고른 이유는, 사용자가 이미 아는 문법이기 때문이다.
//  설명 없이도 "이건 대화다"라고 읽히고, 자기가 한 말이 오른쪽에 쌓이는 걸 보면
//  털어놓은 것이 어디로 사라지지 않았다는 게 눈에 보인다 (§7).
//

import SwiftUI

// MARK: - 말풍선

struct ChatBubble<Content: View>: View {

    enum Speaker {
        case pebble
        case user
    }

    let speaker: Speaker
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if speaker == .user { Spacer(minLength: 44) }

            content
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(background)
                .clipShape(BubbleShape(pointingLeft: speaker == .pebble))
                // 선 대신 따뜻한 그림자로 살짝 띄운다. 선을 두르면 서류 칸처럼 딱딱하다.
                .shadow(color: Color(red: 0.65, green: 0.44, blue: 0.16).opacity(0.10), radius: 10, y: 4)

            if speaker == .pebble { Spacer(minLength: 44) }
        }
    }

    private var background: Color {
        speaker == .pebble ? PebbleTheme.surface : PebbleTheme.mochi.opacity(0.55)
    }
}

/// 한쪽 아래 모서리만 각지게 남긴 말풍선.
///
/// 꼬리를 뾰족하게 그리면 만화처럼 되어 이 앱의 조용한 톤과 어긋난다.
/// 모서리 하나만 덜 둥글게 두는 정도로 방향을 알린다.
struct BubbleShape: InsettableShape {
    var pointingLeft: Bool
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> BubbleShape {
        var copy = self
        copy.inset += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        // 모서리마다 반지름이 달라야 해서 직접 그린다. UIBezierPath의
        // byRoundingCorners는 고른 모서리에 같은 반지름 하나만 줄 수 있다.
        let r = rect.insetBy(dx: inset, dy: inset)
        let big: CGFloat = 24
        let small: CGFloat = 8

        let topLeft = big
        let topRight = big
        let bottomLeft = pointingLeft ? small : big
        let bottomRight = pointingLeft ? big : small

        var path = Path()
        path.move(to: CGPoint(x: r.minX + topLeft, y: r.minY))

        path.addLine(to: CGPoint(x: r.maxX - topRight, y: r.minY))
        path.addArc(
            center: CGPoint(x: r.maxX - topRight, y: r.minY + topRight),
            radius: topRight,
            startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )

        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - bottomRight))
        path.addArc(
            center: CGPoint(x: r.maxX - bottomRight, y: r.maxY - bottomRight),
            radius: bottomRight,
            startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )

        path.addLine(to: CGPoint(x: r.minX + bottomLeft, y: r.maxY))
        path.addArc(
            center: CGPoint(x: r.minX + bottomLeft, y: r.maxY - bottomLeft),
            radius: bottomLeft,
            startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )

        path.addLine(to: CGPoint(x: r.minX, y: r.minY + topLeft))
        path.addArc(
            center: CGPoint(x: r.minX + topLeft, y: r.minY + topLeft),
            radius: topLeft,
            startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - 답할 말

/// 고를 수 있는 답 하나.
struct ReplyChoice: Identifiable, Equatable {
    let id: String
    let label: String
    /// 그 자리의 주된 답인지. 하나만 참이어야 한다.
    var isPrimary: Bool = false
}

/// 아직 하지 않은 내 말.
///
/// 처음에는 내 말풍선과 같은 모양으로 두었다. 그랬더니 이미 보낸 말인지, 지금
/// 눌러야 하는 것인지 헷갈렸다. 오른쪽에 붙은 알약으로 바꿔도 여전히 말풍선
/// 줄기의 일부처럼 보였다. 그래서 대화 줄기와 완전히 다른 문법을 쓴다.
///
///  - 보낸 말: 한쪽에 붙은 말풍선, 글자 길이만큼의 폭
///  - 고를 말: 화면 폭을 채우는 버튼, 굵은 글자, 그림자, 누르면 눌린다
///
/// 고르면 내 말풍선이 되어 위로 올라간다.
struct ReplyChip: View {
    let label: String
    var isPrimary: Bool = false
    var action: () -> Void

    private static let radius: CGFloat = 26

    var body: some View {
        Button {
            TypingFeedback.shared.tap()
            action()
        } label: {
            Text(label)
                .font(PebbleTheme.body(17).weight(.semibold))
                .foregroundStyle(PebbleTheme.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(MochiButtonStyle(
            fill: isPrimary ? PebbleTheme.mochi : PebbleTheme.surface,
            edge: isPrimary ? PebbleTheme.mochiEdge : PebbleTheme.surfaceEdge,
            radius: Self.radius
        ))
        .accessibilityHint(Text("눌러서 이 말로 답해요"))
    }
}

/// 찹쌀떡 버튼.
///
/// 아래에 떡의 두께가 비친다. 누르면 그 두께만큼 꾹 꺼지며 옆으로 살짝 퍼지고,
/// 놓으면 통 튀어 올라 한 번 출렁인다. 눌리는 것이 손에 느껴져야 말풍선이 아니라
/// 버튼으로 읽힌다.
struct MochiButtonStyle: ButtonStyle {
    var fill: Color = PebbleTheme.mochi
    var edge: Color = PebbleTheme.mochiEdge
    var radius: CGFloat = 26
    /// 떡의 두께.
    var depth: CGFloat = 5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return configuration.label
            .background {
                ZStack {
                    shape.fill(edge).offset(y: pressed ? 1 : depth)
                    shape.fill(fill)
                    // 윗면의 윤기.
                    shape.fill(
                        LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0)],
                                       startPoint: .top, endPoint: .center)
                    )
                }
                .shadow(color: Color(red: 0.65, green: 0.44, blue: 0.16).opacity(pressed ? 0.06 : 0.14),
                        radius: pressed ? 4 : 12, y: pressed ? 2 : 8)
            }
            .contentShape(shape)
            .offset(y: pressed ? depth - 1 : 0)
            .scaleEffect(x: pressed && !reduceMotion ? 1.03 : 1, y: pressed && !reduceMotion ? 0.95 : 1, anchor: .bottom)
            .padding(.bottom, depth)
            .animation(
                pressed ? .easeOut(duration: 0.08) : .spring(response: 0.32, dampingFraction: 0.42),
                value: pressed
            )
    }
}

/// 고를 수 있는 답들을 버튼으로 쌓는다.
///
/// 고를 것이 둘 이상이면 위에 "골라서 답하기"를 작게 붙인다. 지금이 내가 고를
/// 차례라는 것을 말풍선 줄기와 따로 알린다.
struct ReplyOptions: View {
    let choices: [ReplyChoice]
    var onSelect: (ReplyChoice) -> Void

    var body: some View {
        VStack(spacing: 14) {
            if choices.count > 1 {
                ReplyHint()
            }
            ForEach(choices) { choice in
                ReplyChip(label: choice.label, isPrimary: choice.isPrimary) {
                    onSelect(choice)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 지금 고를 차례라는 작은 표시.
struct ReplyHint: View {
    var body: some View {
        Label {
            Text(Phrasing.say("골라서 답해 주세요", "골라서 답해 줘"))
        } icon: {
            Image(systemName: "hand.tap")
        }
        .font(PebbleTheme.label(14))
        .foregroundStyle(PebbleTheme.inkSoft)
        .accessibilityHidden(true)
    }
}

// MARK: - 타이핑

/// 글자를 하나씩 드러내 조약돌이 지금 말하고 있는 것처럼 보이게 한다.
///
/// 사람이 치는 것처럼 보이려면 속도만 늦춰서는 안 된다. 간격이 일정하면 아무리
/// 느려도 기계가 뿌리는 것으로 읽힌다. 그래서 세 가지를 함께 쓴다.
///
///  1. 사람이 또박또박 치는 정도의 기본 속도 (초당 8~9자)
///  2. 글자마다 간격을 흔든다 — 사람은 일정한 박자로 치지 않는다
///  3. 문장부호에서 쉰다 — 마침표 뒤에서 숨을 고르고 다음 문장을 시작한다
///
/// 문장이 길면 전체 시간이 `maxDuration`을 넘지 않게 기본 속도를 줄인다.
/// 기다림이 길어지면 대화가 아니라 로딩처럼 느껴지기 때문이다.
struct TypewriterText: View {

    let text: String
    var font: Font = PebbleTheme.companionFont(17)
    var onFinish: () -> Void = {}

    @State private var shownCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 글자 사이 기본 간격. 초당 12~13자 — 익숙한 사람이 치는 속도다.
    private static let perCharacter: Double = 0.078

    /// 문장부호에서 쉬는 시간을 뺀, 글자만의 총 시간 상한.
    private static let maxDuration: Double = 3.6

    /// 간격이 흔들리는 폭. 사람은 같은 박자로 치지 않는다.
    private static let jitter: ClosedRange<Double> = 0.7...1.35

    /// 커서가 깜빡이는 주기. 키보드 커서와 비슷하게 잡았다.
    private static let caretBlink: Double = 0.5

    @State private var isTyping = false
    @State private var caretOn = true

    private let blinkTimer = Timer
        .publish(every: TypewriterText.caretBlink, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        line
            .font(font)
            .lineSpacing(5)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            // 글자 수가 바뀔 때 애니메이션을 걸지 않는다. 걸면 SwiftUI가 앞뒤 상태를
            // 겹쳐 넘기면서 커서가 둘로 보인다.
            .task(id: text) { await reveal() }
            .onReceive(blinkTimer) { _ in
                guard isTyping else { return }
                caretOn.toggle()
            }
            // 낭독 중에도 전체 문장을 읽어주고, 중간 상태를 계속 다시 읽지 않게 한다.
            .accessibilityLabel(text)
    }

    /// 드러난 글자 + 커서.
    ///
    /// 커서를 따로 겹쳐 그리면 줄바꿈된 문장의 끝을 따라가기 어렵다. 글자 뒤에
    /// 이어 붙이면 위치 계산 없이 언제나 마지막 글자 옆에 선다.
    private var line: Text {
        let shown = Text(String(text.prefix(shownCount)))
            .foregroundStyle(PebbleTheme.ink)

        guard isTyping else { return shown }

        // 자리는 늘 차지하고 색만 바꾼다. 커서가 나타났다 사라지면 글자가 흔들린다.
        return shown + Text("|")
            .foregroundStyle(caretOn ? PebbleTheme.key : Color.clear)
    }

    private func reveal() async {
        let glyphs = Array(text)
        guard !glyphs.isEmpty else {
            onFinish()
            return
        }

        // 동작 줄이기를 켠 사용자에게는 한 번에 보여준다. 소리와 진동도 내지 않는다 —
        // 글자가 이미 다 나와 있는데 소리만 이어지면 무엇에 대한 소리인지 알 수 없다.
        guard !reduceMotion else {
            shownCount = glyphs.count
            onFinish()
            return
        }

        shownCount = 0
        isTyping = true
        caretOn = true

        // 문장이 길면 기본 속도를 줄여 전체 시간을 묶어 둔다.
        let step = min(Self.perCharacter, Self.maxDuration / Double(glyphs.count))
        TypingFeedback.shared.begin(step: step)

        for index in glyphs.indices {
            // 사람은 같은 박자로 치지 않는다. 흔들림이 없으면 느려도 기계로 읽힌다.
            let wait = step * Double.random(in: Self.jitter)
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else {
                // 화면을 벗어나거나 건너뛰면 소리도 함께 멈춘다.
                stopTyping()
                return
            }

            shownCount = index + 1
            TypingFeedback.shared.tick(
                glyphs[index],
                progress: Double(index) / Double(glyphs.count),
                step: step
            )

            // 문장부호 뒤에서 숨을 고른다. 여기서 쉬어야 읽는 리듬이 생긴다.
            let breath = Self.pause(after: glyphs[index])
            if breath > 0 {
                // 쉬는 동안 커서는 켜 둔다. 멈춘 게 아니라 뜸을 들이는 것이다.
                caretOn = true
                try? await Task.sleep(for: .seconds(breath))
                guard !Task.isCancelled else {
                    stopTyping()
                    return
                }
            }
        }

        stopTyping()
        onFinish()
    }

    private func stopTyping() {
        isTyping = false
        TypingFeedback.shared.end()
    }

    /// 글자 뒤에 쉬는 시간.
    ///
    /// 치는 속도가 빨라졌으니 쉼도 같이 줄인다. 쉼만 그대로 두면 글자는 빠른데
    /// 문장 사이에서만 늘어져 박자가 어긋난다.
    private static func pause(after character: Character) -> Double {
        switch character {
        case ".", "!", "?": 0.30      // 문장이 끝났다
        case "\n": 0.24               // 줄을 바꿨다
        case ",": 0.13                // 잠깐 끊었다
        default: 0
        }
    }
}

// MARK: - 말 준비 중

/// 조약돌이 다음 말을 고르는 동안 띄우는 점 세 개.
///
/// 답이 즉시 튀어나오면 자동응답처럼 읽힌다. 아주 짧은 뜸이 있어야 듣고
/// 생각한 것처럼 느껴진다.
struct ThinkingDots: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(PebbleTheme.inkFaint)
                    .frame(width: 6, height: 6)
                    .opacity(phase == index ? 1 : 0.3)
                    .scaleEffect(phase == index ? 1.15 : 1)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: phase)
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
        .accessibilityLabel("모찌모가 생각하고 있어요")
    }
}
