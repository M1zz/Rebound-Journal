//
//  AppConfig.swift
//  Rebound Journal
//
//  Created by hyunho lee on 2023/06/10.
//

import SwiftUI
import Foundation

/// Generic configurations for the app
class AppConfig {
    
    /// This is the AdMob Interstitial ad id
    /// Test App ID: ca-app-pub-3940256099942544~1458002511
//    static let adMobAdId: String = "ca-app-pub-3940256099942544/4411468910"
    
#warning("설정필요")
    // MARK: - Settings flow items
    static let emailSupport = "leeo@kakao.com"
    static let privacyURL: URL = URL(string: "https://www.google.com/")!
    static let termsAndConditionsURL: URL = URL(string: "https://www.google.com/")!
    static let yourAppURL: URL = URL(string: "https://apps.apple.com/app/idXXXXXXXXX")!
    
    // MARK: - Generic configurations
    static let headerTitleDaysCount: Int = 90
    
#warning("미래에 구매")
    // MARK: - In App Purchases
    //static let premiumVersion: String = "ReboundJournal.Premium"
}

// MARK: - Mood Level Configurations
enum MoodLevel: Int, CaseIterable, Identifiable {
    case level1 = 1, level2
    var id: Int { hashValue }
    
    /// Mood text options
    var moodOptions: [String] {
        switch self {
        case .level1:
            return [
                String(localized: "깔끔하게 들어가서 기분좋아"),
                String(localized: "여러번만의 성공이라 신나"),
                String(localized: "다시 또 하고싶어"),
                String(localized: "왜 들어갔지? 아리송해"),
                String(localized: "발 뻗고 잘 수 있어"),
                String(localized: "내 자신이 자랑스러워"),
                String(localized: "이건 완전히 운이라고 생각해"),
                String(localized: "완전히 에너지넘쳐")
            ]
        case .level2:
            return [
                String(localized: "나 스스로에게 화가나"),
                String(localized: "아니야 괜찮아 한번 더!"),
                String(localized: "이쯤이야 예상했어"),
                String(localized: "자신이 실망스러워"),
                String(localized: "다른사람이 질투나"),
                String(localized: "혼자인 것 같아 외로워")
            ]

        }
    }
    
    /// Mood chart percentage
    var chartValue: CGFloat {
        switch self {
        case .level1: return 15
        case .level2: return 25
        }
    }
    
    /// Mood chart color
    var chartColor: Color {
        switch self {
        case .level1: return [Color(#colorLiteral(red: 0.9837132096, green: 0.4513888955, blue: 0.4547883272, alpha: 1))][0]
        case .level2: return [Color(#colorLiteral(red: 0.9979071021, green: 0.6928624511, blue: 0.4608915448, alpha: 1))][0]
        }
    }
}

// MARK: - Mood Reasons
enum MoodReason: String, CaseIterable, Identifiable {
    case work, friends, nature, pets, fitness, travel, gaming, shopping
    var id: Int { hashValue }
}

