//
//  PebbleView.swift
//  ZinggumDol
//
//  곁에 있는 동물 친구를 코드로만 그린다. 이미지 에셋을 쓰지 않으므로
//  크기·표정·색이 전부 상태에 반응한다.
//
//  그림 문법은 '모찌'다. 납작한 찹쌀떡 몸, 그라데이션 없는 한 가지 색, 얇은 갈색 선,
//  멀찍이 낮게 놓인 점 눈, ω 입. 덜어 낼수록 순하고 귀여워진다. 동물은 귀와 코로만
//  가른다. 위의 `PebbleShape` 는 이제 징검다리 돌에만 쓴다.
//

import SwiftUI

// MARK: - 형태

/// 조약돌 실루엣.
///
/// 손으로 베지에 꼭짓점을 찍으면 아무리 다듬어도 둥근 사각형처럼 보인다. 그래서
/// 타원의 반지름을 각도에 따라 조금씩 흔들고, 그 점들을 부드럽게 이어 닫는다.
/// 대칭이 깨져야 "도형"이 아니라 "돌"로 읽힌다.
struct PebbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2
        let ry = rect.height / 2
        let steps = 32

        // 타입을 하나하나 못박아 둔다. CGFloat과 Double을 섞어 두면 이 식 하나로
        // 타입 검사 시간이 폭발한다.
        let points: [CGPoint] = (0..<steps).map { index in
            let angle: CGFloat = 2 * .pi * CGFloat(index) / CGFloat(steps)

            // 두 개의 느린 물결을 겹쳐 규칙적이지 않게 만든다.
            let wobble: CGFloat = 1
                + 0.040 * cos(angle * 2 + 0.7)
                + 0.022 * cos(angle * 3 - 1.2)

            // 아래쪽(y가 커지는 방향)은 땅에 닿아 살짝 눌린다.
            let settle: CGFloat = 1 - 0.07 * max(0, sin(angle))

            let radius: CGFloat = wobble * settle
            return CGPoint(
                x: center.x + rx * radius * cos(angle),
                y: center.y + ry * radius * sin(angle)
            )
        }

        return .smoothClosedCurve(through: points)
    }
}

