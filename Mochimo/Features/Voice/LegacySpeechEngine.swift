//
//  LegacySpeechEngine.swift
//  Mochimo
//
//  iOS 18 ~ 25의 받아쓰기 — SFSpeechRecognizer.
//
//  기기 안에서만 받아쓴다(`requiresOnDeviceRecognition`). 서버 인식은 쓰지 않는다 —
//  "말한 것은 기기를 떠나지 않는다"는 약속이 OS 버전에 따라 달라지면 안 된다.
//  기기 안 인식이 없는 언어에서는 엔진을 만들지 않고, 대화는 글로 이어진다.
//  기기 안 인식에는 서버 인식의 1분 제한도 없다.
//
//  말이 한참 끊기면 인식기가 스스로 한 토막을 마무리한다. 그때는 그 토막을 확정하고
//  새 요청으로 이어 듣는다. 마이크는 그대로 열려 있어 사용자는 끊긴 줄 모른다.
//

import AVFoundation
import Foundation
import Speech

@MainActor
final class LegacySpeechEngine: SpeechEngine {

    private let recognizer: SFSpeechRecognizer
    private let report: (SpeechEvent) -> Void
    private let audioEngine = AVAudioEngine()
    private let feed = Feed()
    private var task: SFSpeechRecognitionTask?
    private var isFinishing = false
    /// 지금 토막에서 마지막으로 들린 흔들리는 글과, 토막을 시작한 때.
    private var pending = ""
    private var chunkStart = Date.now
    /// `finish()`가 마지막 토막을 기다리는 자리.
    private var lastWord: CheckedContinuation<Void, Never>?

    /// 이 기기 언어 가운데 기기 안에서 받아쓸 수 있는 말이 없으면 nil.
    init?(report: @escaping (SpeechEvent) -> Void) {
        let candidates = Locale.preferredLanguages.map(Locale.init(identifier:)) + [Locale.current]
        let usable = candidates.lazy
            .compactMap(SFSpeechRecognizer.init(locale:))
            .first { $0.isAvailable && $0.supportsOnDeviceRecognition }
        guard let usable else { return nil }
        recognizer = usable
        self.report = report
    }

    func begin() async throws {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { throw SpeechEngineError.noInput }

        listen()
        input.installTap(onBus: 0, bufferSize: 4_096, format: format, block: Self.tapBlock(feed))
        audioEngine.prepare()
        try audioEngine.start()
    }

    func finish() async {
        isFinishing = true
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        if task != nil {
            feed.request?.endAudio()
            // 남은 말이 확정되기를 기다린다. 인식기가 답하지 않아도 화면을 붙잡지 않는다 —
            // 그때는 `SpeechCapture`가 흔들리던 글을 그대로 답으로 삼는다.
            let timeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                self?.release()
            }
            await withCheckedContinuation { lastWord = $0 }
            timeout.cancel()
        }
        task?.cancel()
        task = nil
        feed.request = nil
    }

    // MARK: - 인식

    private func listen() {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true   // 말하는 동안 화면에 글이 따라 나온다
        request.addsPunctuation = true
        feed.request = request
        pending = ""
        chunkStart = .now

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // 인식기의 큐에서 불린다. 필요한 값만 꺼내 메인으로 넘긴다.
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let confidences = isFinal
                ? (result?.bestTranscription.segments.map { Double($0.confidence) } ?? [])
                : []
            let failed = error != nil
            Task { @MainActor [weak self] in
                self?.heard(text, isFinal: isFinal, confidences: confidences, failed: failed, from: request)
            }
        }
    }

    private func heard(_ text: String?, isFinal: Bool, confidences: [Double], failed: Bool,
                       from request: SFSpeechAudioBufferRecognitionRequest) {
        guard request === feed.request else { return }   // 이미 넘어간 토막의 늦은 알림

        if let text, !isFinal {
            pending = text
            report(.volatile(text))
            return
        }
        guard isFinal || failed else { return }

        // 토막이 끝났다. 확정 없이 오류로 닫혔어도(말이 없었다 등) 들린 데까지는 남긴다.
        report(.finalized(text ?? pending, confidences: confidences))
        task = nil
        if isFinishing {
            release()
        } else if failed, Date.now.timeIntervalSince(chunkStart) < 1 {
            // 열자마자 닫힌다 — 다시 열어도 같다. 맴돌지 않고 글로 넘긴다.
            feed.request = nil
            report(.failed)
        } else {
            listen()   // 이어 듣는다
        }
    }

    private func release() {
        lastWord?.resume()
        lastWord = nil
    }

    // MARK: - 마이크

    /// 오디오 스레드와 메인이 함께 보는, 지금 듣고 있는 요청.
    private final class Feed: @unchecked Sendable {
        private let lock = NSLock()
        private var current: SFSpeechAudioBufferRecognitionRequest?
        var request: SFSpeechAudioBufferRecognitionRequest? {
            get { lock.withLock { current } }
            set { lock.withLock { current = newValue } }
        }
    }

    /// **오디오 스레드에서 돈다.** 메인 액터의 상태를 읽지 않게 격리 없는 정적 함수에서 만든다
    /// (→ `ModernSpeechEngine.tapBlock`).
    nonisolated private static func tapBlock(_ feed: Feed) -> AVAudioNodeTapBlock {
        { buffer, _ in feed.request?.append(buffer) }
    }
}
