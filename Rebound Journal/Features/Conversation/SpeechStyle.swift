//
//  SpeechStyle.swift
//  Rebound Journal
//
//  조약돌이 존댓말을 쓸지 반말을 쓸지.
//
//  이 앱은 사람에게 막힌 얘기를 시키는 앱이다. 그런 말은 상대와의 거리가
//  맞아야 나온다. 누군가에게는 존댓말이 지켜주는 예의고, 누군가에게는
//  그 거리 자체가 벽이라 속을 못 꺼낸다. 어느 쪽이 맞는지는 사용자만 안다.
//
//  기본값은 존댓말이다. 처음 만나는 사이라서 그렇다. 초면에 반말을 쓰는
//  캐릭터는 친근한 게 아니라 무례한 쪽으로 읽힐 위험이 크고, 조약돌은
//  "무해한 존재"여야 한다 (§10). 가까워지는 쪽으로 옮기는 건 사용자가
//  고르게 두고, 앱이 먼저 반말을 걸지는 않는다.
//
//  ---
//
//  **문장을 기계로 바꾸지 않는다.**
//
//  해요체에서 요만 떼면 반말이 되는 것처럼 보이지만 실제로는 아니다.
//  "괜찮아요"는 "괜찮아"가 되어도 "해요"는 "해"가 아니라 "하자"가 자연스럽고,
//  "하셨어요"는 높임 선어말어미까지 걷어내야 "했잖아"가 된다. 규칙으로 짜면
//  대부분 맞고 몇 개가 틀리는데, **이 앱에서 어색한 한 문장은 다른 앱보다
//  비싸다.** 마음이 바닥일 때 읽는 말이라 어색하면 바로 거리감이 된다.
//
//  그래서 두 말투를 각각 손으로 적어 둔다. 문구를 고칠 때 한쪽만 고치면
//  말투에 따라 다른 말을 하게 되므로, 반드시 짝으로 본다.
//

import Foundation

enum SpeechStyle: String, CaseIterable, Identifiable {
    /// 존댓말. 해요체.
    case formal
    /// 반말. 해체.
    case casual

    var id: String { rawValue }

    var name: String {
        switch self {
        case .formal: "존댓말"
        case .casual: "반말"
        }
    }

    /// 고르기 전에 어떤 말투인지 들려주는 한 마디.
    ///
    /// 이름표만으로는 감이 오지 않는다. "반말"이라는 낱말이 무례하게 들릴까
    /// 걱정하는 사람에게는, 조약돌이 실제로 어떻게 말하는지를 보여주는 게
    /// 설명보다 빠르다.
    var sample: String {
        switch self {
        case .formal: "오늘은 어땠어요?"
        case .casual: "오늘은 어땠어?"
        }
    }

    static let storageKey = "pebble.speechStyle"

    /// 지금 말투.
    ///
    /// 문구를 만드는 곳이 전부 뷰 바깥의 순수 함수라 환경값으로 내려보낼 수가
    /// 없다. 저장소에서 바로 읽는다. 화면에서 이 값이 바뀌는 걸 따라가야 하는
    /// 쪽은 같은 열쇠로 `@AppStorage`를 걸어 두면 된다.
    static var current: SpeechStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: storageKey),
                  let style = SpeechStyle(rawValue: raw) else { return .formal }
            return style
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: storageKey) }
    }
}

// MARK: - 말투에 맞춰 고르기

extension Phrasing {

    /// 말투에 맞는 한 문장.
    ///
    /// 한국어가 아니면 말투를 고르지 않는다. 존댓말·반말은 한국어에만 있는
    /// 구분이라 다른 언어에는 옮길 자리가 없다. 존댓말 원문을 키로 삼아
    /// 번역문을 찾아 쓴다.
    static func say(_ formal: String, _ casual: String) -> String {
        guard AppLanguage.isKorean else { return AppLanguage.localized(formal) }
        return SpeechStyle.current == .casual ? casual : formal
    }

    /// 말투를 고르고, 그 안에서 다시 표현 하나를 고른다.
    ///
    /// 두 배열은 **같은 순서로 같은 뜻**을 담는다. 길이가 같으면 씨앗이 뽑는
    /// 자리도 같아서, 말투를 바꿔도 "몇 번째 표현"이 그대로 유지된다. 사용자
    /// 입장에서는 하던 말이 말투만 바뀐 것으로 읽히고, 내용까지 통째로
    /// 갈아치운 것처럼 보이지 않는다.
    static func pick(formal: [String], casual: [String], seed: String) -> String {
        assert(
            formal.count == casual.count,
            "말투별 표현 수가 다르면 말투를 바꿀 때 내용까지 바뀐다"
        )
        // 한국어가 아니면 말투를 고르지 않고 존댓말 쪽을 키로 쓴다.
        // 번역은 pick(_:seed:) 가 맡는다.
        guard AppLanguage.isKorean else { return pick(formal, seed: seed) }
        return pick(SpeechStyle.current == .casual ? casual : formal, seed: seed)
    }
}
