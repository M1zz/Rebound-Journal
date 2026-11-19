//
//  SpeechCapture.swift
//  Mochimo
//
//  음성 입력 (설계 고찰 §7, §8).
//
//  여기는 화면이 보는 상태(듣는 중 · 들린 글 · 신뢰도)만 쥔다. 실제로 듣는 일은
//  엔진이 한다 — iOS 26부터는 SpeechAnalyzer(`ModernSpeechEngine`), 그 아래는
//  SFSpeechRecognizer(`LegacySpeechEngine`). 화면은 어느 쪽인지 모른다.
//
//  어느 엔진이든 전사는 기기 안에서 끝나고, 오디오는 어디에도 저장하지 않는다.
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

    private var engine: (any SpeechEngine)?
    private var confidenceSamples: [Double] = []

    // MARK: - 시작 / 정지

    func start() async {
        guard phase == .idle || isFailed else { return }
        reset()
        phase = .preparing

        guard await requestPermission() else {
            // 권한이 없어도 대화는 계속된다. 텍스트 입력이 늘 열려 있다.
            phase = .unavailable(String(localized: "마이크를 쓸 수 없어요. 적어주셔도 괜찮아요."))
            return
        }

        do {
            try await beginSession()
            phase = .listening
        } catch {
            // 세션을 녹음용으로 연 뒤에 실패했을 수 있다. 붙잡고 있으면 조약돌 목소리가
            // 계속 비켜서 있게 되므로 놓아 준다.
            if AudioSessionQueue.isRecording {
                try? await AudioSessionQueue.close()
                AudioSessionQueue.isRecording = false
            }
            phase = .unavailable(String(localized: "지금은 듣기가 어려워요. 적어주셔도 괜찮아요."))
        }
    }

    /// 듣기를 멈추고 남은 말을 확정한다.
    func stop() async {
        guard phase == .listening || phase == .preparing else { return }
        phase = .finishing

        await engine?.finish()
        engine = nil

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

    private func beginSession() async throws {
        guard let engine = await makeEngine() else { throw SpeechEngineError.unsupportedLanguage }
        AudioSessionQueue.isRecording = true
        do {
            try await AudioSessionQueue.openForRecording()
        } catch {
            AudioSessionQueue.isRecording = false
            throw error
        }
        self.engine = engine
        try await engine.begin()
    }

    private func makeEngine() async -> (any SpeechEngine)? {
        let report: (SpeechEvent) -> Void = { [weak self] in self?.apply($0) }
        if #available(iOS 26.0, macOS 26.0, *) {
            return await ModernSpeechEngine(report: report)
        }
        return LegacySpeechEngine(report: report)
    }

    // MARK: - 결과

    private func apply(_ event: SpeechEvent) {
        switch event {
        case .volatile(let text):
            volatileText = text
        case .finalized(let text, let confidences):
            if !text.isEmpty {
                finalizedText = finalizedText.isEmpty ? text : finalizedText + " " + text
            }
            volatileText = ""
            absorb(confidences)
        case .failed:
            phase = .unavailable(String(localized: "지금은 듣기가 어려워요. 적어주셔도 괜찮아요."))
        }
    }

    /// 구간별 신뢰도를 평균 낸다. 낮으면 §7의 재확인 흐름으로 넘어간다.
    private func absorb(_ values: [Double]) {
        guard !values.isEmpty else { return }
        confidenceSamples.append(contentsOf: values)
        confidence = confidenceSamples.reduce(0, +) / Double(confidenceSamples.count)
    }
}

// MARK: - 엔진

/// 엔진이 들은 것을 알리는 말.
enum SpeechEvent {
    /// 아직 흔들리는 글. 다음 알림이 이것을 통째로 바꾼다.
    case volatile(String)
    /// 확정된 한 토막. 앞서 확정된 글 뒤에 붙는다.
    case finalized(String, confidences: [Double])
    /// 듣기를 시작한 뒤에 실패했다.
    case failed
}

/// 마이크를 열고 들은 말을 글로 알린다. 오디오 세션은 `SpeechCapture`가 열고 닫는다.
@MainActor
protocol SpeechEngine: AnyObject {
    func begin() async throws
    /// 마이크를 닫고 남은 말을 마저 알린 뒤 돌아온다.
    func finish() async
}

enum SpeechEngineError: Error {
    case noInput
    case unsupportedLanguage
}
