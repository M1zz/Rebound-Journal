//
//  DataManager.swift
//  Rebound Journal
//
//  Created by hyunho lee on 2023/06/10.
//

import SwiftUI
import CoreData
import SwiftData
import Foundation


/// Full Screen flow
enum FullScreenMode: Int, Identifiable {
    case entryCreator, readJournalView, reboundCreator, passcodeView, setupPasscodeView, chartView, timelineView, goalTimelineView
    var id: Int { hashValue }
}

/// Main data manager for the app
class DataManager: NSObject, ObservableObject {
    
    /// Dynamic properties that the UI will react to
    @Published var showLoading: Bool = false
    @Published var fullScreenMode: FullScreenMode?
    @Published var performance: [String: MoodLevel] = [String: MoodLevel]()
    @Published var selectedDate: Date = Date()
    @Published var selectedEntryImage: UIImage?
    @Published var seledtedEntry: JournalData?
    @Published var selectedGoal: String?  // 선택된 목표 (목표별 타임라인용)
    //@Published var quotes: QuotesList = QuotesList()
    @Published var didEnterCorrectPasscode: Bool = false
    
    //    /// Dynamic properties that the UI will react to AND store values in UserDefaults
    @AppStorage("savedPasscode") var savedPasscode: String = ""
    @AppStorage("enableReminders") var enableReminders: Bool = false
    @AppStorage("reminderTime") var reminderTime: String = "9:00 AM"
    //    @AppStorage(AppConfig.premiumVersion) var isPremiumUser: Bool = false
    //{
    //didSet { Interstitial.shared.isPremiumUser = isPremiumUser }
    //}
    
    /// Core Data container with the database model
    let container: NSPersistentContainer = NSPersistentContainer(name: "Database")
    
    
    /// Default init method. Load the Core Data container
    init(preview: Bool = false) {
        super.init()
        if preview {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true
        
        container.loadPersistentStores { _, _ in
            self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
        //fetchQuotesData()
    }
    
    /// Calendar days
    var calendarDays: [Date] {
        var days = [Date]()
        for index in 0..<AppConfig.headerTitleDaysCount {
            let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: -index, to: Date())!
            days.append(date)
        }
        days.removeLast()
        days.insert(Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: Date())!, at: 0)
        return days.reversed()
    }
    
    /// Fetch all quotes from local `Quotes` json
    //    private func fetchQuotesData() {
    //        guard let path = Bundle.main.path(forResource: "Quotes", ofType: "json"),
    //              let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe),
    //              let models = try? JSONDecoder().decode(QuotesList.self, from: data)
    //        else { return }
    //        quotes = models.shuffled()
    //    }
}

// MARK: - Save Journal Entry to Core Data
extension DataManager {
    
    /// Save journal entries to Core Data_V2
    /// 1.0.5 기준으로 수정사항을 반영한 함수
    /// 느낀 점은 [MoodReason]이 아닌 String으로 저장
    /// 이미지는 저장하지 않기 때문에 삭제
    func saveEntry_V2(text: String,
                      moodLevel: Int,
                      moodText: String,
                      reboundText: String,
                      reasons: String,
                      isRebounded: Bool = false,
                      hasDeleted: Bool = false) {
        let entryModelId = UUID().uuidString
        let entryModel = JournalEntry(context: container.viewContext)
        entryModel.id = entryModelId
        entryModel.isRebounded = isRebounded
        entryModel.moodLevel = Int16(moodLevel)
        entryModel.moodText = moodText
        entryModel.reboundText = reboundText
        entryModel.hasDeleted = hasDeleted
        entryModel.reasons = reasons
        entryModel.date = Date()
        try? container.viewContext.save()
    }
    
    /// Save journal entries to Core Data
    func saveEntry(text: String,
                   moodLevel: Int,
                   moodText: String,
                   reboundText: String,
                   reasons: [MoodReason],
                   isRebounded: Bool = false,
                   images: [UIImage],
                   hasDeleted: Bool = false) {
        let entryModelId = UUID().uuidString
        let entryModel = JournalEntry(context: container.viewContext)
        entryModel.id = entryModelId
        entryModel.isRebounded = isRebounded
        entryModel.moodLevel = Int16(moodLevel)
        entryModel.moodText = moodText
        entryModel.reboundText = reboundText
        entryModel.hasDeleted = hasDeleted
        entryModel.reasons = reasons.map({ $0.rawValue }).joined(separator: ";")
        for index in 0..<images.count {
            saveImage(images[index], id: "\(entryModelId)-\(index)-thumbnail", thumbnail: true)
            saveImage(images[index], id: "\(entryModelId)-\(index)", thumbnail: false)
        }
        entryModel.date = Date()
        try? container.viewContext.save()
    }
    
    /// Save journal entry image to documents folder
    func saveImage(_ image: UIImage, id: String, thumbnail: Bool) {
        let maxImageWidth = UIScreen.main.bounds.width/2
        let thumbnailQuality = 0.6
        let originalQuality = 0.9
        if thumbnail {
            if let thumbnailData = image.resizeImage(newWidth: maxImageWidth).jpegData(compressionQuality: thumbnailQuality) {
                saveImage(data: thumbnailData, id: id)
            }
        } else {
            if let imageData = image.jpegData(compressionQuality: originalQuality) {
                saveImage(data: imageData, id: id)
            }
        }
    }
}

