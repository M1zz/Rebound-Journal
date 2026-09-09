//
//  SettingView.swift
//  Rebound Journal
//
//  Created by hyunho lee on 12/5/24.
//

import SwiftUI
import StoreKit
import MessageUI
import TipKit
import LeeoKit

struct SettingsView: View {
    @EnvironmentObject var manager: DataManager
    @State private var remindersTime: Date = Date()
    @State private var didConfigureTime: Bool = false
    /// LeeoKit 과 같은 키. 설정의 "버전" 행을 7번 탭하면 켜진다.
    @AppStorage("dev.masterMode") private var devMode = false
    @State private var voiceOn: Bool = true
    @State private var hapticOn: Bool = true
    @State private var speechStyle: SpeechStyle = .formal

    private let speechStyleTip = SpeechStyleSettingTip()
    
    // MARK: - Main rendering function
    var body: some View {
        // LeeoKit 지원 섹션과 사용 통계는 NavigationLink 로 열리므로 스택이 필요하다
        NavigationStack {
            settingsContent
        }
    }

    private var settingsContent: some View {
        ZStack {
            VStack(alignment: .center, spacing: 0) {
                Capsule()
                    .frame(width: 50, height: 5)
                    .padding(12)
                    .foregroundStyle(.secondary)
                ScrollView(.vertical, showsIndicators: false) {
                    Spacer(minLength: 5)
                    VStack {
                        //                        InAppPurchasesPromoBannerView
                        //                        CustomHeader(title: "In-App Purchases")
                        //                        InAppPurchasesView
                        AppCustomSettingsView
                        CustomHeader(title: Constants.Strings.spreadTheWord)
                        RatingShareView
                        CustomHeader(title: Constants.Strings.supportAndPrivacy)
                        PrivacySupportView
                        LeeoSupportView
                    }
                    .padding(.horizontal, 20)
                    Spacer(minLength: 100)
                }
            }
        }.padding(.top, 5).onAppear {
            if !didConfigureTime {
                didConfigureTime = true
                if let storedTime = manager.reminderTime.time {
                    remindersTime = storedTime
                }
            }
        }
        
    }
    
