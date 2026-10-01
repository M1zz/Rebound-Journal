//
//  ReboundJournalApp.swift
//  Rebound Journal
//
//  Created by hyunho lee on 2023/06/10.
//

import SwiftUI
import SwiftData
import TipKit
import LeeoKit

@main
struct ReboundJournalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var manager = DataManager(preview: false)
    /// 징검돌 프로 권한. 앱 어디서든 `store.hasPro` 로 묻는다.
    @StateObject private var store = LeeoStore(
        config: ReboundJournalSpec.paywall!,
        unlockOverride: ReboundJournalApp.debugProOverride
    )

    #if DEBUG
    /// 확인·스크린샷용. 실행 인자 `-debug.pro YES` / `-debug.pro NO` 로 프로 권한을 못박는다.
    /// 인자가 없으면 실제 구매로 판정한다. 배포 빌드에는 이 길이 없다.
    private static let debugProOverride: (@MainActor () -> Bool?)? = {
        // 실행 인자는 문자열("YES")로 들어온다. `as? Bool` 로는 읽히지 않는다.
        UserDefaults.standard.string(forKey: "debug.pro").map { ($0 as NSString).boolValue }
    }
    #else
    private static let debugProOverride: (@MainActor () -> Bool?)? = nil
    #endif

    init() {
        LeeoEngagement.shared.registerLaunch()
        // 페이월·구매 이벤트가 FeedbackHub 로 모이게 한다.
        LeeoAnalyticsCenter.register(ReboundJournalSpec.self)

        // 안내는 조건이 맞는 순간 바로 띄운다. TipKit의 기본값은 하루에 하나라,
        // 그대로 두면 "대화를 한 번 끝냈을 때"라는 조건을 맞춰 놓고도 안내가
        // 다음 날로 밀린다. 그때는 이미 그 안내가 필요한 순간이 아니다.
        //
        // 실패해도 앱은 그대로 돌아간다. 안내가 안 뜰 뿐이라 붙잡지 않는다.
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }

    var sharedModelContainer: ModelContainer = {
        // ⚠️ 스키마를 바꾸지 않는다. 기존 사용자 기록이 이 두 모델에 있다.
        let schema = Schema([
            JournalData.self,
            SubGoalData.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            #if DEBUG
            ScreenshotMode.seed(container)
            #endif
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            SkinnedRoot()
                .environmentObject(manager)
                .environmentObject(store)
                .environment(\.managedObjectContext, manager.container.viewContext)
                .modelContainer(sharedModelContainer)
                .leeoSatisfactionCheck(ReboundJournalSpec.self)
                .leeoStyle(.pebble)
        }
    }
}

/// 고른 조약돌 결을 앱 전체에 내려보낸다.
///
/// 프로 권한이 없으면(환불 등) 고른 값은 남겨 두고 기본 돌로 그린다.
private struct SkinnedRoot: View {
    @EnvironmentObject private var store: LeeoStore
    @AppStorage(PebbleSkin.storageKey) private var chosenSkin = PebbleSkin.free.rawValue

    var body: some View {
        RootView()
            .environment(
                \.pebbleSkin,
                PebbleSkin.effective(PebbleSkin(rawValue: chosenSkin) ?? .free, hasPro: store.hasPro)
            )
    }
}
