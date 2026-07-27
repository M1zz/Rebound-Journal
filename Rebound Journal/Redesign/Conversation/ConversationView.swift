//
//  ConversationView.swift
//  Rebound Journal
//
//  대화 화면 (설계 고찰 §7).
//
//  조약돌의 말은 음성과 텍스트로 함께 나간다. 소리를 놓쳐도 글이 남아 있고,
//  소리를 꺼도 대화가 그대로 굴러간다.
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

    var body: some View {
        ZStack {
            PebbleTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                // 내용이 짧을 때는 가운데에 모이고, 대화가 길어지면 위로 스크롤된다.
                // 그냥 두면 조약돌만 위에 붙고 화면 한가운데가 텅 빈다.
                GeometryReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            companion
                            promptText
                            history
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .frame(minHeight: proxy.size.height, alignment: .center)
                    }
                    .scrollIndicators(.hidden)
                }

                responseArea
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
        }
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

    private var companion: some View {
        HStack {
            Spacer()
            PebbleView(
                mood: speech.isListening ? .listening : engine.mood,
                size: 130,
                isSpeaking: false
            )
            Spacer()
        }
        .padding(.top, 8)
    }

    private var promptText: some View {
        Text(engine.prompt)
            .font(PebbleTheme.companionFont(22))
            .foregroundStyle(PebbleTheme.ink)
            .lineSpacing(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: engine.prompt)
    }

    /// 지나간 대화. 사용자가 자기가 한 말을 되짚을 수 있어야 한다.
    private var history: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(engine.transcript.dropLast()) { line in
                HStack {
                    if line.speaker == .user { Spacer(minLength: 40) }
                    Text(line.text)
                        .font(line.speaker == .pebble
                              ? PebbleTheme.companionFont(15)
                              : PebbleTheme.body(15))
                        .foregroundStyle(line.speaker == .pebble
                                         ? PebbleTheme.inkFaint
                                         : PebbleTheme.inkSoft)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(line.speaker == .user ? PebbleTheme.surfaceMuted : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    if line.speaker == .pebble { Spacer(minLength: 40) }
                }
            }
        }
        .opacity(0.9)
    }

    // MARK: - 응답 영역

    @ViewBuilder
    private var responseArea: some View {
        switch engine.response {
        case .choices(let choices):
            VStack(spacing: 10) {
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
        VStack(spacing: 12) {
            if case .confirming(let tidied) = freeform {
                confirmationCard(tidied: tidied)
            } else {
                inputCard(placeholder: placeholder)
                controls
            }
        }
    }

    private func inputCard(placeholder: String) -> some View {
        SoftCard {
            ZStack(alignment: .topLeading) {
                if draft.isEmpty && speech.displayText.isEmpty {
                    Text(placeholder)
                        .font(PebbleTheme.body(16))
                        .foregroundStyle(PebbleTheme.inkFaint)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }

                if speech.isListening {
                    // 듣는 동안엔 들린 말을 그대로 보여준다. 자기 말이 잡히고 있다는
                    // 확인이 있어야 사용자가 불안해하지 않는다.
                    Text(speech.displayText)
                        .font(PebbleTheme.body(16))
                        .foregroundStyle(PebbleTheme.ink)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextEditor(text: $draft)
                        .font(PebbleTheme.body(16))
                        .foregroundStyle(PebbleTheme.ink)
                        .scrollContentBackground(.hidden)
                        .focused($isDraftFocused)
                        .frame(minHeight: 84)
                }
            }
            .frame(minHeight: 84, alignment: .topLeading)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            micButton

            Button(speech.isListening ? "다 말했어요" : "이대로 둘게요") {
                Task { await handlePrimary() }
            }
            .buttonStyle(WarmButtonStyle())
            .disabled(!speech.isListening && draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(!speech.isListening && draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
        }
        .overlay(alignment: .top) {
            if isTidying {
                Text("정리하고 있어요…")
                    .font(PebbleTheme.label(13))
                    .foregroundStyle(PebbleTheme.inkFaint)
                    .offset(y: -22)
            } else if case .unavailable(let note) = speech.phase {
                // 권한이 없어도 재촉하지 않는다. 적어도 된다고만 알린다.
                Text(note)
                    .font(PebbleTheme.label(13))
                    .foregroundStyle(PebbleTheme.inkFaint)
                    .offset(y: -22)
            }
        }
    }

    private var micButton: some View {
        Button {
            Task { await toggleMic() }
        } label: {
            Image(systemName: speech.isListening ? "waveform" : "mic.fill")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(speech.isListening ? .white : PebbleTheme.ink)
                .frame(width: 54, height: 54)
                .background(speech.isListening ? PebbleTheme.sunlight : PebbleTheme.surfaceMuted)
                .clipShape(Circle())
                .symbolEffect(.variableColor, isActive: speech.isListening)
        }
        .accessibilityLabel(speech.isListening ? "그만 말하기" : "말로 답하기")
    }

    /// §7의 핵심 화면. 다시 말해달라고 하는 대신 정리한 문장을 보여주고 고르게 한다.
    private func confirmationCard(tidied: String) -> some View {
        VStack(spacing: 12) {
            SoftCard(background: PebbleTheme.surfaceMuted) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("혹시 이런 뜻인가요?")
                        .font(PebbleTheme.label(14))
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
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(ConversationScript.emotionSteps, id: \.value) { step in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            selectedEmotion = step.value
                            selectedWord = nil
                        }
                    } label: {
                        Text(step.label)
                            .font(PebbleTheme.label(13))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
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
                            .padding(.vertical, 9)
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
                .frame(height: 42)

                Button("이걸로 할게요") {
                    engine.submitEmotion(value: selectedEmotion, word: selectedWord)
                }
                .buttonStyle(WarmButtonStyle())
            }
        }
    }

    // MARK: - 동작

    private func toggleMic() async {
        if speech.isListening {
            await finishListening()
        } else {
            draft = ""
            speech.reset()
            freeform = .listening
            await speech.start()
        }
    }

    private func handlePrimary() async {
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
