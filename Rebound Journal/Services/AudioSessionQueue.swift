//
//  AudioSessionQueue.swift
//  Rebound Journal
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

    /// 세션 작업을 전용 큐에서 실행하고 끝날 때까지 기다린다.
    static func perform(_ work: @escaping @Sendable (AVAudioSession) throws -> Void) async throws {
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
}
