//
//  viewModel.swift
//  Rebound Journal
//
//  Created by 황석현 on 4/16/25.
//

import Foundation
import SwiftUI

final class ChartViewModel: ObservableObject {
    
    var journals: [JournalData] = []
    @Published var selectedDate = Date()
    @Published var selectedDetailType: Bool = false
    @Published var isDatePickerShown: Bool = false
    
    @Published var journalSummaries: JournalSummary = .init(entries: [])
    @Published var journalDetails: [JournalMetaData] = []
    @Published var groupedJournals: GroupedJournal = []
    @Published var journalCharts: [JournalChart] = []
    
    /// 뷰모델 내의 데이터를 초기화하는 함수
    func fetch(from journals: [JournalData]) {
        // 저널 데이터 저장 (필터링에 사용)
        if self.journals.isEmpty {
            self.journals = journals
        }
        generateJournalSummaries(from: journals)
        generateJournalCharts(from: journals)
        generateJournalDetails(from: journals)
        makeGroupedJournalDetailsByDate()
    }
    
    /// 기록 요약 초기화(연속일수, 전체/타입별 갯수)
    private func generateJournalSummaries(from journals: [JournalData]) {
        self.journalSummaries = JournalSummary(entries: journals)
    }
    /// 차트 데이터 초기화 (선택된 월의 모든 날짜)
    private func generateJournalCharts(from journals: [JournalData]) {
        let calendar = Calendar.current

        // 선택된 날짜의 연도와 월 추출
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)

        // 해당 월의 일수 계산
        guard let range = calendar.range(of: .day, in: .month, for: selectedDate) else { return }

        var charts: [JournalChart] = []

        // 해당 월의 모든 날짜에 대해 차트 생성
        for day in range {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { continue }

            // 일별 데이터 추출
            let dayJournals = journals.filter {
                !$0.hasDeletedUnwrapped && calendar.isDate($0.dateUnwrapped, inSameDayAs: date)
            }

            let goalInCount = dayJournals.filter { $0.isGoalInUnwrapped }.count
            let reboundCount = dayJournals.filter { !$0.isGoalInUnwrapped }.count

            if goalInCount > 0 {
                charts.append(JournalChart(date: date, isGoalIn: true, count: goalInCount))
            } else {
                charts.append(JournalChart(date: date, isGoalIn: true, count: 0))
            }

            if reboundCount > 0 {
                charts.append(JournalChart(date: date, isGoalIn: false, count: reboundCount))
            } else {
                charts.append(JournalChart(date: date, isGoalIn: false, count: 0))
            }
        }
        self.journalCharts = charts
    }
    /// 기록 상세정보 초기화
    private func generateJournalDetails(from journals: [JournalData]) {
        self.journalDetails = journals.map { JournalMetaData(entry: $0)}
    }
    
    /// 슛 기록을 날짜별로 그룹화하는 함수
    func makeGroupedJournalDetailsByDate() {
        let grouped = Dictionary(grouping: journalDetails) { $0.date.yyyyMMdd }
        groupedJournals = grouped.sorted { $0.key < $1.key }
    }
    
    /// 슛 타입별 데이터를 반환하는 함수
    func filteredGroupedJournalDetailsBy(isGoalIn: Bool) -> GroupedJournal {
        if isGoalIn {
            return self.groupedJournals
                .map { (key, values) in (key: key, value: values.filter { $0.isGoalIn }) }
                .filter { !$0.value.isEmpty }
        } else {
            return self.groupedJournals
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
            !$0.hasDeletedUnwrapped &&
            calendar.component(.year, from: $0.dateUnwrapped) == year &&
            calendar.component(.month, from: $0.dateUnwrapped) == month
        }

        fetch(from: filtered)
        self.makeGroupedJournalDetailsByDate()
    }
}

typealias GroupedJournal = [(key: String, value: [JournalMetaData])]
