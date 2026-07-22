//
//  NavigationHeaderView.swift
//  Rebound Journal
//
//  Created by 황석현 on 4/9/25.
//

import SwiftUI

struct ModalHeaderBar: View {

  @State var showAlert: Bool = false
  // 뒤로가기 동작
  var onBack: (() -> Void)?
  var title: String?
  // 나가기 동작
  var onDismiss: (() -> Void)?
  // 경고창 문구(안내, 상세안내)
  var hasAlert: Bool = false

  var body: some View {
    ZStack {
      // 타이틀 중앙 고정
      if let title = title {
        Text(title)
          .font(.system(size: 22, weight: .semibold))
      }

      HStack {
        if let action = onBack {
          Button {
            action()
          } label: {
            Image(systemName: "chevron.left")
              .font(.system(size: 22, weight: .semibold))
              .tint(Color("Default"))
              .padding()
          }
        } else {
          // 공간 차지를 위한 투명한 버튼
          Color.clear
            .frame(width: 44, height: 44)  // 버튼과 동일한 사이즈
        }

        Spacer()

        if let action = onDismiss {
          Button {
            if hasAlert {
              showAlert.toggle()
            } else {
              action()
            }
          } label: {
            Image(systemName: Constants.ImageStrings.xMark)
              .font(.system(size: 22, weight: .semibold))
              .tint(Color("Default"))
              .padding()
          }
          .alert(isPresented: $showAlert) {
            Alert.exitAlert(action: action)
          }
        } else {
          // 오른쪽도 동일하게 공간 확보
          Color.clear
            .frame(width: 44, height: 44)
        }
      }
    }
  }
}

#Preview("Dismiss") {
  ModalHeaderBar(onDismiss: {
    debugPrint("onDismiss")
  })
}
#Preview("onBack") {
  ModalHeaderBar(onBack: { debugPrint("onBack") })
}
#Preview("Title") {
  ModalHeaderBar(title: "Title")
}
#Preview("onBack&Dismiss") {
  ModalHeaderBar(
    onBack: { debugPrint("onBack") },
    onDismiss: { debugPrint("onDismiss") })
}
#Preview("All") {
  ModalHeaderBar(
    onBack: { debugPrint("onBack") }, title: "Title", onDismiss: { debugPrint("onDismiss") })
}
#Preview("Title&Dismiss") {
  ModalHeaderBar(title: "Title", onDismiss: { debugPrint("onDismiss") })
}
