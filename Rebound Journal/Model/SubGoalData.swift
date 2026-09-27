//
//  SubGoalData.swift
//  Rebound Journal
//
//  Created by 황석현 on 5/18/25.
//

import Foundation
import SwiftData

@Model
final class SubGoalData {
    var id: String?
    var date: Date?
    var goalText: String?
    
    init(id: String? = nil, date: Date? = nil, goalText: String? = nil) {
        self.id = id
        self.date = date
        self.goalText = goalText
    }
}
