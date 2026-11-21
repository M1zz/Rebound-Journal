//
//  MochimoApp.swift
//  Mochimo
//
//  Created by hyunho lee on 2023/06/10.
//

import SwiftUI
import SwiftData
import AppIntents
import TipKit
import LeeoKit

@main
struct MochimoApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #else
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @StateObject private var manager = DataManager(preview: false)
    /// 모찌모 프로 권한. 앱 어디서든 `store.hasPro` 로 묻는다.
    @StateObject private var store = LeeoStore(
        config: MochimoSpec.paywall!,
        unlockOverride: MochimoApp.debugProOverride
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
        // 백업 금고 — 예약된 복원 적용 · 업데이트 직전 백업. 저장소를 열기 전에 가장 먼저.
        LeeoVault.start(MochimoSpec.self)
        // 저장소는 금고 뒤에 연다 (프로퍼티 초기값으로 두면 init 보다 먼저 열린다)
        sharedModelContainer = Self.makeModelContainer()
        // Siri 인텐트가 같은 저장소를 쓴다 (→ StepIntents.swift)
        let container = sharedModelContainer
        AppDependencyManager.shared.add(dependency: container)
        LeeoEngagement.shared.registerLaunch()
        // 페이월·구매 이벤트가 FeedbackHub 로 모이게 한다.
        LeeoAnalyticsCenter.register(MochimoSpec.self)
        // 크래시·멈춤 진단(MetricKit)도 같은 곳으로. 설정에서 통계를 끄면 이것도 보내지 않는다.
        LeeoDiagnostics.shared.start(spec: MochimoSpec.self, isEnabled: { UsageReporting.isEnabled })

        // 안내는 조건이 맞는 순간 바로 띄운다. TipKit의 기본값은 하루에 하나라,
        // 그대로 두면 "대화를 한 번 끝냈을 때"라는 조건을 맞춰 놓고도 안내가
        // 다음 날로 밀린다. 그때는 이미 그 안내가 필요한 순간이 아니다.
        //
        // 실패해도 앱은 그대로 돌아간다. 안내가 안 뜰 뿐이라 붙잡지 않는다.
        #if DEBUG
        // 확인용: 실행 인자 `-debug.tips YES` 면 조건과 상관없이 안내를 모두 띄운다.
        if UserDefaults.standard.bool(forKey: "debug.tips") { Tips.showAllTipsForTesting() }
        // 스크린샷에는 안내 카드가 겹치지 않게 한다.
        if ScreenshotMode.isActive { Tips.hideAllTipsForTesting() }
        #endif
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }

    let sharedModelContainer: ModelContainer

    /// 스크린샷을 찍는 중인지(DEBUG `-shot`). 감사 팝업 같은 한 번뿐인 창을 띄우지 않는다.
    private static var isTakingScreenshots: Bool {
        #if DEBUG
        ScreenshotMode.isActive
        #else
        false
        #endif
    }

    private static func makeModelContainer() -> ModelContainer {
        // ⚠️ 스키마를 바꾸지 않는다. 기존 사용자 기록이 이 두 모델에 있다.
        let schema = Schema([
            JournalData.self,
            SubGoalData.self
        ])
        var modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        #if DEBUG
        // 스크린샷 모드는 기록을 지우고 샘플을 심는다. 이 기기의 진짜 기록과 iCloud 에 닿지 않게 메모리에서만 연다.
        if ScreenshotMode.isActive {
            modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        #endif

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            #if DEBUG
            ScreenshotMode.seed(container)
            #endif
            return container
        } catch {
            return StoreFallback.memoryContainer(schema: schema, after: error)
        }
    }

    var body: some Scene {
        WindowGroup(id: MochimoWindow.main) {
            SkinnedRoot()
                .arabicLayout()
                .storeFallbackNotice()
                .environmentObject(manager)
                .environmentObject(store)
                .environment(\.managedObjectContext, manager.container.viewContext)
                .modelContainer(sharedModelContainer)
                .satisfactionCheck(enabled: !Self.isTakingScreenshots)
                // 프로가 되면 콘페티, 모든 사용자는 한 번 감사를 받는다 (LeeoKit 3.46).
                .celebrations(enabled: !Self.isTakingScreenshots)
                // 개발자가 보낸 의견에 답장하면, 앱이 앞으로 올 때 답장을 시트로 보여 준다 (LeeoKit).
                .leeoFeedbackReplyNotice(MochimoSpec.self)
                .leeoStyle(.pebble)
                // 창 크기로 접힘을 재서 아래로 흘린다. 시트 · 알림창도 접힌 선을 비킨다 (LeeoKit Fold).
                .foldAware()
        }
        .commands { MochimoCommands() }
        // 맥 창은 처음에 대화와 지나온 길이 나란히 들어갈 만큼 연다. 아이패드에서는 쓰이지 않는다.
        .defaultSize(width: 1100, height: 760)

        #if os(macOS)
        // 메뉴 막대의 모찌 (→ MenuBarPebble.swift)
        MenuBarExtra {
            QuickNoteView()
                .arabicLayout()
                .environmentObject(manager)
                .modelContainer(sharedModelContainer)
        } label: {
            MenuBarPebbleLabel()
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}

/// 고른 친구와 결을 앱 전체에 내려보낸다.
///
/// 프로 권한이 없으면(환불 등) 고른 값은 남겨 두고 기본 돌로 그린다.
private struct SkinnedRoot: View {
    @EnvironmentObject private var store: LeeoStore
    @AppStorage(PebbleSkin.storageKey) private var chosenSkin = PebbleSkin.free.rawValue
    @AppStorage(PebbleBuddy.storageKey) private var chosenBuddy = PebbleBuddy.default.rawValue

    var body: some View {
        RootView()
            .environment(\.pebbleBuddy, PebbleBuddy(rawValue: chosenBuddy) ?? .default)
            .environment(
                \.pebbleSkin,
                PebbleSkin.effective(PebbleSkin(rawValue: chosenSkin) ?? .free, hasPro: store.hasPro)
            )
    }
}

// MARK: - 저장소를 못 연 날
//
// 예전에는 fatalError 로 죽었다. 그러면 마이그레이션 한 번 어긋난 사용자는 켤 때마다 죽고,
// 기기 안에 멀쩡히 있는 기록도 못 본다. 이제는 디스크의 기록은 건드리지 않고 이번 실행만
// 메모리에서 열고, 사용자에게 그 사실을 알린다.

enum StoreFallback {
    /// 이번 실행이 임시(메모리) 저장소로 열렸는가
    private(set) static var isActive = false

    static func memoryContainer(schema: Schema, after error: Error) -> ModelContainer {
        isActive = true
        print("⚠️ 저장소를 열지 못해 이번 실행은 메모리에서 엽니다: \(error)")
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            )
        } catch {
            // 메모리 저장소마저 안 되는 건 스키마 자체가 잘못된 것 — 개발 중에 바로 드러난다
            fatalError("메모리 저장소도 열지 못함: \(error)")
        }
    }
}

