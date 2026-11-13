//
//  PebbleView.swift
//  ZinggumDol
//
//  곁에 있는 동물 친구를 코드로만 그린다. 몸은 "햇빛에 달궈진 작은 조약돌"
//  (설계 고찰 §10)에서 왔고, 그 위에 친구마다 귀와 무늬를 더한다.
//  이미지 에셋을 쓰지 않으므로 크기·표정·색이 전부 상태에 반응한다.
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
    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blinking = false

    private var faceWidth: CGFloat { size * 0.46 }

    /// 후광까지 포함한 실제 차지 영역.
    ///
    /// 돌 몸통 크기로만 프레임을 잡으면 후광이 프레임 밖으로 삐져나가고, 바로 아래에
    /// 놓인 글자와 겹친다. 그려지는 만큼을 레이아웃에도 정직하게 알려야 한다.
    private var footprint: CGSize {
        CGSize(width: size * 1.35, height: size * 1.05)
    }

    var body: some View {
        ZStack {
            sunGlow
            PebbleEars(buddy: buddy, skin: skin, size: size)
            body_
            PebbleMarkings(buddy: buddy, skin: skin, size: size)
            face
                .offset(y: size * 0.04)
        }
        // 표정·결이 바뀔 때의 전환은 그림 안쪽에만 건다.
        .animation(.easeInOut(duration: 0.45), value: mood)
        .animation(.easeInOut(duration: 0.45), value: skin)
        .frame(width: footprint.width, height: footprint.height)
        // 귀가 솟은 만큼 위로 자리를 더 잡는다. 몸은 바닥에 그대로 앉아 있다.
        .frame(height: footprint.height + size * buddy.earRise, alignment: .bottom)
        // 호흡의 무한 반복은 **크기에만** 건다.
        //
        // 예전에는 `.animation(repeatForever, value: breathing)`이 조약돌 전체에
        // 걸려 있었다. 호흡이 시작되는 순간(시트가 올라오는 중, 목록이 자리를 잡는 중)
        // 함께 바뀐 위치까지 무한 반복으로 잡혀서, 조약돌이 숨 쉬는 게 아니라 제자리를
        // 벗어나 위아래로 널뛰었다. 조약돌이 여섯 개 모인 '조약돌 고르기'에서 특히 심했다.
        .animation(.easeInOut(duration: mood.breathPeriod / 2).repeatForever(autoreverses: true)) { content in
            // 위로 늘어날 때 옆은 줄고, 내려앉을 때 옆으로 퍼진다. 부피가 그대로여야
            // 딱딱한 것이 커졌다 작아지는 게 아니라 말랑한 것이 숨 쉬는 걸로 읽힌다.
            content.scaleEffect(
                x: breathing ? 0.985 : 1.022,
                y: breathing ? 1.032 : 0.972,
                anchor: .bottom
            )
        }
        // '동작 줄이기'를 켜면 숨쉬기를 멈추고 가만히 있는다.
        .onAppear { breathing = !reduceMotion }
        .onChange(of: reduceMotion) { _, reduce in breathing = !reduce }
        .task(id: mood) { await blinkLoop() }
        .accessibilityElement()
        .accessibilityLabel(Text(buddy.name))
        .accessibilityValue(accessibilityMood)
    }

    // MARK: 뒤쪽 햇빛

    private var sunGlow: some View {
        // 돌이 납작하므로 후광도 같은 비율로 눕힌다. 원형이면 위아래로만 크게 번진다.
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        PebbleTheme.sunlight.opacity(mood.glow),
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

    // MARK: 돌 본체

    private var body_: some View {
        PebbleShape()
            .fill(
                // 왼쪽 위에서 해가 든다. 빛이 한 점에서 둥글게 퍼져야 납작한 면이 아니라
                // 통통한 덩어리로 보인다.
                RadialGradient(
                    colors: [skin.lit, skin.mid, skin.shade],
                    center: UnitPoint(x: 0.32, y: 0.24),
                    startRadius: size * 0.04,
                    endRadius: size * 0.86
                )
            )
            .overlay {
                // 아래쪽 반사광 — 땅에서 되비치는 따뜻한 빛.
                PebbleShape()
                    .fill(
                        LinearGradient(
                            colors: [.clear, PebbleTheme.sunlight.opacity(0.14)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                // 가장자리를 따라 도는 빛. 속이 비치는 젤리처럼 테두리가 밝아진다.
                PebbleShape()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.42), .white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: size * 0.05
                    )
                    .blur(radius: size * 0.028)
                    .clipShape(PebbleShape())
            }
            .overlay {
                // 또렷한 반사광 하나와 작은 점 하나. 흐리면 매트한 돌, 또렷하면 쫀득한 표면이다.
                ZStack {
                    Ellipse()
                        .fill(Color.white.opacity(0.62))
                        .frame(width: size * 0.21, height: size * 0.095)
                        .rotationEffect(.degrees(-30))
                        .offset(x: -size * 0.215, y: -size * 0.235)
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: size * 0.042)
                        .offset(x: -size * 0.335, y: -size * 0.115)
                }
                .blur(radius: size * 0.008)
            }
            .frame(width: size, height: size * 0.84)
    }

    // MARK: 표정

    private var face: some View {
        VStack(spacing: size * 0.035) {
            HStack(spacing: size * 0.235) {
                eye
                eye
            }
            // 눈이 감겼다 떠져도 입이 오르내리지 않게 눈 자리 높이를 못박는다.
            .frame(height: size * 0.095)
            mouth
        }
        .background { cheeks }
    }

    @ViewBuilder
    private var eye: some View {
        let closed = blinking || mood.eyeCurve > 0.25
        if closed {
            // 웃거나 눈을 감은 상태 — 위로 볼록한 선(음수 곡률).
            FaceArc(curve: -0.75)
                .stroke(skin.pupil, style: .init(lineWidth: size * 0.024, lineCap: .round))
                .frame(width: size * 0.105, height: size * 0.036)
        } else {
            // 까만 콩 같은 눈에 빛 한 점. 눈을 키우는 대신 빛 한 점으로 생기를 준다.
            Ellipse()
                .fill(skin.pupil)
                .frame(width: size * 0.078, height: size * 0.09)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: size * 0.028)
                        .offset(x: -size * 0.012, y: size * 0.014)
                }
        }
    }

    /// 눈 아래 바깥쪽의 발그레한 볼.
    private var cheeks: some View {
        HStack(spacing: size * 0.33) {
            cheek
            cheek
        }
        .offset(y: size * 0.03)
    }

    private var cheek: some View {
        Ellipse()
            .fill(Color(red: 1.0, green: 0.50, blue: 0.47).opacity(mood.blush))
            .frame(width: size * 0.11, height: size * 0.062)
            .blur(radius: size * 0.018)
    }

    private var mouth: some View {
        let open: CGFloat = isSpeaking ? 0.7 : mood.mouthOpen
        let shape = MouthShape(curve: mood.mouthCurve, open: open)
        return shape
            .fill(skin.pupil)
            .overlay {
                // 벌린 입 안쪽의 혀.
                Ellipse()
                    .fill(Color(red: 0.98, green: 0.47, blue: 0.52))
                    .frame(width: size * 0.085, height: size * 0.06)
                    .offset(y: size * 0.052)
                    .opacity(Double(min(1, open * 1.6)))
                    .clipShape(shape)
            }
            .overlay {
                shape.stroke(
                    skin.pupil,
                    style: .init(lineWidth: size * 0.022, lineCap: .round, lineJoin: .round)
                )
            }
            .frame(
                width: size * (isSpeaking ? 0.13 : 0.12),
                height: size * (isSpeaking ? 0.075 : 0.055)
            )
            .animation(
                isSpeaking && !reduceMotion
                    ? .easeInOut(duration: 0.16).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.2),
                value: isSpeaking
            )
    }

    // MARK: 깜빡임

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

