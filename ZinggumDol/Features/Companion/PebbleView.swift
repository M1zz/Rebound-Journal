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
            MochiEars(buddy: buddy, palette: palette, size: size, twitch: twitch)
            mochiBody
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

    /// 찹쌀떡 몸. 한 가지 색으로 칠하고 얇은 선을 두른다. 햄스터는 배가, 곰은
    /// 주둥이가 몸보다 밝다.
    private var mochiBody: some View {
        let shape = MochiShape()
        return ZStack {
            shape.fill(palette.fill)
            if buddy == .hamster {
                // 눈 아래부터 바닥까지 밝은 배. 몸 테두리를 넘지 않게 몸 모양으로 자른다.
                Ellipse()
                    .fill(palette.belly)
                    .frame(width: size * 0.9, height: size * 0.5)
                    .offset(y: size * 0.27)
            }
        }
        .frame(width: size * Layout.bodyWidth, height: size * Layout.bodyHeight)
        .clipShape(shape)
        .overlay { shape.stroke(palette.line, lineWidth: max(1, size * Layout.line)) }
        .offset(at(0, Layout.bodyY))
    }

    // MARK: 표정

    private var face: some View {
        ZStack {
            // 볼
            ForEach([-1.0, 1.0], id: \.self) { side in
                Ellipse()
                    .fill(Color(red: 0.97, green: 0.64, blue: 0.65).opacity(min(0.75, mood.blush * 2.4)))
                    .frame(width: size * 0.13, height: size * 0.072)
                    .offset(at(side * 0.285, Layout.eyeY + 0.085))
            }
            if buddy == .bear {
                Ellipse()
                    .fill(palette.belly)
                    .frame(width: size * 0.24, height: size * 0.15)
                    .offset(at(0, Layout.mouthY - 0.02))
            }
            ForEach([-1.0, 1.0], id: \.self) { side in
                eye.offset(at(side * Layout.eyeX, Layout.eyeY))
            }
            nose
            mouth.offset(at(0, Layout.mouthY + (buddy.hasNose ? 0.012 : 0)))
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
            Circle()
                .fill(palette.pupil)
                .frame(width: size * 0.064, height: size * 0.064)
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
        case .cat:
            EmptyView()
        }
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
    var hasNose: Bool { self != .cat }
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

/// 몸 뒤에 붙는 귀. 몸이 귀 밑동을 덮어 자연스럽게 이어진다.
private struct MochiEars: View {
    let buddy: PebbleBuddy
    let palette: PebblePalette
    let size: CGFloat
    var twitch: PebbleEarTwitch = .none

    private var line: CGFloat { max(1, size * 0.019) }

    var body: some View {
        switch buddy {
        case .cat:
            pair(x: 0.265, y: -0.255, tilt: 0) {
                ZStack {
                    CatEarShape().fill(palette.fill)
                    CatEarShape().stroke(palette.line, style: .init(lineWidth: line, lineJoin: .round))
                    CatEarInnerShape().fill(innerPink)
                }
                .frame(width: size * 0.24, height: size * 0.27)
            }
        case .bunny:
            // 한쪽 귀는 서고, 한쪽은 옆으로 살짝 늘어졌다. 짝이 안 맞아야 장난스럽다.
            ZStack {
                bunnyEar
                    .rotationEffect(.degrees(-6 - (twitch == .left ? 16 : 0)), anchor: .bottom)
                    .offset(x: -size * 0.15, y: -size * 0.40)
                bunnyEar
                    .rotationEffect(.degrees(38 - (twitch == .right ? 22 : 0)), anchor: .bottom)
                    .offset(x: size * 0.15, y: -size * 0.40)
            }
        case .hamster:
            pair(x: 0.33, y: -0.21, tilt: 0) { roundEar(0.14, inner: innerPink) }
        case .bear:
            pair(x: 0.32, y: -0.215, tilt: 0) { roundEar(0.19, inner: palette.belly) }
        }
    }

    private var bunnyEar: some View {
        ZStack {
            Capsule().fill(palette.fill)
            Capsule().stroke(palette.line, lineWidth: line)
            Capsule().fill(innerPink)
                .frame(width: size * 0.06, height: size * 0.27)
                .offset(y: size * 0.02)
        }
        .frame(width: size * 0.15, height: size * 0.42)
    }

    private func roundEar(_ diameter: CGFloat, inner: Color) -> some View {
        ZStack {
            Circle().fill(palette.fill)
            Circle().stroke(palette.line, lineWidth: line)
            Circle().fill(inner).frame(width: size * diameter * 0.5)
        }
        .frame(width: size * diameter, height: size * diameter)
    }

    /// 왼쪽 귀를 그리고 오른쪽은 거울로 비춘다. 쫑긋할 때는 그쪽 귀만 젖혀진다.
    private func pair(x: CGFloat, y: CGFloat, tilt: Double, ear: () -> some View) -> some View {
        let one = ear()
        let flick = 16.0
        return ZStack {
            one.rotationEffect(.degrees(-tilt - (twitch == .left ? flick : 0)), anchor: .bottom)
                .offset(x: -size * x, y: size * y)
            one.scaleEffect(x: -1)
                .rotationEffect(.degrees(tilt + (twitch == .right ? flick : 0)), anchor: .bottom)
                .offset(x: size * x, y: size * y)
        }
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