extension Path {
    /// 점들을 지나는 부드러운 닫힌 곡선 (Catmull-Rom을 3차 베지에로 변환).
    static func smoothClosedCurve(through points: [CGPoint]) -> Path {
        guard points.count > 2 else { return Path() }

        var path = Path()
        path.move(to: points[0])

        for index in 0..<points.count {
            let previous = points[(index - 1 + points.count) % points.count]
            let start = points[index]
            let end = points[(index + 1) % points.count]
            let next = points[(index + 2) % points.count]

            let control1 = CGPoint(
                x: start.x + (end.x - previous.x) / 6,
                y: start.y + (end.y - previous.y) / 6
            )
            let control2 = CGPoint(
                x: end.x - (next.x - start.x) / 6,
                y: end.y - (next.y - start.y) / 6
            )
            path.addCurve(to: end, control1: control1, control2: control2)
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - 캐릭터

struct PebbleView: View {
    var mood: PebbleMood = .resting
    var size: CGFloat = 160
    /// 말하는 중이면 입이 미세하게 움직인다(Animalese 재생과 맞물린다).
    var isSpeaking: Bool = false

    @Environment(\.pebbleSkin) private var skin
    @Environment(\.pebbleBuddy) private var buddy
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    @State private var blinking = false
    /// 가만히 있다가 가끔 하는 몸짓. 귀를 쫑긋하거나 제자리에서 톡 뛴다.
    @State private var twitch: PebbleEarTwitch = .none
    @State private var idleHop: CGFloat = 0

    private var palette: PebblePalette { skin.palette(for: buddy) }

    /// 후광까지 포함한 실제 차지 영역.
    ///
    /// 몸 크기로만 프레임을 잡으면 후광이 프레임 밖으로 삐져나가고, 바로 아래에
    /// 놓인 글자와 겹친다. 그려지는 만큼을 레이아웃에도 정직하게 알려야 한다.
    private var footprint: CGSize {
        CGSize(width: size * 1.35, height: size * 1.05)
    }

    var body: some View {
        ZStack {
            sunGlow
            groundShadow
            chewyBody
            MochiAccents(buddy: buddy, palette: palette, size: size, twitch: twitch)
            face
        }
        // 표정·결이 바뀔 때의 전환은 그림 안쪽에만 건다.
        .animation(.easeInOut(duration: 0.45), value: mood)
        .animation(.easeInOut(duration: 0.45), value: skin)
        .frame(width: footprint.width, height: footprint.height)
        // 귀가 솟은 만큼 위로 자리를 더 잡는다. 몸은 바닥에 그대로 앉아 있다.
        .frame(height: footprint.height + size * buddy.earRise, alignment: .bottom)
        // 호흡의 무한 반복은 **크기에만** 건다.
        //
        // 예전에는 `.animation(repeatForever, value: breathing)`이 전체에 걸려 있었다.
        // 호흡이 시작되는 순간(시트가 올라오는 중, 목록이 자리를 잡는 중) 함께 바뀐
        // 위치까지 무한 반복으로 잡혀서, 숨 쉬는 게 아니라 제자리를 벗어나 위아래로
        // 널뛰었다. 여럿이 모인 '고르기' 칸에서 특히 심했다.
        .animation(.easeInOut(duration: mood.breathPeriod / 2).repeatForever(autoreverses: true)) { content in
            // 위로 늘어날 때 옆은 줄고, 내려앉을 때 옆으로 퍼진다. 부피가 그대로여야
            // 딱딱한 것이 커졌다 작아지는 게 아니라 말랑한 떡이 숨 쉬는 걸로 읽힌다.
            content.scaleEffect(
                x: breathing ? 0.985 : 1.022,
                y: breathing ? 1.032 : 0.972,
                anchor: .bottom
            )
        }
        // '동작 줄이기'를 켜면 숨쉬기를 멈추고 가만히 있는다.
        .onAppear { breathing = !reduceMotion }
        .onChange(of: reduceMotion) { _, reduce in breathing = !reduce }
        .offset(y: idleHop)
        .task(id: mood) { await blinkLoop() }
        .task(id: reduceMotion) { if !reduceMotion { await fidgetLoop() } }
        .accessibilityElement()
        .accessibilityLabel(Text(buddy.name))
        .accessibilityValue(accessibilityMood)
    }

    // MARK: 자리 (가운데를 원점으로, 크기 대비)

    private enum Layout {
        static let bodyWidth: CGFloat = 1.08
        static let bodyHeight: CGFloat = 0.74
        /// 몸 가운데. 아래로 내려 앉혀 그림자 자리를 남긴다.
        static let bodyY: CGFloat = 0.10
        static let eyeY: CGFloat = 0.145
        static let eyeX: CGFloat = 0.20
        static let mouthY: CGFloat = 0.20
        static let line: CGFloat = 0.019
    }

    private func at(_ x: CGFloat, _ y: CGFloat) -> CGSize {
        CGSize(width: size * x, height: size * y)
    }

    // MARK: 뒤쪽 햇빛과 그림자

    private var sunGlow: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        PebbleTheme.sunlight.opacity(mood.glow * 0.7),
                        PebbleTheme.sunlight.opacity(0)
                    ],
                    center: .center,
                    startRadius: size * 0.18,
                    endRadius: size * 0.60
                )
            )
            .frame(width: footprint.width, height: footprint.height)
            .blur(radius: size * 0.05)
    }

    private var groundShadow: some View {
        Ellipse()
            .fill(Color.black.opacity(0.07))
            .frame(width: size * 0.82, height: size * 0.06)
            .offset(at(0, Layout.bodyY + Layout.bodyHeight / 2 + 0.005))
    }

    // MARK: 몸

    /// 쫀득한 찹쌀떡 몸.
    ///
    /// 몸과 귀를 한 실루엣으로 합쳐 한 번에 칠하고 한 번에 테를 두른다. 귀를 따로
    /// 그려 붙이면 이음매마다 선이 지나가 도형을 모아 놓은 것처럼 보인다.
    /// 위 왼쪽은 밝고 가장자리로 갈수록 그늘이 져서 무게가 실리고, 이마에 떡 같은
    /// 윤기가 돈다.
    private var chewyBody: some View {
        let flick = (left: twitch == .left ? 1.0 : 0, right: twitch == .right ? 1.0 : 0)
        let outline = ChewySilhouette(buddy: buddy, leftFlick: flick.left, rightFlick: flick.right)
        let earInside = ChewySilhouette(buddy: buddy, part: .earInside, leftFlick: flick.left, rightFlick: flick.right)
        let sheen = buddy.sheen
        return ZStack {
            outline.fill(
                RadialGradient(
                    colors: [
                        palette.fill.mix(with: .white, by: 0.6),
                        palette.fill,
                        palette.fill.mix(with: palette.line, by: 0.13)
                    ],
                    center: UnitPoint(x: 0.42, y: 0.45),
                    startRadius: 0,
                    endRadius: size * 0.66
                )
            )
            if buddy == .hamster {
                Ellipse()
                    .fill(palette.belly)
                    .frame(width: size * 0.9, height: size * 0.5)
                    .offset(at(0, 0.37))
                    .blur(radius: size * 0.008)
            }
            earInside
                .fill(buddy.earInsideColor(palette))
                .blur(radius: size * 0.012)
            // 가장자리 안쪽의 그늘. 테두리 바로 안이 살짝 어두워야 몸이 둥글게 부푼다.
            outline
                .stroke(palette.line.opacity(0.18), lineWidth: size * 0.1)
                .blur(radius: size * 0.05)
            // 이마의 윤기.
            Ellipse()
                .fill(Color.white.opacity(sheen))
                .frame(width: size * 0.32, height: size * 0.11)
                .rotationEffect(.degrees(-20))
                .offset(at(-0.21, -0.07))
                .blur(radius: size * 0.022)
            Ellipse()
                .fill(Color.white.opacity(sheen))
                .frame(width: size * 0.14, height: size * 0.045)
                .rotationEffect(.degrees(-20))
                .offset(at(-0.24, -0.085))
                .blur(radius: size * 0.007)
            Circle()
                .fill(Color.white.opacity(sheen))
                .frame(width: size * 0.04)
                .offset(at(-0.4, 0.06))
                .blur(radius: size * 0.006)
        }
        .frame(width: footprint.width, height: footprint.height)
        .clipShape(outline)
        .overlay {
            outline.stroke(
                LinearGradient(
                    colors: [palette.line.mix(with: palette.fill, by: 0.3), palette.line],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: max(1, size * 0.02), lineJoin: .round)
            )
        }
    }

    // MARK: 표정

    private var face: some View {
        ZStack {
            // 볼
            ForEach([-1.0, 1.0], id: \.self) { side in
                Ellipse()
                    .fill(Color(red: 0.97, green: 0.64, blue: 0.65).opacity(min(0.75, mood.blush * 2.4)))
                    .frame(width: size * 0.15, height: size * 0.085)
                    .blur(radius: size * 0.018)
                    .offset(at(side * 0.285, Layout.eyeY + 0.085))
            }
            if buddy == .raccoon {
                // 눈가를 두른 마스크. 바깥으로 살짝 처져야 순해 보인다.
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Ellipse()
                        .fill(palette.line.opacity(0.55))
                        .frame(width: size * 0.19, height: size * 0.12)
                        .rotationEffect(.degrees(side * 14))
                        .offset(at(side * (Layout.eyeX + 0.01), Layout.eyeY + 0.005))
                }
            }
            if buddy == .bear || buddy == .raccoon {
                Ellipse()
                    .fill(palette.belly)
                    .frame(width: size * 0.24, height: size * 0.15)
                    .offset(at(0, Layout.mouthY - 0.02))
            }
            if buddy == .capybara {
                // 뭉툭하고 넓은 코끝. 카피바라는 얼굴의 절반이 코다.
                Capsule()
                    .fill(palette.belly)
                    .frame(width: size * 0.36, height: size * 0.19)
                    .offset(at(0, Layout.mouthY + 0.005))
            }
            if buddy == .seal {
                // 수염 자리 점.
                ForEach([-1.0, 1.0], id: \.self) { side in
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(palette.line.opacity(0.6))
                            .frame(width: size * 0.016)
                            .offset(at(side * (0.085 + Double(i % 2) * 0.03), Layout.mouthY - 0.02 + Double(i) * 0.022))
                    }
                }
            }
            ForEach([-1.0, 1.0], id: \.self) { side in
                eye.offset(at(side * Layout.eyeX, Layout.eyeY))
            }
            nose
            if buddy == .kiwi {
                beak
            } else {
                mouth.offset(at(0, Layout.mouthY + buddy.mouthDrop))
            }
        }
    }

    @ViewBuilder
    private var eye: some View {
        let closed = blinking || mood.eyeCurve > 0.25
        if closed {
            // 웃거나 눈을 감은 상태 — 위로 볼록한 선.
            FaceArc(curve: -0.75)
                .stroke(palette.pupil, style: .init(lineWidth: max(1, size * 0.02), lineCap: .round))
                .frame(width: size * 0.095, height: size * 0.036)
        } else {
            // 점 눈. 크지 않고 멀찍이 낮게 있어야 멍하고 순해 보인다.
            // 살짝 세로로 긴 눈에 반짝임 둘. 점 하나보다 촉촉하고 살아 있다.
            let e = size * buddy.eyeSize
            ZStack {
                Ellipse()
                    .fill(palette.pupil)
                    .frame(width: e * 1.05, height: e * 1.25)
                Circle()
                    .fill(Color.white)
                    .frame(width: e * 0.4)
                    .offset(x: e * 0.18, y: -e * 0.25)
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: e * 0.17)
                    .offset(x: -e * 0.2, y: e * 0.3)
            }
        }
    }

    @ViewBuilder
    private var nose: some View {
        switch buddy {
        case .bear:
            Ellipse()
                .fill(palette.pupil)
                .frame(width: size * 0.058, height: size * 0.04)
                .offset(at(0, Layout.mouthY - 0.035))
        case .bunny, .hamster:
            Ellipse()
                .fill(Color(red: 0.96, green: 0.55, blue: 0.6))
                .frame(width: size * 0.036, height: size * 0.025)
                .offset(at(0, Layout.mouthY - 0.03))
        case .seal, .raccoon:
            Ellipse()
                .fill(palette.pupil)
                .frame(width: size * 0.05, height: size * 0.034)
                .offset(at(0, Layout.mouthY - 0.035))
        case .capybara:
            // 넓은 코 위 콧구멍 두 개.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule()
                    .fill(palette.pupil)
                    .frame(width: size * 0.03, height: size * 0.018)
                    .rotationEffect(.degrees(side * 20))
                    .offset(at(side * 0.05, Layout.mouthY - 0.035))
            }
        case .cat, .kiwi:
            EmptyView()
        }
    }

    /// 키위새의 길고 가는 부리. 말할 때 부리 끝이 살랑인다.
    private var beak: some View {
        KiwiBeakShape()
            .fill(Color(red: 0.93, green: 0.86, blue: 0.70))
            .overlay {
                KiwiBeakShape().stroke(palette.line, style: .init(lineWidth: max(1, size * 0.014), lineJoin: .round))
            }
            .frame(width: size * 0.09, height: size * 0.24)
            .rotationEffect(.degrees(isSpeaking ? 7 : (mood.mouthOpen > 0 ? -5 : 0)), anchor: .top)
            .offset(at(0, Layout.eyeY + 0.12))
            .animation(
                isSpeaking && !reduceMotion
                    ? .easeInOut(duration: 0.16).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.2),
                value: isSpeaking
            )
    }

    /// 다문 입은 ω. 크게 웃거나 말할 때만 벌린다.
    @ViewBuilder
    private var mouth: some View {
        if !isSpeaking && mood.mouthOpen == 0 {
            OmegaMouthShape()
                .stroke(palette.pupil, style: .init(lineWidth: max(1, size * 0.017), lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.105, height: size * 0.03)
        } else {
            openMouth
        }
    }

    private var openMouth: some View {
        let open: CGFloat = isSpeaking ? 0.7 : mood.mouthOpen
        let shape = MouthShape(curve: mood.mouthCurve, open: open)
        return shape
            .fill(palette.pupil)
            .overlay {
                // 벌린 입 안쪽의 혀.
                Ellipse()
                    .fill(Color(red: 0.95, green: 0.49, blue: 0.54))
                    .frame(width: size * 0.06, height: size * 0.045)
                    .offset(y: size * 0.04)
                    .opacity(Double(min(1, open * 1.6)))
                    .clipShape(shape)
            }
            .frame(
                width: size * (isSpeaking ? 0.1 : 0.095),
                height: size * (isSpeaking ? 0.055 : 0.042)
            )
            .animation(
                isSpeaking && !reduceMotion
                    ? .easeInOut(duration: 0.16).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.2),
                value: isSpeaking
            )
    }

    // MARK: 깜빡임 · 몸짓

    /// 일정 간격이 아니라 조금씩 다른 간격으로 깜빡여야 살아 있는 느낌이 난다.
    private func blinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 2.8...6.5)))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.07)) { blinking = true }
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeInOut(duration: 0.09)) { blinking = false }
        }
    }

    /// 몇 초에 한 번, 귀를 쫑긋하거나 톡 뛴다. 간격이 들쭉날쭉해야 살아 있는 것 같다.
    private func fidgetLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 4...9)))
            guard !Task.isCancelled else { return }
            if Bool.random() {
                let ear: PebbleEarTwitch = Bool.random() ? .left : .right
                withAnimation(.spring(response: 0.18, dampingFraction: 0.4)) { twitch = ear }
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { twitch = .none }
            } else {
                withAnimation(.easeOut(duration: 0.16)) { idleHop = -size * 0.07 }
                try? await Task.sleep(for: .milliseconds(160))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { idleHop = 0 }
            }
        }
    }

    private var accessibilityMood: String {
        switch mood {
        case .resting: String(localized: "곁에 있어요")
        case .listening: String(localized: "듣고 있어요")
        case .thinking: String(localized: "생각하고 있어요")
        case .warm: String(localized: "기뻐하고 있어요")
        }
    }
}

