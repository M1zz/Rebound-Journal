//
//  Phrasing.swift
//  Rebound Journal
//
//  같은 뜻을 여러 말로 한다.
//
//  매일 여는 앱이 늘 같은 문장을 내놓으면 사람이 아니라 안내판처럼 읽힌다.
//  조약돌이 곁에 있는 존재로 느껴지려면 말이 조금씩 달라야 한다 (§10).
//
//  다만 **무작위로 고르면 안 된다.** 화면을 다시 그릴 때마다 문장이 바뀌어
//  깜빡이고, 관찰 문장은 뷰를 구분하는 식별자로도 쓰이고 있어서 매번 달라지면
//  전환 애니메이션이 엉킨다.
//
//  그래서 흔들되 정해진 대로 흔든다. 같은 날 같은 목표면 언제나 같은 말이 나오고,
//  날이 바뀌면 다른 말이 나온다.
//

import Foundation

enum Phrasing {

    /// 여러 표현 중 하나를 고른다. 같은 씨앗이면 언제나 같은 것이 나온다.
    static func pick(_ options: [String], seed: String) -> String {
        guard let first = options.first else { return "" }
        guard options.count > 1 else { return first }
        let index = Int(stableHash(seed) % UInt64(options.count))
        return options[index]
    }

    /// 오늘을 가리키는 씨앗. 날이 바뀌면 말도 바뀐다.
    static func today(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    /// 오늘 + 무언가. 같은 날에도 목표가 다르면 다른 말이 나오게 한다.
    static func today(with extra: String, date: Date = Date()) -> String {
        "\(today(date))|\(extra)"
    }

    /// 실행할 때마다 달라지지 않는 해시.
    ///
    /// Swift의 `hashValue`는 프로세스마다 씨앗이 달라 앱을 껐다 켜면 다른 값이
    /// 나온다. 그러면 같은 날인데 앱을 다시 열 때마다 말이 바뀐다. FNV-1a로
    /// 직접 계산해 그 흔들림을 없앤다.
    private static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        return hash
    }
}
