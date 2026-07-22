//
//  MilestoneSystem.swift
//  Rebound Journal
//
//  Created by Claude on 11/17/25.
//

import Foundation

/// 마일스톤 타입
enum MilestoneType: String, CaseIterable, Codable {
    // 연속 성공 관련
    case firstSuccess = "first_success"
    case threeStreak = "three_streak"
    case sevenStreak = "seven_streak"
    case thirtyStreak = "thirty_streak"

    // 총 성공 횟수 관련
    case tenSuccesses = "ten_successes"
    case fiftySuccesses = "fifty_successes"
    case hundredSuccesses = "hundred_successes"

    // 리바운드 관련
    case firstRebound = "first_rebound"
    case tenRebounds = "ten_rebounds"
    case reboundToSuccess = "rebound_to_success"

    // 특별 성취
    case weekendWarrior = "weekend_warrior"       // 주말 5회 연속 성공
    case earlyBird = "early_bird"                 // 아침 목표 7회 연속 성공
    case resilient = "resilient"                  // 5회 실패 후 성공
    case perfectWeek = "perfect_week"             // 일주일 모든 목표 성공
    case hundredPercent = "hundred_percent"       // 특정 목표 10회 연속 100% 성공

    var title: String {
        switch self {
        case .firstSuccess: return "첫 성공"
        case .threeStreak: return "3일 연속 성공"
        case .sevenStreak: return "일주일 연속 성공"
        case .thirtyStreak: return "한 달 연속 성공"
        case .tenSuccesses: return "10번 성공"
        case .fiftySuccesses: return "50번 성공"
        case .hundredSuccesses: return "100번 성공"
        case .firstRebound: return "첫 리바운드"
        case .tenRebounds: return "리바운드 마스터"
        case .reboundToSuccess: return "리바운드로 역전"
        case .weekendWarrior: return "주말 전사"
        case .earlyBird: return "아침형 인간"
        case .resilient: return "불굴의 의지"
        case .perfectWeek: return "완벽한 한 주"
        case .hundredPercent: return "완벽주의자"
        }
    }

    var description: String {
        switch self {
        case .firstSuccess:
            return "축하합니다! 첫 성공을 달성했어요"
        case .threeStreak:
            return "3일 연속 목표를 달성했어요!"
        case .sevenStreak:
            return "놀라워요! 일주일 내내 성공했어요"
        case .thirtyStreak:
            return "대단해요! 한 달 동안 꾸준히 해냈어요"
        case .tenSuccesses:
            return "벌써 10번이나 성공했어요!"
        case .fiftySuccesses:
            return "50번 성공! 정말 대단해요"
        case .hundredSuccesses:
            return "100번 성공! 당신은 챔피언이에요"
        case .firstRebound:
            return "첫 리바운드를 기록했어요"
        case .tenRebounds:
            return "10번의 리바운드로 다시 일어섰어요"
        case .reboundToSuccess:
            return "실패를 딛고 성공했어요!"
        case .weekendWarrior:
            return "주말 5회 연속 성공했어요"
        case .earlyBird:
            return "아침 목표를 7회 연속 달성했어요"
        case .resilient:
            return "5번의 실패 후 다시 성공했어요"
        case .perfectWeek:
            return "일주일 동안 모든 목표를 달성했어요"
        case .hundredPercent:
            return "10회 연속 100% 성공했어요"
        }
    }

    var emoji: String {
        switch self {
        case .firstSuccess: return "🎯"
        case .threeStreak: return "🔥"
        case .sevenStreak: return "⭐"
        case .thirtyStreak: return "👑"
        case .tenSuccesses: return "🏆"
        case .fiftySuccesses: return "🥇"
        case .hundredSuccesses: return "💎"
        case .firstRebound: return "🏀"
        case .tenRebounds: return "🎖️"
        case .reboundToSuccess: return "💪"
        case .weekendWarrior: return "🎪"
        case .earlyBird: return "🌅"
        case .resilient: return "🛡️"
        case .perfectWeek: return "✨"
        case .hundredPercent: return "💯"
        }
    }