/// 얼굴에 쓰는 호.
///
/// `curve`가 **양수면 아래로 볼록**해 웃는 입이 되고, **음수면 위로 볼록**해
/// 감은 눈이 된다. 부호를 지정하지 않으면 입이 찡그린 모양으로 뒤집히기 쉬워서
/// 방향을 형태 안에 못박아 두었다.
struct FaceArc: Shape {
    var curve: CGFloat

    var animatableData: CGFloat {
        get { curve }
        set { curve = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // 볼록해지는 반대편 변을 기준선으로 삼는다.
        let baseline = curve >= 0 ? rect.minY : rect.maxY
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: baseline))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: baseline),
            control: CGPoint(x: rect.midX, y: baseline + rect.height * 1.8 * curve)
        )
        return path
    }
}

/// 입. `open`이 0이면 한 줄짜리 미소, 커질수록 윗입술은 펴지고 아랫입술이 내려가
/// 벌린 입이 된다. 한 형태가 두 표정을 다 맡아야 표정 사이를 매끄럽게 오간다.
struct MouthShape: Shape {
    var curve: CGFloat
    var open: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(curve, open) }
        set { curve = newValue.first; open = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        // 닫힌 입일 때 두 곡선이 정확히 겹쳐 한 줄이 되고, 벌어질수록 아랫입술의
        // 조절점이 양 끝으로 벌어져 뾰족한 V 가 아니라 둥근 바가지 모양이 된다.
        let depth = rect.height * 1.2 * curve
        let left = CGPoint(x: rect.minX, y: rect.minY)
        let right = CGPoint(x: rect.maxX, y: rect.minY)
        let upper = rect.minY + depth * (1 - 0.8 * open)
        let lower = rect.minY + depth * (1 + 0.9 * open)
        let inset = rect.width * (1 / 3 - 0.27 * open)
        var path = Path()
        path.move(to: left)
        path.addCurve(
            to: right,
            control1: CGPoint(x: rect.minX + rect.width / 3, y: upper),
            control2: CGPoint(x: rect.maxX - rect.width / 3, y: upper)
        )
        path.addCurve(
            to: left,
            control1: CGPoint(x: rect.maxX - inset, y: lower),
            control2: CGPoint(x: rect.minX + inset, y: lower)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - 모찌의 생김새

enum PebbleEarTwitch { case none, left, right }

private let innerPink = Color(red: 0.97, green: 0.72, blue: 0.74)

private extension PebbleBuddy {
    /// 코가 있으면 입이 그만큼 내려간다. 카피바라는 넓은 코 아래로 더.
    var mouthDrop: CGFloat {
        switch self {
        case .cat: 0
        case .capybara: 0.035
        default: 0.012
        }
    }

    /// 점 눈 지름. 하프물범 새끼는 눈이 크고 까맣다.
    var eyeSize: CGFloat { self == .seal ? 0.085 : 0.07 }
}

/// 찹쌀떡 실루엣 — 위는 둥글게 솟고, 아래는 바닥에 눌려 넓게 퍼진다.
struct MochiShape: Shape {
    func path(in rect: CGRect) -> Path {
        // 200×200 시안의 (24,76)–(176,180) 상자를 그대로 옮긴다.
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + (x - 24) / 152 * rect.width,
                    y: rect.minY + (y - 76) / 104 * rect.height)
        }
        var path = Path()
        path.move(to: p(24, 142))
        path.addCurve(to: p(100, 76), control1: p(24, 96), control2: p(58, 76))
        path.addCurve(to: p(176, 142), control1: p(142, 76), control2: p(176, 96))
        path.addCurve(to: p(100, 180), control1: p(176, 170), control2: p(146, 180))
        path.addCurve(to: p(24, 142), control1: p(54, 180), control2: p(24, 170))
        path.closeSubpath()
        return path
    }
}

