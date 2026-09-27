//
//  ProFeature.swift
//  Rebound Journal
//
//  징검돌 프로 — 한 번 사면 계속 쓰는 부분유료.
//
//  ---
//
//  **무엇을 팔지 않는가**가 먼저다. 조약돌과의 대화, 기록, 지나온 길, 비밀번호
//  잠금, 알림은 전부 무료다. 막힌 얘기를 꺼내는 앱에서 대화 한가운데 결제 화면이
//  끼어들면 그 순간 조약돌은 곁에 있는 존재가 아니라 판매원이 된다.
//
//  그래서 페이월은 **사용자가 무언가를 더 하려고 손을 뻗은 자리**에만 둔다.
//
//   - 새 목표를 네 번째로 적으려 할 때 (대화 중에 스스로 쪼갠 목표는 막지 않는다.
//     목표는 '지나온 길'에서 내려놓을 수 있어서, 무료로도 자리를 비울 수 있다)
//   - 조약돌의 결을 바꾸려 할 때
//   - 기록을 파일로 내보내려 할 때
//
//  상세한 근거는 `docs/BUSINESS.md`.
//

import SwiftUI
import LeeoKit

/// 프로로 여는 것들. `rawValue`는 `ReboundJournalSpec.monetization`의 게이트 키와 같다.
enum ProFeature: String, CaseIterable, LeeoProFeature {
    case moreGoals = "goal"
    case pebbleSkin
    case export

    /// 무료로 품을 수 있는 목표 수. 게이트 정책의 단일 출처.
    static let freeGoalLimit = 3

    var leeoTitle: String {
        switch self {
        case .moreGoals: String(localized: "목표를 원하는 만큼")
        case .pebbleSkin: String(localized: "내 조약돌 고르기")
        case .export: String(localized: "기록 내보내기")
        }
    }

    var leeoDetail: String {
        switch self {
        case .moreGoals: String(localized: "향하는 곳이 여럿이어도 괜찮아요. 개수 제한 없이 적어 둘 수 있어요.")
        case .pebbleSkin: String(localized: "개울가에서 주운 듯한 돌 다섯 가지가 더 열려요.")
        case .export: String(localized: "지나온 기록을 글 파일로 꺼내 간직해요.")
        }
    }

    var leeoIcon: String {
        switch self {
        case .moreGoals: "flag.2.crossed"
        case .pebbleSkin: "paintpalette"
        case .export: "square.and.arrow.up"
        }
    }

    /// 페이월 혜택 목록. 짧게, 무엇이 좋아지는지만.
    static var benefits: [String] {
        [
            String(localized: "목표를 개수 제한 없이 적어 둬요"),
            String(localized: "조약돌의 결을 여섯 가지 중에서 골라요"),
            String(localized: "지나온 기록을 파일로 내보내요"),
            String(localized: "한 번 사면 계속 써요. 구독이 아니에요")
        ]
    }
}

// MARK: - 페이월

extension View {

    /// 징검돌 프로 페이월을 시트로 띄운다.
    ///
    /// - Parameter feature: 방금 손을 뻗은 기능. 있으면 그 기능을 앞세워 보여 준다.
    ///   설정에서 직접 열 때는 nil — 그때는 "징검돌 프로"라는 이름으로 연다.
    func proPaywall(isPresented: Binding<Bool>, feature: ProFeature? = nil) -> some View {
        modifier(ProPaywallModifier(isPresented: isPresented, feature: feature))
    }
}

private struct ProPaywallModifier: ViewModifier {
    @Binding var isPresented: Bool
    let feature: ProFeature?
    @EnvironmentObject private var store: LeeoStore

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            LeeoPaywallView<ReboundJournalSpec>(
                title: feature == nil ? String(localized: "징검돌 프로") : nil,
                // "구독이 아니에요"는 혜택 목록 마지막 줄에 있다. 부제에서 되풀이하지 않는다.
                subtitle: feature == nil ? String(localized: "무료로 쓰던 건 그대로, 몇 가지가 더 열려요.") : nil,
                features: ProFeature.benefits,
                leadFeature: feature,
                onPurchased: {
                    // 페이월은 자기 스토어로 산다. 앱 쪽 스토어는 따로 다시 읽어야
                    // 닫히자마자 잠금이 풀린 것이 보인다.
                    Task { await store.refreshEntitlements() }
                }
            )
            .leeoStyle(.pebble)
        }
    }
}

extension LeeoStyle {
    /// LeeoKit 화면(페이월 등)을 징검돌 색으로 입힌다.
    static var pebble: LeeoStyle {
        LeeoStyle(
            accent: PebbleTheme.key,
            bg: PebbleTheme.canvas,
            surface: PebbleTheme.surface,
            surfaceAlt: PebbleTheme.surfaceMuted,
            text: PebbleTheme.ink,
            textMuted: PebbleTheme.inkSoft,
            textFaint: PebbleTheme.inkFaint,
            radiusLg: PebbleTheme.cardRadius
        )
    }
}

extension LeeoStore {
    /// 게이트 판정. 기능 키를 문자열로 흘리지 않게 `ProFeature`로만 묻는다.
    func evaluate(_ feature: ProFeature, current: Int = 0) -> LeeoGateDecision {
        gate.evaluate(feature.rawValue, current: current)
    }

    func allows(_ feature: ProFeature) -> Bool {
        gate.allows(feature.rawValue)
    }
}
