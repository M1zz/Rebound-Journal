//
//  SpeechCapture.swift
//  Rebound Journal
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

    private let locale = Locale(identifier: "ko-KR")
    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var converter: AVAudioConverter?
    private var analyzerFormat: AVAudioFormat?
    private var confidenceSamples: [Double] = []

    // MARK: - 시작 / 정지

    func start() async {
        guard phase == .idle || isFailed else { return }
        reset()
        phase = .preparing

        guard await requestPermission() else {
            // 권한이 없어도 대화는 계속된다. 텍스트 입력이 늘 열려 있다.
            phase = .unavailable("마이크를 쓸 수 없어요. 적어주셔도 괜찮아요.")
            return
        }

        do {
            try await beginSession()
            phase = .listening
        } catch {
            phase = .unavailable("지금은 듣기가 어려워요. 적어주셔도 괜찮아요.")
        }
    }

    /// 듣기를 멈추고 남은 말을 확정한다.
    func stop() async {
        guard phase == .listening || phase == .preparing else { return }
        phase = .finishing

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        inputContinuation?.finish()
        inputContinuation = nil

        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
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

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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

    private func beginSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

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

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = continuation

        resultsTask = Task { [weak self] in
            await self?.consume(transcriber)
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.prepareAssets(for: transcriber)
                self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
                    compatibleWith: [transcriber]
                )
                try await analyzer.start(inputSequence: stream)
                try self.startTap()
            } catch {
                self.phase = .unavailable("지금은 듣기가 어려워요. 적어주셔도 괜찮아요.")
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
        let input = audioEngine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else { throw CaptureError.noInput }

        if let analyzerFormat, analyzerFormat != inputFormat {
            converter = AVAudioConverter(from: inputFormat, to: analyzerFormat)
        }

        input.installTap(onBus: 0, bufferSize: 4_096, format: inputFormat) { [weak self] buffer, _ in
            // 오디오 스레드다. 상태를 건드리지 말고 버퍼만 넘긴다.
            guard let self, let continuation = self.inputContinuation else { return }
            guard let prepared = self.convert(buffer) else { return }
            continuation.yield(AnalyzerInput(buffer: prepared))
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    /// 마이크 포맷을 분석기가 받는 포맷으로 맞춘다.
    nonisolated private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter = MainActor.assumeIsolated({ self.converter }),
              let target = MainActor.assumeIsolated({ self.analyzerFormat }) else {
            return buffer   // 변환이 필요 없는 경우
        }

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
    }
}
