//
//  DashboardContentView.swift
//  Rebound Journal
//
//  Created by hyunho lee on 2023/06/10.
//

import SwiftUI
import SwiftData

struct DashboardContentView: View {
    
    @EnvironmentObject var manager: DataManager
    @Environment(\.modelContext)private var modelContext
    @Environment(\.managedObjectContext)private var context
    @ObservedObject var journalCreatorViewModel = JournalCreatorViewModel()
    @ObservedObject var chartViewModel = ChartViewModel()
    @FetchRequest(sortDescriptors: []) private var results: FetchedResults<JournalEntry>
    @Query private var journals: [JournalData]
    @Query private var subGoals: [SubGoalData]
    @State private var isSettingsSheetPresented = false
    @State private var isHistorySheetPresented = false

    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        VStack(spacing: 0) {
            // 상단 헤더
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)

            // 활성 실패 섹션 (고정)
            let activeRebounds = JournalAnalyzer.getActiveRebounds(from: Array(journals))
            if !activeRebounds.isEmpty {
                ActiveReboundSection(activeRebounds: activeRebounds) { rebound in
                    handleRetryRebound(rebound)
                }
                .background(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.05), radius: 3, y: 1)
            }

            // 컨텐츠 (스크롤 가능)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 성장 요약 섹션
                    GrowthSummarySection(journals: Array(journals))
                        .padding(.horizontal)

                    // 목표 현황 섹션
                    GoalStatusSection(
                        subGoals: Array(subGoals),
                        journals: Array(journals)
                    )
                    .padding(.horizontal)

                    // 타임라인 보기 버튼
                    timelineButton
                        .padding(.horizontal)

                    // 하단 여백
                    Color.clear.frame(height: 100)
                }
                .padding(.top, 16)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .bottom) {
            // 하단 버튼
            bottomButton
        }
        // MARK: 10. 화면이동 중 전체화면을 덮는 방법
        .fullScreenCover(item: $manager.fullScreenMode) { type in
            switch type {
            case .entryCreator:
                InteractiveJournalCreator(viewModel: journalCreatorViewModel)
                    .environmentObject(manager)
            case .readJournalView:
                // TODO: 기록 상세화면
                EmptyView()
            case .reboundCreator:
                // TODO: 리바운드 화면
                EmptyView()
            case .passcodeView:
                PasscodeView()
                    .environmentObject(manager)
            case .setupPasscodeView:
                PasscodeView(setupMode: true)
                    .environmentObject(manager)
            case .chartView:
                NewChartView(viewModel: chartViewModel)
                    .environmentObject(manager)
            case .timelineView:
                TimelineView()
                    .environmentObject(manager)
            case .goalTimelineView:
                if let goalName = manager.selectedGoal {
                    GoalTimelineView(goalName: goalName, journals: Array(journals))
                        .environmentObject(manager)
                } else {
                    EmptyView()
                }
            }
        }
        /// Show the passcode view if the passcode was setup
        .onAppear() {
            //Interstitial.shared.loadInterstitial()
            if manager.savedPasscode.count == 4 && !manager.didEnterCorrectPasscode {
                manager.fullScreenMode = .passcodeView
            }
            // 중복되지 않는 CoreData를 SwiftData로 옮기는 함수
            manager.convertDupicateDataToSwiftData(nsContext: context, modelContext: modelContext)
            // FeedbackHub 사용 통계 스냅샷 (LeeoKit이 12시간 간격으로 스로틀)
            UsageReporting.reportSnapshot(journals: Array(journals), subGoals: Array(subGoals))
            // 작은 목표 유무에 따라 슛 생성 화면 상태값 수정
            
        }
        .sheet(isPresented: $isSettingsSheetPresented) {
            SettingsView() // 모달로 표시될 View
        }
    }

    /// 헤더 섹션 (타이틀 + 버튼들)
    private var headerSection: some View {
        HStack {
            Text("성장하기")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)

            Spacer()

            topTrailingButtons
        }
    }

    /// 우측상단 버튼
    private var topTrailingButtons: some View {
        HStack(spacing: 16) {
            // 개발용 샘플 데이터 버튼
            #if DEBUG
            Menu {
                Button("샘플 데이터 생성") {
                    SampleDataGenerator.generateAllSampleData(context: modelContext)
                }
                Button("모든 데이터 삭제", role: .destructive) {
                    SampleDataGenerator.clearAllData(context: modelContext)
                }
            } label: {
                Image(systemName: "cylinder.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25)
            }
            .tint(.purple)
            #endif

            Button {
                manager.fullScreenMode = .chartView
            } label: {
                Image(systemName: "chart.bar.xaxis")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25)
            }
            .tint(Color("Default"))

            Button {
                isSettingsSheetPresented.toggle()
            } label: {
                Image(systemName: "gearshape.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25)
            }
            .tint(Color("Default"))
        }
    }
    /// 목표현황 텍스트
    private var goalStatusText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("목표(\(subGoals.count))")
                .font(.system(size: 22))
                .bold()
            Text("오늘은 어떤 목표에 시도했나요?")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    /// 목표 그리드 (ScrollView 제거)
    private var subGoalGrid: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            // 목표 없는 저널들을 위한 카테고리
            let noGoalCount = journals.count(where: { $0.subGoal == nil || $0.subGoal?.isEmpty == true })
            if noGoalCount > 0 {
                goalCell([DataSentinel.noGoal: noGoalCount])
            }

            // 기존 목표들
            ForEach(subGoals, id: \.self) { item in
                let text = item.goalText ?? DataSentinel.noGoal
                let count = journals.count(where: { $0.subGoal == item.goalText })
                goalCell([text: count])
            }

            // 목표도 저널도 없는 경우에만 안내 메시지 표시
            if subGoals.isEmpty && journals.isEmpty {
                Text("목표를 생성해주세요!")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                    .padding(.top, 50)
            }
        }
    }
    /// 목표 리스트 셀
    private func goalCell(_ data: [String: Int]) -> some View {
        var highlightColor: Color = .gray
        
        if let count = data.values.first {
            switch count {
            case 0..<3:
                highlightColor = Color("GoalFreqLow")
            case 3..<8:
                highlightColor = Color("GoalFreqMid")
            case 8...:
                highlightColor = Color("GoalFreqHigh")
            default:
                break
            }
        }
        
        return VStack(alignment: .leading) {
            if let goal = data.keys.first,
               let count = data.values.first {
                Text(DisplayText.goalName(goal))
                    .lineLimit(1)
										.foregroundStyle(Color("DashboardTitle"))
                    .font(.system(size: 22))
                    .padding(.bottom, 10)
                    .minimumScaleFactor(0.7)
                HStack {
                    Spacer()
                    Text("\(count)번")
                        .font(.system(size: 22, weight: .bold))
												.foregroundStyle(Color("DashboardTitle"))
                }
            } else {
                Text("데이터 없음")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(highlightColor)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    /// 타임라인 보기 버튼
    private var timelineButton: some View {
        Button {
            manager.fullScreenMode = .timelineView
        } label: {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18))
                Text("전체 타임라인 보기")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
            }
            .foregroundStyle(.primary)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    /// 하단 버튼
    private var bottomButton: some View {
        Button {
            manager.fullScreenMode = .entryCreator
        } label: {
            Text("슛-쏘기")
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .bold()
                .background(.tint)
                .foregroundStyle(Color("OnAccent"))
                .clipShape(RoundedRectangle(cornerRadius: 90))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    /// 리바운드 재도전 처리
    private func handleRetryRebound(_ rebound: JournalData) {
        UsageReporting.log(.retryStarted)

        // ViewModel에 재도전할 리바운드 설정
        journalCreatorViewModel.retryingRebound = rebound
        journalCreatorViewModel.subGoal = rebound.subGoalUnwrapped
        journalCreatorViewModel.purpose = rebound.purposeUnwrapped
        journalCreatorViewModel.mainGoal = rebound.mainGoalUnwrapped

        // 기록 화면 열기
        manager.fullScreenMode = .entryCreator
    }
}

