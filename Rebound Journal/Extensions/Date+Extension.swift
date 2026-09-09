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
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMMdEEE")
        return formatter.string(from: self)
    }
    
    var year: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("y")
        return formatter.string(from: self)
    }
    
    var month: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: self)
    }
    
    var dayLabel: String {
        return Date.dayLabelFormatter.string(from: self)
    }

    private static let dayLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("Md")
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
    /// 사용자 로캘의 요일(E) 표기를 쓰는 DateFormatter
    static func weekdayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }
}
