//
//  PlatformCompat.swift
//  Mochimo
//
//  아이폰 · 아이패드와 맥이 이름만 다른 것들을 한곳에 맞춰 둔다.
//  화면 코드에 `#if os` 가 흩어지지 않게 하려는 자리다.
//

import SwiftUI

extension ToolbarItemPlacement {
    /// 제목줄 왼쪽. 맥에서는 창 도구 막대의 앞쪽.
    static var leadingBar: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .navigation
        #endif
    }

    /// 제목줄 오른쪽. 맥에서는 창 도구 막대의 뒤쪽.
    static var trailingBar: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .primaryAction
        #endif
    }
}

extension View {
    /// 제목을 작게 가운데 둔다. 맥 창에는 큰 제목이 없다.
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// 제목줄 바탕을 앱 바탕색으로.
    func navigationBarBackground(_ color: Color) -> some View {
        #if os(iOS)
        toolbarBackground(color, for: .navigationBar)
        #else
        self
        #endif
    }

    /// 화면을 통째로 덮는다. 맥에는 전체 화면 덮개가 없어 창 위 시트로 띄운다.
    func coverScreen<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, content: content)
        #else
        sheet(item: item, content: content)
        #endif
    }

    /// 키보드 위 도구 막대. 맥은 키보드가 화면에 없으니 두지 않는다.
    func keyboardToolbar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        #if os(iOS)
        toolbar { ToolbarItemGroup(placement: .keyboard) { content() } }
        #else
        self
        #endif
    }
}