    var rarity: MilestoneRarity {
        switch self {
        case .firstSuccess, .firstRebound:
            return .common
        case .threeStreak, .tenSuccesses, .reboundToSuccess:
            return .uncommon
        case .sevenStreak, .tenRebounds, .fiftySuccesses, .weekendWarrior:
            return .rare
        case .thirtyStreak, .earlyBird, .resilient, .perfectWeek:
            return .epic
        case .hundredSuccesses, .hundredPercent:
            return .legendary
        }
    }
}

/// 마일스톤 희귀도
enum MilestoneRarity: String, Codable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"

    var title: String {
        switch self {
        case .common: return "일반"
        case .uncommon: return "특별"
        case .rare: return "희귀"
        case .epic: return "영웅"
        case .legendary: return "전설"
        }
    }

    var color: String {
        switch self {
        case .common: return "gray"
        case .uncommon: return "green"
        case .rare: return "blue"
        case .epic: return "purple"
        case .legendary: return "gold"
        }
    }
}

/// 달성한 마일스톤
struct AchievedMilestone: Identifiable, Codable {
    let id: UUID
    let type: MilestoneType
    let achievedDate: Date
    let goal: String?  // 특정 목표와 관련된 경우

    init(type: MilestoneType, achievedDate: Date = Date(), goal: String? = nil) {
        self.id = UUID()
        self.type = type
        self.achievedDate = achievedDate
        self.goal = goal
    }
}

/// 마일스톤 진행 상황
struct MilestoneProgress {
    let type: MilestoneType
    let currentProgress: Int
    let requiredProgress: Int
    let isAchieved: Bool

    var progressPercent: Double {
        guard requiredProgress > 0 else { return 0 }
        return min(Double(currentProgress) / Double(requiredProgress), 1.0)
    }

    var progressPercentInt: Int {
        Int(progressPercent * 100)
    }
}

/// 마일스톤 추적 시스템
class MilestoneTracker {

    /// 새로 달성한 마일스톤 확인
    static func checkNewMilestones(
        in journals: [JournalData],
        previouslyAchieved: [AchievedMilestone] = []
    ) -> [AchievedMilestone] {

        var newMilestones: [AchievedMilestone] = []
        let achievedTypes = Set(previouslyAchieved.map { $0.type })

        // 각 마일스톤 타입별로 체크
        for type in MilestoneType.allCases {
            // 이미 달성한 마일스톤은 스킵 (재달성 가능한 것 제외)
            if achievedTypes.contains(type) && !type.isRepeatable {
                continue
            }

            if let milestone = checkMilestone(type: type, in: journals) {
                newMilestones.append(milestone)
            }
        }

        return newMilestones
    }