/// 몸과 귀를 합친 실루엣, 또는 귀 안쪽만.
///
/// 그리는 칸은 `PebbleView`의 바닥 칸(가로 1.35 × 세로 1.05, 크기 대비)이다.
/// 가운데를 원점으로 몸과 귀를 같은 자리에 놓고, 귀는 밑동을 축으로 쫑긋한다.
struct ChewySilhouette: Shape {
    enum Part { case outline, earInside }

    let buddy: PebbleBuddy
    var part: Part = .outline
    var leftFlick: Double = 0
    var rightFlick: Double = 0

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(leftFlick, rightFlick) }
        set { leftFlick = newValue.first; rightFlick = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let size = rect.width / 1.35
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let ears = [-1.0, 1.0].compactMap { side in
            buddy.ear(side: side, flick: side < 0 ? leftFlick : rightFlick, size: size, center: center)
        }
        switch part {
        case .earInside:
            return ears.reduce(into: Path()) { $0.addPath($1.inside) }
        case .outline:
            let body = MochiShape().path(in: CGRect(
                x: center.x - size * 0.54, y: center.y + size * (0.10 - 0.37),
                width: size * 1.08, height: size * 0.74
            ))
            return ears.reduce(body) { $0.union($1.outline) }
        }
    }
}

private extension PebbleBuddy {
    /// 이마 윤기의 세기. 진한 털에서는 은은하게.
    var sheen: Double {
        switch self {
        case .bear, .capybara, .kiwi, .raccoon: 0.3
        case .hamster: 0.55
        default: 0.95
        }
    }

