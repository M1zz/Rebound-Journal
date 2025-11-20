//
//  EmotionTracker.swift
//  Rebound Journal
//
//  Created by 황석현 on 3/23/25.
//

import SwiftUI

struct EmotionTracker: View {
    // Shared Dependencies
    @ObservedObject var viewModel: JournalCreatorViewModel

    // UI State
    @State var emotionValue: Double = 2.0 // 0(부정) ~ 4(긍정), 중립 시작
    @State var emotionText: [String] = []
    @State var selectedEmotionTags: [String] = []

    var currentEmotionLevel: EmotionLevel {
        switch emotionValue {
        case 0..<1.0: return .level3  // 매우 부정
        case 1.0..<2.0: return .level2  // 약간 부정
        case 2.0..<3.0: return .level1  // 약간 긍정
        default: return .level0  // 매우 긍정
        }
    }

    // 기타 상태
    var isFirstEnter: Bool {
        !viewModel.isSliderEditing && viewModel.emotionValue == nil
    }
    var isSliderEditing: Bool {
        viewModel.isSliderEditing
    }

    var text = Constants.SystemText()

    var body: some View {
        VStack(spacing: 24) {
            // 감정 도형 표시
            if isSliderEditing || !isFirstEnter {
                EmotionalShape(value: emotionValue)
                    .frame(height: 150)
            }

            // 슬라이더
            VStack(spacing: 12) {
                HStack {
                    Text("부정")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("긍정")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                HorizontalEmotionSlider(
                    sliderValue: $emotionValue,
                    isEdited: $viewModel.isSliderEditing
                )
                .onChange(of: emotionValue) { _, newValue in
                    debugPrint("Slider: \(newValue)")

                    // 감정 텍스트 업데이트
                    switch currentEmotionLevel {
                    case .level0:
                        emotionText = Constants.ContentText().emotionTextsLevel0
                    case .level1:
                        emotionText = Constants.ContentText().emotionTextsLevel1
                    case .level2:
                        emotionText = Constants.ContentText().emotionTextsLevel2
                    case .level3:
                        emotionText = Constants.ContentText().emotionTextsLevel3
                    }
                }
                .onChange(of: viewModel.isSliderEditing) { _, _ in
                    viewModel.emotionValue = emotionValue
                }
            }

            // 감정 태그 선택
            if !isSliderEditing && !isFirstEnter {
                EmotionText(emotions: $emotionText, selectedTags: $selectedEmotionTags)
                    .onChange(of: selectedEmotionTags) { _, newValue in
                        viewModel.emotionText = newValue
                    }
            }

            // 첫 진입 가이드
            if isFirstEnter {
                Text(text.sliderGuide)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.description)
                    .bold()
                    .padding()
            }
        }
    }
}


// MARK: - Emotional Shape with Glassmorphism

struct EmotionalShape: View {
    let value: Double  // 0(부정) ~ 4(긍정)
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var displayedSpikeCount: Double = 0
    @State private var displayedSpikeDepth: Double = 0

    var shapeColor: Color {
        // 0(부정) -> 4(긍정)으로 색상 변화
        switch value {
        case 0..<0.5:
            return Color(red: 0.6, green: 0.1, blue: 0.4)  // 진한 보라
        case 0.5..<1.0:
            return Color(red: 0.8, green: 0.1, blue: 0.2)  // 빨강
        case 1.0..<1.5:
            return Color(red: 1.0, green: 0.4, blue: 0.2)  // 주황
        case 1.5..<2.0:
            return Color(red: 1.0, green: 0.6, blue: 0.3)  // 연한 주황
        case 2.0..<2.5:
            return Color(red: 1.0, green: 0.9, blue: 0.2)  // 노랑
        case 2.5..<3.0:
            return Color(red: 0.8, green: 0.9, blue: 0.3)  // 연두
        case 3.0..<3.5:
            return Color(red: 0.4, green: 0.8, blue: 0.3)  // 초록
        default:
            return Color(red: 0.2, green: 0.7, blue: 0.4)  // 진한 초록
        }
    }

    var targetSpikeCount: Int {
        // 부정적일수록 뾰족, 긍정적일수록 부드러움
        switch value {
        case 0..<1.0: return 12  // 매우 뾰족
        case 1.0..<2.0: return 8   // 뾰족
        case 2.0..<3.0: return 6   // 약간 뾰족
        default: return 0  // 원형
        }
    }

