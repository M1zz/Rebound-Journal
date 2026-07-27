//
//  ConversationEngine.swift
//  Rebound Journal
//
//  `ConversationScript`를 걸어가는 상태 기계.
//
//  기록은 기존 SwiftData 스키마(`JournalData` / `SubGoalData`)에 그대로 저장한다.
//  저장 계층의 이름에는 골인·리바운드가 남아 있지만 화면에는 절대 나오지 않는다.
//  스키마를 바꾸면 기존 사용자의 기록이 날아가기 때문에 일부러 건드리지 않았다.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class ConversationEngine {

    // MARK: 말풍선

    struct Utterance: Identifiable, Equatable {
        enum Speaker { case pebble, user }
        let id = UUID()
        let speaker: Speaker
        let text: String
    }

    /// 목표에 닿았는지. 사용자가 고르는 게 아니라 관찰에서 시작되고,
    /// 사용자가 "했는데 남기질 못했어요"라고 정정하면 바뀐다.
    enum Path: Equatable { case reached, notReached }

    // MARK: 공개 상태

    private(set) var transcript: [Utterance] = []
    private(set) var beat: Beat = .observation
    private(set) var response: ResponseKind = .acknowledgement("")
    private(set) var mood: PebbleMood = .resting
    private(set) var isFinished = false

    /// 조약돌이 방금 한 말. 화면 상단에 크게 놓인다(§7 텍스트 병행 표시).
    private(set) var prompt: String = ""

    let goal: String
    private(set) var path: Path

    // MARK: 모은 것

    private var facts: String = ""
    private var emotionValue: Int?
    private var emotionWord: String?
    private var smallerGoal: String = ""
    private let pastSuccess: PastSuccess?

    /// 사용자가 도중에 그만뒀는지. 그만둬도 지금까지 말한 건 저장한다.
    private(set) var didLeaveEarly = false

    // MARK: 생성

    init(observation: GoalObservation, journals: [JournalData]) {
        switch observation.kind {
        case .reached(let goal, _):
            self.goal = goal
            self.path = .reached
        case .notReached(let goal, _), .neverAttempted(let goal):
            self.goal = goal
            self.path = .notReached
        case .noGoalYet, .quiet:
            self.goal = ""
            self.path = .notReached
        }

        self.pastSuccess = ProgressObserver.recentSuccess(journals: journals, excluding: self.goal)

        say(observation.headline)
        enterConfirmOrFacts()
    }

    // MARK: - 사용자 입력

    func choose(_ choice: Choice) {
        echo(choice.label)

        switch choice.outcome {
        case .leave:
            didLeaveEarly = true
            finish(with: ConversationScript.leaveClose, mood: .resting)

        case .correctToReached:
            // 앱의 관찰이 틀렸다. 정정을 순순히 받아들이는 것이 중요하다 —
            // 앱이 자기 판단을 고집하면 사용자는 다시는 정정하지 않는다.
            path = .reached
            mood = .warm
            askWhatWorked()

        case .confirmObservation:
            askFacts()

        case .advance:
            advance()
        }
    }

    func submitFreeform(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        echo(trimmed)

        switch beat {
        case .facts:
            facts = trimmed
            askEmotion()
        case .smaller:
            smallerGoal = trimmed
            finish(with: ConversationScript.analyticClose, mood: .warm)
        default:
            advance()
        }
    }

    func submitEmotion(value: Int, word: String?) {
        emotionValue = value
        emotionWord = word
        echo(word ?? ConversationScript.emotionSteps.first { $0.value == value }?.label ?? "")

        if path == .reached {
            finish(with: ConversationScript.reachedClose, mood: .warm)
        } else {
            showSeparation()
        }
    }

    /// 조약돌이 혼자 말하는 마디에서 다음으로 넘긴다.
    func advance() {
        switch beat {
        case .separation:
            if let pastSuccess {
                showRecall(pastSuccess)
            } else {
                askSmallerOrClose()
            }
        case .recall:
            askSmallerOrClose()
        default:
            break
        }
    }

    // MARK: - 마디 이동

    private func enterConfirmOrFacts() {
        if path == .reached {
            askWhatWorked()
        } else {
            beat = .confirm
            mood = .resting
            response = .choices(ConversationScript.confirmChoices(goal: goal))
        }
    }

    private func askFacts() {
        beat = .facts
        mood = .listening
        say(ConversationScript.factsPrompt(goal: goal))
        response = .freeform(placeholder: ConversationScript.factsPlaceholder)
    }

    private func askWhatWorked() {
        beat = .facts
        mood = .warm
        say(ConversationScript.whatWorkedPrompt(goal: goal))
        response = .freeform(placeholder: ConversationScript.whatWorkedPlaceholder)
    }

    private func askEmotion() {
        beat = .emotion
        mood = .listening
        say(ConversationScript.emotionPrompt)
        response = .emotionScale
    }

    private func showSeparation() {
        beat = .separation
        mood = .thinking
        say(ConversationScript.separation(
            facts: facts,
            emotion: emotionWord ?? currentEmotionLabel
        ))
        response = .acknowledgement("네")
    }

    private func showRecall(_ success: PastSuccess) {
        beat = .recall
        mood = .warm
        say(success.recollection)
        response = .acknowledgement("그랬죠")
    }

    /// 여기가 §5의 "실패 직후에는 분석을 강요하지 말라"를 실행하는 지점이다.
    ///
    /// 감정이 바닥이면 쪼개기 질문(§6)을 통째로 건너뛴다. 지금 계획을 세우라고
    /// 하면 세우지 못하고, 못 세운 경험이 하나 더 쌓일 뿐이다.
    private func askSmallerOrClose() {
        let low = (emotionValue ?? 2) <= ConversationScript.tooLowToAnalyze
        guard !low else {
            finish(with: ConversationScript.gentleClose, mood: .resting)
            return
        }

        beat = .smaller
        mood = .listening
        say(ConversationScript.smallerPrompt)
        response = .freeform(placeholder: ConversationScript.smallerPlaceholder)
    }

    private func finish(with message: String, mood newMood: PebbleMood) {
        beat = .close
        mood = newMood
        say(message)
        response = .acknowledgement("닫기")
        isFinished = true
    }

    // MARK: - 말

    /// 소리는 여기서 내지 않는다. 글자가 화면에 찍히는 순간에 맞춰
    /// `TypewriterText`가 한 글자씩 낸다 — 엔진은 말이 생겼다는 것만 알린다.
    private func say(_ text: String) {
        prompt = text
        transcript.append(Utterance(speaker: .pebble, text: text))
    }

    private func echo(_ text: String) {
        transcript.append(Utterance(speaker: .user, text: text))
    }

    private var currentEmotionLabel: String {
        guard let emotionValue else { return "그저 그래요" }
        return ConversationScript.emotionSteps.first { $0.value == emotionValue }?.label ?? "그저 그래요"
    }

    // MARK: - 저장

    /// 대화에서 나온 것만 저장한다. 사용자가 말하지 않은 칸은 비워 둔다.
    ///
    /// 중간에 그만뒀어도 저장한다 — 말한 것이 사라지면 다음에 다시 말할 마음이 들지 않는다.
    func persist(in context: ModelContext) {
        guard !goal.isEmpty else { return }
        guard !facts.isEmpty || emotionValue != nil else { return }

        let journal = JournalData(
            id: UUID().uuidString,
            date: Date(),
            hasDeleted: false,
            isGoalIn: path == .reached,
            emotionValue: emotionValue,
            emotionText: emotionWord,
            review: facts.isEmpty ? nil : facts,
            nextPlan: smallerGoal.isEmpty ? nil : smallerGoal,
            isRebounded: false,
            purpose: nil,
            mainGoal: nil,
            subGoal: goal,
            linkedReboundId: nil,
            // 미해결 상태는 실패 기록에만 둔다(기존 스키마 규약).
            isResolved: path == .reached ? nil : false,
            retryCount: nil
        )
        context.insert(journal)

        // 사용자가 스스로 쪼갠 목표는 곧바로 추적 대상이 된다.
        // 앱이 만든 게 아니라 사용자가 만든 것이라는 점이 §6의 핵심이다.
        if !smallerGoal.isEmpty {
            let existing = (try? context.fetch(FetchDescriptor<SubGoalData>())) ?? []
            let alreadyThere = existing.contains { $0.goalText == smallerGoal }
            if !alreadyThere {
                context.insert(SubGoalData(
                    id: UUID().uuidString,
                    date: Date(),
                    goalText: smallerGoal
                ))
            }
        }
    }
}