    func earInsideColor(_ palette: PebblePalette) -> Color {
        switch self {
        case .bear, .capybara: palette.belly
        case .raccoon: palette.line.opacity(0.5)
        default: innerPink
        }
    }

    /// 한쪽 귀의 겉과 안. `side`는 왼쪽 -1, 오른쪽 1. 귀가 없으면 nil.
    func ear(side: CGFloat, flick: Double, size: CGFloat, center: CGPoint) -> (outline: Path, inside: Path)? {
        // 귀 하나의 칸(크기 대비)과 놓일 자리, 기울기. 오른쪽은 왼쪽을 거울로 비춘다.
        let x, y, w, h: CGFloat
        var tilt: Double
        var mirrored = side > 0
        let outer: (CGRect) -> Path
        let inner: (CGRect) -> Path
        switch self {
        case .cat, .raccoon:
            (x, y, w, h) = self == .cat ? (0.265, -0.255, 0.24, 0.27) : (0.27, -0.25, 0.22, 0.23)
            tilt = self == .cat ? 0 : 8
            outer = { CatEarShape().path(in: $0) }
            inner = { CatEarInnerShape().path(in: $0) }
        case .hamster, .bear, .capybara:
            let d: CGFloat = self == .hamster ? 0.14 : self == .bear ? 0.19 : 0.10
            (x, y, w, h) = self == .hamster ? (0.33, -0.21, d, d) : self == .bear ? (0.32, -0.215, d, d) : (0.30, -0.24, d, d)
            tilt = 0
            outer = { Circle().path(in: $0) }
            inner = { Circle().path(in: $0.insetBy(dx: $0.width * 0.25, dy: $0.height * 0.25)) }
        case .bunny:
            // 한쪽 귀는 서고, 한쪽은 옆으로 살짝 늘어졌다. 거울 없이 따로 기울인다.
            (x, y, w, h) = (0.15, -0.40, 0.15, 0.42)
            tilt = side < 0 ? 6 : 38
            mirrored = false
            outer = { Capsule().path(in: $0) }
            inner = { r in
                Capsule().path(in: CGRect(x: r.midX - size * 0.03, y: r.midY - size * 0.135 + size * 0.02,
                                          width: size * 0.06, height: size * 0.27))
            }
        case .seal, .kiwi:
            return nil
        }
        let frame = CGRect(x: -w * size / 2, y: -h * size / 2, width: w * size, height: h * size)
        // 왼쪽 귀는 바깥(-)으로, 오른쪽은 거울이라 같은 값이 바깥(+)으로 기운다.
        let flickDegrees = (self == .bunny ? (side < 0 ? 16 : 22) : 16) * flick
        let angle: Double = self == .bunny
            ? (side < 0 ? -tilt - flickDegrees : tilt - flickDegrees)
            : (side < 0 ? -tilt - flickDegrees : tilt + flickDegrees)
        var t = CGAffineTransform.identity
        if mirrored { t = t.concatenating(CGAffineTransform(scaleX: -1, y: 1)) }
        t = t.concatenating(CGAffineTransform(translationX: 0, y: -h * size / 2))
            .concatenating(CGAffineTransform(rotationAngle: angle * .pi / 180))
            .concatenating(CGAffineTransform(translationX: 0, y: h * size / 2))
            .concatenating(CGAffineTransform(translationX: center.x + side * x * size, y: center.y + y * size))
        return (outer(frame).applying(t), inner(frame).applying(t))
    }
}

