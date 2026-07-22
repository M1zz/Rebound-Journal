//
//  HomeView.swift
//  Rebound Journal
//
//  Created by 황석현 on 8/19/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    
    @StateObject var viewModel = HomeViewModel()
    
    @Query private var subGoals: [SubGoalData]
    @Query private var journals: [JournalData]
    
    private var hasGoals: Bool { !subGoals.isEmpty }
    private var hasJournals: Bool { !journals.isEmpty }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                topView(geometry)
                bottomView(geometry)
            }
        }
    }
    
    @ViewBuilder
    private func topView(_ geometry: GeometryProxy) -> some View {
        ZStack {
            // Background
            Image(.homeTop)
                .resizable()
                .ignoresSafeArea()
                .frame(height: geometry.size.height * 0.3)
            
            // Contents
            VStack {
                topTrailingButton
                if hasGoals {
                    GoalList(viewModel: viewModel)
                } else {
                    Spacer()
                    Text("슈팅이 빗맞아도 괜찮아요.\n 리바운드로 실패를 기회로 바꾸면 되니까요.")
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.bottom, 50)
                }
            }
        }
    }
    @ViewBuilder
    private func bottomView(_ geometry: GeometryProxy) -> some View {
        ZStack {
            // Background
            Image(.homeBottom)
                .resizable()
                .ignoresSafeArea()
                .frame(height: geometry.size.height * 0.7)
            
            // Contents
            VStack(spacing: 0) {
                if hasJournals {
                    bottomHeader
                    JournalList(viewModel: viewModel)
                }
            }
            
            VStack {
                Spacer()
                if !hasJournals {
                    Text("더 나은 나를 위해 지금 슛을 쏴 보세요!")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.bottom, 30)
                }
                bottomButton
            }
            
        }
    }
    
    private var topTrailingButton: some View {
        HStack {
            Spacer()
            // 전체기록 버튼
            Button {
                print("전체기록 보기")
            } label: {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25)
                    .bold()
            }
            .tint(Color("Default"))

            // 통계화면 버튼
            Button {
                print("통계화면 보기")
            } label: {
                Image(systemName: "chart.bar.xaxis")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25)
            }
            .tint(Color("Default"))

            // 설정화면 버튼
            Button {
                print("설정화면 보기")
            } label: {
                Image(systemName: "gearshape.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25)
            }
            .tint(Color("Default"))
        }
        .padding(.trailing)
    }
    private var bottomHeader: some View {
        HStack {
            Text("다시 리바운드-!")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.accent)
        }
        .padding(.top, 20)
    }
    private var bottomButton: some View {
        Button {
            print("슛-쏘기 클릭")
        } label: {
            Text("슛-쏘기")
                .font(.title3)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .bold()
                .background(.tint)
                .foregroundStyle(Color("TextColor"))
                .clipShape(RoundedRectangle(cornerRadius: 90))
                .padding(.horizontal)
            // SE 대응 패딩
                .padding(.bottom, UIDevice.current.userInterfaceIdiom == .phone && UIScreen.main.bounds.height < 700 ? 16 : 0)
        }
    }
    
}

#Preview {
    HomeView()
}

