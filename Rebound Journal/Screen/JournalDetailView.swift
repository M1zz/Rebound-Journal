//
//  JournalDetailView.swift
//  Rebound Journal
//
//  Created by Leeo on 4/19/24.
//

import SwiftUI

struct JournalDetailView: View {
    @EnvironmentObject var manager: DataManager
    @State private var todayText: String = ""
    @State private var showAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Spacer()
                Button {
                    // MARK: 11. Binding과 EnvironmentObject로 다른화면의 데이터 바꾸기
                    manager.fullScreenMode = nil
                } label: {
                    Image(systemName: Constants.ImageStrings.xMark)
                        .font(.system(size: 20,
                                      weight: .semibold))
                }
            }
            
            Image("level\(manager.seledtedEntry!.moodLevel)")
                .resizable()
                .scaledToFit()
                .frame(width: 50)
                .clipShape(.rect(cornerRadius: 10))
            
            Text(Constants.Strings.whatIshoot)
                .multilineTextAlignment(.leading)
                .font(.system(size: 28, weight: .semibold))
            HStack {
                Text(manager.seledtedEntry?.moodText ?? "empty")
                    .padding()
                Spacer()
            }
            .multilineTextAlignment(.leading)
            .background(.list)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.1), radius: 10)
            
            Text(Constants.Strings.myReboundPlan)
                .multilineTextAlignment(.leading)
                .font(.system(size: 28, weight: .semibold))
            
            HStack {
                Text(manager.seledtedEntry?.reboundText ?? "empty")
                    .padding()
                Spacer()
            }
            .multilineTextAlignment(.leading)
            .background(.list)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.1), radius: 10)
            
            Spacer()
            
            
            Button(action: {
                showAlert = true
            }) {
                Image(systemName: "trash.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 50)
                    .foregroundColor(.default)
                    .padding()
            }

            .cornerRadius(20) // 버튼에 대한 코너 반지름을 20으로 설정
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("삭제"),
                    message: Text("정말 삭제하시겠습니까?"),
                    primaryButton: .destructive(Text("삭제"), action: {
                        manager.deleteSelectedEntry(with: manager.seledtedEntry!)
                        manager.fullScreenMode = nil
                    }),
                    secondaryButton: .cancel(Text("취소"))
                )
            }
            .frame(maxWidth: .infinity, maxHeight: 60)
            .background(Color.red.cornerRadius(20)) // 배경에 대한 코너 반지름을 설정
            .edgesIgnoringSafeArea(.all)
            
            
        }
        .padding()
    }
}

#Preview {
    JournalDetailView()
        .environmentObject(DataManager())
}
