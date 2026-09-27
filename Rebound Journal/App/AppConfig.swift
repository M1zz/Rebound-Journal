//
//  AppConfig.swift
//  Rebound Journal
//
//  Created by hyunho lee on 2023/06/10.
//

import Foundation

/// 앱 밖으로 나가는 주소들.
enum AppConfig {
    static let supportEmail = "leeo@kakao.com"

    /// 메일 앱이 무엇이든 열리도록 `mailto:`로 둔다.
    /// (기본 메일 앱이 없으면 MFMailComposeViewController 는 아예 뜨지 않는다)
    static var supportMailURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: ReboundJournalSpec.appName)]
        return components.url!
    }

    /// 앱 공유 링크.
    static var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/id\(ReboundJournalSpec.appStoreID ?? "")")!
    }
}