// MARK: - 친구의 귀와 무늬

/// 몸 뒤에 붙는 귀. 몸이 귀 밑동을 덮어 자연스럽게 이어진다.
private struct PebbleEars: View {
    let buddy: PebbleBuddy
    let skin: PebbleSkin
    let size: CGFloat

    private let innerPink = Color(red: 1.0, green: 0.62, blue: 0.64)

    var body: some View {
        switch buddy {
        case .hamster:
            pair(x: 0.35, y: -0.30, tilt: 0) { roundEar(0.13, inner: innerPink.opacity(0.75)) }
        case .bear:
            pair(x: 0.31, y: -0.345, tilt: 0) { roundEar(0.20, inner: skin.shade.opacity(0.55)) }
        case .cat:
            pair(x: 0.27, y: -0.40, tilt: 16) {
                ZStack {
                    CatEarShape().fill(fur)
                    CatEarShape().fill(innerPink.opacity(0.7))
                        .frame(width: size * 0.12, height: size * 0.13)
                        .offset(y: size * 0.03)
                }
                .frame(width: size * 0.25, height: size * 0.25)
            }
        case .bunny:
            pair(x: 0.15, y: -0.56, tilt: 9) {
                ZStack {
                    Ellipse().fill(fur)
                    Ellipse().fill(innerPink.opacity(0.7))
                        .frame(width: size * 0.07, height: size * 0.30)
                        .offset(y: size * 0.03)
                }
                .frame(width: size * 0.16, height: size * 0.46)
            }
        }
    }

