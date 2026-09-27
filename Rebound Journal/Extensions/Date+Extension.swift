//
//  Date+Extension.swift
//  Rebound Journal
//
//  Created by hyunho lee on 4/18/24.
//

import Foundation

extension Date {
    func string(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}
