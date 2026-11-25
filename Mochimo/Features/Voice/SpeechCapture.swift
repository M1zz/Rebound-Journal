//
//  SpeechCapture.swift
//  Mochimo
//
//  음성 입력 (설계 고찰 §7, §8).
//
//  iOS 26의 SpeechAnalyzer를 쓴다. SFSpeechRecognizer의 세션당 1분 제한이 없어서,
//  §8에서 걱정했던 "짧은 발화 단위로 쪼개야 하는" 제약을 피할 수 있다. 사용자가
//  천천히, 멈칫거리며 말해도 끊기지 않는다 — 막힌 얘기를 할 때 그렇게 말하게 된다.
//
//  전사는 기기 안에서 끝나고, 오디오는 어디에도 저장하지 않는다.
//

import AVFoundation
import Foundation
import Speech

@MainActor
@Observable
final class SpeechCapture {

    enum Phase: Equatable {
        case idle
        /// 모델을 내려받거나 준비하는 중.
        case preparing
        case listening
        case finishing
        /// 마이크나 인식 권한이 없다. 텍스트로만 진행한다.
        case unavailable(String)
    }

    private(set) var phase: Phase = .idle

    /// 확정된 문장. 사용자가 말을 마치면 이게 답이 된다.
    private(set) var finalizedText: String = ""
    /// 아직 확정되지 않은, 실시간으로 흔들리는 부분.
    private(set) var volatileText: String = ""

    /// 0 ~ 1. 낮으면 재요청 대신 패러프레이즈 재확인으로 넘긴다 (§7).
    private(set) var confidence: Double?

    /// 이 값 아래면 정리해서 되묻는다.
    static let confidenceFloor: Double = 0.62

    var displayText: String {
        volatileText.isEmpty ? finalizedText
            : (finalizedText.isEmpty ? volatileText : finalizedText + " " + volatileText)
    }

    var isListening: Bool { phase == .listening }

    /// 되물어야 하는 상태인지. 인식이 흐릿할 때만 true.
    var needsConfirmation: Bool {
        guard let confidence else { return false }
        return confidence < Self.confidenceFloor && !finalizedText.isEmpty
    }

    // MARK: 내부

    // 받아쓰기는 사용자가 실제로 말하는 언어를 따른다.
    // 기기 언어와 지역을 그대로 넘기면(예: 중국어 + 미국 지역) 인식 모델이 없다고 실패한다.
    // 그래서 기기 언어 순서대로 받아쓰기가 아는 가장 가까운 말을 고른다.
    private var locale = Locale.current

    private static func spokenLocale() async -> Locale? {
        let candidates = Locale.preferredLanguages.map(Locale.init(identifier:)) + [Locale.current]
        for candidate in candidates {
            if let supported = await SpeechTranscriber.supportedLocale(equivalentTo: candidate) {
                return supported
            }
        }
        return nil
    }
    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    /// `analyzer` 를 실제로 켰는가(`start(inputSequence:)` 가 끝났는가). 켜지 않은 분석기에
    /// '끝까지 확정하고 마치기' 를 부르면 돌아오지 않을 수 있어, 그때는 바로 취소한다.
    private var analyzerStarted = false
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var analyzerFormat: AVAudioFormat?
    /// 듣기를 한 번 시작할 때마다 오르는 번호. 준비(모델 받기 · 분석기 켜기)는 뒤에서 오래 걸릴 수
    /// 있어서, 그사이 사용자가 멈추거나 다시 시작하면 늦게 끝난 옛 준비가 마이크를 켜면 안 된다.
    /// 번호가 달라졌으면 그 준비는 아무것도 하지 않고 물러난다.
    private var generation = 0
    /// 마이크 버스에 탭을 걸어 두었는가. 걸지 않았을 때는 입력 노드를 건드리지 않는다.
    private var hasTap = false
    private var confidenceSamples: [Double] = []

    // MARK: - 시작 / 정지

