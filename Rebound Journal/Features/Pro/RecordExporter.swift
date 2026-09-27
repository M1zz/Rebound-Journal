//
//  RecordExporter.swift
//  Rebound Journal
//
//  지나온 기록을 글 파일 하나로 꺼낸다. (프로)
//
//  표나 점수로 정리하지 않는다. 화면에서처럼 **내가 쓴 이야기**로 읽혀야 한다.
//  그래서 날짜 순서로, 그날 향하던 곳과 있었던 일, 기분, 다음 걸음만 적는다.
//  횟수·달성률·연속 일수는 파일에도 두지 않는다 (§4·§6).
//
//  오래된 날부터 적는다. 화면은 최근 것을 먼저 보여 주지만, 파일은 처음부터
//  읽어 내려가는 물건이다.
//

import Foundation

enum RecordExporter {

    /// 기록 전체를 글로 만든다.
    static func text(journals: [JournalData], now: Date = Date()) -> String {
        let days = ProgressObserver.allDays(journals: journals).reversed()

        var lines: [String] = [
            String(localized: "징검돌 기록"),
            String(localized: "내보낸 날: \(dayTitle(now))"),
            ""
        ]

        if days.isEmpty {
            lines.append(String(localized: "아직 남긴 기록이 없어요."))
        }

        for day in days {
            lines.append("── \(dayTitle(day.day)) ──")
            for entry in day.entries {
                lines.append(contentsOf: block(for: entry))
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// 공유 시트에 넘길 파일. 임시 폴더에 쓰고 그 주소를 돌려준다.
    static func file(journals: [JournalData], now: Date = Date()) throws -> URL {
        let stamp = now.formatted(.iso8601.year().month().day())
        let name = String(localized: "징검돌 기록") + " \(stamp).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try text(journals: journals, now: now).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - 한 기록

    private static func block(for entry: JournalData) -> [String] {
        var lines: [String] = []
        let goal = clean(entry.subGoal) ?? clean(entry.mainGoal) ?? String(localized: "적어둔 목표 없음")
        let reached = entry.isGoalInUnwrapped ? String(localized: "닿았어요") : String(localized: "닿지 않았어요")
        lines.append("· \(goal) — \(reached)")

        if let review = clean(entry.review) {
            lines.append(String(localized: "  있었던 일: \(review)"))
        }
        if let emotion = clean(entry.emotionText) {
            lines.append(String(localized: "  기분: \(emotion)"))
        }
        if let plan = clean(entry.nextPlan) {
            lines.append(String(localized: "  다음 걸음: \(plan)"))
        }
        return lines
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func dayTitle(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("yMMMdEEEE")
        return formatter.string(from: day)
    }
}
