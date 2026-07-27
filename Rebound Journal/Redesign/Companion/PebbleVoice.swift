//
//  PebbleVoice.swift
//  Rebound Journal
//
//  조약돌의 목소리. 설계 고찰 §9의 Animalese 방식을 따른다.
//
//  실제 사람 목소리를 흉내내지 않는 것이 핵심이다(§9 이점). 문장을 읽어주는 대신,
//  글자가 화면에 찍히는 그 순간마다 아주 짧은 소리 알갱이를 하나씩 낸다.
//  "기계 같다"는 불쾌한 골짜기가 생길 여지 자체가 없고, 문장은 눈으로 읽는다(§7).
//
//  문장 전체를 미리 만들어 두지 않고 글자마다 실시간으로 내보내는 이유는,
//  타이핑 속도가 문장 길이에 따라 달라지기 때문이다. 미리 만들면 긴 문장에서
//  소리와 글자가 조금씩 어긋난다.
//
//  음높이는 글자에서 결정론적으로 뽑으므로, 같은 문장은 언제나 같은 소리로 들린다.
//

import AVFoundation
import Foundation

@MainActor
final class PebbleVoice {

    static let shared = PebbleVoice()

    /// 사용자가 소리를 끌 수 있어야 한다. 조용히 곁에 있는 게 기본이므로 켜 두되,
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

    /// 같은 음·길이의 알갱이는 다시 만들지 않는다. 초당 20번 넘게 부르는 자리라
    /// 매번 새로 합성할 이유가 없다.
    private var cache: [String: AVAudioPCMBuffer] = [:]

    private init() {}

    // MARK: - 재생

    /// 글자 하나가 화면에 나타나는 순간 부른다.
    ///
    /// - Parameters:
    ///   - character: 방금 찍힌 글자. 공백·구두점이면 소리를 내지 않는다.
    ///   - progress: 문장에서의 위치(0...1). 끝으로 갈수록 음을 살짝 낮춰 말이
    ///     마무리되는 느낌을 준다.
    ///   - step: 글자 사이 간격(초). 알갱이 길이를 이보다 짧게 잡아야 소리가
    ///     밀리지 않는다.
    func blip(for character: Character, progress: Double, step: Double) {
        guard isEnabled else { return }
        guard let frequency = Self.frequency(for: character, progress: progress) else { return }

        do {
            try wireIfNeeded()
        } catch {
            // 소리는 부가적인 요소다. 실패해도 대화는 그대로 진행되어야 한다.
            return
        }

        let duration = min(Self.maxBlipLength, step * 0.85)
        guard let buffer = blipBuffer(frequency: frequency, duration: duration) else { return }

        if !player.isPlaying { player.play() }
        // 앞 알갱이를 자르지 않고 이어 붙인다. 알갱이가 간격보다 짧으므로 밀리지 않는다.
        player.scheduleBuffer(buffer, at: nil, options: [])
    }

    func stop() {
        guard isWired else { return }
        player.stop()
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

    /// 알갱이 하나의 최대 길이. 이보다 길면 "토도도독"이 아니라 "삐-"가 된다.
    private static let maxBlipLength: Double = 0.034

    private func blipBuffer(frequency: Double, duration: Double) -> AVAudioPCMBuffer? {
        let key = "\(Int(frequency))-\(Int(duration * 1000))"
        if let cached = cache[key] { return cached }

        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(duration * sampleRate)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames

        let count = Int(frames)
        for n in 0..<count {
            let t = Double(n) / sampleRate
            let progress = Double(n) / Double(count)

            // 빠르게 붙고 부드럽게 사라지는 포락선 — 딱딱한 클릭음을 없앤다.
            let attack = min(progress / 0.18, 1)
            let release = pow(1 - progress, 1.6)
            let envelope = attack * release

            // 기본음 + 약한 배음. 배음이 섞여야 "삐" 소리가 아니라 목소리처럼 들린다.
            var sample = sin(2 * .pi * frequency * t)
            sample += 0.34 * sin(2 * .pi * frequency * 2 * t)
            sample += 0.12 * sin(2 * .pi * frequency * 3 * t)

            channel[n] = Float(sample * envelope * 0.16)
        }

        cache[key] = buffer
        return buffer
    }

    /// 글자에서 음높이를 뽑는다. 소리를 내지 않을 글자면 nil.
    ///
    /// 한글은 초성을 기준으로 삼는다(§9의 PyAnimalese 참고 방식). 같은 초성이면 같은
    /// 음이 나므로 말투에 일관성이 생긴다.
    private static func frequency(for character: Character, progress: Double) -> Double? {
        guard let scalar = character.unicodeScalars.first else { return nil }

        // 공백과 구두점에서는 쉰다. 쉼 없이 이어지면 말이 아니라 기계음이 된다.
        guard !CharacterSet.whitespacesAndNewlines.contains(scalar),
              !CharacterSet.punctuationCharacters.contains(scalar) else { return nil }

        let scale: [Double] = [392, 440, 494, 523, 587, 659, 698]   // G4 믹솔리디안 — 밝지만 들뜨지 않는다

        let degree: Int
        if (0xAC00...0xD7A3).contains(scalar.value) {
            let choseong = Int(scalar.value - 0xAC00) / 588      // 초성 0..18
            degree = choseong % scale.count
        } else {
            degree = Int(scalar.value) % scale.count
        }

        // 문장 끝으로 갈수록 살짝 내려가 말이 마무리되는 느낌을 준다.
        return scale[degree] * (1 - 0.10 * progress)
    }
}
