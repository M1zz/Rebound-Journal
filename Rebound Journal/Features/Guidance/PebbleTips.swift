//
//  PebbleTips.swift
//  Rebound Journal
//
//  기능을 알려주는 자리. TipKit을 쓴다.
//
//  이 앱에는 첫 실행 안내(온보딩)가 없다. 열자마자 조약돌이 말을 거는 게
//  전부여야 하고(§5-A), 그 앞에 설명 화면을 세우면 대화가 시작되기도 전에
//  읽을 거리부터 주는 셈이 된다. 그래서 안내는 **필요해진 순간에 그 자리에서**
//  뜨게 한다. TipKit이 하는 일이 정확히 그거다.
//
//  띄우는 조건이 곧 설계다.
//
//  말투 안내는 **대화를 한 번 끝낸 뒤에야** 뜬다. 조약돌이 어떻게 말하는지
//  겪어보지 않은 사람에게 "말투를 바꿀 수 있어요"는 아무 의미가 없다. 한 번
//  들어봐야 "좀 딱딱한데" 또는 "이대로가 좋은데"라는 판단이 서고, 그때가
//  이 안내가 쓸모 있는 유일한 시점이다.
//

import SwiftUI
import TipKit

/// 말투를 바꿀 수 있다는 안내.
///
/// 첫 화면의 `...` 단추에 붙는다. 설정이 어디 있는지까지 같이 알려줘야
/// 안내를 읽고 나서 헤매지 않는다.
struct SpeechStyleTip: Tip {

    /// 대화를 한 번 끝냈다는 신호.
    static let conversationFinished = Tips.Event(id: "conversationFinished")

    var title: Text {
        Text(Phrasing.say("말투를 고를 수 있어요", "말투를 고를 수 있어"))
    }

    var message: Text? {
        Text(Phrasing.say(
            "조약돌이 존댓말을 쓸지 반말을 쓸지 설정에서 정할 수 있어요.",
            "조약돌이 존댓말을 쓸지 반말을 쓸지 설정에서 정할 수 있어."
        ))
    }

    var image: Image? {
        Image(systemName: "quote.bubble")
    }

    var rules: [Rule] {
        // 한 번은 겪어보고 나서 판단할 수 있게 한다.
        #Rule(Self.conversationFinished) { $0.donations.count >= 1 }
    }
}

/// 설정 화면에서 말투 항목 위에 놓이는 설명.
///
/// 여기서는 "무엇을 고르는 것인지"가 아니라 **"골라도 괜찮다"**를 말한다.
/// 반말을 고르는 걸 망설이는 쪽이 실제로 많고, 망설임의 이유는 대개
/// "나중에 못 바꾸면 어쩌지"다. 되돌릴 수 있다고 먼저 말해 둔다.
struct SpeechStyleSettingTip: Tip {

    var title: Text {
        Text(Phrasing.say("편한 쪽으로 두세요", "편한 쪽으로 둬"))
    }

    var message: Text? {
        Text(Phrasing.say(
            "언제든 다시 바꿀 수 있어요. 바꾸면 조약돌이 그 말투로 다시 인사해요.",
            "언제든 다시 바꿀 수 있어. 바꾸면 조약돌이 그 말투로 다시 인사할게."
        ))
    }

    var options: [Option] {
        // 설정에 들어온 사람은 이미 찾아온 것이라 한 번만 보여주면 된다.
        [MaxDisplayCount(1)]
    }
}
