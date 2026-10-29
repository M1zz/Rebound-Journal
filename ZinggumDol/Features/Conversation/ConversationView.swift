//
//  ConversationView.swift
//  ZinggumDol
//
//  대화 (설계 고찰 §7).
//
//  따로 뜨는 화면이 아니라 홈 안에서 이어진다. 홈에서 조약돌이 건넨 말과 내가
//  누른 답이 그대로 위에 남고, 그 아래로 대화가 계속된다. 모달로 띄웠을 때는
//  다른 방으로 끌려간 것 같았고, 언제 닫힐지 몰라 불안했다.
//
//  위에는 지금 몇 번째 단계인지 돌로 보여준다. 끝나면 무엇이 남았는지 카드로
//  보여주고, 사용자가 "마칠게요"를 눌러야 홈 인사로 돌아간다.
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
import LeeoKit

struct ConversationView: View {

    @Environment(\.modelContext) private var modelContext
    /// 마무리 카드 아래의 응원 부탁은 이미 프로를 가진 사람에게만 선다.
    @EnvironmentObject private var store: LeeoStore
    /// 마무리 카드의 징검다리를 그리려고 읽는다. 방금 남긴 기록까지 들어와야 한다.
    @Query private var allJournals: [JournalData]

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

    /// 홈에서 이미 오간 말. 대화 위에 그대로 남겨 이어진 대화로 보이게 한다.
    private let preface: [ConversationEngine.Utterance]
    /// 엔진이 첫마디로 다시 하는 말 중 홈에서 이미 한 것. 두 번 보이지 않게 숨긴다.
    private let repeatedIDs: Set<UUID>
    /// 사용자가 "마칠게요"를 눌렀을 때. 홈 인사로 돌아간다.
    private let onFinish: () -> Void

    @State private var isConfirmingLeave = false

