//
//  ModernSpeechEngine.swift
//  Mochimo
//
//  iOS 26부터의 받아쓰기 — SpeechAnalyzer.
//
//  SFSpeechRecognizer의 세션당 1분 제한이 없어서, 사용자가 천천히, 멈칫거리며 말해도
//  끊기지 않는다 — 막힌 얘기를 할 때 그렇게 말하게 된다.
//

import AVFoundation
import Foundation
import Speech

@available(iOS 26.0, macOS 26.0, *)
@MainActor
final class ModernSpeechEngine: SpeechEngine {

    private let locale: Locale
    private let report: (SpeechEvent) -> Void
    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var converter: AVAudioConverter?
    private var analyzerFormat: AVAudioFormat?


    /// 이 기기 언어 가운데 받아쓰기가 아는 말이 없으면 nil.
    init?(report: @escaping (SpeechEvent) -> Void) async {
        guard let locale = await Self.spokenLocale() else { return nil }
        self.locale = locale
        self.report = report
    }

    // 받아쓰기는 사용자가 실제로 말하는 언어를 따른다.
    // 기기 언어와 지역을 그대로 넘기면(예: 중국어 + 미국 지역) 인식 모델이 없다고 실패한다.
    // 그래서 기기 언어 순서대로 받아쓰기가 아는 가장 가까운 말을 고른다.
    private static func spokenLocale() async -> Locale? {
        let candidates = Locale.preferredLanguages.map(Locale.init(identifier:)) + [Locale.current]
        for candidate in candidates {
            if let supported = await SpeechTranscriber.supportedLocale(equivalentTo: candidate) {
                return supported
            }
        }
        return nil
    }

    func begin() async throws {
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
                self.report(.failed)
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
        guard inputFormat.sampleRate > 0 else { throw SpeechEngineError.noInput }

        if let analyzerFormat, analyzerFormat != inputFormat {
            converter = AVAudioConverter(from: inputFormat, to: analyzerFormat)
        }

        guard let continuation = inputContinuation else { return }
        input.installTap(
            onBus: 0,
            bufferSize: 4_096,
            format: inputFormat,
            block: Self.tapBlock(converter: converter, target: analyzerFormat, continuation: continuation)
        )

        audioEngine.prepare()
        try audioEngine.start()
    }

    /// 마이크가 버퍼를 건넬 때마다 부르는 블록. **오디오 스레드에서 돈다.**
    ///
    /// 그래서 이 블록은 메인 액터의 상태를 하나도 읽지 않는다. 필요한 것(변환기 ·
    /// 목표 포맷 · 넘길 곳)은 탭을 걸 때 미리 받아 쥐고 들어간다.
    ///
    /// 예전에는 블록 안에서 `MainActor.assumeIsolated` 로 `converter` 를 읽었다.
    /// 오디오 스레드는 메인이 아니라서 그 자리에서 앱이 멈췄다(2.1.4 크래시 —
    /// AVFAudio 콜백 → `convert(_:)` → `assumeIsolated`). 메서드 안에서 만든 클로저는
    /// 메인 액터에 묶일 수 있으니, 블록은 격리 없는 정적 함수에서 만든다.
    nonisolated private static func tapBlock(
        converter: AVAudioConverter?,
        target: AVAudioFormat?,
        continuation: AsyncStream<AnalyzerInput>.Continuation
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard let prepared = convert(buffer, with: converter, to: target) else { return }
            continuation.yield(AnalyzerInput(buffer: prepared))
        }
    }

    /// 마이크 포맷을 분석기가 받는 포맷으로 맞춘다.
    nonisolated private static func convert(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter?,
        to target: AVAudioFormat?
    ) -> AVAudioPCMBuffer? {
        guard let converter, let target else {
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

    func finish() async {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        inputContinuation?.finish()
        inputContinuation = nil

        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        resultsTask?.cancel()
        resultsTask = nil
        analyzer = nil
        transcriber = nil
    }

    // MARK: - 결과

    private func consume(_ transcriber: SpeechTranscriber) async {
        do {
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                if result.isFinal {
                    report(.finalized(text, confidences: result.text.runs.compactMap { $0.transcriptionConfidence }))
                } else {
                    report(.volatile(text))
                }
            }
        } catch {
            // 스트림이 끊겨도 지금까지 들은 말은 남는다.
            report(.volatile(""))
        }
    }
}
