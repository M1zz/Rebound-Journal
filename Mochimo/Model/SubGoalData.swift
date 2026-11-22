//
//  SubGoalData.swift
//  Mochimo
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
    /// 이 목표가 향하는 삶의 목표(`LifeGoalData.id`). 삶의 목표에서 놓은 돌이면 있다.
    var lifeGoalID: String?
    /// 이 돌로 줄여 보려는 장애물(`ObstacleData.id`).
    var obstacleID: String?

    init(id: String? = nil, date: Date? = nil, goalText: String? = nil,
         lifeGoalID: String? = nil, obstacleID: String? = nil) {
        self.id = id
        self.date = date
        self.goalText = goalText
        self.lifeGoalID = lifeGoalID
        self.obstacleID = obstacleID
    }
}
