//
//  StepIntents.swift
//  ZinggumDol
//
//  "징검돌, 운동 오늘 했어" / "운동 오늘 못 했어" — 앱을 열지 않고 오늘의 한 걸음을 남긴다.
//  대화 화면이 저장하는 것과 같은 모양으로 남긴다(ConversationEngine.persist).
//

import AppIntents
import Foundation
import SwiftData

struct StepGoalEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("목표", comment: "Siri: one small goal")
    )
    static let defaultQuery = StepGoalQuery()

    let id: String
    let text: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(text)") }
}

struct StepGoalQuery: EntityStringQuery {
    @Dependency private var container: ModelContainer

    private func goals() -> [StepGoalEntity] {
        let all = (try? ModelContext(container).fetch(FetchDescriptor<SubGoalData>())) ?? []
        return all.compactMap { goal in
            guard let id = goal.id, let text = goal.goalText, !text.isEmpty else { return nil }
            return StepGoalEntity(id: id, text: text)
        }
    }

    func entities(for identifiers: [String]) async throws -> [StepGoalEntity] {
        goals().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [StepGoalEntity] {
        goals().filter { $0.text.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [StepGoalEntity] { goals() }
}

struct LogStepIntent: AppIntent {
    static let title = LocalizedStringResource("오늘 한 걸음 남기기", comment: "Siri: log today's step toward a goal")
    static let description = IntentDescription(
        LocalizedStringResource("오늘 목표를 디뎠는지 남깁니다.", comment: "Siri: log step description")
    )

    @Parameter(title: LocalizedStringResource("목표", comment: "Siri: goal parameter"),
               requestValueDialog: IntentDialog(LocalizedStringResource("어떤 목표인가요?", comment: "Siri: ask which goal")))
    var goal: StepGoalEntity

    @Parameter(title: LocalizedStringResource("했어요", comment: "Siri: whether the goal was done today"), default: true)
    var reached: Bool

    @Dependency private var container: ModelContainer

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(container)
        context.insert(JournalData(
            id: UUID().uuidString,
            date: Date(),
            hasDeleted: false,
            isGoalIn: reached,
            emotionValue: nil,
            emotionText: nil,
            review: nil,
            nextPlan: nil,
            isRebounded: false,
            purpose: nil,
            mainGoal: nil,
            subGoal: goal.text,
            linkedReboundId: nil,
            // 미해결 상태는 실패 기록에만 둔다(기존 스키마 규약).
            isResolved: reached ? nil : false,
            retryCount: nil
        ))
        try context.save()
        UsageReporting.logShot(isGoalIn: reached, resolvedRebound: false)
        return .result(dialog: reached
            ? IntentDialog(LocalizedStringResource("‘\(goal.text)’ 한 걸음 디뎠어요.", comment: "Siri: step done. Argument is the goal"))
            : IntentDialog(LocalizedStringResource("남겼어요. 헛디딘 날도 길의 일부예요. 앱에서 무엇이 막았는지 천천히 돌아봐요.", comment: "Siri: step missed, gentle")))
    }
}

struct ZinggumDolShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogStepIntent(),
            phrases: ["Log \(\.$goal) in \(.applicationName)", "Log today’s step in \(.applicationName)"],
            shortTitle: "Log Today’s Step",
            systemImageName: "figure.walk"
        )
    }
}