extension View {
    /// 임시 저장소로 열렸으면 한 번 알린다. 앱의 맨 바깥 화면에 붙인다.
    func storeFallbackNotice() -> some View {
        modifier(StoreFallbackNotice())
    }
}

private struct StoreFallbackNotice: ViewModifier {
    @State private var isPresented = StoreFallback.isActive

    func body(content: Content) -> some View {
        content.alert("기록을 열지 못했어요", isPresented: $isPresented) {
        } message: {
            Text("저장된 기록은 지워지지 않았어요. 다만 지금 적는 내용은 저장되지 않으니, 앱을 껐다 켜 보세요.")
        }
    }
}

extension View {
    /// 아랍어에서는 화면을 오른쪽에서 왼쪽으로 놓고, 숫자 · 날짜를 0~9 와 양력으로 맞춘다 (§`AppLanguage.locale`).
    /// 맥은 앱 언어만 아랍어일 때 창 안을 왼쪽부터 그려서 방향을 직접 준다. 맥의 시트는 따로 뜬 창이라
    /// 이 값을 물려받지 못하니, 시트 안 화면에도 붙인다. 아이폰 · 아이패드에서는 원래 방향과 같아 아무것도 바뀌지 않는다.
    /// 다른 언어는 기기 설정을 그대로 따르게 손대지 않는다.
    @ViewBuilder
    func arabicLayout() -> some View {
        if AppLanguage.isArabic {
            environment(\.locale, AppLanguage.locale)
                .environment(\.layoutDirection, .rightToLeft)
        } else {
            self
        }
    }
}

private extension View {
    /// 쓰다 보면 "즐겁게 쓰고 계신가요?" 를 묻는다 (LeeoKit). 스크린샷을 찍을 때는 붙이지 않는다 —
    /// 같은 기기에서 여러 번 띄우다 보면 조건이 차서 화면을 가린다.
    @ViewBuilder
    func satisfactionCheck(enabled: Bool) -> some View {
        if enabled {
            leeoSatisfactionCheck(MochimoSpec.self)
        } else {
            self
        }
    }

    /// 프로가 되면 콘페티, 모든 사용자는 한 번 감사를 받는다 (LeeoKit). 스크린샷을 찍을 때는 붙이지 않는다.
    @ViewBuilder
    func celebrations(enabled: Bool) -> some View {
        if enabled {
            leeoCelebrations(appName: MochimoSpec.displayName)
        } else {
            self
        }
    }
}