    /// 특정 마일스톤 체크
    private static func checkMilestone(
        type: MilestoneType,
        in journals: [JournalData]
    ) -> AchievedMilestone? {

        let validJournals = journals.filter { !$0.hasDeletedUnwrapped }
        let successJournals = validJournals.filter { $0.isGoalInUnwrapped }

        switch type {
        // 첫 성공
        case .firstSuccess:
            if !successJournals.isEmpty {
                return AchievedMilestone(
                    type: .firstSuccess,
                    achievedDate: successJournals.first?.dateUnwrapped ?? Date()
                )
            }

        // 연속 성공 (3일)
        case .threeStreak:
            if checkStreak(count: 3, in: validJournals) {
                return AchievedMilestone(type: .threeStreak)
            }

        // 연속 성공 (7일)
        case .sevenStreak:
            if checkStreak(count: 7, in: validJournals) {
                return AchievedMilestone(type: .sevenStreak)
            }

        // 연속 성공 (30일)
        case .thirtyStreak:
            if checkStreak(count: 30, in: validJournals) {
                return AchievedMilestone(type: .thirtyStreak)
            }

        // 총 성공 10회
        case .tenSuccesses:
            if successJournals.count >= 10 {
                return AchievedMilestone(type: .tenSuccesses)
            }

        // 총 성공 50회
        case .fiftySuccesses:
            if successJournals.count >= 50 {
                return AchievedMilestone(type: .fiftySuccesses)
            }

        // 총 성공 100회
        case .hundredSuccesses:
            if successJournals.count >= 100 {
                return AchievedMilestone(type: .hundredSuccesses)
            }

        // 첫 리바운드
        case .firstRebound:
            let reboundJournals = validJournals.filter { !($0.nextPlan?.isEmpty ?? true) }
            if !reboundJournals.isEmpty {
                return AchievedMilestone(
                    type: .firstRebound,
                    achievedDate: reboundJournals.first?.dateUnwrapped ?? Date()
                )
            }

        // 리바운드 10회
        case .tenRebounds:
            let reboundCount = validJournals.filter { !($0.nextPlan?.isEmpty ?? true) }.count
            if reboundCount >= 10 {
                return AchievedMilestone(type: .tenRebounds)
            }

        // 리바운드 후 성공
        case .reboundToSuccess:
            if checkReboundToSuccess(in: validJournals) {
                return AchievedMilestone(type: .reboundToSuccess)
            }

        // 특별 성취들
        case .weekendWarrior:
            if checkWeekendWarrior(in: validJournals) {
                return AchievedMilestone(type: .weekendWarrior)
            }

        case .earlyBird:
            if checkEarlyBird(in: validJournals) {
                return AchievedMilestone(type: .earlyBird)
            }

        case .resilient:
            if checkResilient(in: validJournals) {
                return AchievedMilestone(type: .resilient)
            }

        case .perfectWeek:
            if checkPerfectWeek(in: validJournals) {
                return AchievedMilestone(type: .perfectWeek)
            }

        case .hundredPercent:
            if let goal = checkHundredPercent(in: validJournals) {
                return AchievedMilestone(type: .hundredPercent, goal: goal)
            }
        }

        return nil
    }

    /// 연속 성공 체크
    private static func checkStreak(count: Int, in journals: [JournalData]) -> Bool {
        let sorted = journals.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }

        var streak = 0
        for journal in sorted {
            if journal.isGoalInUnwrapped {
                streak += 1
                if streak >= count {
                    return true
                }
            } else {
                break
            }
        }

