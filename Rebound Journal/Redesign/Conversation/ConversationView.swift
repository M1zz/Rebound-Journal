//
//  ConversationView.swift
//  Rebound Journal
//
//  대화 화면 (설계 고찰 §7).
//
//  조약돌이 위에 있고, 주고받은 말이 아래에 말풍선으로 쌓인다. 조약돌의 말은
//  글자가 하나씩 나타나고, 소리도 같이 난다. 소리를 놓쳐도 글이 남고, 소리를
//  꺼도 대화는 그대로 굴러간다.
//
//  말하는 동안에는 입력을 막는다. 질문이 다 나오기 전에 답을 받으면 대화가 아니라
//  양식 작성이 된다.
//
//  이 화면에는 "다시 말씀해 주세요"가 없다. 인식이 흐릿하면 정리해서 되묻고,
//  그마저 안 되면 들린 대로 띄워 고치게 한다.
//

import SwiftUI
import SwiftData

struct ConversationView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var engine: ConversationEngine
    @State private var speech = SpeechCapture()

    @State private var draft: String = ""
    @State private var freeform: FreeformState = .editing
    @State private var isTidying = false
    @State private var selectedEmotion: Int?
    @State private var selectedWord: String?
    @FocusState private var isDraftFocused: Bool

    // 말풍선 등장 제어
    @State private var isThinking = false
    @State private var typingID: UUID?
    @State private var revealedIDs: Set<UUID> = []

    init(observation: GoalObservation, journals: [JournalData]) {
        _engine = State(initialValue: ConversationEngine(observation: observation, journals: journals))
    }

    /// 자유 응답 칸의 상태.
    private enum FreeformState: Equatable {
        case editing
        case listening
        /// 인식이 흐릿해 정리한 문장을 되묻는 중 (§7).
        case confirming(tidied: String)
    }

    /// 조약돌이 아직 말하는 중인지. 이때는 답할 차례가 아니다.
    private var isPebbleSpeaking: Bool {
        isThinking || typingID != nil
    }

    var body: some View {
        ZStack {
            PebbleTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                companion
                thread
                inputArea
            }
        }
        .task(id: engine.transcript.count) { await revealLatest() }
        .onChange(of: engine.beat) { _, _ in resetInput() }
        .interactiveDismissDisabled(!engine.isFinished)
    }

    // MARK: - 머리

    private var header: some View {
        HStack {
            Spacer()
            // 언제든 닫을 수 있다. 닫아도 지금까지 말한 건 저장된다.
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PebbleTheme.inkFaint)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    // MARK: - 조약돌

    /// 화면 위에 계속 머문다. 대화 상대가 누구인지 눈에서 사라지지 않아야 한다.
    private var companion: some View {
        PebbleView(
            mood: speech.isListening ? .listening : engine.mood,
            size: 92,
            isSpeaking: typingID != nil
        )
        .padding(.bottom, 6)
    }

    // MARK: - 대화 줄기

    private var thread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(visibleTranscript) { line in
                        bubble(for: line)
                            .id(line.id)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if isThinking {
                        ChatBubble(speaker: .pebble) { ThinkingDots() }
                            .id(Self.thinkingAnchor)
                            .transition(.opacity)
                    }

                    // 듣는 동안 내 말이 오른쪽에 실시간으로 쌓인다. 잡히고 있다는
                    // 확인이 있어야 말하다 멈추지 않는다.
                    if speech.isListening {
                        ChatBubble(speaker: .user) {
                            listeningBubbleContent
                        }
                        .id(Self.listeningAnchor)
                        .transition(.opacity)
                    }

                    Color.clear.frame(height: 4).id(Self.bottomAnchor)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            // 말풍선이 아래에 붙어 답하는 자리 바로 위에 온다. 위로 붙이면 대화가
            // 한두 마디일 때 화면 가운데가 통째로 비어 보인다.
            .defaultScrollAnchor(.bottom)
            // 조약돌이 말하는 중에 화면을 누르면 끝까지 건너뛴다.
            .contentShape(Rectangle())
            .onTapGesture { skipTyping() }
            .onChange(of: engine.transcript.count) { _, _ in scroll(proxy) }
            .onChange(of: isThinking) { _, _ in scroll(proxy) }
            .onChange(of: speech.displayText) { _, _ in scroll(proxy) }
            .onChange(of: typingID) { _, _ in scroll(proxy) }
        }
    }

    /// 아직 등장할 차례가 아닌 조약돌의 말은 감춘다. 그 자리에는 점 세 개가 떠 있다.
    ///
    /// `isThinking`만 보고 판단하면, 말이 추가된 직후 타이핑이 시작되기 전
    /// 한 프레임 동안 문장 전체가 스쳐 지나간다.
    private var visibleTranscript: [ConversationEngine.Utterance] {
        engine.transcript.filter { line in
            line.speaker == .user || revealedIDs.contains(line.id) || line.id == typingID
        }
    }

    @ViewBuilder
    private func bubble(for line: ConversationEngine.Utterance) -> some View {
        switch line.speaker {
        case .pebble:
            ChatBubble(speaker: .pebble) {
                if line.id == typingID {
                    TypewriterText(text: line.text) {
                        revealedIDs.insert(line.id)
                        typingID = nil
                    }
                } else {
                    // 말풍선은 글자 길이만큼만 차지한다. maxWidth를 채우면 짧은 말도
                    // 화면 폭을 가득 채워 말풍선처럼 보이지 않는다.
                    Text(line.text)
                        .font(PebbleTheme.companionFont(17))
                        .foregroundStyle(PebbleTheme.ink)
                        .lineSpacing(5)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .user:
            ChatBubble(speaker: .user) {
                Text(line.text)
                    .font(PebbleTheme.body(16))
                    .foregroundStyle(PebbleTheme.ink)
                    .lineSpacing(4)
            }
        }
    }

    private var listeningBubbleContent: some View {
        HStack(spacing: 8) {
            if speech.displayText.isEmpty {
                Text("듣고 있어요")
                    .font(PebbleTheme.body(16))
                    .foregroundStyle(PebbleTheme.inkFaint)
            } else {
                Text(speech.displayText)
                    .font(PebbleTheme.body(16))
                    .foregroundStyle(PebbleTheme.ink)
                    .lineSpacing(4)
            }
            Image(systemName: "waveform")
                .font(.system(size: 13))
                .foregroundStyle(PebbleTheme.sunlight)
                .symbolEffect(.variableColor, isActive: true)
        }
    }

    // MARK: - 입력 영역

    @ViewBuilder
    private var inputArea: some View {
        Group {
            if isPebbleSpeaking {
                // 말이 끝나기 전에는 답할 자리를 만들지 않는다.
                Color.clear.frame(height: 8)
            } else {
                responseControls
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.22), value: isPebbleSpeaking)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var responseControls: some View {
        switch engine.response {
        case .choices(let choices):
            VStack(spacing: 8) {
                ForEach(choices) { choice in
                    Button(choice.label) { engine.choose(choice) }
                        .buttonStyle(ChoiceButtonStyle())
                }
            }

        case .freeform(let placeholder):
            freeformArea(placeholder: placeholder)

        case .emotionScale:
            emotionArea

        case .acknowledgement(let label):
            Button(label) {
                if engine.isFinished { close() } else { engine.advance() }
            }
            .buttonStyle(WarmButtonStyle())
        }
    }

    // MARK: 자유 응답 + 음성

    @ViewBuilder
    private func freeformArea(placeholder: String) -> some View {
        if case .confirming(let tidied) = freeform {
            confirmationCard(tidied: tidied)
        } else {
            VStack(spacing: 8) {
                if isTidying {
                    Text("정리하고 있어요…")
                        .font(PebbleTheme.label(13))
                        .foregroundStyle(PebbleTheme.inkFaint)
                } else if case .unavailable(let note) = speech.phase {
                    // 권한이 없어도 재촉하지 않는다. 적어도 된다고만 알린다.
                    Text(note)
                        .font(PebbleTheme.label(13))
                        .foregroundStyle(PebbleTheme.inkFaint)
                }

                composer(placeholder: placeholder)
            }
        }
    }

    /// 메신저 입력줄. 말하거나 적거나, 둘 중 편한 쪽으로.
    private func composer(placeholder: String) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            micButton

            HStack(alignment: .bottom, spacing: 8) {
                TextField(placeholder, text: $draft, axis: .vertical)
                    .font(PebbleTheme.body(16))
                    .foregroundStyle(PebbleTheme.ink)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isDraftFocused)
                    .disabled(speech.isListening)

                if canSend {
                    Button {
                        Task { await handleSend() }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(PebbleTheme.sunlight)
                            .clipShape(Circle())
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(PebbleTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(PebbleTheme.hairline, lineWidth: 1)
            }
        }
        .animation(.easeOut(duration: 0.16), value: canSend)
    }

    private var canSend: Bool {
        speech.isListening || !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var micButton: some View {
        Button {
            Task { await toggleMic() }
        } label: {
            Image(systemName: speech.isListening ? "stop.fill" : "mic.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(speech.isListening ? .white : PebbleTheme.inkSoft)
                .frame(width: 44, height: 44)
                .background(speech.isListening ? PebbleTheme.sunlight : PebbleTheme.surfaceMuted)
                .clipShape(Circle())
        }
        .accessibilityLabel(speech.isListening ? "그만 말하기" : "말로 답하기")
    }

    /// §7의 핵심 화면. 다시 말해달라고 하는 대신 정리한 문장을 보여주고 고르게 한다.
    private func confirmationCard(tidied: String) -> some View {
        VStack(spacing: 10) {
            SoftCard(background: PebbleTheme.surfaceMuted) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("혹시 이런 뜻인가요?")
                        .font(PebbleTheme.label(13))
                        .foregroundStyle(PebbleTheme.inkFaint)
                    Text(tidied)
                        .font(PebbleTheme.body(17))
                        .foregroundStyle(PebbleTheme.ink)
                        .lineSpacing(5)
                }
            }

            HStack(spacing: 10) {
                Button("조금 달라요") {
                    // 다시 말하게 하지 않는다. 정리된 문장을 편집 상태로 넘긴다.
                    draft = tidied
                    freeform = .editing
                    isDraftFocused = true
                }
                .buttonStyle(ChoiceButtonStyle())

                Button("맞아요") {
                    engine.submitFreeform(tidied)
                }
                .buttonStyle(WarmButtonStyle())
            }
        }
    }

    // MARK: 감정

    private var emotionArea: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(ConversationScript.emotionSteps, id: \.value) { step in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            selectedEmotion = step.value
                            selectedWord = nil
                        }
                    } label: {
                        Text(step.label)
                            .font(PebbleTheme.label(12))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(ChoiceButtonStyle(selected: selectedEmotion == step.value))
                }
            }

            if let selectedEmotion {
                // 눈금을 고르면 낱말을 고를 수 있다. 낱말은 선택이지 의무가 아니다.
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(ConversationScript.emotionWords(for: selectedEmotion).prefix(9), id: \.self) { word in
                            Button(word) {
                                selectedWord = (selectedWord == word) ? nil : word
                            }
                            .font(PebbleTheme.label(14))
                            .foregroundStyle(PebbleTheme.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedWord == word
                                        ? PebbleTheme.sunlight.opacity(0.22)
                                        : PebbleTheme.surface)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule().strokeBorder(
                                    selectedWord == word ? PebbleTheme.sunlight : PebbleTheme.hairline,
                                    lineWidth: 1
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .scrollIndicators(.hidden)
                .frame(height: 38)

                Button("이걸로 할게요") {
                    engine.submitEmotion(value: selectedEmotion, word: selectedWord)
                }
                .buttonStyle(WarmButtonStyle())
            }
        }
    }

    // MARK: - 말풍선 등장

    private static let bottomAnchor = "bottom"
    private static let thinkingAnchor = "thinking"
    private static let listeningAnchor = "listening"

    /// 새 조약돌 말이 오면 잠깐 뜸을 들였다가 글자를 하나씩 드러낸다.
    private func revealLatest() async {
        guard let latest = engine.transcript.last else { return }
        guard latest.speaker == .pebble, !revealedIDs.contains(latest.id), typingID != latest.id else { return }

        withAnimation(.easeOut(duration: 0.2)) { isThinking = true }
        try? await Task.sleep(for: .milliseconds(480))
        guard !Task.isCancelled else {
            isThinking = false
            return
        }
        withAnimation(.easeOut(duration: 0.2)) {
            isThinking = false
            typingID = latest.id
        }
    }

    /// 화면을 누르면 타이핑을 끝까지 건너뛴다. 기다리기 싫은 사람도 있다.
    private func skipTyping() {
        guard let typingID else { return }
        TypingFeedback.shared.end()
        revealedIDs.insert(typingID)
        self.typingID = nil
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
        }
    }

    // MARK: - 동작

    private func toggleMic() async {
        if speech.isListening {
            await finishListening()
        } else {
            draft = ""
            isDraftFocused = false
            speech.reset()
            freeform = .listening
            await speech.start()
        }
    }

    private func handleSend() async {
        if speech.isListening {
            await finishListening()
        } else {
            engine.submitFreeform(draft)
        }
    }

    /// 듣기를 마친 뒤의 분기. **어느 갈래에도 재요청이 없다.**
    private func finishListening() async {
        await speech.stop()
        let heard = speech.finalizedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !heard.isEmpty else {
            // 아무것도 안 잡혔다. 다시 말해달라고 하지 않고 조용히 텍스트 칸으로 돌아간다.
            freeform = .editing
            isDraftFocused = true
            return
        }

        guard speech.needsConfirmation else {
            engine.submitFreeform(heard)
            return
        }

        isTidying = true
        let tidied = await Paraphraser.shared.tidy(heard, answering: engine.prompt)
        isTidying = false

        if let tidied {
            freeform = .confirming(tidied: tidied)
        } else {
            // 모델을 못 쓰는 기기. 들린 대로 편집 상태로 넘긴다.
            draft = heard
            freeform = .editing
        }
    }

    private func resetInput() {
        draft = ""
        freeform = .editing
        selectedEmotion = nil
        selectedWord = nil
        speech.reset()
    }

    private func close() {
        Task {
            if speech.isListening { await speech.stop() }
            PebbleVoice.shared.stop()
            engine.persist(in: modelContext)
            dismiss()
        }
    }
}
