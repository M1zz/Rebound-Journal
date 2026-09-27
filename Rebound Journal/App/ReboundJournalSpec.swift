//
//  ReboundJournalSpec.swift
//  Rebound Journal
//
//  LeeoKit 계약. 피드백·법적 링크·수익모델을 한곳에서 선언한다.
//

import Foundation
import LeeoKit

enum ReboundJournalSpec: LeeoAppSpec {
    /// 메일 제목·만족도 안내·페이월에 나가는 이름. 스토어 이름과 같게 언어별로.
    /// (FeedbackHub는 `appIdentifier`로 앱을 가르므로 이 값이 바뀌어도 모이는 곳은 같다)
    static let appName = String(localized: "징검돌")
    static let developerEmail = "mizzking75@gmail.com"

    /// ⚠️ appIdentifier 는 FeedbackHub 에 쌓인 피드백·사용 통계와의 계약이다. 바꾸지 않는다.
    static let feedback = LeeoFeedbackConfig(
        containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
        appIdentifier: "com.leeo.ReboundJournal"
    )

    /// App Store 숫자 ID — 리뷰 딥링크, 공유 링크(`AppConfig.appStoreURL`).
    static let appStoreID: String? = "6450388408"

    /// ⚠️ 개인정보 처리방침 주소는 App Store Connect 에 등록한 것과 같아야 한다.
    ///    페이지 원본은 레포의 `docs/` (GitHub Pages, main 브랜치 /docs).
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/Rebound-Journal/privacy.html")!,
        supportURL: URL(string: "https://m1zz.github.io/Rebound-Journal/")!,
        // 계정을 만들지 않는다. 기록은 기기와 사용자의 iCloud 에만 있다.
        createsAccounts: false,
        marketingURL: URL(string: "https://m1zz.github.io/Rebound-Journal/")!
    )

    /// 페이월 퍼널(노출·게이트·구매 시도·완료·복원)을 FeedbackHub 사용 통계로 보낸다.
    /// 이벤트 이름만 올라가고 기록 내용은 나가지 않는다 (`UsageReporting` 과 같은 저장소).
    static let analytics: any LeeoAnalytics = LeeoUsageAnalytics(spec: ReboundJournalSpec.self)

    /// 평생 이용권 상품 ID.
    /// ⚠️ App Store Connect·구매자 영수증과의 계약이다. 한 번 팔기 시작하면 바꾸지 않는다.
    static let proProductID = "com.leeo.ReboundJournal.pro"

    /// 수익모델 — 무료로 쓰다가 **한 번 사면 평생** (구독 아님). 근거는 `docs/BUSINESS.md`.
    ///
    /// 게이트 키는 `ProFeature.rawValue` 와 같다.
    ///  - goal: 무료로 품을 수 있는 목표 수. '새 목표 적기'에서만 따진다. 대화 중에 스스로
    ///    쪼갠 목표는 개수에 들어가지만 막지 않는다 — 대화 한가운데 페이월을 띄우지 않는다.
    ///  - pebbleSkin / export: 프로 전용.
    static let monetization = LeeoMonetization.freemium(
        LeeoPurchaseConfig(
            productIDs: [proProductID],
            gate: LeeoGatePolicy(
                freeLimits: [ProFeature.moreGoals.rawValue: ProFeature.freeGoalLimit],
                proOnly: [ProFeature.pebbleSkin.rawValue, ProFeature.export.rawValue],
                warnWhenRemaining: 1
            ),
            // 위젯과 같은 앱 그룹. 오프라인에서도 마지막으로 확인한 권한으로 곧바로 연다.
            cacheSuiteName: PebbleSnapshot.appGroup
        )
    )
}
