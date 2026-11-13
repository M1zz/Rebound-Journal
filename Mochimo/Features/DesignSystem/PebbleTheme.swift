//
//  PebbleTheme.swift
//  Mochimo
//
//  모찌모의 떡집 팔레트. 찹쌀 바탕, 콩고물 버튼, 쑥빛 닿은 날, 팥앙금 글자.
//  검정·회색·경고 빨강을 쓰지 않는다. 가장 진한 색도 따뜻한 갈색이다.
//  (무드보드: 쫀득 · 말랑 · 따끈 · 느긋 · 다정)
//

import SwiftUI
import UIKit

enum PebbleTheme {

    // MARK: - 색

    /// 찹쌀 바탕. 갓 찐 떡처럼 따뜻한 흰빛.
    static let canvas = dynamic(light: 0xFFF8EF, dark: 0x1C1613)
    /// 한 겹 올라온 면. 바탕보다 밝아야 말풍선이 떠 보인다.
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x2A211C)
    /// 바탕 위에서 아주 살짝만 구분되는 면.
    static let surfaceMuted = dynamic(light: 0xF7EEE3, dark: 0x231C18)

    /// 조약돌 본체 (밝은 쪽 → 그늘 쪽). 따뜻하되 붉은 기는 뺀 강가 돌의 잿빛 모래색.
    /// 살구빛 베이지는 윤기와 볼이 얹히면 돌이 아니라 살로 읽힌다.
    static let pebbleLit = dynamic(light: 0xEFEBE0, dark: 0xD9D4C7)
    static let pebbleMid = dynamic(light: 0xCFC9B9, dark: 0xADA696)
    static let pebbleShade = dynamic(light: 0x9C9584, dark: 0x7C7566)

    /// 키 컬러 — 구운 콩고물.
    ///
    /// 강조 글자·아이콘·선과, 흰 글자를 얹는 면에 쓴다. 찹쌀 바탕 위에서도
    /// 글자로 읽히도록(4.5:1) 콩고물보다 한 번 더 구운 색이다.
    static let key = dynamic(light: 0x9A6127, dark: 0xE2B36A, lightHigh: 0x7E4C1B, darkHigh: 0xF0CB8C)

    /// 키 컬러 면 위에 얹는 글자·아이콘.
    static let onKey = dynamic(light: 0xFFFFFF, dark: 0x1C1613)

    /// 콩고물. 가장 먼저 누를 버튼의 면. 위에는 팥 글자를 얹는다.
    static let mochi = dynamic(light: 0xF4D58D, dark: 0xD9B36A)
    /// 콩고물 버튼 아래 두께. 눌리면 이 두께가 꺼진다.
    static let mochiEdge = dynamic(light: 0xE0B460, dark: 0xA88545)
    /// 흰 버튼 아래 두께.
    static let surfaceEdge = dynamic(light: 0xEADBC8, dark: 0x18120F)

    /// 쑥. 해낸 날.
    static let sprout = dynamic(light: 0xA8C69A, dark: 0x8FB082)
    static let sproutLit = dynamic(light: 0xCFE3C3, dark: 0xB0CBA4)
    /// 딸기 찹쌀. 볼, 하트.
    static let strawberry = dynamic(light: 0xF7B6BE, dark: 0xE79AA4)

    /// 조약돌에 드는 햇빛. **강조색이 아니다.**
    ///
    /// 예전에는 이 색 하나가 햇빛과 강조를 겸했고, 그래서 앰버 버튼이 화면을
    /// 덮었다. 지금은 조약돌 뒤 후광과 돌 아래 반사광에만 쓴다. "햇빛에 달궈진
    /// 작은 조약돌"(§10)은 캐릭터의 설정이라 여기까지 차갑게 만들면 안 된다.
    static let sunlight = dynamic(light: 0xE8A33D, dark: 0xE0A65A)

    /// 팥앙금 글자.
    static let ink = dynamic(light: 0x4A3530, dark: 0xF3E9E1)
    static let inkSoft = dynamic(light: 0x6F584F, dark: 0xCDBBB0, lightHigh: 0x523E37, darkHigh: 0xE2D3C9)
    /// 흐린 글자. 흐려도 찹쌀 바탕에서 본문 대비(4.5:1)는 지킨다. 안 보이는 글자는 없는 글자다.
    static let inkFaint = dynamic(light: 0x85695D, dark: 0xA8958A, lightHigh: 0x664F45, darkHigh: 0xC4B3A8)

    static let hairline = dynamic(light: 0xF0E3D3, dark: 0x3A2F29)

    // MARK: - 치수

    /// 시트 맨 위 제목까지의 여백.
    ///
    /// 시트는 위쪽 모서리가 크게 둥글고, 그 자리에 손잡이가 놓인다. 여느 화면과
    /// 같은 여백(12pt)을 주면 제목이 그 곡선 안쪽으로 파고들어 **화면이 위로
    /// 잘려 나간 것처럼 보인다.** 실제로 잘린 건 없는데도 그렇게 읽힌다.
    ///
    /// 곡선과 손잡이가 차지하는 만큼을 비워 둔다.
    static let sheetHeaderTop: CGFloat = 30

    // MARK: - 타이포
    //
    // 전부 둥근 글꼴. 각진 글자는 말랑한 친구 옆에서 혼자 딱딱하다.
    // 친구의 말은 조금 더 도톰하게, 사용자의 말과 UI는 보통 굵기로 두어
    // 말하는 주체가 둘이라는 걸 굵기로 구분한다.
    //
    // 작은 글자는 쓰지 않는다. 곁들이는 글자(label)도 기본 13pt 아래로 내려가지 않는다.
    //
    // 크기는 가장 가까운 텍스트 스타일로 옮겨 '더 큰 텍스트'를 따라 커지게 한다.
    // 기본 크기에서는 예전 값과 1pt 안쪽으로 같다.

    static func companionFont(_ size: CGFloat = 21) -> Font {
        .system(textStyle(size + 1), design: .rounded, weight: .medium)
    }

    static func title(_ size: CGFloat = 26) -> Font {
        .system(textStyle(size), design: .rounded, weight: .semibold)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        .system(textStyle(size + 1), design: .rounded, weight: .regular)
    }

    static func label(_ size: CGFloat = 14) -> Font {
        .system(textStyle(max(13, size + 2)), design: .rounded, weight: .medium)
    }

    /// 기본 크기가 `size`에 가장 가까운 텍스트 스타일.
    static func textStyle(_ size: CGFloat) -> Font.TextStyle {
        switch size {
        case 30...: .largeTitle   // 34
        case 24..<30: .title      // 28
        case 21..<24: .title2     // 22
        case 19..<21: .title3     // 20
        case 17..<19: .body       // 17
        case 16..<17: .callout    // 16
        case 14..<16: .subheadline // 15
        case 13..<14: .footnote   // 13
        case 12..<13: .caption    // 12
        default: .caption2        // 11
        }
    }

    // MARK: - 간격 / 모양

    static let cardRadius: CGFloat = 28
    static let gutter: CGFloat = 24

    // MARK: - 유틸

    /// 라이트·다크 한 쌍. `lightHigh`·`darkHigh`를 주면 '대비 증가'일 때 그 값을 쓴다.
    static func dynamic(light: UInt32, dark: UInt32, lightHigh: UInt32? = nil, darkHigh: UInt32? = nil) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let isHigh = traits.accessibilityContrast == .high
            let rgb = isDark ? (isHigh ? darkHigh ?? dark : dark) : (isHigh ? lightHigh ?? light : light)
            return UIColor(rgb: rgb)
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

