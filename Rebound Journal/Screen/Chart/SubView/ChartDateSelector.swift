//
//  ChartDateSelector.swift
//  Rebound Journal
//
//  Created by 황석현 on 4/21/25.
//

import SwiftUI

struct ChartDateSelector: View {

    @ObservedObject var viewModel: ChartViewModel
    @State private var selectedYear: Int
    @State private var selectedMonth: Int

    init(viewModel: ChartViewModel) {
        self.viewModel = viewModel
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: viewModel.selectedDate))
        _selectedMonth = State(initialValue: Calendar.current.component(.month, from: viewModel.selectedDate))
    }
    
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var years: [Int] {
        let start = currentYear - 5
        let end = currentYear
        return Array(start...end)
    }

    private let months = Array(1...12)
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    viewModel.isDatePickerShown = false
                } label: {
                    Text("취소")
                }
                Spacer()
                Button {
                    viewModel.isDatePickerShown = false
                    viewModel.updateSelectedDate(year: selectedYear, month: selectedMonth)
                } label: {
                    Text("확인")
                }
            }
            HStack {
                Picker("년도", selection: $selectedYear) {
                    ForEach(years, id: \.self) { year in
                        Text("\(String(year))년").tag(year)
                    }
                }
                .pickerStyle(.wheel)
                
                Picker("월", selection: $selectedMonth) {
                    ForEach(months, id: \.self) { month in
                        Text(Self.monthName(month)).tag(month)
                    }
                }
                .pickerStyle(.wheel)
            }
            .padding(.vertical, 10)
            .presentationDetents([.fraction(0.4)])
            
        }
        .padding()
    }
}

extension ChartDateSelector {
    /// 사용자 로캘의 월 이름 (한국어 "3월", 영어 "Mar")
    static func monthName(_ month: Int) -> String {
        let symbols = Calendar.current.shortMonthSymbols
        guard (1...symbols.count).contains(month) else { return String(month) }
        return symbols[month - 1]
    }
}

#Preview {
    ChartDateSelector(viewModel: ChartViewModel())
}
