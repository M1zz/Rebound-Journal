//
//  PebbleTheme.swift
//  ZinggumDol
//
//  햇빛에 달궈진 조약돌(설계 고찰 §10)에서 끌어온 팔레트.
//  따뜻한 흙색 계열로만 구성해, 화면 어디에도 "판단하는" 색(경고 빨강 등)을 쓰지 않는다.
//

import SwiftUI
import UIKit

enum PebbleTheme {

    // MARK: - 색

    /// 개울가 이른 아침의 물안개 같은 배경.
    ///
    /// 크림 계열이었다가 옮겼다. 따뜻하긴 했지만 그 값은 이미 여러 대화형 앱이
    /// 쓰고 있어서, 열자마자 "어디서 본 화면"이 됐다. 바탕을 물빛 쪽으로
    /// 옮기니 이름·키 컬러와 같은 말을 하게 되고, 무엇보다 **따뜻한 조약돌이
    /// 유일한 온기**가 되어 시선이 캐릭터로 모인다.
    static let canvas = dynamic(light: 0xEFF3F3, dark: 0x111717)
    /// 카드처럼 한 겹 올라온 면. 바탕보다 밝아야 말풍선이 떠 보인다.
    static let surface = dynamic(light: 0xFCFDFD, dark: 0x1C2323)
    /// 배경 위에서 아주 살짝만 구분되는 면.
    static let surfaceMuted = dynamic(light: 0xE7EDEC, dark: 0x161C1C)

    /// 조약돌 본체 (밝은 쪽 → 그늘 쪽). 돌은 계속 따뜻하다.
    static let pebbleLit = dynamic(light: 0xF1E3CB, dark: 0xDCC3A2)
    static let pebbleMid = dynamic(light: 0xD6C0A0, dark: 0xB59572)
    static let pebbleShade = dynamic(light: 0xAC9070, dark: 0x8A6D4E)

    /// 키 컬러 — 개울 물빛.
    ///
    /// 강조는 전부 이 색으로 한다. 답풍선, 고른 표시, 점, 커서.
    ///
    /// 차가운 키를 쓰는 이유는 두 가지다. 하나는 따뜻한 돌과 온도가 갈려야
    /// 조약돌이 앞으로 나온다는 것 — 키와 돌이 같은 계열이면 서로 묻힌다.
    /// 다른 하나는 이 앱이 개울을 건너는 이야기라는 것이다 (앱 이름 §4).
    static let key = dynamic(light: 0x5F8F93, dark: 0x7FB3B6, lightHigh: 0x466E72, darkHigh: 0x9FD0D3)

    /// 키 컬러 면 위에 얹는 글자·아이콘.
    ///
    /// 다크에서는 키가 밝은 물빛이라 흰 글자가 묻힌다(대비 2.3:1). 그때는 바탕색 글자를 쓴다.
    static let onKey = dynamic(light: 0xFFFFFF, dark: 0x111717)

    /// 조약돌에 드는 햇빛. **강조색이 아니다.**
    ///
    /// 예전에는 이 색 하나가 햇빛과 강조를 겸했고, 그래서 앰버 버튼이 화면을
    /// 덮었다. 지금은 조약돌 뒤 후광과 돌 아래 반사광에만 쓴다. "햇빛에 달궈진
    /// 작은 조약돌"(§10)은 캐릭터의 설정이라 여기까지 차갑게 만들면 안 된다.
    static let sunlight = dynamic(light: 0xE8A33D, dark: 0xE0A65A)

    static let ink = dynamic(light: 0x232C2B, dark: 0xE9EFEE)
    static let inkSoft = dynamic(light: 0x566564, dark: 0xA3B0AF, lightHigh: 0x3F4B4A, darkHigh: 0xC4CFCE)
    /// 흐린 글자. '대비 증가'를 켜면 본문 대비(4.5:1)를 넘게 짙어진다.
    static let inkFaint = dynamic(light: 0x899695, dark: 0x71807E, lightHigh: 0x5F6B6A, darkHigh: 0x9AA7A5)

    static let hairline = dynamic(light: 0xDBE3E2, dark: 0x28302F)

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
    // 조약돌의 말은 세리프로, 사용자의 말과 UI는 산세리프로 둔다.
    // 말하는 주체가 둘이라는 걸 글꼴로 구분해, 사용자가 앱의 질문과
    // 자기 대답을 헷갈리지 않게 한다.
    //
    // 크기는 가장 가까운 텍스트 스타일로 옮겨 '더 큰 텍스트'를 따라 커지게 한다.
    // 기본 크기에서는 예전 값과 1pt 안쪽으로 같다.

    static func companionFont(_ size: CGFloat = 21) -> Font {
        .system(textStyle(size), design: .serif, weight: .regular)
    }

    static func title(_ size: CGFloat = 26) -> Font {
        .system(textStyle(size), design: .rounded, weight: .semibold)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        .system(textStyle(size), weight: .regular)
    }

    static func label(_ size: CGFloat = 14) -> Font {
        .system(textStyle(size), design: .rounded, weight: .medium)
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

    static let cardRadius: CGFloat = 22
    static let gutter: CGFloat = 20

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
