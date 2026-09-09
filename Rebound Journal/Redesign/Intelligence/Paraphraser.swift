//
//  Paraphraser.swift
//  Rebound Journal
//
//  설계 고찰 §7의 가장 중요한 UX 원칙을 지키기 위한 장치.
//
//      "다시 말씀해 주세요"를 절대 띄우지 않는다.
//
//  사용자가 막힌 일을 털어놓는 순간에 재요청은 상처가 된다. 그래서 인식이 흐릿하면
//  다시 말해달라고 하는 대신, 온디바이스 모델이 들린 대로 정리해서 되묻는다.
//
//      "혹시 이런 뜻인가요?" → 사용자는 "맞아요" 또는 부분 수정만 하면 된다.
//
//  모델을 쓸 수 없는 기기에서도 재요청은 없다. 들린 원문을 그대로 편집 가능한
//  텍스트로 띄우는 것이 폴백이다.
//

import FoundationModels
import Foundation

@Generable
struct TidiedUtterance {
    @Guide(description: "사용자가 말한 내용을 자연스러운 한국어 한두 문장으로 정리한 것. 없는 내용을 지어내지 말 것.")
    var text: String

    @Guide(description: "정리에 확신이 있으면 true. 원문이 너무 짧거나 뜻을 알 수 없으면 false.")
    var isConfident: Bool
}

@MainActor
final class Paraphraser {

    static let shared = Paraphraser()

    private init() {}

    /// 이 기기에서 온디바이스 모델을 쓸 수 있는지.
    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    var unavailabilityReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            nil
        case .unavailable(.deviceNotEligible):
            "이 기기에서는 정리 기능을 쓸 수 없어요. 들린 대로 적어둘게요."
        case .unavailable(.appleIntelligenceNotEnabled):
            "설정에서 Apple Intelligence를 켜면 말한 내용을 더 잘 정리해 드려요."
        case .unavailable(.modelNotReady):
            "정리 기능을 준비하고 있어요. 지금은 들린 대로 적어둘게요."
        case .unavailable:
            "지금은 정리 기능을 쓸 수 없어요. 들린 대로 적어둘게요."
        }
    }

    /// 전사 결과를 읽을 수 있는 문장으로 정리한다.
    ///
    /// - Returns: 정리된 문장. 모델을 못 쓰거나 확신이 없으면 `nil`.
    ///            `nil`이어도 **다시 말해달라고 하지 않는다.** 호출부는 원문을
    ///            편집 가능한 상태로 보여주기만 한다.
    func tidy(_ raw: String, answering question: String) async -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isAvailable else { return nil }

        let session = LanguageModelSession {
            """
            당신은 사용자가 음성으로 말한 내용을 글로 다듬는 역할만 맡습니다.

            규칙:
            - 사용자가 말하지 않은 내용을 절대 추가하지 마세요.
            - 조언하거나 위로하거나 평가하지 마세요. 정리만 하세요.
            - 사용자의 1인칭 시점과 말투를 유지하세요.
            - 군더더기(음, 어, 반복)를 덜어내고 문장을 완성하세요.
            - 한두 문장으로 짧게 유지하세요.
            - 뜻을 알 수 없으면 isConfident를 false로 두세요.
            """
        }

        do {
            let response = try await session.respond(
                to: """
                질문: \(question)
                들린 말: \(trimmed)

                들린 말을 정리해 주세요.
                """,
                generating: TidiedUtterance.self,
                options: GenerationOptions(temperature: 0.2)
            )
            let result = response.content
            guard result.isConfident else { return nil }

            let tidied = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            // 원문과 사실상 같으면 재확인을 띄울 이유가 없다.
            guard !tidied.isEmpty, tidied != trimmed else { return nil }
            return tidied
        } catch {
            return nil
        }
    }

    /// 되짚어 주는 문장(§5-B)은 일부러 모델에 맡기지 않는다.
    ///
    /// 사실과 감정을 갈라 주는 그 한 문장은 사용자가 가장 약해져 있는 순간에 나온다.
    /// 생성 모델이 여기서 어긋난 말을 하면 회복이 어렵기 때문에, 문구는
    /// `ConversationScript.separation(facts:emotion:)`의 고정 템플릿으로만 만든다.
    /// 이 주석은 그 결정을 나중에 되돌리지 않기 위해 남겨둔다.
    static let separationIsIntentionallyDeterministic = true
}
