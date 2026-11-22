//
//  LifeGoalData.swift
//  Mochimo
//
//  내 삶의 목표 — 언젠가 꼭 건너가고 싶은 개울 건너편.
//
//  `SubGoalData`(지금 해보는 목표)는 매일 조약돌이 묻는 돌 하나다. 삶의 목표는 그보다 멀다.
//  그래서 삶의 목표 자체는 매일 묻지 않는다. 사이를 막는 장애물을 꺼내 두고, 그중 하나를 골라
//  사용자가 스스로 돌(지금 해보는 목표)을 놓는다 (§6). 돌이 쌓이면 건너간다.
//
//  CloudKit 으로 동기화되므로 모든 속성은 선택값이다. 이름을 바꾸지 않는다.
//

import Foundation
import SwiftData

@Model
final class LifeGoalData {
    var id: String?
    var title: String?
    var date: Date?

    // 구체화 질문의 답 (LifeGoalQuestion). 비어 있으면 아직 답하지 않은 것.
    var answerWhen: String?
    var answerWho: String?
    var answerHow: String?
    var answerWhyNot: String?
    var answerValue: String?

    /// 건너간 날. 있으면 이룬 목표다.
    var reachedDate: Date?
    /// 잠시 내려놓은 날. 지우지 않고 따로 둔다. 언제든 다시 꺼낸다.
    var restingDate: Date?
    /// 꿈을 찾아서에서 옮겨 왔으면 그 앱의 목표 id. 두 번 가져와도 겹치지 않게 한다.
    var importedFrom: String?

    init(title: String, date: Date = Date()) {
        self.id = UUID().uuidString
        self.title = title
        self.date = date
    }
}

/// 삶의 목표 앞을 막고 있는 것 하나.
///
/// 숫자로 재지 않는다. 있고, 치웠고, 어떻게 치웠는지만 남는다.
@Model
final class ObstacleData {
    var id: String?
    var lifeGoalID: String?
    var text: String?
    var date: Date?
    /// 치운 날. 있으면 넘어선 장애물이다.
    var clearedDate: Date?
    /// 어떻게 넘었는지, 사용자가 남긴 말.
    var clearedNote: String?

    init(lifeGoalID: String, text: String, date: Date = Date()) {
        self.id = UUID().uuidString
        self.lifeGoalID = lifeGoalID
        self.text = text
        self.date = date
    }
}

/// 기록에 붙인 사진 한 장. 어떤 기록(`JournalData.id`)의 사진인지 `recordID` 로 가리킨다.
///
/// 사진은 iCloud 로 같이 넘어가야 해서 파일이 아니라 모델로 둔다 (`.externalStorage` → CloudKit 자산).
@Model
final class RecordPhoto {
    var id: String?
    var recordID: String?
    var date: Date?
    @Attribute(.externalStorage) var data: Data?

    init(recordID: String, data: Data, date: Date = Date()) {
        self.id = UUID().uuidString
        self.recordID = recordID
        self.data = data
        self.date = date
    }
}

// MARK: - 구체화 질문

/// 삶의 목표를 또렷하게 만드는 물음. 한 번에 하나씩 묻는다.
///
/// "무엇이 막나" 는 여기 없다 — 그건 장애물 목록(`ObstacleData`)이 맡는다.
enum LifeGoalQuestion: String, CaseIterable, Identifiable {
    case when, who, how, whyNot, value

    var id: String { rawValue }

    var question: String {
        switch self {
        case .when: Phrasing.say("언제쯤 해보고 싶어요?", "언제쯤 해보고 싶어?")
        case .who: Phrasing.say("누구와 함께하고 싶어요?", "누구와 함께하고 싶어?")
        case .how: Phrasing.say("어떻게 하면 될 것 같아요?", "어떻게 하면 될 것 같아?")
        case .whyNot: Phrasing.say("지금 바로 못 하는 건 왜일까요?", "지금 바로 못 하는 건 왜일까?")
        case .value: Phrasing.say("이걸 이루면 나에게 뭐가 달라질까요?", "이걸 이루면 나한테 뭐가 달라질까?")
        }
    }

    var label: String {
        switch self {
        case .when: String(localized: "언제")
        case .who: String(localized: "누구와")
        case .how: String(localized: "어떻게")
        case .whyNot: String(localized: "아직 못 한 까닭")
        case .value: String(localized: "나에게 주는 의미")
        }
    }
}

extension LifeGoalData {
    var titleUnwrapped: String { title ?? "" }
    var isReached: Bool { reachedDate != nil }
    var isResting: Bool { restingDate != nil && reachedDate == nil }
    var isActive: Bool { reachedDate == nil && restingDate == nil }

    func answer(_ question: LifeGoalQuestion) -> String {
        let value: String? = switch question {
        case .when: answerWhen
        case .who: answerWho
        case .how: answerHow
        case .whyNot: answerWhyNot
        case .value: answerValue
        }
        return value ?? ""
    }

    func setAnswer(_ question: LifeGoalQuestion, _ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let value: String? = clean.isEmpty ? nil : clean
        switch question {
        case .when: answerWhen = value
        case .who: answerWho = value
        case .how: answerHow = value
        case .whyNot: answerWhyNot = value
        case .value: answerValue = value
        }
    }

    /// 아직 답하지 않은 첫 물음. 다 답했으면 nil.
    var nextQuestion: LifeGoalQuestion? {
        LifeGoalQuestion.allCases.first { answer($0).isEmpty }
    }
}

extension ObstacleData {
    var textUnwrapped: String { text ?? "" }
    var isCleared: Bool { clearedDate != nil }
}

// MARK: - 돌과 삶의 목표 잇기

enum LifeGoalLink {
    /// 이 목표(돌)가 향하는 삶의 목표의 이름. 기록의 `mainGoal` 에 적어 두면
    /// 삶의 목표 화면이 그 이름으로 지나온 기록을 모은다 (기록은 목표를 이름으로 가리키는 게 이 앱의 약속).
    static func lifeGoalTitle(forGoal goal: String, in context: ModelContext) -> String? {
        guard !goal.isEmpty,
              let stone = try? context.fetch(FetchDescriptor<SubGoalData>()).first(where: { $0.goalText == goal }),
              let lifeID = stone.lifeGoalID,
              let life = try? context.fetch(FetchDescriptor<LifeGoalData>()).first(where: { $0.id == lifeID })
        else { return nil }
        return life.title
    }

    static func lifeGoalID(forGoal goal: String, in context: ModelContext) -> String? {
        guard !goal.isEmpty else { return nil }
        return (try? context.fetch(FetchDescriptor<SubGoalData>()))?.first { $0.goalText == goal }?.lifeGoalID
    }
}