        return false
    }

    /// 리바운드 후 성공 체크
    private static func checkReboundToSuccess(in journals: [JournalData]) -> Bool {
        let sorted = journals.sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }

        for i in 0..<sorted.count - 1 {
            let current = sorted[i]
            let next = sorted[i + 1]

            // 실패 기록이고 리바운드 계획이 있으며, 다음이 성공인 경우
            if !current.isGoalInUnwrapped &&
               !(current.nextPlan?.isEmpty ?? true) &&
               next.isGoalInUnwrapped {
                return true
            }
        }

        return false
    }

    /// 주말 전사 체크 (주말 5회 연속 성공)
    private static func checkWeekendWarrior(in journals: [JournalData]) -> Bool {
        let weekendJournals = journals.filter { journal in
            let weekday = Calendar.current.component(.weekday, from: journal.dateUnwrapped)
            return weekday == 1 || weekday == 7 // 일요일(1) 또는 토요일(7)
        }
        .sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }

        return checkStreak(count: 5, in: weekendJournals)
    }

    /// 아침형 인간 체크 (아침 목표 7회 연속 성공)
    private static func checkEarlyBird(in journals: [JournalData]) -> Bool {
        // 아침(6-12시) 목표만 필터링
        let morningJournals = journals.filter { journal in
            let hour = Calendar.current.component(.hour, from: journal.dateUnwrapped)
            return hour >= 6 && hour < 12
        }

        return checkStreak(count: 7, in: morningJournals)
    }

    /// 불굴의 의지 체크 (5회 실패 후 성공)
    private static func checkResilient(in journals: [JournalData]) -> Bool {
        let sorted = journals.sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }

        var consecutiveFailures = 0
        for journal in sorted {
            if !journal.isGoalInUnwrapped {
                consecutiveFailures += 1
            } else {
                if consecutiveFailures >= 5 {
                    return true
                }
                consecutiveFailures = 0
            }
        }

        return false
    }

    /// 완벽한 한 주 체크
    private static func checkPerfectWeek(in journals: [JournalData]) -> Bool {
        let calendar = Calendar.current
        let now = Date()

        // 최근 7일 확인
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return false
        }

        let recentJournals = journals.filter {
            ($0.date ?? Date()) >= weekAgo
        }

        // 7일 동안 매일 기록이 있고 모두 성공인지 확인
        let uniqueDays = Set(recentJournals.map {
            calendar.startOfDay(for: $0.dateUnwrapped)
        })

        return uniqueDays.count >= 7 && recentJournals.allSatisfy { $0.isGoalInUnwrapped }
    }

    /// 100% 완벽주의자 체크 (특정 목표 10회 연속 성공)
    private static func checkHundredPercent(in journals: [JournalData]) -> String? {
        let goalGroups = Dictionary(grouping: journals) { $0.subGoalUnwrapped }

        for (goal, goalJournals) in goalGroups {
            let sorted = goalJournals.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
            if checkStreak(count: 10, in: sorted) {
                return goal
            }
        }

        return nil
    }

    /// 모든 마일스톤 진행 상황
    static func getAllProgress(in journals: [JournalData]) -> [MilestoneProgress] {
        return MilestoneType.allCases.compactMap { type in
            getProgress(for: type, in: journals)
        }
    }

    /// 특정 마일스톤 진행 상황
    static func getProgress(
        for type: MilestoneType,
        in journals: [JournalData]
    ) -> MilestoneProgress? {

        let validJournals = journals.filter { !$0.hasDeletedUnwrapped }
        let successJournals = validJournals.filter { $0.isGoalInUnwrapped }

        var current = 0
        var required = 0

        switch type {
        case .firstSuccess:
            current = successJournals.isEmpty ? 0 : 1
            required = 1

        case .threeStreak:
            current = getCurrentStreak(in: validJournals)
            required = 3

        case .sevenStreak:
            current = getCurrentStreak(in: validJournals)
            required = 7

        case .thirtyStreak:
            current = getCurrentStreak(in: validJournals)
            required = 30

        case .tenSuccesses:
            current = successJournals.count
            required = 10

        case .fiftySuccesses:
            current = successJournals.count
            required = 50

        case .hundredSuccesses:
            current = successJournals.count
            required = 100

        case .firstRebound:
            current = validJournals.filter { !($0.nextPlan?.isEmpty ?? true) }.isEmpty ? 0 : 1
            required = 1

        case .tenRebounds:
            current = validJournals.filter { !($0.nextPlan?.isEmpty ?? true) }.count
            required = 10

        default:
            return nil  // 특별 성취는 진행률 표시 안 함
        }

        return MilestoneProgress(
            type: type,
            currentProgress: current,
            requiredProgress: required,
            isAchieved: current >= required
        )
    }

    /// 현재 연속 성공 횟수
    private static func getCurrentStreak(in journals: [JournalData]) -> Int {
        let sorted = journals.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }

        var streak = 0
        for journal in sorted {
            if journal.isGoalInUnwrapped {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }
}

// MARK: - Extensions

extension MilestoneType {
    /// 재달성 가능 여부
    var isRepeatable: Bool {
        switch self {
        case .perfectWeek, .weekendWarrior:
            return true
        default:
            return false
        }
    }
}