/// 몸 바깥에 얹는 것들. 카피바라의 유자, 키위새의 삐친 털.
private struct MochiAccents: View {
    let buddy: PebbleBuddy
    let palette: PebblePalette
    let size: CGFloat
    var twitch: PebbleEarTwitch = .none

    private var line: CGFloat { max(1, size * 0.019) }

    var body: some View {
        switch buddy {
        case .capybara:
            yuzu.offset(x: size * 0.05, y: -size * 0.315)
        case .kiwi:
            KiwiTuftShape()
                .stroke(palette.line, style: .init(lineWidth: line, lineCap: .round))
                .frame(width: size * 0.10, height: size * 0.08)
                .offset(x: size * 0.01, y: -size * 0.30)
                .rotationEffect(.degrees(twitch == .none ? 0 : 10), anchor: .bottom)
        default:
            EmptyView()
        }
    }

    /// 온천의 카피바라처럼 아무렇지 않게 얹고 있는 유자.
    private var yuzu: some View {
        ZStack {
            Circle().fill(
                RadialGradient(colors: [Color(red: 1.0, green: 0.88, blue: 0.45), Color(red: 1.0, green: 0.74, blue: 0.2)],
                               center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.08)
            )
            Circle().stroke(Color(red: 0.78, green: 0.52, blue: 0.10), lineWidth: line)
            Ellipse()
                .fill(Color(red: 0.45, green: 0.70, blue: 0.35))
                .frame(width: size * 0.07, height: size * 0.035)
                .rotationEffect(.degrees(-25))
                .offset(x: size * 0.035, y: -size * 0.06)
        }
        .frame(width: size * 0.13, height: size * 0.13)
    }
}

