//
//  AppDelegate.swift
//  Rebound Journal
//
//  Created by hyunho lee on 12/8/24.
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UITextView.appearance().backgroundColor = .clear
        UNUserNotificationCenter.current().delegate = self
        #if DEBUG
        // 스크린샷에 알림 허락 창이 덮이지 않게.
        if ScreenshotMode.isActive { return true }
        #endif
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        // 추적 권한(ATT)은 묻지 않는다. 광고도 추적도 없는 앱이 그 창을 띄우면
        // 심사에서 사유 없는 요청으로 걸리고, 사용자에게는 괜한 의심만 남긴다.
        return true
    }
}

// MARK: - 앱이 켜져 있을 때 온 알림도 보여 준다

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.sound, .list, .banner])
    }
}
