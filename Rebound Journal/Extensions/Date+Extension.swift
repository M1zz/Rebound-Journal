//
//  Date+Extension.swift
//  Rebound Journal
//
//  Created by hyunho lee on 4/18/24.
//

import Foundation

// MARK: - Useful extensions
extension Date {
    var longFormat: String {
        string(format: "MM/dd/yyyy")
    }
    
    var headerTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "MMMM d E"
        return formatter.string(from: self)
    }
    
    var year: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "y"
        return formatter.string(from: self)
    }
    
    var month: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: self)
    }
    
    var dayLabel: String {
        return Date.dayLabelFormatter.string(from: self)
    }

    private static let dayLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M.d"
        return formatter
    }()

    /// yyyy mm dd 형식 (예: "2025 04 21")
    var yyyyMMdd: String {
        return Date.yyyyMMddFormatter.string(from: self)
    }

    private static let yyyyMMddFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy MM dd"
        return formatter
    }()

    func string(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}

extension DateFormatter {
    // 한국어 로케일 및 "E" 형식(요일)으로 설정된 DateFormatter를 반환하는 static 메소드
    static func koreanWeekdayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR") // 한국어 로케일 설정
        formatter.dateFormat = "E" // 요일만 표시
        return formatter
    }
}
