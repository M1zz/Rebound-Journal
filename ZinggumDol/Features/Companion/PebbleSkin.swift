//
//  PebbleSkin.swift
//  ZinggumDol
//
//  친구의 결. 몸 색 몇 가지.
//
//  표정·호흡·목소리는 그대로 두고 **색만** 바꾼다. 친구가 하는 말과
//  태도는 누구에게나 같아야 하고, 꾸미는 건 "내 돌"이라는 애착까지만이다.
//
//  기본 돌(모래)은 누구나 쓴다. 나머지는 프로에서 열린다. 기록을 막지 않는
//  순수한 덤이라, 무료 사용자에게서 아무것도 빼앗지 않는다.
//
//  앱과 위젯이 함께 컴파일한다. 위젯은 스스로 고르지 않고 앱이 `PebbleSnapshot`에
//  적어 준 결을 그대로 쓴다.
//

import SwiftUI

enum PebbleSkin: String, CaseIterable, Identifiable, Codable {
    /// 친구마다 타고난 색 — 토끼는 우유빛, 햄스터는 살구빛, 곰은 밤빛.
    /// 이름은 처음 조약돌의 모래빛에서 왔다. 저장된 값이라 바꾸지 않는다.
    case sand
    case slate
    case moss
    case sunset
    case seashell
    case inkstone

    var id: String { rawValue }

    /// 무료로 쓰는 결.
    static let free: PebbleSkin = .sand

    var requiresPro: Bool { self != Self.free }

    var name: String {
        switch self {
        case .sand: String(localized: "기본")
        case .slate: String(localized: "구름")
        case .moss: String(localized: "말차")
        case .sunset: String(localized: "노을")
        case .seashell: String(localized: "우유")
        case .inkstone: String(localized: "먹")
        }
    }

    // MARK: - 색 (밝은 쪽 → 그늘 쪽)

    var lit: Color {
        switch self {
        case .sand: PebbleTheme.pebbleLit
        case .slate: PebbleTheme.dynamic(light: 0xDCE2E3, dark: 0xB9C2C4)
        case .moss: PebbleTheme.dynamic(light: 0xDDE4C9, dark: 0xBAC49E)
        case .sunset: PebbleTheme.dynamic(light: 0xF4D7C5, dark: 0xDDB199)
        case .seashell: PebbleTheme.dynamic(light: 0xF8F1EA, dark: 0xE4D8CE)
        case .inkstone: PebbleTheme.dynamic(light: 0x77726D, dark: 0x6A6560)
        }
    }

    var mid: Color {
        switch self {
        case .sand: PebbleTheme.pebbleMid
        case .slate: PebbleTheme.dynamic(light: 0xB0BABD, dark: 0x8F9A9D)
        case .moss: PebbleTheme.dynamic(light: 0xB5C197, dark: 0x94A176)
        case .sunset: PebbleTheme.dynamic(light: 0xDEAB90, dark: 0xBF8C71)
        case .seashell: PebbleTheme.dynamic(light: 0xE7D8CD, dark: 0xC7B6A9)
        case .inkstone: PebbleTheme.dynamic(light: 0x4F4B48, dark: 0x46423F)
        }
    }

    var shade: Color {
        switch self {
        case .sand: PebbleTheme.pebbleShade
        case .slate: PebbleTheme.dynamic(light: 0x7E888C, dark: 0x656F73)
        case .moss: PebbleTheme.dynamic(light: 0x7F8D63, dark: 0x67744D)
        case .sunset: PebbleTheme.dynamic(light: 0xB27C62, dark: 0x91614A)
        case .seashell: PebbleTheme.dynamic(light: 0xC3AFA1, dark: 0xA08D80)
        case .inkstone: PebbleTheme.dynamic(light: 0x34312F, dark: 0x2C2927)
        }
    }

    /// 눈과 입. 대부분은 그늘색이면 충분하지만, 어두운 돌에서는 그늘색이
    /// 몸에 묻혀 표정이 사라진다. 표정이 안 보이면 조약돌이 아니라 그냥 돌이다.
    var face: Color {
        switch self {
        case .inkstone: PebbleTheme.dynamic(light: 0xEDE6DC, dark: 0xE2DACF)
        default: shade
        }
    }

    /// 눈동자와 입. 반짝이는 눈은 바탕이 충분히 짙어야 빛 한 점이 살아난다.
    /// 그늘색보다 한참 짙은, 돌마다의 먹색이다.
    var pupil: Color {
        switch self {
        case .sand: PebbleTheme.dynamic(light: 0x3D3933, dark: 0x3D3933)
        case .slate: PebbleTheme.dynamic(light: 0x2E383C, dark: 0x2E383C)
        case .moss: PebbleTheme.dynamic(light: 0x333D22, dark: 0x333D22)
        case .sunset: PebbleTheme.dynamic(light: 0x54301F, dark: 0x54301F)
        case .seashell: PebbleTheme.dynamic(light: 0x54443A, dark: 0x54443A)
        case .inkstone: face
        }
    }
}

// MARK: - 실제로 칠할 색

/// 친구를 칠하는 네 가지 색. 모찌 그림은 그라데이션 없이 납작하게 칠하고
/// 얇은 선으로 테두리를 두른다.
struct PebblePalette {
    /// 몸 색.
    var fill: Color
    /// 햄스터의 배, 곰의 주둥이처럼 몸보다 밝은 자리.
    var belly: Color
    /// 테두리 선.
    var line: Color
    /// 눈 · 입.
    var pupil: Color
}

