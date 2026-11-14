//
//  MochimoWidgetBundle.swift
//  MochimoWidget
//

import SwiftUI
import WidgetKit

@main
struct MochimoWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        SpeakWidget()
    }
}
