//
//  AudioSessionQueue.swift
//  Mochimo
//
//  오디오 세션을 만지는 일은 전부 여기 한 줄로 세운다.
//
//  `AVAudioSession`의 `setCategory`·`setActive`는 메인 스레드에서 부르면 화면이
//  멈칫할 수 있다 (세션이 켜져 있을 때 특히). 그리고 이 앱에서는 세션을 만지는
//  곳이 둘이다 — 조약돌 목소리(`PebbleVoice`, 재생)와 받아쓰기(`SpeechCapture`, 녹음).
//  둘이 각자 다른 스레드에서 만지면 서로의 설정을 덮어쓴다. 그래서 전용 직렬 큐
//  하나에서 차례로 처리한다.
//

import AVFoundation

enum AudioSessionQueue {

    private static let queue = DispatchQueue(label: "pebble.audio.session", qos: .userInitiated)

    /// 받아쓰기 중인지. 이때는 조약돌 목소리가 세션을 재생용으로 되돌리지 않는다 —
    /// 되돌리면 듣고 있던 마이크가 끊긴다.
    @MainActor static var isRecording = false

    // 맥에는 오디오 세션이 없다. 앱마다 소리가 그대로 섞이고 마이크도 따로 열 필요가 없다.
    // 그래서 아래 세 가지는 맥에서 아무 일도 하지 않고, 재생 준비는 늘 된 것으로 본다.

    /// 받아쓰기용으로 연다. 듣던 소리는 줄이고 스피커로 낸다.
    static func openForRecording() async throws {
        #if os(iOS)
        try await perform { session in
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        }
        #endif
    }

    /// 조약돌 목소리용으로 연다.
    ///
    /// .playback — 무음 스위치를 켜 두어도 들린다. .ambient 로 두면 무음 모드에서 아무 소리도
    /// 나지 않는데, 대부분 무음으로 두고 쓰니 이 기능이 있는 줄도 모르게 된다. 소리를 끄는
    /// 스위치는 설정 안에 따로 있다. .mixWithOthers 로 듣던 음악은 끊지 않는다.
    static func openForPlayback() async throws {
        #if os(iOS)
        try await perform { session in
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        }
        #endif
    }

    /// 닫는다. 다른 앱 소리가 원래대로 돌아오게 알린다.
    static func close() async throws {
        #if os(iOS)
        try await perform { try $0.setActive(false, options: .notifyOthersOnDeactivation) }
        #endif
    }

    /// 지금 세션이 재생용인지. 받아쓰기 뒤에 녹음용으로 남아 있으면 소리를 내면 안 된다.
    static var isOpenForPlayback: Bool {
        #if os(iOS)
        AVAudioSession.sharedInstance().category == .playback
        #else
        true
        #endif
    }

    #if os(iOS)
    /// 세션 작업을 전용 큐에서 실행하고 끝날 때까지 기다린다.
    private static func perform(_ work: @escaping @Sendable (AVAudioSession) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try work(AVAudioSession.sharedInstance())
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    #endif
}
