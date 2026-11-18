//
//  AppCommands.swift
//  Mochimo
//
//  아이패드 키보드와 맥 메뉴 막대의 단축키.
//
//  한 곳에 적으면 두 곳에 다 선다 — 맥에서는 메뉴 막대의 메뉴로, 아이패드에서는 ⌘ 를 길게
//  눌렀을 때 뜨는 단축키 목록과 iPadOS 메뉴 막대로. 화면은 `StepRouter` 를 보고 움직인다.
//

import SwiftUI

struct MochimoCommands: Commands {

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            command("모찌모와 이야기하기", .talk, key: "t")
            command("목표 추가", .addGoal, key: "n")
        }
        CommandGroup(replacing: .appSettings) {
            command("설정", .settings, key: ",")
        }
        CommandMenu("모찌모") {
            command("내 목표", .goals, key: "g")
            command("지나온 길", .lookBack, key: "l")
            command("남긴 것들", .records, key: "r")
        }
    }

    private func command(_ title: LocalizedStringKey, _ command: AppCommand, key: KeyEquivalent) -> some View {
        Button(title) {
            StepRouter.shared.command = command
        }
        .keyboardShortcut(key, modifiers: .command)
    }
}
