//
//  SettingsView.swift
//  Rebound Journal
//
//  Created by hyunho lee on 12/5/24.
//

import SwiftUI
import SwiftData
import StoreKit
import TipKit
import LeeoKit

struct SettingsView: View {
    @EnvironmentObject private var manager: DataManager
    @EnvironmentObject private var store: LeeoStore
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext
    @Query private var journals: [JournalData]

    @State private var remindersTime: Date = Date()
    @State private var didConfigureTime: Bool = false
    /// LeeoKit 과 같은 키. 설정의 "버전" 행을 7번 탭하면 켜진다.
    @AppStorage("dev.masterMode") private var devMode = false
    @State private var voiceOn: Bool = true
    @State private var hapticOn: Bool = true
    @State private var speechStyle: SpeechStyle = .formal
    /// 익명 사용 통계를 보내는가. 저장은 '끄기' 키라 뒤집어서 든다 (→ UsageReporting).
    @AppStorage(UsageReporting.optOutKey) private var usageOptOut = false
    @AppStorage(PebbleSkin.storageKey) private var chosenSkin = PebbleSkin.free.rawValue
    @State private var isConfirmingPasscodeRemoval = false

    @State private var paywallFeature: ProFeature?
    @State private var isShowingPaywall = false
    @State private var exportFile: ExportFile?
    @State private var exportFailed = false

    // 모든 기록 지우기 — 두 번 묻는다. 한 번은 무엇이 사라지는지, 한 번은 정말인지.
    @State private var isConfirmingErase = false
    @State private var isTypingEraseWord = false
    @State private var eraseWord = ""
    @State private var eraseResult: EraseResult?

    private let speechStyleTip = SpeechStyleSettingTip()

    var body: some View {
        // LeeoKit 지원 섹션과 사용 통계는 NavigationLink 로 열리므로 스택이 필요하다
        NavigationStack {
            content
        }
        .proPaywall(isPresented: $isShowingPaywall, feature: paywallFeature)
        .sheet(item: $exportFile) { file in
            ShareSheet(items: [file.url])
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            String(localized: "모든 기록을 지울까요?"),
            isPresented: $isConfirmingErase,
            titleVisibility: .visible
        ) {
            Button(String(localized: "지우기"), role: .destructive) {
                eraseWord = ""
                isTypingEraseWord = true
            }
            if store.hasPro {
                Button(String(localized: "먼저 내보내기")) { exportRecords() }
            }
            Button(String(localized: "취소"), role: .cancel) { }
        } message: {
            Text("목표와 남긴 기록이 모두 사라지고 되돌릴 수 없어요. iCloud로 이어진 다른 기기에서도 지워져요. 설정과 구매는 그대로 남아요.")
        }
        .alert(String(localized: "정말 지울까요?"), isPresented: $isTypingEraseWord) {
            TextField(String(localized: "지우기"), text: $eraseWord)
            Button(String(localized: "취소"), role: .cancel) { }
            Button(String(localized: "모두 지우기"), role: .destructive) { eraseAll() }
                .disabled(!isEraseWordTyped)
        } message: {
            Text("확인을 위해 '\(String(localized: "지우기"))'라고 적어 주세요.")
        }
        .alert(item: $eraseResult) { result in
            Alert(title: Text(result.title))
        }
        .alert(String(localized: "기록을 내보내지 못했어요"), isPresented: $exportFailed) {
            Button(String(localized: "확인"), role: .cancel) { }
        } message: {
            Text("잠시 후 다시 해 주세요.")
        }
        .confirmationDialog(
            String(localized: "정말 비밀번호를 삭제하고 보안을 낮추겠습니까?"),
            isPresented: $isConfirmingPasscodeRemoval,
            titleVisibility: .visible
        ) {
            Button(String(localized: "비밀번호 삭제"), role: .destructive) {
                manager.savedPasscode = ""
            }
            Button(String(localized: "취소"), role: .cancel) { }
        }
    }