extension PebbleSkin {
    /// 이 결로 그 친구를 칠할 색. 기본 결은 친구마다 타고난 색을 쓴다.
    func palette(for buddy: PebbleBuddy) -> PebblePalette {
        self == .sand
            ? buddy.natural
            : PebblePalette(fill: lit, belly: Color.white.opacity(0.55), line: shade, pupil: pupil)
    }
}

// MARK: - 저장

extension PebbleSkin {

    /// 사용자가 고른 결을 적어 두는 자리. 프로 권한이 있는지는 따지지 않는다 —
    /// 그 판단은 `effective(_:hasPro:)`가 한다. 환불 뒤에 다시 사도 고른 것이
    /// 남아 있게 하려는 것.
    static let storageKey = "pebble.skin"

    /// 지금 실제로 그릴 결.
    static func effective(_ chosen: PebbleSkin, hasPro: Bool) -> PebbleSkin {
        chosen.requiresPro && !hasPro ? .free : chosen
    }
}

// MARK: - 환경

private struct PebbleSkinKey: EnvironmentKey {
    static let defaultValue: PebbleSkin = .free
}

extension EnvironmentValues {
    /// `PebbleView`가 그릴 결. 앱 뿌리에서 한 번 넣어 주면 모든 조약돌이 따른다.
    var pebbleSkin: PebbleSkin {
        get { self[PebbleSkinKey.self] }
        set { self[PebbleSkinKey.self] = newValue }
    }
}

// MARK: - 친구

/// 곁에 있는 친구가 어떤 동물인가. 결(`PebbleSkin`)이 색이라면 이것은 모양이다.
///
/// 처음에는 말하는 조약돌이었다. 돌이 말을 거는 게 낯설다는 목소리가 있어, 같은
/// 말랑한 몸에 귀와 작은 무늬를 더해 동물 친구로 만들었다. 표정·호흡·목소리는
/// 모두 같다. 결과 서로 독립이라 어떤 친구든 어떤 색으로도 그릴 수 있다.
///
/// 누구나 고른다. 친구는 이 앱의 얼굴이라 프로로 잠그지 않는다 — 색만 프로다.
enum PebbleBuddy: String, CaseIterable, Identifiable, Codable {
    case bunny
    case hamster
    case cat
    case bear
    case seal
    case raccoon
    case capybara
    case kiwi

    var id: String { rawValue }

    static let `default`: PebbleBuddy = .bunny
    static let storageKey = "pebble.buddy"

    var name: String {
        switch self {
        case .hamster: String(localized: "햄스터")
        case .cat: String(localized: "고양이")
        case .bunny: String(localized: "토끼")
        case .bear: String(localized: "곰")
        case .seal: String(localized: "하프물범")
        case .raccoon: String(localized: "라쿤")
        case .capybara: String(localized: "카피바라")
        case .kiwi: String(localized: "키위새")
        }
    }

    /// 타고난 색. 여럿이 나란히 있을 때 한눈에 서로 달라 보이게 고른다.
    var natural: PebblePalette {
        func d(_ light: UInt32, _ dark: UInt32) -> Color { PebbleTheme.dynamic(light: light, dark: dark) }
        return switch self {
        case .bunny: PebblePalette(
            fill: d(0xFFFFFF, 0xEEE8E8), belly: d(0xFFFFFF, 0xEEE8E8),
            line: d(0x8A6A66, 0x775A56), pupil: d(0x3A2B2A, 0x3A2B2A))
        case .hamster: PebblePalette(
            fill: d(0xF8CD95, 0xDDB07A), belly: d(0xFFF7EC, 0xEADFD2),
            line: d(0x8A5A34, 0x74492A), pupil: d(0x3A2416, 0x3A2416))
        case .cat: PebblePalette(
            fill: d(0xFFF9F2, 0xEDE4D9), belly: d(0xFFF9F2, 0xEDE4D9),
            line: d(0x7A5E4C, 0x6A5040), pupil: d(0x3A2B24, 0x3A2B24))
        case .bear: PebblePalette(
            fill: d(0xD9AC82, 0xBE916A), belly: d(0xF5DEC6, 0xDDC4AA),
            line: d(0x6E4A30, 0x5C3C25), pupil: d(0x2E1D12, 0x2E1D12))
        case .seal: PebblePalette(
            fill: d(0xFFFFFF, 0xE9EEF2), belly: d(0xFFFFFF, 0xE9EEF2),
            line: d(0x7E8FA0, 0x6B7B8C), pupil: d(0x1E2228, 0x1E2228))
        case .raccoon: PebblePalette(
            fill: d(0xBDB8C0, 0xA39EA7), belly: d(0xF7F5F8, 0xDDD9DF),
            line: d(0x5C5662, 0x4E4854), pupil: d(0x1F1C22, 0x1F1C22))
        case .capybara: PebblePalette(
            fill: d(0xC4915E, 0xA97A4C), belly: d(0x9C6B42, 0x845936),
            line: d(0x6B4A2E, 0x5A3D25), pupil: d(0x2A1C12, 0x2A1C12))
        case .kiwi: PebblePalette(
            fill: d(0x8F7A62, 0x7A6753), belly: d(0x8F7A62, 0x7A6753),
            line: d(0x4A3C2E, 0x3E3226), pupil: d(0x1E140C, 0x1E140C))
        }
    }

    /// 귀가 몸 위로 솟는 만큼(몸 크기 대비). 레이아웃이 그만큼 자리를 더 잡는다.
    var earRise: CGFloat {
        self == .bunny ? 0.12 : 0
    }
}

private struct PebbleBuddyKey: EnvironmentKey {
    static let defaultValue: PebbleBuddy = .default
}

extension EnvironmentValues {
    var pebbleBuddy: PebbleBuddy {
        get { self[PebbleBuddyKey.self] }
        set { self[PebbleBuddyKey.self] = newValue }
    }
}
