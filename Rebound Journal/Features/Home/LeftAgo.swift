//
//  LeftAgo.swift
//  Rebound Journal
//
//  "언제 남겼는지"를 사람 말로. 지나온 길과 내 목표가 같이 쓴다.
//
//  날짜를 그대로 적으면 셈을 하게 되고, 셈은 "며칠이나 비었네"로 이어진다.
//  그래서 가까운 건 가깝게, 먼 건 "오래전"으로 뭉뚱그린다.
//

import Foundation

enum LeftAgo {
    static func label(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "오늘 남김") }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "어제 남김")
        }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        return switch days {
        case ..<0: String(localized: "오늘 남김")
        case 0..<7: String(localized: "\(days)일 전에 남김")
        case 7..<30: String(localized: "\(days / 7)주 전에 남김")
        default: String(localized: "오래전에 남김")
        }
    }
}
