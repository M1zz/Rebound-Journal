//
//  RootView.swift
//  Rebound Journal
//
//  새 진입점. 화면은 `TodayView`로 갈아끼웠지만, 기존 앱이 하던 두 가지 일은
//  그대로 남겨야 한다.
//
//   1. CoreData → SwiftData 이관. 예전 버전에서 쓴 기록이 여기서 넘어온다.
//   2. 비밀번호 잠금. 막힌 얘기를 적어두는 앱이라 이건 오히려 더 중요하다.
//

import SwiftUI
import SwiftData

struct RootView: View {

    @EnvironmentObject var manager: DataManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.managedObjectContext) private var coreDataContext

    var body: some View {
        TodayView()
            .fullScreenCover(item: $manager.fullScreenMode) { mode in
                switch mode {
                case .passcodeView:
                    PasscodeView()
                        .environmentObject(manager)
                case .setupPasscodeView:
                    PasscodeView(setupMode: true)
                        .environmentObject(manager)
                case .chartView:
                    NewChartView(viewModel: ChartViewModel())
                        .environmentObject(manager)
                case .timelineView:
                    TimelineView()
                        .environmentObject(manager)
                case .goalTimelineView:
                    if let goal = manager.selectedGoal {
                        GoalTimelineView(goalName: goal, journals: [])
                            .environmentObject(manager)
                    } else {
                        EmptyView()
                    }
                case .entryCreator, .readJournalView, .reboundCreator:
                    // 예전 기록 흐름은 대화(`ConversationView`)로 대체됐다.
                    EmptyView()
                }
            }
            .onAppear {
                if manager.savedPasscode.count == 4 && !manager.didEnterCorrectPasscode {
                    manager.fullScreenMode = .passcodeView
                }
                manager.convertDupicateDataToSwiftData(
                    nsContext: coreDataContext,
                    modelContext: modelContext
                )
            }
    }
}
