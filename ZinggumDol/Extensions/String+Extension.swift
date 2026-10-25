//
//  String+Extension.swift
//  ZinggumDol
//
//  Created by hyunho lee on 4/18/24.
//

import Foundation

extension String {
    func date(format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.date(from: self)
    }
    
    var time: Date? {
        date(format: "h:mm a")
    }
    
    var dateComponents: DateComponents {
        guard let dateObject = time else { return DateComponents() }
        return Calendar.current.dateComponents([.hour, .minute], from: dateObject)
    }
}

// MARK: - 한국어 조사

extension String {

    /// 받침 유무에 맞는 조사를 고른다. 조사만 돌려주므로 이름을 따옴표로 감쌀 때도 쓴다.
    ///
    ///     "'\(goal)'\(goal.particle("을", "를")) 돌아본 지"
    ///     // 운동하기 → "'운동하기'를 돌아본 지"
    ///     // 독서방  → "'독서방'을 돌아본 지"
    ///
    /// 사용자가 적은 목표 이름을 문장에 끼워 넣는 자리가 많은데, 조사를 하나로
    /// 박아두면 "'운동하기'을 돌아본 지"처럼 어긋난다. 자기가 쓴 말이 이상하게
    /// 되돌아오면 앱이 내 얘기를 듣고 있다는 느낌부터 깨진다.
    ///
    /// - Parameters:
    ///   - withFinal: 받침이 있을 때 (을/은/이/과/아)
    ///   - withoutFinal: 받침이 없을 때 (를/는/가/와/야)
    func particle(_ withFinal: String, _ withoutFinal: String) -> String {
        // 조사는 한국어에만 있다. 다른 언어에서는 붙이지 않는다 —
        // 영어 문장에 "을/를"이 남으면 문장이 깨진 것으로 읽힌다.
        guard AppLanguage.isKorean else { return "" }
        return hasFinalConsonant ? withFinal : withoutFinal
    }

    /// 조사까지 붙인 문자열. 따옴표 없이 이름을 그대로 쓸 때.
    func withParticle(_ withFinal: String, _ withoutFinal: String) -> String {
        self + particle(withFinal, withoutFinal)
    }

    /// 마지막 글자에 받침이 있는지.
    ///
    /// 한글이 아닌 글자로 끝나면(영문·숫자) 판단할 수 없으므로 받침이 없는 것으로
    /// 본다. "gym를"이 "gym을"보다 덜 어색하다.
    var hasFinalConsonant: Bool {
        guard let last = unicodeScalars.last else { return false }
        guard (0xAC00...0xD7A3).contains(last.value) else { return false }
        return (last.value - 0xAC00) % 28 != 0
    }
}

// MARK: - 다른 언어의 대소문자

extension String {

    /// '어제' · '며칠 전에' 같은 때 말을 끼운 문장의 대소문자를 맞춘다. 한국어에서는 그대로.
    ///
    /// 때 말 번역은 문장 첫머리에 올 때를 기준으로 대문자로 시작한다("Gestern", "Il y a peu").
    /// 그 말이 문장 가운데 오면 첫 글자를 소문자로 낮추고, 문장 첫 글자는 대문자로 올린다.
    /// 그대로 두면 "dass du Gestern …", "Yesterday … a few days ago" 처럼 읽힌다.
    func fixingCase(around phrase: String) -> String {
        guard !AppLanguage.isKorean, !phrase.isEmpty else { return self }
        var out = self
        if let range = out.range(of: phrase), range.lowerBound != out.startIndex {
            out.replaceSubrange(range, with: phrase.prefix(1).lowercased() + phrase.dropFirst())
        }
        if let first = out.first, first.isLowercase {
            out = first.uppercased() + out.dropFirst()
        }
        return out
    }
}
