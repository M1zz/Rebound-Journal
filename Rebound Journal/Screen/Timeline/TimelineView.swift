//
//  TimelineView.swift
//  Rebound Journal
//
//  Created by Claude on 11/20/25.
//

import SwiftUI
import SwiftData

/// 전체 타임라인을 보여주는 화면
struct TimelineView: View {
    @EnvironmentObject var manager: DataManager

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            ModalHeaderBar(title: "타임라인") {
                manager.fullScreenMode = nil
            }

            // 타임라인 컨텐츠
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    JournalTimelineView()
                        .padding(.horizontal)

                    // 하단 여백
                    Color.clear.frame(height: 100)
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview {
    TimelineView()
        .environmentObject(DataManager())
}
