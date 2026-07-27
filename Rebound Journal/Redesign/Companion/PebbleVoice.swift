//
//  PebbleVoice.swift
//  Rebound Journal
//
//  조약돌의 목소리. 설계 고찰 §9의 Animalese 방식을 따른다.
//
//  실제 사람 목소리를 흉내내지 않는 것이 핵심이다(§9 이점). 그래서 TTS로 문장을
//  읽는 대신, 글자마다 아주 짧은 소리 알갱이를 만들어 빠르게 이어 붙인다.
//  "기계 같다"는 불쾌한 골짜기 자체가 생기지 않고, 문장은 화면의 텍스트로 읽힌다(§7).
//
//  음높이는 글자에서 결정론적으로 뽑으므로, 같은 문장은 언제나 같은 소리로 들린다.
//

import AVFoundation
import Foundation

@MainActor
final class PebbleVoice {

    static let shared = PebbleVoice()

    /// 사용자가 소리를 끌 수 있어야 한다. 조용히 곁에 있는 게 기본값이므로 켜 두되,
    /// 무음 스위치를 존중하는 세션 카테고리를 쓴다.
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    private static let enabledKey = "pebble.voice.enabled"

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let pitchUnit = AVAudioUnitTimePitch()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var isWired = false

    private init() {}

    // MARK: - 재생

    /// 문장을 조약돌 소리로 재생한다. 글자 수가 많아도 재생 길이는 제한된다.
    func speak(_ text: String) {
        guard isEnabled else { return }
        let blips = Self.blipPitches(for: text)
        guard !blips.isEmpty else { return }

        do {
            try wireIfNeeded()
            guard let buffer = makeBuffer(pitches: blips) else { return }
            if !player.isPlaying { player.play() }
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        } catch {
            // 소리는 부가적인 요소다. 실패해도 대화는 그대로 진행되어야 한다.
            return
        }
    }

    func stop() {
        guard isWired else { return }
        player.stop()
    }

    /// 문장 길이에 비례하는 대략적인 재생 시간. 입 모양 애니메이션을 맞추는 데 쓴다.
    func estimatedDuration(of text: String) -> Double {
        Double(Self.blipPitches(for: text).count) * Self.blipStride
    }

    // MARK: - 엔진

    private func wireIfNeeded() throws {
        guard !isWired else {
            if !engine.isRunning { try engine.start() }
            return
        }

        // .ambient — 음악을 끊지 않고, 무음 스위치를 따른다.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true, options: [])

        engine.attach(player)
        engine.attach(pitchUnit)
        // 작고 둥근 존재감을 위해 전체를 한 옥타브 가까이 올린다(§9).
        pitchUnit.pitch = 700
        engine.connect(player, to: pitchUnit, format: format)
        engine.connect(pitchUnit, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()
        isWired = true
    }

    // MARK: - 합성

    /// 소리 알갱이 하나의 간격(초). 말이 빠르게 굴러가도록 짧게 잡는다.
    private static let blipStride: Double = 0.062
    private static let blipLength: Double = 0.052
    /// 한 문장이 아무리 길어도 이만큼만 소리 낸다. 텍스트가 본문이고 소리는 신호일 뿐이다.
    private static let maxBlips = 28

    private func makeBuffer(pitches: [Double]) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let total = Double(pitches.count) * Self.blipStride + 0.08
        let frames = AVAudioFrameCount(total * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames

        for i in 0..<Int(frames) { channel[i] = 0 }

        for (index, frequency) in pitches.enumerated() {
            let start = Int(Double(index) * Self.blipStride * sampleRate)
            let length = Int(Self.blipLength * sampleRate)

            for n in 0..<length {
                let position = start + n
                guard position < Int(frames) else { break }
                let t = Double(n) / sampleRate
                let progress = Double(n) / Double(length)

                // 빠르게 붙고 부드럽게 사라지는 포락선 — 딱딱한 클릭음을 없앤다.
                let attack = min(progress / 0.14, 1)
                let release = pow(1 - progress, 1.7)
                let envelope = attack * release

                // 기본음 + 약한 배음. 배음을 조금 섞어야 "삐" 소리가 아니라 목소리처럼 들린다.
                var sample = sin(2 * .pi * frequency * t)
                sample += 0.34 * sin(2 * .pi * frequency * 2 * t)
                sample += 0.12 * sin(2 * .pi * frequency * 3 * t)
                // 살짝 흔들어 기계적인 정확함을 지운다.
                sample *= 1 + 0.06 * sin(2 * .pi * 18 * t)

                channel[position] += Float(sample * envelope * 0.16)
            }
        }
        return buffer
    }

    /// 글자에서 음높이를 뽑는다.
    ///
    /// 한글은 초성을 기준으로 삼는다(§9의 PyAnimalese 참고 방식). 같은 초성이면 같은
    /// 음이 나므로 말투에 일관성이 생기고, 문장의 억양은 위치에 따라 완만하게 흐른다.
    private static func blipPitches(for text: String) -> [Double] {
        let audible = text.unicodeScalars.filter { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar)
                && !CharacterSet.punctuationCharacters.contains(scalar)
        }
        guard !audible.isEmpty else { return [] }

        let scale: [Double] = [392, 440, 494, 523, 587, 659, 698]   // G4 믹솔리디안 — 밝지만 들뜨지 않는다
        let clipped = audible.prefix(maxBlips)

        return clipped.enumerated().map { index, scalar in
            let degree: Int
            if (0xAC00...0xD7A3).contains(scalar.value) {
                let choseong = Int(scalar.value - 0xAC00) / 588      // 초성 0..18
                degree = choseong % scale.count
            } else {
                degree = Int(scalar.value) % scale.count
            }

            // 문장 끝으로 갈수록 살짝 내려가 말이 마무리되는 느낌을 준다.
            let decline = 1 - 0.10 * (Double(index) / Double(max(clipped.count - 1, 1)))
            return scale[degree] * decline
        }
    }
}