    private var content: some View {
        VStack(alignment: .center, spacing: 0) {
            Capsule()
                .frame(width: 50, height: 5)
                .padding(12)
                .foregroundStyle(.secondary)
            ScrollView(.vertical, showsIndicators: false) {
                Spacer(minLength: 5)
                VStack {
                    proSection
                    sectionHeader(String(localized: "조약돌"))
                    if AppLanguage.isKorean {
                        // 존댓말·반말은 한국어에만 있는 구분이다. 다른 언어에서는
                        // 고를 것이 없으므로 아예 내보내지 않는다.
                        speechStyleSection
                    }
                    skinSection
                    companionFeedbackSection
                    sectionHeader(String(localized: "기록"))
                    recordsSection
                    sectionHeader(String(localized: "앱 비밀번호"))
                    passcodeSection
                    sectionHeader(String(localized: "매일 알림"))
                    dailyRemindersSection
                    sectionHeader(String(localized: "사용 통계"))
                    usageSharingSection
                    sectionHeader(String(localized: "소식을 퍼뜨리세요"))
                    ratingShareSection
                    sectionHeader(String(localized: "지원 및 개인정보 보호"))
                    privacySupportSection
                    leeoSupportSection
                }
                .padding(.horizontal, 20)
                Spacer(minLength: 100)
            }
        }
        .padding(.top, 5)
        .onAppear {
            if !didConfigureTime {
                didConfigureTime = true
                if let storedTime = manager.reminderTime.time {
                    remindersTime = storedTime
                }
            }
        }
    }

