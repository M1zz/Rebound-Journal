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
    /// 햇빛에 달궈진 모래빛 — 설계 고찰 §10의 원래 조약돌.
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
        case .sand: String(localized: "모래")
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

    var id: String { rawValue }

    static let `default`: PebbleBuddy = .bunny
    static let storageKey = "pebble.buddy"

    var name: String {
        switch self {
        case .hamster: String(localized: "햄스터")
        case .cat: String(localized: "고양이")
        case .bunny: String(localized: "토끼")
        case .bear: String(localized: "곰")
        }
    }

    /// 귀가 몸 위로 솟는 만큼(몸 크기 대비). 레이아웃이 그만큼 자리를 더 잡는다.
    var earRise: CGFloat {
        switch self {
        case .bunny: 0.26
        case .cat: 0.03
        default: 0
        }
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
