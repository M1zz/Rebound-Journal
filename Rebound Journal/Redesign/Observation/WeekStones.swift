//
//  WeekStones.swift
//  Rebound Journal
//
//  한 주를 징검다리로 본다. 요일 하나가 돌 하나다.
//
//  이 시각화가 지켜야 할 것은 "밟지 않은 돌을 실패로 보이지 않게" 하는 것이다.
//  달력에 빈칸이 생기면 사람은 그걸 못 지킨 날로 읽는다. 하지만 징검다리에서
//  밟지 않은 돌은 없어진 게 아니라 그냥 거기 있는 돌이다. 헛디뎠어도 개울에
//  빠진 게 아니라는 것 — 그게 이 앱 이름이 담고 있는 말이고, 여기서 그림으로
//  보여야 한다 (§4·§6).
//
//  그래서 어디에도 숫자를 두지 않는다. 며칠 밟았는지, 몇 퍼센트인지 세지 않는다.
//

import Foundation

struct StoneDay: Identifiable, Equatable {

    enum State: Equatable {
        /// 목표에 닿은 날. 햇빛을 받은 돌.
        case reached
        /// 남겼지만 닿지는 못한 날. 밟긴 했으나 미끄러진 돌.
        case recorded
        /// 아무것도 남기지 않은 날. 그냥 놓여 있는 돌.
        case untouched
        /// 아직 오지 않은 날.
        case ahead
    }

    let date: Date
    let state: State
    let isToday: Bool

    var id: Date { date }

    /// 요일 한 글자.
    var weekdayLabel: String {
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        let index = Calendar.current.component(.weekday, from: date) - 1
        return symbols[max(0, min(6, index))]
    }

    var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var accessibilityDescription: String {
        let day = "\(Calendar.current.component(.month, from: date))월 \(dayNumber)일"
        return switch state {
        case .reached: "\(day), 목표에 닿은 날"
        case .recorded: "\(day), 기록을 남긴 날"
        case .untouched: "\(day), 남긴 기록 없음"
        case .ahead: "\(day), 아직 오지 않은 날"
        }
    }
}

enum WeekStones {

    /// 주의 시작(일요일)을 구한다.
    static func startOfWeek(containing date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    /// 그 주의 돌 일곱 개.
    static func days(
        weekStarting start: Date,
        journals: [JournalData],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [StoneDay] {
        let today = calendar.startOfDay(for: now)
        let live = journals.filter(\.isValidForDisplay)

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let day = calendar.startOfDay(for: date)

            let onThatDay = live.filter { calendar.isDate($0.dateUnwrapped, inSameDayAs: day) }

            let state: StoneDay.State
            if day > today {
                state = .ahead
            } else if onThatDay.isEmpty {
                state = .untouched
            } else if onThatDay.contains(where: \.isGoalInUnwrapped) {
                state = .reached
            } else {
                state = .recorded
            }

            return StoneDay(date: day, state: state, isToday: day == today)
        }
    }

    /// 그 주에 남긴 기록이 하나라도 있는지. 없으면 조약돌이 굳이 말을 얹지 않는다.
    static func hasAnything(_ days: [StoneDay]) -> Bool {
        days.contains { $0.state == .reached || $0.state == .recorded }
    }

    /// 다음 주로 넘어갈 수 있는지. 오지 않은 주는 보여주지 않는다.
    static func canGoForward(from start: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        start < startOfWeek(containing: now, calendar: calendar)
    }

    /// 주를 옮긴다.
    static func week(_ start: Date, movedBy weeks: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .weekOfYear, value: weeks, to: start) ?? start
    }

    /// 화면에 적을 주 이름.
    static func title(for start: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(start, equalTo: startOfWeek(containing: now, calendar: calendar), toGranularity: .day) {
            return "이번 주"
        }
        let previous = startOfWeek(containing: calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now,
                                   calendar: calendar)
        if calendar.isDate(start, equalTo: previous, toGranularity: .day) {
            return "지난주"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: start) + " 주"
    }
}