// MARK: - Update Journal Entry to Core Data
extension DataManager {
    func updateSelectedEntry(modelContext: ModelContext, with selectedEntry: JournalData) {
        selectedEntry.isRebounded = true
        try? modelContext.save()
    }
}

// MARK: - Delete Journal Entry to Core Data
extension DataManager {
    func deleteSelectedEntry(modelContext: ModelContext, with selectedEntry: JournalData) {
        selectedEntry.hasDeleted = true
        try? modelContext.save()
    }
}

// MARK: - Save/Fetch image from documents folder
extension DataManager {
    /// Load image from documents folder
    func loadImage(id: String) -> UIImage? {
        guard let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        if let imageData = try? Data(contentsOf: documentsUrl.appendingPathComponent("\(id).jpg")) {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    /// Save image to the documents folder
    func saveImage(data: Data, id: String) {
        guard let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = documentsUrl.appendingPathComponent("\(id).jpg")
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Load images from documents
extension DataManager {
    /// Load images for a journal entry id
    func loadImages(id: String, thumbnails: Bool = true) -> [UIImage]? {
        var images = [UIImage]()
        let imageName = "\(id)-index\(thumbnails ? "-thumbnail" : "")"
        for index in 0..<4 {
            let updatedName = imageName.replacingOccurrences(of: "index", with: "\(index)")
            if let image = loadImage(id: updatedName) {
                image.accessibilityIdentifier = updatedName
                images.append(image)
            }
        }
        return images
    }
}

// MARK: - Schedule daily reminders
extension DataManager {
    
    /// Schedule a daily reminder if needed
    func scheduleDailyReminderIfNeeded() {
        func removePendingNotifications() {
            let center = UNUserNotificationCenter.current()
            center.removeAllDeliveredNotifications()
            center.removeAllPendingNotificationRequests()
        }
        
        if enableReminders {
            removePendingNotifications()
            let notificationContent = UNMutableNotificationContent()
            notificationContent.title = "징검돌"
            // 재촉하지 않는다. "실패"를 꺼내지도, 미루지 말라고 다그치지도 않는다(§4·§5).
            notificationContent.body = "오늘 어땠는지, 잠깐 같이 볼까요?"
            notificationContent.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: reminderTime.dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "reminder", content: notificationContent, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { _ in }
        } else {
            removePendingNotifications()
        }
    }
    
}

// MARK: - Fetch Journal Entries
extension DataManager {
    static func loadJournalEntries(context: NSManagedObjectContext) -> [JournalEntry] {
        let request = NSFetchRequest<JournalEntry>(entityName: "JournalEntry")
        
        debugPrint("뷰모델 : \(context)")
        do {
            let items = try context.fetch(request)
            return items
        } catch {
            debugPrint("데이터 읽기 실패: \(error)")
            return []
        }
    }
}

// MARK: Sync SwiftData with CoreData

extension DataManager {

    /// SwiftData 내의 ID만 반환하는 함수
    func fetchSwiftDataIDs(context: ModelContext) -> [String] {
        do {
            let journalData: [JournalData] = try context.fetch(FetchDescriptor<JournalData>())
            return journalData.compactMap { $0.id }
        } catch {
            debugPrint("데이터를 찾을 수 없습니다.")
            return []
        }
    }

    /// 중복되지 않는 JournalEntry를 반환하는 함수
    func fetchNonDuplicateCoreDataEntries(context: NSManagedObjectContext, modelContext: ModelContext) -> [JournalEntry] {
        let fetchRequest = NSFetchRequest<JournalEntry>(entityName: "JournalEntry")
        let swiftDataIDs = fetchSwiftDataIDs(context: modelContext)
        
        do {
            let coreDataEntries = try context.fetch(fetchRequest)
            let nonDuplicateEntries = coreDataEntries.filter { entry in
                guard let entryID = entry.id else { return false }
                return !swiftDataIDs.contains(entryID)
            }
            return nonDuplicateEntries
        } catch {
            debugPrint("Error fetching non-duplicate CoreData entries: \(error)")
            return []
        }
    }
    
    /// 중복되지 않은 데이터가 있다면 저장하는 함수
    func convertDupicateDataToSwiftData(nsContext: NSManagedObjectContext, modelContext: ModelContext) {
        let data = fetchNonDuplicateCoreDataEntries(context: nsContext, modelContext: modelContext)
        
        if !data.isEmpty {
            for item in data {
                let newData = JournalData(id: item.id,
                                          date: item.date,
                                          hasDeleted: item.hasDeleted,
                                          isGoalIn: (item.moodLevel == 1) ? true : false,
                                          emotionValue: 0,
                                          emotionText: item.moodText,
                                          review: item.text,
                                          nextPlan: item.reboundText,
                                          isRebounded: item.isRebounded,
                                          purpose: nil,
                                          mainGoal: nil,
                                          subGoal: nil)
                modelContext.insert(newData)
            }
            debugPrint("Sync \(data.count) Data")
        }
        else {
            debugPrint("There is no data to sync")
        }
    }
}
