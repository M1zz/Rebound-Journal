//
//  PebbleSkin.swift
//  Rebound Journal
//
//  조약돌의 결. 개울가에서 주울 법한 돌 몇 가지.
//
//  표정·호흡·목소리는 그대로 두고 **돌의 색만** 바꾼다. 조약돌이 하는 말과
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
        case .sand: String(localized: "모래알")
        case .slate: String(localized: "강돌")
        case .moss: String(localized: "이끼돌")
        case .sunset: String(localized: "노을돌")
        case .seashell: String(localized: "조가비")
        case .inkstone: String(localized: "먹돌")
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