    func start() async {
        guard phase == .idle || isFailed else { return }
        reset()
        generation += 1
        // 이 시작의 번호. 아래에서 기다리는 사이(권한 창 · 언어 고르기 · 세션 열기) 사용자가 멈추거나
        // 화면을 닫으면 번호가 오른다. 그러면 깨어난 뒤에 마이크를 켜지 않고 물러난다 — 안 그러면
        // 화면이 사라진 뒤에 마이크가 켜지고, 세션이 녹음용으로 남아 조약돌 목소리가 조용해진다.
        let session = generation
        // 지난번이 어긋난 채 끝났으면 탭 · 엔진이 남아 있을 수 있다. 깨끗이 하고 시작한다.
        tearDownAudio()
        phase = .preparing

        let allowed = await requestPermission()
        guard generation == session else { return }
        guard allowed else {
            // 권한이 없어도 대화는 계속된다. 텍스트 입력이 늘 열려 있다.
            phase = .unavailable(String(localized: "마이크를 쓸 수 없어요. 적어주셔도 괜찮아요."))
            return
        }

        do {
            try await beginSession(session)
            guard generation == session else { return }
            phase = .listening
        } catch {
            guard generation == session else { return }
            await fail()
        }
    }

    /// 듣기를 열다가 어긋났다. 마이크 · 분석기 · 세션을 모두 놓고 텍스트로만 간다.
    ///
    /// 세션을 녹음용으로 붙잡은 채 두면 조약돌 목소리가 계속 비켜서 있게 된다.
    private func fail() async {
        generation += 1
        tearDownAudio()
        inputContinuation?.finish()
        inputContinuation = nil
        resultsTask?.cancel()
        resultsTask = nil
        // 켠 분석기를 그냥 놓으면 모델을 쥔 채 남는다. 확정할 말은 없으니 바로 끝낸다.
        if analyzerStarted { await analyzer?.cancelAndFinishNow() }
        analyzerStarted = false
        analyzer = nil
        transcriber = nil
        if AudioSessionQueue.isRecording {
            try? await AudioSessionQueue.close()
            AudioSessionQueue.isRecording = false
        }
        phase = .unavailable(String(localized: "지금은 듣기가 어려워요. 적어주셔도 괜찮아요."))
    }

    /// 탭을 걷고 엔진을 세운다. 여러 번 불러도 되고, 탭이 없어도 된다.
    ///
    /// AVFAudio 는 어긋나면 NSException 을 던진다. 받아쓰기는 곁들이는 기능이라 잡아서 넘긴다
    /// (→ ObjCGuard).
    private func tearDownAudio() {
        guard hasTap || audioEngine.isRunning else { return }
        hasTap = false
        // 둘을 따로 감싼다. 한 블록이면 탭 걷기가 어긋났을 때 엔진 세우기를 건너뛰어 마이크가 켜진 채 남는다.
        try? ObjCGuard.perform { self.audioEngine.inputNode.removeTap(onBus: 0) }
        try? ObjCGuard.perform { self.audioEngine.stop() }
    }

    /// 듣기를 멈추고 남은 말을 확정한다.
    func stop() async {
        guard phase == .listening || phase == .preparing else { return }
        phase = .finishing
        // 아직 준비 중이던 것이 있으면 늦게 끝나도 마이크를 켜지 못하게 한다.
        generation += 1

        tearDownAudio()
        inputContinuation?.finish()
        inputContinuation = nil

        if analyzerStarted {
            try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        } else {
            // 준비 중에 멈췄다 — 분석기는 아직 켜지지 않았다. 켜지 않은 분석기에 확정을 부르면
            // 돌아오지 않아 `.finishing` 에 갇힐 수 있다. 확정할 말도 없으니 바로 끝낸다.
            await analyzer?.cancelAndFinishNow()
        }
        analyzerStarted = false
        resultsTask?.cancel()
        resultsTask = nil
        analyzer = nil
        transcriber = nil

        // 확정되지 않은 꼬리도 버리지 않는다. 사용자가 말한 건 말한 것이다.
        if !volatileText.isEmpty {
            finalizedText = displayText
            volatileText = ""
        }
        finalizedText = finalizedText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 메인 스레드에서 끄지 않는다. 조약돌 목소리가 켜 둔 세션이 살아 있을 수 있다.
        try? await AudioSessionQueue.close()
        AudioSessionQueue.isRecording = false
        phase = .idle
    }

