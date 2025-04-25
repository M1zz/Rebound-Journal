//
//  viewModel.swift
//  Rebound Journal
//
//  Created by 황석현 on 4/16/25.
//

import Foundation
import CoreData
import SwiftUI

final class ChartViewModel: ObservableObject {
    
    @Published var journals: [JournalModel] = []
    @Published var journalSummary: JournalSummary = .init(entries: [])
    @Published var journalData: [JournalMetaData] = []
    @Published var groupedJournalData: GroupedJournal = []
    @Published var journalChart: [JournalChart] = []
    @Published var selectedDate = Date()
    @Published var selectedDetailType: Bool = false
    @Published var isDatePickerShown: Bool = false
    
    /// 모델에서 가져온 데이터를 차트로 보여주기 위한 데이터 로직
    /// 가장 오래된 순으로 정렬하고 지웠던 이력이 있는 데이터를 제외하고
    /// 객체를 저장하는 함수
    func makeChartItems(from journals: [JournalModel]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 7일치 날짜 생성: [0~6]일 전
        let last7Days = (0...6).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }.reversed()
        
        var result: [JournalChart] = []
        
        for date in last7Days {
            let dayJournals = journals.filter {
                !$0.hasDeleted && calendar.isDate($0.date, inSameDayAs: date)
            }
            
            let goalInCount = dayJournals.filter { $0.isGoalIn }.count
            let reboundCount = dayJournals.filter { !$0.isGoalIn }.count
            
            if goalInCount > 0 {
                result.append(JournalChart(date: date, isGoalIn: true, count: goalInCount))
            } else {
                result.append(JournalChart(date: date, isGoalIn: true, count: 0))
            }
            
            if reboundCount > 0 {
                result.append(JournalChart(date: date, isGoalIn: false, count: reboundCount))
            } else {
                result.append(JournalChart(date: date, isGoalIn: false, count: 0))
            }
        }
        
        self.journalChart = result
    }
    
    /// 슛 기록을 날짜별로 그룹화하는 함수
    func makeGroupedJournalData() {
        let grouped = Dictionary(grouping: journalData) { $0.date.dayLabel }
        groupedJournalData = grouped.sorted { $0.key < $1.key }
    }
    
    /// 슛 타입별로 기록을 그룹화하여 전달하는 함수
    func filteredGroupedJournalData(isGoalIn: Bool) -> GroupedJournal {
        if isGoalIn {
            return self.groupedJournalData
                .map { (key, values) in (key: key, value: values.filter { $0.isGoalIn }) }
                .filter { !$0.value.isEmpty }
        } else {
            return self.groupedJournalData
                .map { (key, values) in (key: key, value: values.filter { !$0.isGoalIn }) }
                .filter { !$0.value.isEmpty }
        }
    }
    
    /// 날짜(월) 변경 시, 뷰모델에 설정한 날짜를 전달하는 함수
    func updateSelectedDate(year: Int, month: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)) {
            selectedDate = newDate
            applyJournalFilter(for: year, month: month)
        }
    }
    
    /// 날짜(월) 변경 시, 동작하는 함수로 날짜와 일치하는 데이터들만 추려내는 함수다.
    private func applyJournalFilter(for year: Int, month: Int) {
        let calendar = Calendar.current
        let filtered = journals.filter {
            !$0.hasDeleted &&
            calendar.component(.year, from: $0.date) == year &&
            calendar.component(.month, from: $0.date) == month
        }
        
        self.journalData = filtered.map { JournalMetaData(entry: $0) }
        self.journalSummary = JournalSummary(entries: filtered)
        self.makeChartItems(from: filtered)
        self.makeGroupedJournalData()
    }
    
    func getJournals(context: NSManagedObjectContext) {
        let entries = DataManager.loadJournalEntries(context: context)
        self.journals = JournalModel.convertToJournalModel(entries: entries)
        self.journalData = self.journals
            .filter { !$0.hasDeleted}
            .map { JournalMetaData(entry: $0) }
        self.journalSummary = JournalSummary(entries: self.journals)
        self.makeChartItems(from: self.journals)
        self.makeGroupedJournalData()
        print("Journals = \(self.journals.count)")
        print("JournalData = \(self.journalData.count)")
        print("JournalSummary = \(self.journalSummary.total)")
        print("JournalChartItems = \(self.journalChart.count)")
        print("GroupedJournalData = \(self.groupedJournalData.count)")
    }
}

/// 날짜별로 그룹화된 딕셔너리 타입
typealias GroupedJournal = [(key: String, value: [JournalMetaData])]
