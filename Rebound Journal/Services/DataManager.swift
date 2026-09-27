//
//  DataManager.swift
//  Rebound Journal
//
//  Created by hyunho lee on 2023/06/10.
//
//  기록 자체는 SwiftData(`JournalData`/`SubGoalData`)가 들고 있다. 여기 남은 건
//  화면 사이에서 함께 봐야 하는 몇 가지 상태뿐이다.
//
//   - 비밀번호 잠금
//   - 매일 알림
//   - 1.x 시절 CoreData 기록을 SwiftData로 옮기기
//

import SwiftUI
import CoreData
import SwiftData

/// 앱 전체를 덮는 화면. 지금은 비밀번호 화면만 이렇게 띄운다.
///
/// 저장하지 않는 값이라 케이스를 줄여도 기존 사용자에게 영향이 없다.
enum FullScreenMode: Int, Identifiable {
    case passcodeView, setupPasscodeView
    var id: Int { rawValue }
}

final class DataManager: NSObject, ObservableObject {

    @Published var fullScreenMode: FullScreenMode?
    @Published var didEnterCorrectPasscode: Bool = false

    // ⚠️ 키 이름은 기존 사용자의 UserDefaults와 맞물려 있다. 바꾸지 않는다.
    @AppStorage("savedPasscode") var savedPasscode: String = ""
    @AppStorage("enableReminders") var enableReminders: Bool = false
    @AppStorage("reminderTime") var reminderTime: String = "9:00 AM"

    /// 1.x에서 쓰던 CoreData 저장소. 옮겨 올 기록을 읽는 데만 쓴다.
    ///
    /// ⚠️ 모델 이름 "Database"와 엔티티 `JournalEntry`는 이관이 기대는 값이다.
    let container: NSPersistentContainer = NSPersistentContainer(name: "Database")

    init(preview: Bool = false) {
        super.init()
        let description = container.persistentStoreDescriptions.first
        if preview {
            description?.url = URL(fileURLWithPath: "/dev/null")
        }
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true

        container.loadPersistentStores { [weak self] _, error in
            // 옛 저장소를 못 열어도 앱은 그대로 쓸 수 있다. 옮겨 올 기록이 없는 것과 같다.
            if let error {
                debugPrint("CoreData 저장소를 열지 못함: \(error)")
                return
            }
            self?.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
    }
}

// MARK: - 매일 알림

extension DataManager {

    func scheduleDailyReminderIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        guard enableReminders else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "징검돌")
        // 재촉하지 않는다. "실패"를 꺼내지도, 미루지 말라고 다그치지도 않는다(§4·§5).
        content.body = String(localized: "오늘 어땠는지, 잠깐 같이 볼까요?")
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: reminderTime.dateComponents, repeats: true)
        center.add(UNNotificationRequest(identifier: "reminder", content: content, trigger: trigger)) { _ in }
    }
}

// MARK: - CoreData → SwiftData 이관

extension DataManager {

    /// SwiftData에 아직 없는 CoreData 기록을 옮겨 온다.
    ///
    /// 앱을 열 때마다 불린다. id로 이미 옮긴 것을 걸러내므로 여러 번 불러도 겹치지 않는다.
    func migrateCoreDataToSwiftData(nsContext: NSManagedObjectContext, modelContext: ModelContext) {
        let pending = coreDataEntriesNotYetMigrated(context: nsContext, modelContext: modelContext)
        guard !pending.isEmpty else { return }

        for item in pending {
            modelContext.insert(JournalData(
                id: item.id,
                date: item.date,
                hasDeleted: item.hasDeleted,
                isGoalIn: item.moodLevel == 1,
                emotionValue: 0,
                emotionText: item.moodText,
                review: item.text,
                nextPlan: item.reboundText,
                isRebounded: item.isRebounded,
                purpose: nil,
                mainGoal: nil,
                subGoal: nil
            ))
        }
        do {
            try modelContext.save()
            debugPrint("CoreData 기록 \(pending.count)개를 옮김")
        } catch {
            debugPrint("CoreData 기록을 옮기다 저장 실패: \(error)")
        }
    }

    private func coreDataEntriesNotYetMigrated(context: NSManagedObjectContext, modelContext: ModelContext) -> [JournalEntry] {
        do {
            let migrated = Set(try modelContext.fetch(FetchDescriptor<JournalData>()).compactMap(\.id))
            let entries = try context.fetch(NSFetchRequest<JournalEntry>(entityName: "JournalEntry"))
            return entries.filter { entry in
                guard let id = entry.id else { return false }
                return !migrated.contains(id)
            }
        } catch {
            debugPrint("이관할 CoreData 기록을 읽지 못함: \(error)")
            return []
        }
    }
}
