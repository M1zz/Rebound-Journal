//
//  ChartDetailView.swift
//  Rebound Journal
//
//  Created by 황석현 on 4/1/25.
//

import SwiftUI

struct ChartDetailView: View {
    @Binding var isPresented: Bool
    @State var viewModel: ChartViewModel
    
    var body: some View {
        ScrollView {
            ModalHeaderBar(onBack: { isPresented = false }, title: viewModel.selectedDetailType ? "전체 골인" : "전체 리바운드")
            shootLog
        }
    }
    private var shootLog: some View {
        VStack {
            HStack {
                Text("\(viewModel.selectedDate.year)년")
                    .padding(5)
                    .opacity(0.5)
                Spacer()
            }
            ForEach(viewModel.filteredGroupedJournalData(isGoalIn: viewModel.selectedDetailType), id: \.key) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.key)
                        .font(.title3.bold())
                        .opacity(0.5)
                        .padding(.leading, 5)
                    
                    ForEach(group.value) { item in
                        VStack(alignment: .leading) {
                            Text("\(item.isGoalIn ? "골인" : "리바운드") - \(item.emotionText)")
                                .bold()
                                .padding(.bottom, 10)
                            Text(item.review)
                            Divider()
                            Text(item.nextPlan)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    ChartDetailView(isPresented: .constant(true),
                    viewModel: ChartViewModel())
}
