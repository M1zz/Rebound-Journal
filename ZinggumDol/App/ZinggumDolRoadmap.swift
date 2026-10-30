//
//  ZinggumDolRoadmap.swift
//  ZinggumDol
//
//  **앞으로 만들 것**의 원본. 설정 ▸ 앞으로 만들 기능(`LeeoRoadmapView`)이 이 목록을 그대로 보여 준다.
//
//  ⚠️ 개발하다 "이건 다음에" 가 생기면 **여기에 한 줄을 더한다.** 코드의 TODO 주석으로만 남기지 않는다.
//     - 새 항목: `.planned`. 손대기 시작하면 `.building`. 내보내면 `.shipped("2.1.0")`.
//     - id 는 한 번 정하면 바꾸지 않는다(문구는 바꿔도 된다).
//     - 문구는 사용자 말로 쓴다(내부 이름 · 기술 용어 금지). 번역은 Localizable.xcstrings 의 en 칸을 채운다.
//     - 사용자에게 보일 만한 것만 적는다. 리팩터링 · 시험 · 빌드 설정은 `.sprintcommander/tasks.json` 의 몫이다.
//

import SwiftUI
import LeeoKit

extension ZinggumDolSpec {
    static var roadmap: [LeeoRoadmapItem] {[
        // MARK: 다음에 만들어요
        .init(id: "autosave", status: .planned,
              title: String(localized: "쓰던 이야기 이어 쓰기", comment: "Roadmap item: keep unfinished writing"),
              detail: String(localized: "쓰다가 앱이 꺼져도 쓰던 이야기가 남아 있어요.", comment: "Roadmap item detail: keep unfinished writing")),
        .init(id: "lock.faceid", status: .planned,
              title: String(localized: "Face ID 잠금", comment: "Roadmap item: Face ID lock"),
              detail: String(localized: "암호 대신 Face ID로 내 기록을 열 수 있어요.", comment: "Roadmap item detail: Face ID lock")),
        .init(id: "shortcuts", status: .planned,
              title: String(localized: "Siri와 단축어", comment: "Roadmap item: Siri and Shortcuts"),
              detail: String(localized: "Siri에게 말하거나 단축어로 바로 기록을 남겨요.", comment: "Roadmap item detail: Siri and Shortcuts")),
        .init(id: "gift", status: .building,
              title: String(localized: "Pro 선물하기", comment: "Roadmap item: gift Pro"),
              detail: String(localized: "결제는 보내는 분이 하고, Pro는 받는 분이 써요.", comment: "Roadmap item detail: gift Pro")),
        .init(id: "onboarding", status: .planned,
              title: String(localized: "처음 쓰는 분을 위한 안내", comment: "Roadmap item: onboarding"),
              detail: String(localized: "처음 열었을 때 무엇을 할 수 있는지 짧게 보여 줘요.", comment: "Roadmap item detail: onboarding")),
        .init(id: "whatsnew", status: .planned,
              title: String(localized: "업데이트 소식", comment: "Roadmap item: what's new"),
              detail: String(localized: "업데이트 뒤 처음 열 때 무엇이 새로 생겼는지 알려 줘요.", comment: "Roadmap item detail: what's new")),
        .init(id: "lang.more", status: .shipped("2.1.1"),
              title: String(localized: "더 많은 언어", comment: "Roadmap item: more languages"),
              detail: String(localized: "더 많은 나라 말로 앱을 쓸 수 있게 해요.", comment: "Roadmap item detail: more languages")),
        .init(id: "a11y.voiceover", status: .planned,
              title: String(localized: "VoiceOver로 더 편하게", comment: "Roadmap item: better VoiceOver support"),
              detail: String(localized: "화면 읽기 기능이 단추와 내용을 빠짐없이, 알맞은 순서로 읽어 줘요.", comment: "Roadmap item detail: better VoiceOver support")),
        .init(id: "a11y.largetext", status: .planned,
              title: String(localized: "큰 글씨에 맞춘 화면", comment: "Roadmap item: layouts that fit large text sizes"),
              detail: String(localized: "글자 크기를 키워도 잘리지 않고 보기 좋게 다시 배치돼요.", comment: "Roadmap item detail: large text layouts")),
        .init(id: "a11y.contrast", status: .planned,
              title: String(localized: "보기 편한 색과 대비", comment: "Roadmap item: better colors and contrast"),
              detail: String(localized: "대비를 높이거나 색을 구별하기 어려워도 내용을 알아볼 수 있어요.", comment: "Roadmap item detail: colors and contrast")),
        .init(id: "a11y.keyboard", status: .planned,
              title: String(localized: "키보드로 조작하기", comment: "Roadmap item: keyboard control"),
              detail: String(localized: "아이패드나 맥에서 키보드만으로 주요 기능을 쓸 수 있어요.", comment: "Roadmap item detail: keyboard control")),
        .init(id: "fold", status: .building,
              title: String(localized: "펼치는 아이폰 화면", comment: "Roadmap item: foldable iPhone layout"),
              detail: String(localized: "펼치는 아이폰에서 넓은 화면을 두 쪽으로 나눠 써요.", comment: "Roadmap item detail: foldable iPhone layout")),
    ]}
}

// MARK: - 화면

/// 설정 ▸ 앞으로 만들 기능. "이런 기능이 있으면 좋겠어요" 는 기능 제안으로 시작하는 피드백 화면을 연다.
struct RoadmapScreen: View {
    @State private var showFeedback = false

    var body: some View {
        LeeoRoadmapView<ZinggumDolSpec>(onSuggest: { showFeedback = true })
            .leeoStyle(.pebble)
            .navigationDestination(isPresented: $showFeedback) {
                LeeoFeedbackView<ZinggumDolSpec>(initialType: .feature)
            }
    }
}