    private var fur: LinearGradient {
        LinearGradient(colors: [skin.lit, skin.mid], startPoint: .top, endPoint: .bottom)
    }

    private func roundEar(_ diameter: CGFloat, inner: Color) -> some View {
        ZStack {
            Circle().fill(fur)
            Circle().fill(inner).frame(width: size * diameter * 0.52)
        }
        .frame(width: size * diameter, height: size * diameter)
    }

    /// 왼쪽 귀를 그리고 오른쪽은 거울로 비춘다. 바깥으로 `tilt`도만큼 벌어진다.
    private func pair(x: CGFloat, y: CGFloat, tilt: Double, ear: () -> some View) -> some View {
        let one = ear()
        return ZStack {
            one.rotationEffect(.degrees(-tilt), anchor: .bottom)
                .offset(x: -size * x, y: size * y)
            one.rotationEffect(.degrees(tilt), anchor: .bottom)
                .offset(x: size * x, y: size * y)
        }
    }
}

/// 몸 위의 작은 무늬. 동물로 읽히게 하는 한 가지씩만 더한다.
private struct PebbleMarkings: View {
    let buddy: PebbleBuddy
    let skin: PebbleSkin
    let size: CGFloat

    var body: some View {
        switch buddy {
        case .hamster:
            // 볼주머니처럼 아래로 퍼지는 밝은 얼굴.
            Ellipse()
                .fill(Color.white.opacity(0.45))
                .frame(width: size * 0.62, height: size * 0.30)
                .blur(radius: size * 0.03)
                .offset(y: size * 0.17)
        case .bear:
            // 입가의 밝은 주둥이.
            Ellipse()
                .fill(Color.white.opacity(0.30))
                .frame(width: size * 0.30, height: size * 0.18)
                .blur(radius: size * 0.012)
                .offset(y: size * 0.13)
        case .cat:
            // 양쪽 수염 두 가닥씩.
            HStack(spacing: size * 0.44) {
                whiskers.scaleEffect(x: -1)
                whiskers
            }
            .offset(y: size * 0.12)
        case .bunny:
            EmptyView()
        }
    }

    private var whiskers: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size * 0.02))
            path.addLine(to: CGPoint(x: size * 0.12, y: 0))
            path.move(to: CGPoint(x: 0, y: size * 0.05))
            path.addLine(to: CGPoint(x: size * 0.12, y: size * 0.06))
        }
        .stroke(skin.pupil.opacity(0.35), style: .init(lineWidth: size * 0.011, lineCap: .round))
        .frame(width: size * 0.12, height: size * 0.06)
    }
}

/// 끝이 둥근 고양이 귀.
private struct CatEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX - w * 0.12, y: rect.minY + h * 0.12),
            control: CGPoint(x: rect.minX + w * 0.12, y: rect.minY + h * 0.45)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX + w * 0.12, y: rect.minY + h * 0.12),
            control: CGPoint(x: rect.midX, y: rect.minY - h * 0.05)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX - w * 0.12, y: rect.minY + h * 0.45)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 44) {
        HStack(spacing: 32) {
            PebbleView(mood: .resting, size: 110)
            PebbleView(mood: .listening, size: 110)
        }
        HStack(spacing: 32) {
            PebbleView(mood: .thinking, size: 110)
            PebbleView(mood: .warm, size: 110)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(PebbleTheme.canvas)
}
