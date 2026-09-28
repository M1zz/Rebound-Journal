//
//  DataEraser.swift
//  Rebound Journal
//
//  모든 기록을 지운다. 되돌릴 수 없다.
//
//  지우는 것: 목표, 남긴 기록, 1.x 시절 CoreData 기록과 사진, 위젯에 걸린 한 마디.
//  남기는 것: 설정(비밀번호·알림·말투·조약돌 결·소리), 구매(프로).
//    — 기록을 비우고 싶은 것이지 앱을 처음 상태로 돌리고 싶은 게 아니다.
//      구매는 애초에 지울 수도 없다 (App Store 계정에 있다).
//
//  ⚠️ 1.x CoreData 저장소를 같이 비우지 않으면, 다음 실행 때 이관
//     (`DataManager.migrateCoreDataToSwiftData`)이 옛 기록을 **다시 가져온다.**
//     지운 기록이 되살아나는 건 이 기능에서 가장 나쁜 실패다.
//
//  하나씩 지운다. 한꺼번에 지우는 배치 삭제는 iCloud 동기화에 실리지 않을 수 있어서,
//  이 기기에서만 비고 다른 기기에서 다시 내려올 수 있다.
//

import Foundation
import CoreData
import SwiftData
import WidgetKit

@MainActor
enum DataEraser {

    static func eraseAll(modelContext: ModelContext, legacyContainer: NSPersistentContainer) throws {
        for journal in try modelContext.fetch(FetchDescriptor<JournalData>()) {
            modelContext.delete(journal)
        }
        for goal in try modelContext.fetch(FetchDescriptor<SubGoalData>()) {
            modelContext.delete(goal)
        }
        try modelContext.save()

        try eraseLegacyStore(legacyContainer)
        eraseLegacyPhotos()

        // 홈 화면의 조약돌이 지운 기록 얘기를 계속하면 안 된다.
        PebbleSnapshot.save(.resting)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 1.x CoreData 기록. 이관이 다시 가져가지 못하게 원본을 비운다.
    private static func eraseLegacyStore(_ container: NSPersistentContainer) throws {
        let context = container.viewContext
        let entries = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "JournalEntry"))
        guard !entries.isEmpty else { return }
        entries.forEach(context.delete)
        try context.save()
    }

    /// 1.x 에서 기록에 붙이던 사진 (Documents/<id>-<n>[-thumbnail].jpg).
    private static func eraseLegacyPhotos() {
        let files = FileManager.default
        guard let documents = files.urls(for: .documentDirectory, in: .userDomainMask).first,
              let items = try? files.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil) else { return }
        for url in items where url.pathExtension.lowercased() == "jpg" {
            try? files.removeItem(at: url)
        }
    }
}
