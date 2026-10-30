//
//  PasscodeView.swift
//  ZinggumDol
//
//  Created by hyunho lee on 12/5/24.
//

import SwiftUI
import LeeoKit

/// Main view to setup a passcode
struct PasscodeView: View {
    
    @EnvironmentObject var manager: DataManager
    @Environment(\.presentationMode) var presentation
    @State private var showWrongPasswordAnimation: Bool = false
    @State private var passcodeArray: [String] = [String]()
    @State private var setupPasscode: String = ""
    @State var setupMode: Bool = false
    
    // MARK: - Main rendering function
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            PasscodeView
        }.background(BackgroundBlurView().ignoresSafeArea())
    }
    
    /// Passcode view
    private var PasscodeView: some View {
        var passcodeTitle = setupPasscode.count == 4
            ? String(localized: "비밀번호 확인")
            : String(localized: "비밀번호 설정")
        if !setupMode { passcodeTitle = String(localized: "비밀번호 입력") }
        return VStack(spacing: 30) {
            Text(passcodeTitle).bold().font(.title2)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 15) {
                ForEach(0..<4, id: \.self) { index in
                    ZStack {
                        if passcodeArray.count > index {
                            Circle()
                        } else {
                            Circle().strokeBorder(lineWidth: 2)
                                
                        }
                    }.frame(width: 12, height: 12, alignment: .center)
                }
            }.offset(x: showWrongPasswordAnimation ? -20 : 0)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("입력한 숫자"))
            .accessibilityValue(Text("4개 중 \(passcodeArray.count)개"))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 20, content: {
                ForEach(0..<9, id: \.self, content: { index in
                    KeypadButton(index: index + 1)
                })
            }).padding([.leading, .trailing, .top], 40)
            KeypadButton(index: 0)
        }.foregroundColor(Color("Default"))
    }
    
    /// Create keypad button
    private func KeypadButton(index: Int) -> some View {
        let size = Self.keySize
        return Button(action: {
            UIImpactFeedbackGenerator().impactOccurred()
            if setupMode == true {
                if passcodeArray.count != 4 {
                    passcodeArray.append("\(index)")
                }
                if passcodeArray.count == 4 {
                    verifySetupPasscode()
                }
            } else {
                if passcodeArray.count != 4 {
                    passcodeArray.append("\(index)")
                }
                if passcodeArray.count == 4 {
                    if manager.savedPasscode == passcodeArray.joined() {
                        manager.didEnterCorrectPasscode = true
                        presentation.wrappedValue.dismiss()
                    } else {
                        resetPasscodeEntry()
                    }
                }
            }
        }, label: {
            ZStack {
                Circle().foregroundColor(Color.accentColor).opacity(0.5)
                Text("\(index)").font(.system(size: 35)).foregroundColor(Color("LightColor")).opacity(0.7)
            }
        })
        .frame(width: size, height: size)
        .disabled(passcodeArray.count == 4)
    }
    
    /// 숫자 단추 하나의 지름. 화면 폭을 셋으로 나눈다.
    /// 아이폰 듀오를 펴면 이 화면은 고르는 쪽 판 한 장에만 서므로(`foldConfined`) 그 판 크기로 재고,
    /// 네 줄이 판 높이 안에 들도록 높이로도 줄인다. 접혀 있으면 예전 셈 그대로다.
    private static var keySize: CGFloat {
        let fold = FoldState.current
        guard fold.isUnfolded else { return UIScreen.main.bounds.width / 3 - 50 }
        let pane = fold.choosePaneSize
        // 제목 · 점 · 사이 간격 · 위 여백이 차지하는 높이를 빼고 네 줄로 나눈다.
        return max(44, min(pane.width / 3 - 50, (pane.height - 260) / 4))
    }

    /// Verify setup passcode
    private func verifySetupPasscode() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if setupPasscode == passcodeArray.joined() {
                manager.savedPasscode = setupPasscode
                presentation.wrappedValue.dismiss()
            } else {
                if setupPasscode.count == 0 {
                    setupPasscode = passcodeArray.joined()
                    passcodeArray.removeAll()
                } else {
                    setupPasscode = ""
                    resetPasscodeEntry()
                }
            }
        }
    }
    
    private func resetPasscodeEntry() {
        passcodeArray.removeAll()
        // 흔들림이 보이지 않는 사람에게도 틀렸다는 걸 알린다.
        AccessibilityNotification.Announcement(String(localized: "비밀번호가 맞지 않아요")).post()
        let duration = 0.1
        withAnimation(Animation.easeIn(duration: duration)) {
            showWrongPasswordAnimation = true
        }
        withAnimation(Animation.easeIn(duration: duration).delay(duration)) {
            showWrongPasswordAnimation = false
        }
    }
}

#Preview {
    PasscodeView().environmentObject(DataManager(preview: true))
}

/// 비밀번호 화면 뒤로 앱을 흐리게 비춘다.
private struct BackgroundBlurView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
