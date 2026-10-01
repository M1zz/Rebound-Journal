//
//  ScreenshotMode.swift
//  Rebound Journal
//
//  App Store 스크린샷을 찍는 자리. **DEBUG 빌드에서만** 있다.
//
//  시뮬레이터는 손으로 누를 수 없으니 실행 인자로 화면을 연다:
//
//      xcrun simctl launch <기기> com.leeo.ReboundJournal -shot lookBack -AppleLanguages "(en)"
//
//  `-shot` 이 붙으면 기존 데이터를 비우고 그 언어로 된 기록을 새로 심는다.
//  값: home · conversation · lookBack · records · addGoal · settings
//

#if DEBUG
import Foundation
import SwiftData

enum ScreenshotMode {

    /// `-shot <화면>` 실행 인자. 인자는 UserDefaults 로 들어온다.
    static var scene: String? { UserDefaults.standard.string(forKey: "shot") }

    static var isActive: Bool { scene != nil }

    private static var isKorean: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ko") ?? true
    }

    static func seed(_ container: ModelContainer) {
        guard isActive else { return }
        let context = ModelContext(container)
        try? context.delete(model: JournalData.self)
        try? context.delete(model: SubGoalData.self)

        let ko = isKorean
        let walk = ko ? "저녁에 30분 걷기" : "Walk 30 minutes after dinner"
        let wake = ko ? "7시에 일어나기" : "Wake up at 7"
        let read = ko ? "자기 전 책 10쪽" : "Read 10 pages before bed"
        for goal in [walk, wake, read] {
            context.insert(SubGoalData(id: UUID().uuidString, date: .now, goalText: goal))
        }

        // (며칠 전, 목표, 해냈나, 감정, 느낀 점, 다음엔)
        let records: [(Int, String, Bool, Int, String, String)] = ko ? [
            (0, walk, true, 4, "비가 그쳐서 한강까지 걸었다. 걷고 나니 머리가 맑아졌다.", ""),
            (1, wake, false, 2, "알람을 끄고 다시 잠들었다. 새벽 2시까지 휴대폰을 봤다.", "11시 반에 휴대폰을 거실에 두고 오기"),
            (2, walk, true, 4, "동생이랑 같이 걸었다. 혼자일 때보다 금방 지나갔다.", ""),
            (3, read, true, 3, "10쪽만 읽으려다 한 장을 다 읽었다.", ""),
            (4, walk, false, 2, "야근하고 오니 9시. 걸을 힘이 없었다.", "늦는 날은 집 앞 한 바퀴만"),
            (5, wake, true, 4, "커튼을 열어 두고 잤더니 저절로 눈이 떠졌다.", ""),
            (6, read, true, 3, "누워서 읽으니 잠이 잘 왔다.", ""),
        ] : [
            (0, walk, true, 4, "The rain stopped, so I walked all the way to the river. My head feels clear.", ""),
            (1, wake, false, 2, "Turned off the alarm and fell back asleep. I was on my phone until 2 a.m.", "Leave my phone in the living room at 11:30"),
            (2, walk, true, 4, "Walked with my sister. Time flew compared to walking alone.", ""),
            (3, read, true, 3, "Meant to read 10 pages and finished a whole chapter.", ""),
            (4, walk, false, 2, "Got home at 9 after working late. No energy left to walk.", "On late days, just one lap around the block"),
            (5, wake, true, 4, "Slept with the curtains open and woke up on my own.", ""),
            (6, read, true, 3, "Reading in bed made me sleepy in a good way.", ""),
        ]
        let calendar = Calendar.current
        for (daysAgo, goal, done, emotion, review, next) in records {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now)!
            context.insert(JournalData(
                id: UUID().uuidString,
                date: date,
                isGoalIn: done,
                emotionValue: emotion,
                review: review,
                nextPlan: next,
                isRebounded: false,
                subGoal: goal,
                isResolved: done ? nil : false
            ))
        }
        try? context.save()
    }
}
#endif