    // MARK: - 공용 조각

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color("Default"))
            Spacer()
        }
    }

    private func card<Content: View>(bottomPadding: CGFloat = 40, @ViewBuilder _ content: () -> Content) -> some View {
        VStack { content() }
            .padding([.top, .bottom], 5)
            .background(Color(.systemGray6)
                .cornerRadius(15)
                .shadow(color: Color.primary.opacity(0.07), radius: 10))
            .padding(.bottom, bottomPadding)
    }

    private func row(_ title: String, icon: String, locked: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator().impactOccurred()
            action()
        } label: {
            HStack {
                rowIcon(icon)
                Text(title).font(.body)
                Spacer()
                if locked {
                    proBadge
                }
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.primary)
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            rowIcon(icon)
            Text(title).font(.body)
            Spacer()
            // 제목은 옆 글자가 보여 주므로 감추되, VoiceOver 에는 읽히게 넘긴다.
            Toggle(title, isOn: isOn).labelsHidden()
        }
        .foregroundStyle(.primary)
        .padding()
    }

    private func rowIcon(_ name: String) -> some View {
        Image(systemName: name)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 22, height: 22, alignment: .center)
    }

    private var proBadge: some View {
        Text("프로")
            .font(PebbleTheme.label(11))
            .foregroundStyle(PebbleTheme.key)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .overlay(Capsule().strokeBorder(PebbleTheme.key.opacity(0.6), lineWidth: 1))
    }

    private func openPaywall(for feature: ProFeature?) {
        paywallFeature = feature
        isShowingPaywall = true
    }

    // MARK: - 징검돌 프로

    @ViewBuilder
    private var proSection: some View {
        if store.hasPro {
            card {
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(PebbleTheme.key)
                    Text("징검돌 프로를 쓰고 있어요. 고마워요.")
                        .font(.body)
                    Spacer()
                }
                .padding()
            }
        } else {
            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("징검돌 프로")
                        .font(PebbleTheme.title(20))
                        .foregroundStyle(PebbleTheme.ink)
                    Text("목표를 제한 없이 적고, 조약돌을 고르고, 기록을 파일로 간직해요. 한 번 사면 계속 써요.")
                        .font(.subheadline)
                        .foregroundStyle(PebbleTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        openPaywall(for: nil)
                    } label: {
                        Text("알아보기")
                            .font(PebbleTheme.label(15))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(PebbleTheme.key, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                Divider().padding(.horizontal)

                Button {
                    Task { await store.restore() }
                } label: {
                    HStack {
                        rowIcon("arrow.clockwise")
                        Text("구매 복원").font(.body)
                        Spacer()
                        if store.isRestoring { ProgressView() }
                    }
                    .foregroundStyle(.primary)
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(store.isRestoring)
            }
        }
    }

    // MARK: - 조약돌 말투
    //
    // 고르는 자리에서 **실제로 어떻게 말하는지 들려준다.** "존댓말/반말"이라는
    // 이름표만으로는 감이 오지 않고, 특히 반말은 낱말만 보면 무례하게 느껴져
    // 골라보기 전에 접는 사람이 있다. 조약돌이 실제로 하는 말을 밑에 깔아 두면
    // 고르기 전에 확인할 수 있다.
    private var speechStyleSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                TipView(speechStyleTip)
                    .tipBackground(Color(.systemBackground))

                HStack {
                    rowIcon("quote.bubble")
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
        }
        // 저장소가 UserDefaults라 관찰 대상이 아니다. 아래 소리·촉감 토글과
        // 같은 이유로 화면 상태를 따로 들고 바뀔 때 옮겨 적는다.
        .onAppear { speechStyle = SpeechStyle.current }
        .onChange(of: speechStyle) { _, newValue in
            SpeechStyle.current = newValue
            // 고른 순간 한 번 울린다. 말투가 바뀌었다는 걸 손으로도 알린다.
            TypingFeedback.shared.tap()
        }
    }

    // MARK: - 조약돌 결 (프로)
    //
    // 잠긴 결도 **그대로 보여 준다.** 무엇을 고를 수 있는지 봐야 고르고 싶어진다.
    // 눌렀을 때만 페이월이 뜨고, 고른 결은 기억해 둔다 — 산 뒤에 다시 고르지 않아도 된다.
    private var skinSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    rowIcon("paintpalette")
                    Text("조약돌 고르기").font(.body)
                    Spacer()
                    if !store.hasPro { proBadge }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 12) {
                    ForEach(PebbleSkin.allCases) { option in
                        skinOption(option)
                    }
                }
            }
            .foregroundStyle(.primary)
            .padding()
        }
    }

    private func skinOption(_ option: PebbleSkin) -> some View {
        let chosen = PebbleSkin(rawValue: chosenSkin) ?? .free
        let isSelected = PebbleSkin.effective(chosen, hasPro: store.hasPro) == option
        let isLocked = option.requiresPro && !store.hasPro
        return Button {
            // 잠긴 결을 눌러도 골라 둔다. 사고 나면 바로 그 돌이 된다.
            chosenSkin = option.rawValue
            if isLocked {
                openPaywall(for: .pebbleSkin)
            } else {
                TypingFeedback.shared.tap()
            }
        } label: {
            VStack(spacing: 6) {
                PebbleView(mood: .resting, size: 46)
                    .environment(\.pebbleSkin, option)
                    .frame(height: 52)
                HStack(spacing: 3) {
                    if isLocked {
                        Image(systemName: "lock.fill").font(.system(size: 9))
                    }
                    Text(option.name)
                        .font(PebbleTheme.label(12))
                }
                .foregroundStyle(isSelected ? PebbleTheme.key : PebbleTheme.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? PebbleTheme.key.opacity(0.10) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? PebbleTheme.key : .clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(isLocked ? Text("프로에서 열려요") : Text(verbatim: ""))
    }

    // MARK: - 조약돌 소리와 촉감
    //
    // 소리와 진동을 따로 둔다. 늦은 밤처럼 소리는 껐지만 촉감은 남기고 싶은
    // 자리가 이 앱에서는 오히려 흔하다.
    private var companionFeedbackSection: some View {
        card {
            toggleRow(String(localized: "말할 때 소리"), icon: "speaker.wave.2", isOn: $voiceOn)
            Divider().padding(.horizontal)
            toggleRow(String(localized: "말할 때 진동"), icon: "hand.tap", isOn: $hapticOn)
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
    }

    // MARK: - 기록 내보내기 (프로)

    private var recordsSection: some View {
        card {
            row(String(localized: "기록 내보내기"),
                icon: "square.and.arrow.up",
                locked: !store.hasPro) {
                exportRecords()
            }
            Divider().padding(.horizontal)
            row(String(localized: "모든 기록 지우기"), icon: "trash") {
                isConfirmingErase = true
            }
        }
    }

    /// 적은 낱말이 맞는지. 영어 화면에서는 번역된 낱말("Delete")을 적는다.
    private var isEraseWordTyped: Bool {
        let typed = eraseWord.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed == String(localized: "지우기") || typed == "지우기"
    }

    private func eraseAll() {
        guard isEraseWordTyped else { return }
        do {
            try DataEraser.eraseAll(modelContext: modelContext, legacyContainer: manager.container)
            eraseResult = .done
        } catch {
            eraseResult = .failed
        }
    }

    private func exportRecords() {
        guard store.allows(.export) else {
            openPaywall(for: .export)
            return
        }
        do {
            exportFile = ExportFile(url: try RecordExporter.file(journals: journals))
        } catch {
            exportFailed = true
        }
    }

    // MARK: - 매일 알림

    private var dailyRemindersSection: some View {
        card {
            toggleRow(String(localized: "알림 켜기"), icon: "bell",
                      isOn: $manager.enableReminders.onChange { _ in
                          manager.scheduleDailyReminderIfNeeded()
                      })
            if manager.enableReminders {
                Divider().padding(.horizontal)
                HStack {
                    rowIcon("clock")
                    Text("시간").font(.body)
                    Spacer()
                    DatePicker(String(localized: "시간"), selection: $remindersTime.onChange { date in
                        manager.reminderTime = date.string(format: "h:mm a")
                        manager.scheduleDailyReminderIfNeeded()
                    }, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                }
                .foregroundStyle(.primary)
                .padding()
            }
        }
    }

    // MARK: - 익명 사용 통계
    //
    // **무엇을 보내는지 먼저 말하고, 그 옆에서 끌 수 있게 한다.** 기본은 보냄이다.

    private var usageSharingSection: some View {
        card {
            VStack(alignment: .leading, spacing: 0) {
                toggleRow(String(localized: "익명 사용 통계 보내기"), icon: "chart.bar",
                          isOn: Binding(get: { !usageOptOut }, set: { usageOptOut = !$0 }))
                Text("앱을 연 날, 대화를 끝낸 날, 목표를 만든 것 같은 행동의 종류, 기록과 목표의 개수, 구매 화면을 본 것만 보냅니다. 적으신 내용은 한 글자도 나가지 않고, 누가 보냈는지는 이 기기에서 만든 무작위 번호로만 구분합니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding([.horizontal, .bottom])
            }
        }
    }

    // MARK: - 비밀번호

    private var passcodeSection: some View {
        card {
            row(String(localized: "비밀번호 설정"), icon: "circle.grid.3x3") {
                manager.fullScreenMode = .setupPasscodeView
            }
            Divider().padding(.horizontal)
            row(String(localized: "비밀번호 삭제"), icon: "lock.slash") {
                isConfirmingPasscodeRemoval = true
            }
        }
    }

    // MARK: - 평점과 공유

    private var ratingShareSection: some View {
        card {
            row(String(localized: "평점주기"), icon: "star") {
                requestReview()
            }
            Divider().padding(.horizontal)
            ShareLink(item: AppConfig.appStoreURL) {
                HStack {
                    rowIcon("square.and.arrow.up")
                    Text(String(localized: "앱 공유하기")).font(.body)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundStyle(.primary)
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 지원과 개인정보

    private var privacySupportSection: some View {
        card(bottomPadding: 0) {
            row(String(localized: "개발자에게 메일 보내기"), icon: "envelope.badge") {
                openURL(AppConfig.supportMailURL)
            }
            Divider().padding(.horizontal)
            row(String(localized: "개인정보 보호정책"), icon: "hand.raised") {
                openURL(ReboundJournalSpec.legal.privacyURL)
            }
        }
    }

    // MARK: - LeeoKit 지원 (피드백·리뷰 + 사용 통계)

    private var leeoSupportSection: some View {
        VStack {
            LeeoSupportSection<ReboundJournalSpec>()
                .foregroundColor(Color("TextColor"))
                .padding()
            if devMode {
                usageStatsRow
                    .foregroundColor(Color("TextColor"))
                    .padding()
            }
        }
        .padding([.top, .bottom], 5)
        .background(Color("DiarySecondary").cornerRadius(15)
            .shadow(color: Color.primary.opacity(0.07), radius: 10))
        .padding(.top, 40)
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

// MARK: - 지우기 결과

private enum EraseResult: Identifiable {
    case done, failed
    var id: Self { self }
    var title: String {
        switch self {
        case .done: String(localized: "모두 지웠어요.")
        case .failed: String(localized: "지우지 못했어요. 잠시 후 다시 해 주세요.")
        }
    }
}

// MARK: - 내보낸 파일

private struct ExportFile: Identifiable {
    let url: URL
    var id: URL { url }
}

/// 파일을 넘기는 공유 시트. `ShareLink`는 누르기 전에 파일이 있어야 해서,
/// 누른 뒤에 파일을 만드는 이 자리에는 맞지 않는다.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .environmentObject(DataManager(preview: true))
        .environmentObject(LeeoStore(config: ReboundJournalSpec.paywall!))
}
