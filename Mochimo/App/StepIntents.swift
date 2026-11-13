//
//  StepIntents.swift
//  Mochimo
//
//  "모찌모, 운동 오늘 했어" / "운동 오늘 못 했어" — 앱을 열지 않고 오늘의 한 걸음을 남긴다.
//  대화 화면이 저장하는 것과 같은 모양으로 남긴다(ConversationEngine.persist).
//
//  목표는 Spotlight 에도 싣는다. Siri 는 색인된 것만 찾는다. 누르면 그 목표 얘기로 앱이 열린다.
//  비밀번호를 걸어 둔 사람의 목표는 싣지 않는다 — 잠금을 건 이유가 남이 못 보게 하려는 것이다.
//

import AppIntents
import CoreSpotlight
import Foundation
import SwiftData

// MARK: - 앱 화면으로 넘기는 요청

@MainActor @Observable
final class StepRouter {
    static let shared = StepRouter()
    /// 열어 달라는 목표. TodayView 가 그 목표로 바꾸고 비운다.
    var goalText: String?
}

struct StepGoalEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("목표", comment: "Siri: one small goal")
    )
    static let defaultQuery = StepGoalQuery()

    let id: String
    let text: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(text)") }
}

extension StepGoalEntity: IndexedEntity {}

struct StepGoalQuery: EntityStringQuery {
    @Dependency private var container: ModelContainer

    private func goals() -> [StepGoalEntity] { Self.goals(in: container) }

    static func goals(in container: ModelContainer) -> [StepGoalEntity] {
        let all = (try? ModelContext(container).fetch(FetchDescriptor<SubGoalData>())) ?? []
        return all.compactMap { goal in
            guard let id = goal.id, let text = goal.goalText, !text.isEmpty else { return nil }
            return StepGoalEntity(id: id, text: text)
        }
    }

    /// 앱을 열 때 · 뒤로 보낼 때 Spotlight 의 목표를 새로 싣는다. 잠겨 있으면 지우기만 한다.
    static func reindex(_ container: ModelContainer, locked: Bool) async {
        let index = CSSearchableIndex.default()
        try? await index.deleteAppEntities(ofType: StepGoalEntity.self)
        guard !locked else { return }
        try? await index.indexAppEntities(goals(in: container))
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
               description: LocalizedStringResource("한 걸음을 남길 목표", comment: "Siri: goal parameter description"),
               requestValueDialog: IntentDialog(LocalizedStringResource("어떤 목표인가요?", comment: "Siri: ask which goal")))
    var goal: StepGoalEntity

    @Parameter(title: LocalizedStringResource("했어요", comment: "Siri: whether the goal was done today"),
               description: LocalizedStringResource("오늘 목표를 디뎠으면 켜고, 못 했으면 끕니다.", comment: "Siri: reached parameter description"),
               default: true)
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

/// Spotlight 에서 목표를 누르면 그 목표 얘기로 앱이 열린다.
struct OpenGoalIntent: OpenIntent {
    static let title = LocalizedStringResource("목표 열기", comment: "Siri/Spotlight: open a goal")
    static let description = IntentDescription(
        LocalizedStringResource("그 목표에 대해 모찌모와 이야기합니다.", comment: "Siri: open goal description")
    )

    @Parameter(title: LocalizedStringResource("목표", comment: "Siri: goal parameter"),
               description: LocalizedStringResource("이야기할 목표", comment: "Siri: open goal parameter description"))
    var target: StepGoalEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        StepRouter.shared.goalText = target.text
        return .result()
    }
}

struct MochimoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogStepIntent(),
            phrases: ["Log \(\.$goal) in \(.applicationName)", "Log today’s step in \(.applicationName)"],
            shortTitle: "Log Today’s Step",
            systemImageName: "figure.walk"
        )
    }
}