    /// Create custom header view
    private func CustomHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color("Default"))
            
            Spacer()
        }
    }
    
    /// Custom settings item
    private func SettingsItem(title: String, icon: String, remindersToggle: Bool = false, timePicker: Bool = false, action: @escaping() -> Void) -> some View {
        func itemCellView() -> some View {
            HStack {
                Image(systemName: icon).resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22, alignment: .center)
                Text(title).font(.body)
                Spacer()
                if timePicker {
                    DatePicker("", selection: $remindersTime.onChange({ date in
                        manager.reminderTime = date.string(format: "h:mm a")
                        manager.scheduleDailyReminderIfNeeded()
                    }), displayedComponents: .hourAndMinute)
                } else {
                    if remindersToggle {
                        Toggle("", isOn: $manager.enableReminders.onChange({ _ in
                            manager.scheduleDailyReminderIfNeeded()
                        })).labelsHidden()
                    } else {
                        Image(systemName: "chevron.right")
                    }
                }
            }.foregroundStyle(.primary).padding()
        }
        return ZStack {
            if remindersToggle || timePicker {
                itemCellView()
            } else {
                Button(action: {
                    UIImpactFeedbackGenerator().impactOccurred()
                    action()
                }, label: {
                    itemCellView()
                })
            }
        }
    }
    
    //    // MARK: - In App Purchases
    //    private var InAppPurchasesView: some View {
    //        VStack {
    //            SettingsItem(title: "Upgrade Premium", icon: "crown") {
    //                manager.fullScreenMode = .premium
    //            }
    //            Color("TextColor").frame(height: 1).opacity(0.1)
    //            SettingsItem(title: "Restore Purchases", icon: "arrow.clockwise") {
    //                manager.fullScreenMode = .premium
    //            }
    //        }.padding([.top, .bottom], 5).background(
    //            Color("Secondary").cornerRadius(15)
    //                .shadow(color: Color.primary.opacity(0.07), radius: 10)
    //        ).padding(.bottom, 40)
    //    }
    //
    //    private var InAppPurchasesPromoBannerView: some View {
    //        ZStack {
    //            if manager.isPremiumUser == false {
    //                ZStack {
    //                    Color("BackgroundColor")
    //                    HStack {
    //                        VStack(alignment: .leading) {
    //                            Text("Premium Version").bold().font(.system(size: 20))
    //                            Text("- Enable App Passcode").font(.system(size: 15)).opacity(0.7)
    //                            Text("- Add Photos to journal").font(.system(size: 15)).opacity(0.7)
    //                            Text("- Remove ads").font(.system(size: 15)).opacity(0.7)
    //                        }
    //                        Spacer()
    //                        Image(systemName: "crown.fill").font(.system(size: 45))
    //                    }.foregroundColor(.white).padding([.leading, .trailing], 20)
    //                }.frame(height: 110).cornerRadius(16).padding(.bottom, 5)
    //            }
    //        }
    //    }
    
    // MARK: - App Custom settings
    private var AppCustomSettingsView: some View {
        VStack {
            CustomHeader(title: "조약돌")
            SpeechStyleView
            CompanionFeedbackView
            CustomHeader(title: Constants.Strings.appPasscode)
            PasscodeView
            CustomHeader(title: Constants.Strings.dailyReminders)
            DailyRemindersView
        }
    }

    // MARK: - 조약돌 말투
    //
    // 고르는 자리에서 **실제로 어떻게 말하는지 들려준다.** "존댓말/반말"이라는
    // 이름표만으로는 감이 오지 않고, 특히 반말은 낱말만 보면 무례하게 느껴져
    // 골라보기 전에 접는 사람이 있다. 조약돌이 실제로 하는 말을 밑에 깔아 두면
    // 고르기 전에 확인할 수 있다.
    private var SpeechStyleView: some View {
        VStack(alignment: .leading, spacing: 12) {
            TipView(speechStyleTip)
                .tipBackground(Color(.systemBackground))

            HStack {
                Image(systemName: "quote.bubble")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22, alignment: .center)
                Text("말투").font(.body)
                Spacer()
            }

            Picker("말투", selection: $speechStyle) {
                ForEach(SpeechStyle.allCases) { style in
                    Text(style.name).tag(style)
                }
            }
            .pickerStyle(.segmented)

            // 고른 말투로 조약돌이 한마디 한다.
            Text(speechStyle.sample)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeOut(duration: 0.18), value: speechStyle)
        }
        .foregroundStyle(.primary)
        .padding()
        // 저장소가 UserDefaults라 관찰 대상이 아니다. 아래 소리·촉감 토글과
        // 같은 이유로 화면 상태를 따로 들고 바뀔 때 옮겨 적는다.
        .onAppear { speechStyle = SpeechStyle.current }
        .onChange(of: speechStyle) { _, newValue in
            SpeechStyle.current = newValue
            // 고른 순간 한 번 울린다. 말투가 바뀌었다는 걸 손으로도 알린다.
            TypingFeedback.shared.tap()
        }
        .padding([.top, .bottom], 5)
        .background(Color(.systemGray6)
            .cornerRadius(15)
            .shadow(color: Color.primary.opacity(0.07),
                    radius: 10))
        .padding(.bottom, 40)
    }

    // MARK: - 조약돌 소리와 촉감
    //
    // 소리와 진동을 따로 둔다. 늦은 밤처럼 소리는 껐지만 촉감은 남기고 싶은
    // 자리가 이 앱에서는 오히려 흔하다.
    private var CompanionFeedbackView: some View {
        VStack {
            ToggleItem(title: "말할 때 소리", icon: "speaker.wave.2", isOn: $voiceOn)
            Divider()
                .padding(.horizontal)
            ToggleItem(title: "말할 때 진동", icon: "hand.tap", isOn: $hapticOn)
        }
        // 저장소가 UserDefaults라 관찰 대상이 아니다. 화면 상태를 따로 들고
        // 바뀔 때 옮겨 적는다. 계산 프로퍼티에 직접 Binding을 걸면 토글이
        // 다시 그려지지 않아 눌러도 제자리로 튕긴다.
        .onAppear {
            voiceOn = PebbleVoice.shared.isEnabled
            hapticOn = TypingFeedback.shared.isHapticEnabled
        }
        .onChange(of: voiceOn) { _, newValue in
            PebbleVoice.shared.isEnabled = newValue
        }
        .onChange(of: hapticOn) { _, newValue in
            TypingFeedback.shared.isHapticEnabled = newValue
            // 켠 직후 한 번 울려 어떤 느낌인지 바로 알게 한다.
            if newValue { TypingFeedback.shared.tap() }
        }
        .padding([.top, .bottom], 5)
        .background(Color(.systemGray6)
            .cornerRadius(15)
            .shadow(color: Color.primary.opacity(0.07),
                    radius: 10))
        .padding(.bottom, 40)
    }

    /// 켜고 끄기만 하는 항목. 기존 `SettingsItem`은 알림 토글에 묶여 있어 재사용이 안 된다.
    private func ToggleItem(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22, alignment: .center)
            Text(title).font(.body)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
        .foregroundStyle(.primary)
        .padding()
    }
    
    // MARK: - Daily Reminders section
    private var DailyRemindersView: some View {
        VStack {
            SettingsItem(title: Constants.Strings.enableReminders,
                         icon: "bell",
                         remindersToggle: true) { }
            if manager.enableReminders {
                Divider()
                    .padding(.horizontal)
                SettingsItem(title: String(localized: "시간"),
                             icon: "clock",
                             timePicker: true) { }
            }
        }
        .padding([.top, .bottom], 5)
        .background(Color(.systemGray6)
            .cornerRadius(15)
            .shadow(color: Color.primary.opacity(0.07),
                    radius: 10))
        .padding(.bottom, 40)
    }
    
    // MARK: - Set and Reset passcode
    private var PasscodeView: some View {
        VStack {
            SettingsItem(title: Constants.Strings.setPasscode, icon: "circle.grid.3x3") {
                manager.fullScreenMode = .setupPasscodeView
            }
            Divider()
                .padding(.horizontal)
            SettingsItem(title: Constants.Strings.disablePasscode,
                         icon: "lock.slash") {
                presentAlert(title: String(localized: "비밀번호 삭제"),
                             message: String(localized: "정말 비밀번호를 삭제하고 보안을 낮추겠습니까?"),
                             primaryAction: UIAlertAction(title: String(localized: "취소"), style: .cancel, handler: nil),
                             secondaryAction: UIAlertAction(title: String(localized: "비밀번호 삭제"), style: .destructive, handler: { _ in
                    manager.savedPasscode = ""
                }))
            }
        }.padding([.top, .bottom], 5).background(
            Color("DiarySecondary").cornerRadius(15)
                .shadow(color: Color.primary.opacity(0.07), radius: 10)
        ).padding(.bottom, 40)
    }
    
    // MARK: - Rating and Share
    private var RatingShareView: some View {
        VStack {
            SettingsItem(title: Constants.Strings.rateApp,
                         icon: "star") {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
            }
            Divider()
                .padding(.horizontal)
            SettingsItem(title: Constants.Strings.shareApp,
                         icon: "square.and.arrow.up") {
                let shareController = UIActivityViewController(activityItems: [AppConfig.yourAppURL], applicationActivities: nil)
                rootController?.present(shareController, animated: true, completion: nil)
            }
        }.padding([.top, .bottom], 5).background(
            Color("DiarySecondary").cornerRadius(15)
                .shadow(color: Color.primary.opacity(0.07), radius: 10)
        ).padding(.bottom, 40)
    }
    
    // MARK: - Support & Privacy
    private var PrivacySupportView: some View {
        VStack {
            SettingsItem(title: Constants.Strings.eMailUs,
                         icon: "envelope.badge") {
                EmailPresenter.shared.present()
            }
#warning("약관추가")
            //            Divider()
            //                .padding(.horizontal)
            //            SettingsItem(title: Constants.Strings.privacyPolicy,
            //                         icon: "hand.raised") {
            //                UIApplication.shared.open(AppConfig.privacyURL, options: [:], completionHandler: nil)
            //            }
            //            Divider()
            //                .padding(.horizontal)
            //            SettingsItem(title: Constants.Strings.termsOfUse,
            //                         icon: "doc.text") {
            //                UIApplication.shared.open(AppConfig.termsAndConditionsURL, options: [:], completionHandler: nil)
            //            }
        }.padding([.top, .bottom], 5).background(
            Color("DiarySecondary").cornerRadius(15)
                .shadow(color: Color.primary.opacity(0.07), radius: 10)
        )
    }

    // MARK: - LeeoKit Support (feedback & review + 사용 통계)
    private var LeeoSupportView: some View {
        VStack {
            LeeoSupportSection<ReboundJournalSpec>()
                .foregroundColor(Color("TextColor"))
                .padding()
            if devMode {
                usageStatsRow
                    .foregroundColor(Color("TextColor"))
                    .padding()
            }
        }.padding([.top, .bottom], 5).background(
            Color("DiarySecondary").cornerRadius(15)
                .shadow(color: Color.primary.opacity(0.07), radius: 10)
        ).padding(.top, 40)
    }

    /// FeedbackHub 로 올라간 사용 통계 대시보드 (개발자 모드에서만 보인다)
    private var usageStatsRow: some View {
        NavigationLink {
            LeeoUsageStatsView<ReboundJournalSpec>()
        } label: {
            Label(String(localized: "사용 통계 (개발자)"), systemImage: "chart.bar.doc.horizontal")
        }
    }
}

// MARK: - Preview UI
#Preview {
    SettingsView()
        .environmentObject(DataManager(preview: true))
        .environment(\.colorScheme, .dark)
}

// MARK: - Mail presenter for SwiftUI
class EmailPresenter: NSObject, MFMailComposeViewControllerDelegate {
    public static let shared = EmailPresenter()
    private override init() { }
    
    func present() {
        if !MFMailComposeViewController.canSendMail() {
            presentAlert(title: "Email Client", message: "Your device must have the native iOS email app installed for this feature.")
            return
        }
        let picker = MFMailComposeViewController()
        picker.setToRecipients([AppConfig.emailSupport])
        picker.mailComposeDelegate = self
        rootController?.present(picker, animated: true, completion: nil)
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        rootController?.dismiss(animated: true, completion: nil)
    }
}
