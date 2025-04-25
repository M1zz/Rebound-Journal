//
//  JounrnalCreator.swift
//  Rebound Journal
//
//  Created by 황석현 on 3/21/25.
//

import SwiftUI

struct JounrnalCreator: View {
    // Shared Dependencies
    @EnvironmentObject var manager: DataManager
    @ObservedObject var viewModel: JournalCreatorViewModel
    // UI State
    @State private var showAlert: Bool = false
    
    var body: some View {
        VStack {
            ModalHeaderBar(onDismiss:  {
                manager.fullScreenMode = nil
            }, hasAlert: true)
            switch viewModel.currentStep {
            case .shoot: SelectShootTypeView(viewModel: viewModel)
            case .emotion: EmotionInputView(viewModel: viewModel)
            case .review: ReviewPlanView(viewModel: viewModel)
                    .environmentObject(manager)
            }
        }
    }
}

#Preview {
    JounrnalCreator(viewModel: JournalCreatorViewModel())
        .environmentObject(DataManager())
}
