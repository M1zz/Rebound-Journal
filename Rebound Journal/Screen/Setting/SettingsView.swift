//
//  SettingView.swift
//  Rebound Journal
//
//  Created by hyunho lee on 12/5/24.
//

import SwiftUI
import StoreKit
import MessageUI

struct SettingsView: View {
    @EnvironmentObject var manager: DataManager
    @State private var remindersTime: Date = Date()
    @State private var didConfigureTime: Bool = false
    
    // MARK: - Main rendering function
    var body: some View {
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
								.font(.headline)
								.foregroundStyle(.primary)
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
    //                .shadow(color: Color.black.opacity(0.07), radius: 10)
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
            CustomHeader(title: Constants.Strings.appPasscode)
            PasscodeView
            CustomHeader(title: Constants.Strings.dailyReminders)
            DailyRemindersView
        }
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
                SettingsItem(title: "시간",
                             icon: "clock",
                             timePicker: true) { }
            }
        }
        .padding([.top, .bottom], 5)
        .background(Color(.systemGray6)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.07),
                    radius: 10))
        .padding(.bottom, 40)
    }
    
    // MARK: - Set and Reset passcode
    private var PasscodeView: some View {
        VStack {
            SettingsItem(title: Constants.Strings.setPasscode, icon: "circle.grid.3x3") {
                manager.fullScreenMode = .setupPasscodeView
                //                if manager.isPremiumUser {
                //                    manager.fullScreenMode = .setupPasscodeView
                //                } else {
                //                    manager.fullScreenMode = .premium
                //                }
            }
            Divider()
                .padding(.horizontal)
            SettingsItem(title: Constants.Strings.disablePasscode,
                         icon: "lock.slash") {
                presentAlert(title: "비밀번호 삭제",
                             message: "정말 비밀번호를 삭제하고 보안을 낮추겠습니까?",
                             primaryAction: UIAlertAction(title: "취소", style: .cancel, handler: nil),
                             secondaryAction: UIAlertAction(title: "비밀번호 삭제", style: .destructive, handler: { _ in
                    manager.savedPasscode = ""
                }))
            }
        }.padding([.top, .bottom], 5).background(
            Color(.systemGray6).cornerRadius(15)
                .shadow(color: Color.black.opacity(0.07), radius: 10)
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
            Color(.systemGray6).cornerRadius(15)
                .shadow(color: Color.black.opacity(0.07), radius: 10)
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
            Color(.systemGray6).cornerRadius(15)
                .shadow(color: Color.black.opacity(0.07), radius: 10)
        )
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
