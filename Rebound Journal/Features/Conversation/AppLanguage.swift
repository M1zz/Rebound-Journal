//
//  AppLanguage.swift
//  Rebound Journal
//
//  지금 앱이 어떤 언어로 말하고 있는지.
//
//  조약돌의 문구는 한국어 문법에 맞춰 조립된다 — 조사를 붙이고(§`String.particle`),
//  존댓말·반말 두 벌을 손으로 적어 둔다(§`SpeechStyle`). 둘 다 한국어에만 있는
//  장치라, 다른 언어에서는 그 조립을 멈추고 번역문을 그대로 써야 한다.
//
//  판단 기준은 번들이 실제로 고른 현지화다. 기기 언어가 아니라 **앱이 지금
//  어느 lproj 를 읽고 있는지**를 봐야 한다. 기기가 프랑스어여도 앱에 프랑스어가
//  없으면 개발 언어(한국어)로 뜨는데, 그때 조사를 빼면 한국어 문장이 깨진다.
//

import Foundation

enum AppLanguage {

    /// 지금 화면에 나가는 말이 한국어인가.
    static var isKorean: Bool {
        guard let code = Bundle.main.preferredLocalizations.first else { return true }
        return code.hasPrefix("ko")
    }

    /// 한국어 원문을 키로 삼아 현재 언어의 문장을 찾는다.
    ///
    /// 조약돌의 문구는 대부분 `Phrasing.say` / `pick` 안에 있는 평범한 문자열이라
    /// 컴파일러가 문자열 카탈로그로 뽑아 가지 못한다. 그래서 실행 중에 직접 찾는다.
    /// 카탈로그에 키가 없으면 원문(한국어)이 그대로 돌아온다.
    static func localized(_ korean: String) -> String {
        guard !isKorean else { return korean }
        return String(localized: String.LocalizationValue(korean))
    }
}
