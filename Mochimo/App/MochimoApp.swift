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
        // Siri 인텐트가 같은 저장소를 쓴다 (→ StepIntents.swift).
        // 저장소를 못 열었어도 **언제나** 넣는다. 아무것도 넣지 않으면 인텐트가 `@Dependency` 를
        // 읽는 순간 앱이 죽는다 — Siri · 단축어에서 부르면 사용자는 이유도 모른 채 실패만 본다.
        let intentStore = IntentStore(container: sharedModelContainer, isTemporary: StoreFallback.isActive)
        AppDependencyManager.shared.add(dependency: intentStore)
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

    /// nil 이면 저장소를 디스크로도 메모리로도 열지 못한 것 — 화면 대신 안내만 띄운다(`StoreBrokenView`).
    let sharedModelContainer: ModelContainer?

    /// 스크린샷을 찍는 중인지(DEBUG `-shot`). 감사 팝업 같은 한 번뿐인 창을 띄우지 않는다.
    private static var isTakingScreenshots: Bool {
        #if DEBUG
        ScreenshotMode.isActive
        #else
        false
        #endif
    }

    private static func makeModelContainer() -> ModelContainer? {
        // ⚠️ 있는 모델과 속성을 지우거나 이름을 바꾸지 않는다. 기존 사용자 기록이 JournalData · SubGoalData 에 있다.
        //    더하는 것은 선택값으로만 (CloudKit). 새 모델 · 속성은 CloudKit 콘솔에서 프로덕션 스키마로 배포해야 동기화된다.
        let schema = Schema([
            JournalData.self,
            SubGoalData.self,
            LifeGoalData.self,
            ObstacleData.self,
            RecordPhoto.self
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
            if let sharedModelContainer {
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
            } else {
                StoreBrokenView()
                    .arabicLayout()
            }
        }
        .commands { MochimoCommands() }
        // 맥 창은 처음에 대화와 지나온 길이 나란히 들어갈 만큼 연다. 아이패드에서는 쓰이지 않는다.
        .defaultSize(width: 1100, height: 760)

        #if os(macOS)
        // 메뉴 막대의 모찌 (→ MenuBarPebble.swift)
        MenuBarExtra {
            if let sharedModelContainer {
                QuickNoteView()
                    .arabicLayout()
                    .environmentObject(manager)
                    .modelContainer(sharedModelContainer)
            } else {
                StoreBrokenView()
                    .arabicLayout()
            }
        } label: {
            if let sharedModelContainer {
                MenuBarPebbleLabel()
                    .modelContainer(sharedModelContainer)
            } else {
                Image(systemName: "exclamationmark.triangle")
            }
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

    /// 방금 적은 것을 디스크에 내리지 못했다는 알림. 맨 바깥 화면이 받아 한 번 알린다.
    static let saveFailed = Notification.Name("mochimo.store.saveFailed")
    /// 저장 실패는 이번 실행에 한 번만 알린다. 디스크가 찼으면 적을 때마다 실패하는데,
    /// 그때마다 창을 띄우면 쓰던 글을 가로막는다.
    @MainActor private static var didReportSaveFailure = false

    @MainActor
    static func reportSaveFailure(_ error: Error) {
        print("⚠️ 기록을 저장하지 못했습니다: \(error)")
        guard !didReportSaveFailure else { return }
        didReportSaveFailure = true
        NotificationCenter.default.post(name: saveFailed, object: nil)
    }

    static func memoryContainer(schema: Schema, after error: Error) -> ModelContainer? {
        isActive = true
        print("⚠️ 저장소를 열지 못해 이번 실행은 메모리에서 엽니다: \(error)")
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            )
        } catch {
            // 메모리 저장소마저 안 되는 건 스키마 자체가 잘못된 것 — 개발 중에 바로 드러난다.
            // 그래도 죽지는 않는다. 모든 화면이 이 모델들을 @Query 로 읽어 화면을 그릴 수는 없으니,
            // 저장소 없이 안내 한 장만 띄운다(`StoreBrokenView`). 켤 때마다 죽는 앱은 지우는 것 말고
            // 사용자가 할 수 있는 일이 없고, 지우면 기기 안의 기록도 같이 사라진다.
            print("⚠️ 메모리 저장소도 열지 못했습니다: \(error)")
            return nil
        }
    }
}

/// 저장소를 끝내 열지 못했을 때의 화면. 모델을 읽는 화면은 하나도 올리지 않는다.
///
/// 문구는 임시 저장소 알림과 같은 것을 쓴다 — 여기까지 오는 일은 거의 없어 새 문구를 스물네 개
/// 언어로 두지 않았다.
private struct StoreBrokenView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("기록을 열지 못했어요")
                .font(.title3.weight(.semibold))
            Text("저장된 기록은 지워지지 않았어요. 다만 지금 적는 내용은 저장되지 않으니, 앱을 껐다 켜 보세요.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        // 적은 것을 디스크에 내리지 못했을 때도 같은 말로 알린다 (→ ModelContext.saveNow).
        .onReceive(NotificationCenter.default.publisher(for: StoreFallback.saveFailed)) { _ in
            // 저장은 대개 시트를 닫는 순간에 한다. 시트가 내려가는 도중에는 알림창이 뜨지 못하니
            // 내려간 뒤에 띄운다.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { isPresented = true }
        }
    }
}

// MARK: - 적은 것을 바로 내리기 · 지워진 모델

extension ModelContext {
    /// 방금 적은 것을 바로 디스크에 내린다.
    ///
    /// 이 앱은 따로 저장을 부르지 않고 SwiftData 의 자동 저장에 맡겨 왔다. 자동 저장은 잠깐 뒤에
    /// 돌아서, 그 사이 앱이 죽거나 꺼지면 방금 남긴 기록이 조용히 사라진다. 사용자가 적은 것은
    /// 그 자리에서 내린다.
    ///
    /// 실패해도 바뀐 것은 컨텍스트에 남아 자동 저장이 다시 시도한다. 사용자에게는 한 번 알린다.
    @MainActor @discardableResult
    func saveNow() -> Bool {
        guard hasChanges else { return true }
        do {
            try save()
            return true
        } catch {
            StoreFallback.reportSaveFailure(error)
            return false
        }
    }
}

extension PersistentModel {
    /// 지워졌거나(이 화면 · 다른 창 · iCloud 동기화) 저장소에서 떨어져 나간 모델인지.
    ///
    /// 시트나 확인창이 모델을 쥐고 있는 사이 그 모델이 지워지고 저장까지 끝나면, 속성을 읽는
    /// 순간 SwiftData 가 "backing data could no longer be found" 로 앱을 죽인다. 쥐고 있던
    /// 모델을 읽거나 고치기 전에 이것부터 본다.
    var isGone: Bool { isDeleted || modelContext == nil }
}

extension Binding {
    /// `.sheet(item:)` 에 모델을 넘길 때 쓴다. 쥐고 있던 모델이 지워졌으면 없는 것으로 읽혀 시트가 닫힌다.
    ///
    /// 시트는 화면을 다시 그릴 때마다 `item.id` 를 읽는데, 이 앱의 모델은 `id` 가 저장된 속성이라
    /// 지워진 모델이면 거기서 죽는다. 시트 안 화면이 스스로 닫기 전에 바깥에서 먼저 막는다.
    func droppingGone<Model: PersistentModel>() -> Binding<Model?> where Value == Model? {
        Binding(
            get: {
                guard let model = wrappedValue, !model.isGone else { return nil }
                return model
            },
            set: { wrappedValue = $0 }
        )
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
