//
//  PebbleView.swift
//  Rebound Journal
//
//  "햇빛에 달궈진 작은 조약돌"(설계 고찰 §10)을 코드로만 그린다.
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
                + 0.055 * cos(angle * 2 + 0.7)
                + 0.032 * cos(angle * 3 - 1.2)

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

    @State private var breathing = false
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
            body_
            face
                .offset(y: size * 0.04)
        }
        .frame(width: footprint.width, height: footprint.height)
        .scaleEffect(breathing ? 1.025 : 0.985, anchor: .bottom)
        .animation(
            .easeInOut(duration: mood.breathPeriod / 2).repeatForever(autoreverses: true),
            value: breathing
        )
        .animation(.easeInOut(duration: 0.45), value: mood)
        .onAppear { breathing = true }
        .task(id: mood) { await blinkLoop() }
        .accessibilityElement()
        .accessibilityLabel("조약돌")
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
                // 왼쪽 위에서 해가 든다.
                LinearGradient(
                    colors: [PebbleTheme.pebbleLit, PebbleTheme.pebbleMid, PebbleTheme.pebbleShade],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                // 표면이 매끄럽다는 걸 알려주는 반사광 한 점.
                Ellipse()
                    .fill(Color.white.opacity(0.34))
                    .frame(width: size * 0.26, height: size * 0.15)
                    .rotationEffect(.degrees(-24))
                    .offset(x: -size * 0.20, y: -size * 0.24)
                    .blur(radius: size * 0.035)
            }
            .overlay {
                // 아래쪽 반사광 — 땅에서 되비치는 따뜻한 빛.
                PebbleShape()
                    .fill(
                        LinearGradient(
                            colors: [.clear, PebbleTheme.sunlight.opacity(0.22)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
            }
            .frame(width: size, height: size * 0.78)
    }

    // MARK: 표정

    private var face: some View {
        VStack(spacing: size * 0.055) {
            HStack(spacing: faceWidth * 0.52) {
                eye
                eye
            }
            mouth
        }
    }

    @ViewBuilder
    private var eye: some View {
        let closed = blinking || mood.eyeCurve > 0.25
        if closed {
            // 웃거나 눈을 감은 상태 — 위로 볼록한 선(음수 곡률).
            FaceArc(curve: -0.75)
                .stroke(PebbleTheme.pebbleShade, style: .init(lineWidth: size * 0.022, lineCap: .round))
                .frame(width: size * 0.10, height: size * 0.035)
        } else {
            Capsule()
                .fill(PebbleTheme.pebbleShade)
                .frame(width: size * 0.055, height: size * 0.075)
        }
    }

    private var mouth: some View {
        FaceArc(curve: mood.mouthCurve)
            .stroke(
                PebbleTheme.pebbleShade.opacity(0.85),
                style: .init(lineWidth: size * 0.020, lineCap: .round)
            )
            .frame(
                width: size * (isSpeaking ? 0.13 : 0.11),
                height: size * (isSpeaking ? 0.075 : 0.05)
            )
            .animation(
                isSpeaking
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