/// 고양이 귀(왼쪽). 시안의 (46,56)–(80,94) 상자에서 옮긴 둥근 꼭짓점 세모.
private struct CatEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + (x - 46) / 34 * rect.width, y: rect.minY + (y - 56) / 38 * rect.height)
        }
        var path = Path()
        path.move(to: p(46, 94))
        path.addLine(to: p(54, 62))
        path.addQuadCurve(to: p(61, 60), control: p(56, 56))
        path.addLine(to: p(80, 80))
        path.closeSubpath()
        return path
    }
}

private struct CatEarInnerShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + (x - 46) / 34 * rect.width, y: rect.minY + (y - 56) / 38 * rect.height)
        }
        var path = Path()
        path.move(to: p(55, 70))
        path.addLine(to: p(59, 84))
        path.addLine(to: p(68, 80))
        path.closeSubpath()
        return path
    }
}

/// 키위새 부리. 위가 넓고 아래로 가늘게 내려오다 끝이 살짝 앞으로 휜다.
private struct KiwiBeakShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX + rect.width * 0.15, y: rect.maxY),
                          control: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.maxY * 0.75))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.maxY * 0.7))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                          control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.06))
        path.closeSubpath()
        return path
    }
}

/// 키위새 정수리의 삐친 털 두 가닥.
private struct KiwiTuftShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - rect.width * 0.1, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.15),
                          control: CGPoint(x: rect.midX - rect.width * 0.1, y: rect.minY))
        path.move(to: CGPoint(x: rect.midX + rect.width * 0.05, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.midX + rect.width * 0.1, y: rect.minY + rect.height * 0.2))
        return path
    }
}

/// 다문 입 ω.
private struct OmegaMouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                          control: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY + rect.height * 1.6))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.minY + rect.height * 1.6))
        return path
    }
}

#Preview {
    VStack(spacing: 30) {
        ForEach(PebbleBuddy.allCases) { buddy in
            HStack(spacing: 24) {
                PebbleView(mood: .resting, size: 110)
                PebbleView(mood: .warm, size: 110)
            }
            .environment(\.pebbleBuddy, buddy)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(PebbleTheme.canvas)
}