    func reset() {
        finalizedText = ""
        volatileText = ""
        confidence = nil
        confidenceSamples = []
    }

    private var isFailed: Bool {
        if case .unavailable = phase { return true }
        return false
    }

    // MARK: - 권한

    private func requestPermission() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speech else { return false }

        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - 세션

    private func beginSession(_ session: Int) async throws {
        guard let spoken = await Self.spokenLocale() else { throw CaptureError.unsupportedLanguage }
        guard generation == session else { throw CancellationError() }
        locale = spoken
        AudioSessionQueue.isRecording = true
        do {
            try await AudioSessionQueue.openForRecording()
        } catch {
            AudioSessionQueue.isRecording = false
            throw error
        }
        // 세션을 여는 사이 멈췄다. 방금 연 녹음용 세션을 도로 닫고 물러난다.
        guard generation == session else {
            try? await AudioSessionQueue.close()
            AudioSessionQueue.isRecording = false
            throw CancellationError()
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            // volatileResults — 말하는 동안 화면에 글이 따라 나온다. 사용자가 자기 말이
            // 잡히고 있다는 걸 눈으로 확인할 수 있어야 불안하지 않다.
            reportingOptions: [.volatileResults],
            attributeOptions: [.transcriptionConfidence]
        )
        self.transcriber = transcriber

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        analyzerStarted = false

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = continuation

        resultsTask = Task { [weak self] in
            await self?.consume(transcriber)
        }

        let session = generation
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.prepareAssets(for: transcriber)
                guard self.generation == session else { return }
                self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
                    compatibleWith: [transcriber]
                )
                guard self.generation == session else { return }
                try await analyzer.start(inputSequence: stream)
                // 준비하는 사이 사용자가 멈췄거나 다시 시작했다. 여기서 마이크를 켜면 화면은
                // 멈춘 줄 아는데 탭이 걸린 채 남고, 다음에 시작할 때 같은 버스에 탭을 또 걸다가
                // 예외로 앱이 죽는다. 멈추기는 이 분석기가 안 켜진 줄 알고 지나갔으니 여기서 끈다.
                guard self.generation == session else {
                    await analyzer.cancelAndFinishNow()
                    return
                }
                self.analyzerStarted = true
                try self.startTap()
            } catch {
                guard self.generation == session else { return }
                await self.fail()
            }
        }
    }

    /// 한국어 인식 모델이 없으면 내려받는다. 최초 1회만 걸린다.
    private func prepareAssets(for transcriber: SpeechTranscriber) async throws {
        if await AssetInventory.status(forModules: [transcriber]) != .installed,
           let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        try await AssetInventory.reserve(locale: locale)
    }

    private func startTap() throws {
        // 입력 노드를 처음 읽는 것부터 감싼다 — 마이크가 없거나 형식이 무효면 여기서도 예외가 난다.
        var node: AVAudioInputNode?
        var hasInput = false
        try ObjCGuard.perform {
            let found = self.audioEngine.inputNode
            let format = found.outputFormat(forBus: 0)
            hasInput = format.sampleRate > 0 && format.channelCount > 0
            node = found
        }
        guard hasInput, let input = node else { throw CaptureError.noInput }
        guard let continuation = inputContinuation else { return }

        let block = Self.tapBlock(target: analyzerFormat, continuation: continuation)
        try ObjCGuard.perform {
            // 같은 버스에 탭이 둘이면 예외다. 남은 것이 있을 수 있으니 먼저 걷는다.
            input.removeTap(onBus: 0)
            // 형식은 넘기지 않는다(nil = 버스의 지금 형식). 앞에서 읽어 둔 형식을 넘기면, 그사이
            // 블루투스 이어폰이 통화 모드로 바뀌는 등 하드웨어 형식이 달라졌을 때 "형식이
            // 하드웨어와 다르다" 는 예외로 죽는다. 변환은 블록이 받은 버퍼의 실제 형식으로 한다.
            input.installTap(onBus: 0, bufferSize: 4_096, format: nil, block: block)
            self.audioEngine.prepare()
        }
        hasTap = true
        // 엔진 켜기는 Swift 오류도 던지고 예외도 던진다. 둘 다 받는다.
        var startError: Error?
        do {
            try ObjCGuard.perform {
                do { try self.audioEngine.start() } catch { startError = error }
            }
        } catch {
            startError = error
        }
        if let startError {
            tearDownAudio()
            throw startError
        }
    }

    /// 마이크가 버퍼를 건넬 때마다 부르는 블록. **오디오 스레드에서 돈다.**
    ///
    /// 그래서 이 블록은 메인 액터의 상태를 하나도 읽지 않는다. 필요한 것(목표 포맷 · 넘길 곳)은
    /// 탭을 걸 때 미리 받아 쥐고 들어간다.
    ///
    /// 예전에는 블록 안에서 `MainActor.assumeIsolated` 로 `converter` 를 읽었다.
    /// 오디오 스레드는 메인이 아니라서 그 자리에서 앱이 멈췄다(2.1.4 크래시 —
    /// AVFAudio 콜백 → `convert(_:)` → `assumeIsolated`). 메서드 안에서 만든 클로저는
    /// 메인 액터에 묶일 수 있으니, 블록은 격리 없는 정적 함수에서 만든다.
    nonisolated private static func tapBlock(
        target: AVAudioFormat?,
        continuation: AsyncStream<AnalyzerInput>.Continuation
    ) -> AVAudioNodeTapBlock {
        let bridge = TapBridge(target: target)
        return { buffer, _ in
            guard let prepared = bridge.convert(buffer) else { return }
            continuation.yield(AnalyzerInput(buffer: prepared))
        }
    }

    /// 마이크 포맷을 분석기가 받는 포맷으로 맞춘다. 오디오 스레드에서만 쓴다(탭 블록 하나가 쥔다).
    ///
    /// 변환기는 **들어온 버퍼의 형식**으로 만든다. 듣는 도중 마이크가 바뀌면(이어폰을 꽂거나 뺌)
    /// 형식도 바뀌는데, 처음 형식으로 만든 변환기에 다른 형식의 버퍼를 넣으면 한 조각도 못 건진다.
    private final class TapBridge: @unchecked Sendable {
        private let target: AVAudioFormat?
        private var converter: AVAudioConverter?
        private var source: AVAudioFormat?

        init(target: AVAudioFormat?) { self.target = target }

        func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
            guard let target, buffer.format != target else {
                return buffer   // 변환이 필요 없는 경우
            }
            guard buffer.format.sampleRate > 0, buffer.frameLength > 0 else { return nil }
            if converter == nil || source != buffer.format {
                converter = AVAudioConverter(from: buffer.format, to: target)
                source = buffer.format
            }
            guard let converter else { return nil }

            let ratio = target.sampleRate / buffer.format.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1_024
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }

            var consumed = false
            var error: NSError?
            converter.convert(to: output, error: &error) { _, status in
                if consumed {
                    status.pointee = .noDataNow
                    return nil
                }
                consumed = true
                status.pointee = .haveData
                return buffer
            }
            return error == nil && output.frameLength > 0 ? output : nil
        }
    }

    // MARK: - 결과

    private func consume(_ transcriber: SpeechTranscriber) async {
        do {
            for try await result in transcriber.results {
                let text = String(result.text.characters)

                if result.isFinal {
                    finalizedText = finalizedText.isEmpty
                        ? text
                        : finalizedText + " " + text
                    volatileText = ""
                    absorbConfidence(from: result.text)
                } else {
                    volatileText = text
                }
            }
        } catch {
            // 스트림이 끊겨도 지금까지 들은 말은 남는다.
            volatileText = ""
        }
    }

    /// 구간별 신뢰도를 평균 낸다. 낮으면 §7의 재확인 흐름으로 넘어간다.
    private func absorbConfidence(from text: AttributedString) {
        let values = text.runs.compactMap { $0.transcriptionConfidence }
        guard !values.isEmpty else { return }
        confidenceSamples.append(contentsOf: values)
        confidence = confidenceSamples.reduce(0, +) / Double(confidenceSamples.count)
    }

    enum CaptureError: Error {
        case noInput
        case unsupportedLanguage
    }
}