    init(
        observation: GoalObservation,
        journals: [JournalData],
        preface: [ConversationEngine.Utterance] = [],
        onFinish: @escaping () -> Void
    ) {
        let engine = ConversationEngine(observation: observation, journals: journals)
        let saidAtHome = Set(preface.filter { $0.speaker == .pebble }.map(\.text))
        _engine = State(initialValue: engine)
        self.preface = preface
        self.repeatedIDs = Set(engine.transcript.filter { saidAtHome.contains($0.text) }.map(\.id))
        self.onFinish = onFinish
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
                companion
                stageBar
                thread
                inputArea
            }
        }
        .task(id: engine.transcript.count) { await revealPending() }
        .onChange(of: engine.beat) { _, _ in resetInput() }
        // 끝나는 순간 저장한다. 마무리 카드의 징검다리에 오늘 돌이 켜져 있어야 한다.
        .onChange(of: engine.isFinished) { _, finished in
            if finished { engine.persist(in: modelContext) }
        }
        .confirmationDialog(
            Text(Phrasing.say("여기까지 할까요?", "여기까지 할까?")),
            isPresented: $isConfirmingLeave,
            titleVisibility: .visible
        ) {
            Button(Phrasing.say("여기까지 할게요", "여기까지 할게")) { leave() }
            Button(Phrasing.say("계속 얘기할게요", "계속 얘기할게"), role: .cancel) {}
        } message: {
            Text(Phrasing.say("지금까지 말한 건 남아요.", "지금까지 말한 건 남아."))
        }
    }

    // MARK: - 단계

    /// 지금 몇 번째 단계인지. 남은 길이 보여야 언제 끝날지 몰라 불안하지 않다.
    ///
    /// 숫자 대신 돌로 그린다. 지나온 단계는 밝은 돌, 지금 단계는 테두리가 둘린 돌,
    /// 남은 단계는 흐린 돌이다.
    private var stageBar: some View {
        let stages = engine.stages
        let current = stages.firstIndex(of: engine.currentStage) ?? 0
        let done = engine.isFinished

        return HStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(Array(stages.enumerated()), id: \.offset) { index, _ in
                    PebbleShape()
                        .fill(index < current || done
                              ? AnyShapeStyle(PebbleTheme.pebbleMid)
                              : AnyShapeStyle(PebbleTheme.inkFaint.opacity(index == current ? 0.3 : 0.22)))
                        .frame(width: 14, height: 11)
                        .overlay {
                            if index == current && !done {
                                PebbleShape().stroke(PebbleTheme.key, lineWidth: 1.5).padding(-2)
                            }
                        }
                }
            }
            Text(engine.currentStage.label)
                .font(PebbleTheme.label(13))
                .foregroundStyle(PebbleTheme.inkSoft)

            Spacer()

            if !engine.isFinished {
                // 언제든 멈출 수 있다. 눌러도 바로 사라지지 않고, 무엇이 남는지 알려준 뒤 멈춘다.
                Button {
                    isConfirmingLeave = true
                } label: {
                    Text(Phrasing.say("여기까지", "여기까지"))
                        .font(PebbleTheme.label(13))
                        .foregroundStyle(PebbleTheme.inkFaint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PebbleTheme.surfaceMuted, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .animation(.easeOut(duration: 0.25), value: engine.currentStage)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("\(engine.stages.count)단계 중 \(current + 1)단계, \(engine.currentStage.label)"))
    }

    // MARK: - 조약돌

    /// 화면 위에 계속 머문다. 대화 상대가 누구인지 눈에서 사라지지 않아야 한다.
    private var companion: some View {
        InteractivePebble(
            mood: speech.isListening ? .listening : engine.mood,
            size: 110,
            isSpeaking: typingID != nil
        )
        .padding(.bottom, 6)
    }

    // MARK: - 대화 줄기

    private var thread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // 홈에서 이미 오간 말. 다시 찍지 않고 그대로 둔다.
                    ForEach(preface) { line in
                        bubble(for: line)
                    }

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

                    // 마지막 말이 다 찍힌 뒤에 무엇이 남았는지 보여준다.
                    if engine.isFinished && !isPebbleSpeaking {
                        ConversationSummaryCard(
                            summary: engine.summary,
                            week: WeekStones.thisWeek(journals: allJournals, goal: engine.goal)
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                        // 이야기를 막 하나 더 남긴 자리. 아직 프로가 아닌 사람에게는 페이월이 맞는 길이라 묻지 않는다.
                        if store.hasPro, let tipJar = store.tipJar {
                            LeeoTipAskSlot<ZinggumDolSpec>(
                                tipJar: tipJar,
                                reached: ZinggumDolTipMoments.reached(talks: allJournals.count)
                            )
                        }
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
            .onChange(of: engine.isFinished) { _, _ in scroll(proxy) }
        }
    }

    /// 아직 등장할 차례가 아닌 조약돌의 말은 감춘다. 그 자리에는 점 세 개가 떠 있다.
    ///
    /// `isThinking`만 보고 판단하면, 말이 추가된 직후 타이핑이 시작되기 전
    /// 한 프레임 동안 문장 전체가 스쳐 지나간다.
    private var visibleTranscript: [ConversationEngine.Utterance] {
        engine.transcript.filter { line in
            guard !repeatedIDs.contains(line.id) else { return false }
            return line.speaker == .user || revealedIDs.contains(line.id) || line.id == typingID
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
                Text(Phrasing.say("듣고 있어요", "듣고 있어"))
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
                .foregroundStyle(PebbleTheme.key)
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
                // 대화 줄기와 답하는 자리를 선으로 가른다. 선 위는 이미 오간 말,
                // 선 아래는 지금 내가 할 일이다. 같은 오른쪽에 있어도 섞여 보이지 않는다.
                VStack(spacing: 12) {
                    Rectangle()
                        .fill(PebbleTheme.hairline)
                        .frame(height: 1)
                        .padding(.horizontal, -20)
                    responseControls
                }
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
            ReplyOptions(
                choices: choices.map { ReplyChoice(id: $0.id, label: $0.label) }
            ) { picked in
                guard let choice = choices.first(where: { $0.id == picked.id }) else { return }
                engine.choose(choice)
            }

        case .freeform(let placeholder):
            freeformArea(placeholder: placeholder)

        case .emotionScale:
            emotionArea

        case .acknowledgement(let label):
            ReplyOptions(choices: [ReplyChoice(id: "ack", label: label, isPrimary: true)]) { _ in
                if engine.isFinished { finish() } else { engine.advance() }
            }
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
                    Text(Phrasing.say("정리하고 있어요…", "정리하고 있어…"))
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
                            .foregroundStyle(PebbleTheme.onKey)
                            .frame(width: 32, height: 32)
                            .background(PebbleTheme.key)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(Text("보내기"))
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
                .foregroundStyle(speech.isListening ? PebbleTheme.onKey : PebbleTheme.inkSoft)
                .frame(width: 44, height: 44)
                .background(speech.isListening ? PebbleTheme.key : PebbleTheme.surfaceMuted)
                .clipShape(Circle())
        }
        .accessibilityLabel(speech.isListening ? "그만 말하기" : "말로 답하기")
        .accessibilityInputLabels(speech.isListening ? [Text("멈추기"), Text("그만 말하기")] : [Text("마이크"), Text("말로 답하기")])
    }

    /// §7의 핵심 화면. 다시 말해달라고 하는 대신 정리한 문장을 보여주고 고르게 한다.
    private func confirmationCard(tidied: String) -> some View {
        VStack(spacing: 10) {
            SoftCard(background: PebbleTheme.surfaceMuted) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Phrasing.say("혹시 이런 뜻인가요?", "혹시 이런 뜻이야?"))
                        .font(PebbleTheme.label(13))
                        .foregroundStyle(PebbleTheme.inkFaint)
                    Text(tidied)
                        .font(PebbleTheme.body(17))
                        .foregroundStyle(PebbleTheme.ink)
                        .lineSpacing(5)
                }
            }

            ReplyOptions(choices: [
                ReplyChoice(id: "yes", label: Phrasing.say("맞아요", "맞아"), isPrimary: true),
                ReplyChoice(id: "edit", label: Phrasing.say("조금 달라요", "조금 달라"))
            ]) { picked in
                if picked.id == "yes" {
                    engine.submitFreeform(tidied)
                } else {
                    // 다시 말하게 하지 않는다. 정리된 문장을 편집 상태로 넘긴다.
                    draft = tidied
                    freeform = .editing
                    isDraftFocused = true
                }
            }
        }
    }

    // MARK: 감정

    private var emotionArea: some View {
        VStack(spacing: 10) {
            // 눈금도 답하는 말이다. 다른 선택지와 같은 버튼으로 둔다.
            // 고르면 체크가 달린 표시로 바뀌고, "이걸로 할게요"를 눌러야 보내진다.
            if selectedEmotion == nil {
                ReplyOptions(
                    choices: ConversationScript.emotionSteps.map {
                        ReplyChoice(id: "\($0.value)", label: $0.label)
                    }
                ) { picked in
                    withAnimation(.easeOut(duration: 0.18)) {
                        selectedEmotion = Int(picked.id)
                        selectedWord = nil
                    }
                }
            } else if let value = selectedEmotion {
                // 고른 눈금은 아직 보낸 말이 아니다. 말풍선으로 그리면 이미 보낸 것처럼
                // 읽히므로, 고른 알약에 체크를 달고 "이걸로 할게요"를 눌러야 올라간다.
                Button {
                    // 잘못 골랐으면 되돌릴 수 있어야 한다.
                    withAnimation(.easeOut(duration: 0.18)) {
                        selectedEmotion = nil
                        selectedWord = nil
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                        Text(ConversationScript.emotionSteps.first { $0.value == value }?.label ?? "")
                            .font(PebbleTheme.body(16).weight(.semibold))
                        Text(Phrasing.say("바꾸기", "바꾸기"))
                            .font(PebbleTheme.label(12))
                            .foregroundStyle(PebbleTheme.inkFaint)
                    }
                    .foregroundStyle(PebbleTheme.key)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(PebbleTheme.key.opacity(0.14))
                    .clipShape(Capsule())
                    .overlay { Capsule().strokeBorder(PebbleTheme.key, lineWidth: 1.5) }
                }
                .buttonStyle(.plain)
            }

            if let selectedEmotion {
                // 눈금을 고르면 낱말을 고를 수 있다. 낱말은 선택이지 의무가 아니다.
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(ConversationScript.emotionWords(for: selectedEmotion).prefix(9), id: \.self) { word in
                            Button {
                                selectedWord = (selectedWord == word) ? nil : word
                            } label: {
                                HStack(spacing: 4) {
                                    SelectionCheck(isSelected: selectedWord == word)
                                    Text(word)
                                }
                            }
                            .accessibilityAddTraits(selectedWord == word ? .isSelected : [])
                            .font(PebbleTheme.label(14))
                            .foregroundStyle(PebbleTheme.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedWord == word
                                        ? PebbleTheme.key.opacity(0.22)
                                        : PebbleTheme.surface)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule().strokeBorder(
                                    selectedWord == word ? PebbleTheme.key : PebbleTheme.hairline,
                                    lineWidth: 1
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .scrollIndicators(.hidden)
                .frame(minHeight: 38)
                .fixedSize(horizontal: false, vertical: true)

                ReplyOptions(choices: [
                    ReplyChoice(id: "done", label: Phrasing.say("이걸로 할게요", "이걸로 할게"), isPrimary: true)
                ]) { _ in
                    engine.submitEmotion(value: selectedEmotion, word: selectedWord)
                }
            }
        }
    }

    // MARK: - 말풍선 등장

    private static let bottomAnchor = "bottom"
    private static let thinkingAnchor = "thinking"
    private static let listeningAnchor = "listening"

    /// 아직 안 나온 조약돌의 말을 순서대로 하나씩 내보낸다.
    ///
    /// 한 마디가 두 문장으로 나뉘는 자리가 있다(지난 기록을 꺼낸 뒤 질문하기).
    /// 마지막 것만 처리하면 앞 문장이 영영 감춰진 채 남으므로, 밀린 것을 전부
    /// 훑으며 앞의 타이핑이 끝나기를 기다렸다가 다음으로 넘어간다.
    private func revealPending() async {
        while !Task.isCancelled {
            guard let next = engine.transcript.first(where: {
                $0.speaker == .pebble && !revealedIDs.contains($0.id) && !repeatedIDs.contains($0.id)
            }) else { return }

            withAnimation(.easeOut(duration: 0.2)) { isThinking = true }
            try? await Task.sleep(for: .milliseconds(480))
            guard !Task.isCancelled else {
                isThinking = false
                return
            }
            withAnimation(.easeOut(duration: 0.2)) {
                isThinking = false
                typingID = next.id
            }

            // 타이핑이 끝나면 `TypewriterText`가 revealedIDs에 넣고 typingID를 비운다.
            // 그 신호를 기다린다. 건너뛰기를 눌러도 같은 자리에서 풀린다.
            while !Task.isCancelled && typingID == next.id {
                try? await Task.sleep(for: .milliseconds(40))
            }
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
            TypingFeedback.shared.tap()
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
            TypingFeedback.shared.tap()
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

    /// 도중에 그만둔다. 조약돌이 인사하고 마무리 카드가 뜬 뒤에 "마칠게요"로 나간다.
    private func leave() {
        Task {
            if speech.isListening { await speech.stop() }
            isDraftFocused = false
            engine.leave()
        }
    }

    private func finish() {
        Task {
            if speech.isListening { await speech.stop() }
            PebbleVoice.shared.stop()
            engine.persist(in: modelContext)
            onFinish()
        }
    }
}

// MARK: - 마무리 카드

/// 대화가 남긴 것.
///
/// 말한 것이 어디로 갔는지, 그래서 이 목표가 이번 주에 어디쯤인지를 한자리에서
/// 보여준다. 이게 없으면 대화가 그냥 흘러가 버린 것처럼 느껴진다.
///
/// 해냈는지는 적되 점수를 매기지 않는다. 닿지 못한 날도 "남긴 날"로 적고,
/// 이번 주 돌은 밝기로만 보여준다 (§4).
struct ConversationSummaryCard: View {
    let summary: ConversationEngine.Summary
    let week: [StoneDay]

    var body: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: summary.isSaved ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(summary.isSaved ? PebbleTheme.key : PebbleTheme.inkFaint)
                    Text(summary.isSaved
                         ? Phrasing.say("오늘 남긴 것", "오늘 남긴 것")
                         : Phrasing.say("이번엔 남긴 게 없어요", "이번엔 남긴 게 없어"))
                        .font(PebbleTheme.label(14))
                        .foregroundStyle(PebbleTheme.inkSoft)
                }

                if !summary.goal.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.goal)
                            .font(PebbleTheme.title(19))
                            .foregroundStyle(PebbleTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if summary.isSaved {
                            Text(summary.reached
                                 ? Phrasing.say("오늘 해냈어요", "오늘 해냈어")
                                 : Phrasing.say("오늘 얘기를 남겼어요", "오늘 얘기를 남겼어"))
                                .font(PebbleTheme.label(13))
                                .foregroundStyle(summary.reached ? PebbleTheme.key : PebbleTheme.inkSoft)
                        }
                    }
                }

                if summary.isSaved {
                    VStack(alignment: .leading, spacing: 8) {
                        if let facts = summary.facts {
                            row("text.bubble", facts)
                        }
                        if let feeling = summary.feeling {
                            row("heart", feeling)
                        }
                        if let next = summary.nextStep {
                            // 새로 생긴 목표. 다음에 조약돌이 이걸로 말을 건다.
                            row("flag", next, caption: Phrasing.say("새 목표로 추가했어요", "새 목표로 추가했어"))
                        }
                    }
                }

                if !summary.goal.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "이 목표의 이번 주"))
                            .font(PebbleTheme.label(12))
                            .foregroundStyle(PebbleTheme.inkFaint)
                        WeekStoneStrip(days: week, stoneWidth: 24)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func row(_ icon: String, _ text: String, caption: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(PebbleTheme.inkFaint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                if let caption {
                    Text(caption)
                        .font(PebbleTheme.label(12))
                        .foregroundStyle(PebbleTheme.key)
                }
                Text(text)
                    .font(PebbleTheme.body(15))
                    .foregroundStyle(PebbleTheme.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 응원을 부탁할 순간

/// 조약돌과 나눈 이야기 수(남긴 기록 하나가 대화 하나다). 이만큼 곁에 있었다는 숫자라 고마운 순간이다.
/// 큰 것부터 넘긴다 — 함께 넘어선 작은 순간은 LeeoKit 이 다 쓴 것으로 친다.
enum ZinggumDolTipMoments {
    static let talks = [100, 30, 10]

    static func reached(talks count: Int) -> [LeeoTipMoment] {
        talks.filter { count >= $0 }.map { threshold in
            LeeoTipMoment(id: "talks.\(threshold)",
                          message: String(localized: "지금까지 이야기를 \(count)번 나눴어요",
                                          comment: "Tip ask card: how many conversations the user has had with the pebble so far"))
        }
    }
}