    var targetSpikeDepth: Double {
        // 스파이크의 깊이
        switch value {
        case 0..<1.0: return 0.5  // 깊게
        case 1.0..<2.0: return 0.3  // 중간
        case 2.0..<3.0: return 0.15  // 얕게
        default: return 0.0  // 없음
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                // 배경 글로우 효과
                if displayedSpikeCount <= 1 {
                    Circle()
                        .fill(shapeColor.opacity(0.3))
                        .frame(width: size * 0.9, height: size * 0.9)
                        .blur(radius: 20)
                } else {
                    SpikedShape(spikes: max(1, Int(displayedSpikeCount)), spikeDepth: displayedSpikeDepth)
                        .fill(shapeColor.opacity(0.3))
                        .frame(width: size * 0.9, height: size * 0.9)
                        .blur(radius: 20)
                        .rotationEffect(.degrees(rotation))
                }

                // 메인 도형 (유리 재질)
                if displayedSpikeCount <= 1 {
                    // 긍정: 부드러운 원
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    shapeColor.opacity(0.7),
                                    shapeColor.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size * 0.8, height: size * 0.8)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: shapeColor.opacity(0.3), radius: 15, x: 0, y: 8)
                } else {
                    // 부정: 뾰족한 도형
                    SpikedShape(spikes: max(1, Int(displayedSpikeCount)), spikeDepth: displayedSpikeDepth)
                        .fill(
                            LinearGradient(
                                colors: [
                                    shapeColor.opacity(0.7),
                                    shapeColor.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size * 0.8, height: size * 0.8)
                        .overlay(
                            SpikedShape(spikes: max(1, Int(displayedSpikeCount)), spikeDepth: displayedSpikeDepth)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .rotationEffect(.degrees(rotation))
                        .shadow(color: shapeColor.opacity(0.3), radius: 15, x: 0, y: 8)
                }

                // 유리 하이라이트 (상단)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.8), .white.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: size / 6
                        )
                    )
                    .frame(width: size * 0.25, height: size * 0.25)
                    .offset(x: -size * 0.15, y: -size * 0.15)
                    .blur(radius: 3)

                // 유리 반사 효과 (하단)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0), .white.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.8, height: size * 0.8)
                    .mask(
                        Circle()
                            .frame(width: size * 0.8, height: size * 0.8)
                    )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(scale)
        }
        .onChange(of: value) { oldValue, newValue in
            // 부드러운 도형 전환 애니메이션
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                displayedSpikeCount = Double(targetSpikeCount)
                displayedSpikeDepth = targetSpikeDepth
                scale = 0.95
            }

            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.15)) {
                scale = 1.0
            }

            // 부정적일 때 회전 애니메이션
            if targetSpikeCount > 0 {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            } else {
                rotation = 0
            }
        }
        .onAppear {
            displayedSpikeCount = Double(targetSpikeCount)
            displayedSpikeDepth = targetSpikeDepth

            if targetSpikeCount > 0 {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
    }
}

// MARK: - Spiked Shape

struct SpikedShape: Shape {
    let spikes: Int
    let spikeDepth: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        let angleIncrement = (2 * .pi) / Double(spikes * 2)

        for i in 0..<(spikes * 2) {
            let angle = angleIncrement * Double(i) - .pi / 2
            let length = i % 2 == 0 ? radius : radius * (1 - spikeDepth)

            let x = center.x + cos(angle) * length
            let y = center.y + sin(angle) * length

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Horizontal Emotion Slider

struct HorizontalEmotionSlider: View {
    @Binding var sliderValue: Double  // 0(부정) ~ 4(긍정)
    @Binding var isEdited: Bool

    var body: some View {
        Slider(value: $sliderValue, in: 0...4) { editing in
            isEdited = editing
            if !editing {
                // 슬라이더 편집이 끝나면 0.5 단위로 스냅
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        sliderValue = round(sliderValue * 2) / 2
                    }
                }
            }
        }
        .tint(sliderColor)
    }

    var sliderColor: Color {
        switch sliderValue {
        case 0..<1.0: return Color(red: 0.7, green: 0.1, blue: 0.3)  // 부정: 빨강-보라
        case 1.0..<2.0: return Color(red: 1.0, green: 0.5, blue: 0.2)  // 주황
        case 2.0..<3.0: return Color(red: 1.0, green: 0.9, blue: 0.2)  // 노랑
        default: return Color(red: 0.3, green: 0.7, blue: 0.3)  // 긍정: 초록
        }
    }
}

#Preview {
    EmotionTracker(viewModel: JournalCreatorViewModel())
}