extension View {
    /// 대화가 흐르는 스크롤의 위 가장자리를 칼같이 자르지 않고 흐리게 녹인다.
    ///
    /// 말이 쌓여 위로 밀려나면 맨 위 말풍선이 친구 바로 아래에서 반쯤 잘린 채
    /// 멈춘다. 잘린 선은 고장처럼 보인다. 흐려지며 사라지면 '위로 흘러갔다'로 읽힌다.
    /// 위에 여백을 두어 맨 위 말풍선의 그림자도 잘리지 않게 한다.
    func conversationScrollEdge(fade: CGFloat = 28) -> some View {
        self
            .contentMargins(.top, fade * 0.6, for: .scrollContent)
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: fade)
                    Color.black
                }
            }
    }
}

/// 찹쌀떡 같은 카드. 선 없이 따뜻한 그림자로 살짝 떠 있다.
struct SoftCard<Content: View>: View {
    var background: Color = PebbleTheme.surface
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PebbleTheme.gutter)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: PebbleTheme.cardRadius, style: .continuous))
            .shadow(color: Color(red: 0.65, green: 0.44, blue: 0.16).opacity(0.09), radius: 14, y: 6)
    }
}

// 화면 폭을 채우는 버튼 스타일(WarmButtonStyle·ChoiceButtonStyle)은 걷어냈다.
// 사용자가 답하는 자리는 전부 `ReplyChip` 으로 통일했다. 보낸 말풍선과 헷갈리지 않게
// 화면 폭을 채우는 버튼으로 그린다.
// 한때는 답도 말풍선 모양으로 두었지만, 이미 보낸 말과 눌러야 할 것이 헷갈려 버튼으로 돌아왔다.

/// 고른 것을 색으로만 알리지 않는다. '색상 없이 구별'을 켜면 글자 앞에 체크를 붙인다.
struct SelectionCheck: View {
    let isSelected: Bool
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        if isSelected && differentiateWithoutColor {
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .accessibilityHidden(true)
        }
    }
}
