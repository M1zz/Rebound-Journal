//
//  PebbleTheme.swift
//  Rebound Journal
//
//  햇빛에 달궈진 조약돌(설계 고찰 §10)에서 끌어온 팔레트.
//  따뜻한 흙색 계열로만 구성해, 화면 어디에도 "판단하는" 색(경고 빨강 등)을 쓰지 않는다.
//

import SwiftUI
import UIKit

enum PebbleTheme {

    // MARK: - 색

    /// 햇빛이 스며든 종이 같은 배경.
    static let canvas = dynamic(light: 0xFDF8F1, dark: 0x15120F)
    /// 카드처럼 한 겹 올라온 면.
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x211D18)
    /// 배경 위에서 아주 살짝만 구분되는 면. 관찰 카드에 쓴다.
    static let surfaceMuted = dynamic(light: 0xF6EEE2, dark: 0x1C1813)

    /// 조약돌 본체 (밝은 쪽 → 그늘 쪽).
    static let pebbleLit = dynamic(light: 0xF2DCBE, dark: 0xDCC3A2)
    static let pebbleMid = dynamic(light: 0xD9BC96, dark: 0xB59572)
    static let pebbleShade = dynamic(light: 0xB08F68, dark: 0x8A6D4E)

    /// 햇빛. 조약돌 뒤 글로우와 강조 요소에 함께 쓴다.
    static let sunlight = dynamic(light: 0xE8A33D, dark: 0xE0A65A)

    static let ink = dynamic(light: 0x2E2620, dark: 0xF0E7DA)
    static let inkSoft = dynamic(light: 0x6B5B4C, dark: 0xB0A190)
    static let inkFaint = dynamic(light: 0x9C8B7A, dark: 0x7E7264)

    static let hairline = dynamic(light: 0xE7DACA, dark: 0x332C24)

    // MARK: - 타이포
    //
    // 조약돌의 말은 세리프로, 사용자의 말과 UI는 산세리프로 둔다.
    // 말하는 주체가 둘이라는 걸 글꼴로 구분해, 사용자가 앱의 질문과
    // 자기 대답을 헷갈리지 않게 한다.

    static func companionFont(_ size: CGFloat = 21) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static func title(_ size: CGFloat = 26) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular)
    }

    static func label(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    // MARK: - 간격 / 모양

    static let cardRadius: CGFloat = 22
    static let gutter: CGFloat = 20

    // MARK: - 유틸

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - 공용 컴포넌트

/// 그림자를 거의 쓰지 않고 면과 여백으로만 구분하는 카드.
struct SoftCard<Content: View>: View {
    var background: Color = PebbleTheme.surface
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PebbleTheme.gutter)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: PebbleTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PebbleTheme.cardRadius, style: .continuous)
                    .strokeBorder(PebbleTheme.hairline, lineWidth: 1)
            }
    }
}

/// 주 동작 버튼. 압박을 주지 않도록 채도를 낮게 유지한다.
struct WarmButtonStyle: ButtonStyle {
    var prominent: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PebbleTheme.label(17))
            .foregroundStyle(prominent ? Color.white : PebbleTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(prominent ? PebbleTheme.sunlight : PebbleTheme.surfaceMuted)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 대화 중 사용자가 고르는 선택지. 항상 "지금은 넘어가기"와 같은 줄에 놓인다.
struct ChoiceButtonStyle: ButtonStyle {
    var selected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PebbleTheme.body(16))
            .foregroundStyle(PebbleTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(selected ? PebbleTheme.sunlight.opacity(0.18) : PebbleTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        selected ? PebbleTheme.sunlight : PebbleTheme.hairline,
                        lineWidth: selected ? 1.5 : 1
                    )
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
