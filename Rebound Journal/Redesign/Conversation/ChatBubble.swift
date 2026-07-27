//
//  ChatBubble.swift
//  Rebound Journal
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(background)
                .clipShape(BubbleShape(pointingLeft: speaker == .pebble))
                .overlay {
                    BubbleShape(pointingLeft: speaker == .pebble)
                        .strokeBorder(border, lineWidth: 1)
                }

            if speaker == .pebble { Spacer(minLength: 44) }
        }
    }

    private var background: Color {
        speaker == .pebble ? PebbleTheme.surface : PebbleTheme.sunlight.opacity(0.16)
    }

    private var border: Color {
        speaker == .pebble ? PebbleTheme.hairline : PebbleTheme.sunlight.opacity(0.30)
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
        let big: CGFloat = 20
        let small: CGFloat = 6

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

// MARK: - 타이핑

/// 글자를 하나씩 드러내 조약돌이 지금 말하고 있는 것처럼 보이게 한다.
///
/// 문장이 길어도 전체 시간이 `maxDuration`을 넘지 않게 속도를 조절한다.
/// 기다림이 길어지면 대화가 아니라 로딩처럼 느껴지기 때문이다.
struct TypewriterText: View {

    let text: String
    var font: Font = PebbleTheme.companionFont(17)
    var onFinish: () -> Void = {}

    @State private var shownCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let perCharacter: Double = 0.038
    private static let maxDuration: Double = 1.8

    var body: some View {
        Text(String(text.prefix(shownCount)))
            .font(font)
            .foregroundStyle(PebbleTheme.ink)
            .lineSpacing(5)
            .frame(maxWidth: .infinity, alignment: .leading)
            // 글자가 늘어나며 말풍선이 커질 때 덜컥거리지 않게 한다.
            .animation(.easeOut(duration: 0.08), value: shownCount)
            .task(id: text) { await reveal() }
            // 낭독 중에도 전체 문장을 읽어주고, 중간 상태를 계속 다시 읽지 않게 한다.
            .accessibilityLabel(text)
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
        let step = min(Self.perCharacter, Self.maxDuration / Double(glyphs.count))
        TypingFeedback.shared.begin(step: step)

        for index in glyphs.indices {
            try? await Task.sleep(for: .seconds(step))
            guard !Task.isCancelled else {
                // 화면을 벗어나거나 건너뛰면 소리도 함께 멈춘다.
                TypingFeedback.shared.end()
                return
            }
            shownCount = index + 1
            TypingFeedback.shared.tick(
                glyphs[index],
                progress: Double(index) / Double(glyphs.count),
                step: step
            )
        }

        TypingFeedback.shared.end()
        onFinish()
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
        .accessibilityLabel("조약돌이 생각하고 있어요")
    }
}
