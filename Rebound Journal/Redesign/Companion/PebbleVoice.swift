//
//  PebbleVoice.swift
//  Rebound Journal
//
//  조약돌의 목소리. 설계 고찰 §9의 Animalese 방식.
//
//  동물의 숲의 동물어는 사전 녹음이 아니라 **음성을 잘라 변조해 빠르게 잇는** 것이다.
//  그대로 따른다.
//
//   1. 앱이 시작할 때 아주 짧은 음절 몇 개를 TTS로 합성해 둔다.
//   2. 앞뒤 무음을 잘라내고 알갱이로 만든다.
//   3. 글자가 화면에 찍힐 때마다 알갱이 하나를, 그 글자에서 뽑은 피치로 재생한다.
//
//  사인파를 합성하면 "삐" 하는 전자음이 되지 목소리가 되지 않는다. 사람 음성에서
//  출발해야 목소리의 결이 남고, 잘게 잘라 피치를 올려 빠르게 흘리면 무슨 말인지
//  알아들을 수 없게 되어 "실제 목소리를 흉내내지 않는다"는 §9의 이점도 지켜진다.
//
//  TTS를 쓸 수 없는 자리를 대비해 톤 합성을 폴백으로 남겨 뒀다. 소리가 아예 없는
//  것보다는 낫다.
//

import AVFoundation
import Foundation

@MainActor
final class PebbleVoice {

    static let shared = PebbleVoice()

    /// 사용자가 소리를 끌 수 있어야 한다. 켜고 끄는 건 설정 화면에 있다.
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

    /// TTS에서 잘라낸 소리 알갱이들. 글자마다 하나씩 골라 쓴다.
    private var grains: [AVAudioPCMBuffer] = []
    private var isRendering = false

    /// TTS를 못 쓸 때의 폴백(톤 합성) 캐시.
    private var toneCache: [String: AVAudioPCMBuffer] = [:]

    private init() {}

    // MARK: - 준비

    /// 앱이 뜰 때 한 번 부른다. 첫 말풍선이 찍히기 전에 알갱이를 만들어 두기 위해서다.
    func prepare() {
        guard grains.isEmpty, !isRendering else { return }
        isRendering = true
        Task { [weak self] in
            let rendered = await Self.renderGrains()
            guard let self else { return }
            self.grains = rendered
            self.isRendering = false
        }
    }

    // MARK: - 재생

    /// 글자 하나가 화면에 나타나는 순간 부른다.
    ///
    /// - Parameters:
    ///   - character: 방금 찍힌 글자. 공백·구두점이면 소리를 내지 않는다.
    ///   - progress: 문장에서의 위치(0...1). 끝으로 갈수록 음을 살짝 낮춘다.
    ///   - step: 글자 사이 간격(초).
    func blip(for character: Character, progress: Double, step: Double) {
        guard isEnabled else { return }
        guard let tone = Self.tone(for: character, progress: progress) else { return }

        do {
            try wireIfNeeded()
        } catch {
            // 소리는 부가적인 요소다. 실패해도 대화는 그대로 진행되어야 한다.
            return
        }

        // 글자마다 피치를 흔든다. Animalese의 "랜덤 피치 조절"에 해당한다.
        pitchUnit.pitch = Float(tone.cents)

        let buffer: AVAudioPCMBuffer?
        if grains.isEmpty {
            buffer = toneBuffer(frequency: tone.frequency, duration: min(0.034, step * 0.85))
        } else {
            buffer = grains[tone.index % grains.count]
        }
        guard let buffer else { return }

        if !player.isPlaying { player.play() }
        // 앞 알갱이를 자르지 않고 이어 붙인다. 겹쳐 울리는 게 오히려 수다스럽게 들린다.
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

        // .playback — 무음 스위치를 켜 두어도 들린다.
        //
        // .ambient로 두면 무음 모드에서 아무 소리도 나지 않는다. 대부분 무음으로
        // 두고 쓰는데 그러면 이 기능이 있는 줄도 모르게 된다. 소리를 끄는 스위치는
        // 설정 안에 따로 있으니, 그쪽을 진짜 스위치로 삼는다.
        // .mixWithOthers를 함께 줘서 듣던 음악은 끊지 않는다.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true, options: [])

        engine.attach(player)
        engine.attach(pitchUnit)
        // 잘게 자른 음절을 빠르게 흘려보낸다. 느리면 말이 되어 버려서 §9의
        // "무슨 말인지 알아들을 수 없는 소리"가 되지 않는다.
        pitchUnit.rate = 1.9
        engine.connect(player, to: pitchUnit, format: format)
        engine.connect(pitchUnit, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()
        isWired = true
    }

    // MARK: - 글자에서 소리 고르기

    private struct Tone {
        /// 어느 알갱이를 쓸지.
        let index: Int
        /// 피치를 얼마나 올릴지(cents).
        let cents: Double
        /// 폴백 톤의 주파수.
        let frequency: Double
    }

    private static func tone(for character: Character, progress: Double) -> Tone? {
        guard let scalar = character.unicodeScalars.first else { return nil }

        // 공백과 구두점에서는 쉰다. 쉼 없이 이어지면 말이 아니라 기계음이 된다.
        guard !CharacterSet.whitespacesAndNewlines.contains(scalar),
              !CharacterSet.punctuationCharacters.contains(scalar) else { return nil }

        // 한글은 초성을 기준으로 삼는다(§9의 PyAnimalese 참고 방식).
        // 같은 초성이면 같은 소리가 나므로 말투에 일관성이 생긴다.
        let seed: Int
        if (0xAC00...0xD7A3).contains(scalar.value) {
            seed = Int(scalar.value - 0xAC00) / 588      // 초성 0..18
        } else {
            seed = Int(scalar.value)
        }

        // 문장 끝으로 갈수록 살짝 내려가 말이 마무리되는 느낌을 준다.
        let decline = 220 * progress
        let spread = Double(seed % 7) * 55 - 165
        let scale: [Double] = [392, 440, 494, 523, 587, 659, 698]

        return Tone(
            index: seed,
            cents: 780 + spread - decline,
            frequency: scale[seed % scale.count] * (1 - 0.10 * progress)
        )
    }

    // MARK: - TTS 알갱이 만들기

    /// 짧은 음절 몇 개를 합성해 앞뒤 무음을 잘라낸다.
    ///
    /// 글자마다 그때그때 합성하면 초당 열 번 넘게 부르게 되어 따라오지 못한다.
    /// 미리 몇 개만 만들어 두고 피치만 바꿔 돌려 쓴다.
    private nonisolated static func renderGrains() async -> [AVAudioPCMBuffer] {
        let seeds = ["다", "리", "무", "제", "고", "야", "너"]
        let target = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

        // 합성기를 루프 밖에서 붙잡는다.
        //
        // 지역 변수로 두면 write()를 부르자마자 함수가 끝나면서 합성기가 풀려,
        // 콜백이 영영 오지 않는다. 그러면 알갱이가 하나도 안 만들어진 채
        // 조용히 폴백 톤만 나간다.
        let synthesizer = AVSpeechSynthesizer()

        var grains: [AVAudioPCMBuffer] = []
        for seed in seeds {
            guard let raw = await synthesize(seed, using: synthesizer, target: target) else { continue }
            guard let grain = trim(raw) else { continue }
            grains.append(grain)
        }
        return grains
    }

    private nonisolated static func synthesize(
        _ text: String,
        using synthesizer: AVSpeechSynthesizer,
        target: AVAudioFormat
    ) async -> AVAudioPCMBuffer? {
        await withCheckedContinuation { continuation in
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate

            var chunks: [AVAudioPCMBuffer] = []
            var converter: AVAudioConverter?
            var finished = false

            synthesizer.write(utterance) { buffer in
                guard !finished else { return }
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }

                if pcm.frameLength == 0 {
                    // 빈 버퍼가 끝을 알린다.
                    finished = true
                    continuation.resume(returning: join(chunks, format: target))
                    return
                }

                // write()는 보통 Int16 PCM을 준다. float으로 바꿔 두지 않으면
                // floatChannelData가 nil이라 한 조각도 못 쌓는다.
                if converter == nil, pcm.format != target {
                    converter = AVAudioConverter(from: pcm.format, to: target)
                }
                if let converted = convert(pcm, using: converter, to: target) {
                    chunks.append(converted)
                }
            }
        }
    }

    private nonisolated static func join(
        _ chunks: [AVAudioPCMBuffer],
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let frames = chunks.reduce(AVAudioFrameCount(0)) { $0 + $1.frameLength }
        guard frames > 0,
              let joined = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let destination = joined.floatChannelData else { return nil }

        var offset = 0
        for chunk in chunks {
            guard let source = chunk.floatChannelData else { continue }
            destination[0].advanced(by: offset).update(from: source[0], count: Int(chunk.frameLength))
            offset += Int(chunk.frameLength)
        }
        joined.frameLength = AVAudioFrameCount(offset)
        return offset > 0 ? joined : nil
    }

    private nonisolated static func convert(
        _ buffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter?,
        to target: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        guard let converter else {
            // 이미 같은 형식이면 그대로 복사만 한다.
            guard buffer.format == target,
                  let copy = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: buffer.frameLength),
                  let source = buffer.floatChannelData,
                  let destination = copy.floatChannelData else { return nil }
            copy.frameLength = buffer.frameLength
            destination[0].update(from: source[0], count: Int(buffer.frameLength))
            return copy
        }

        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 2_048
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }

        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                // .endOfStream을 주면 컨버터가 스트림이 끝났다고 보고, 같은 컨버터로
                // 넘기는 이후 조각을 전부 버린다. 음절 하나가 몇 밀리초로 줄어든
                // 원인이 이것이었다. 지금은 더 줄 게 없다는 뜻만 전한다.
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil && output.frameLength > 0 ? output : nil
    }

    /// 앞뒤 무음을 걷어내고 가장 소리가 큰 자리에서 짧게 잘라낸다.
    ///
    /// 통째로 쓰면 "다"라고 또렷하게 들려서 말이 되어 버린다. 알아들을 수 없을 만큼
    /// 짧아야 §9가 말한 "실제 목소리를 흉내내지 않는" 상태가 된다.
    private nonisolated static func trim(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let samples = buffer.floatChannelData?[0] else { return nil }
        let total = Int(buffer.frameLength)
        guard total > 0 else { return nil }

        let threshold: Float = 0.02
        var start = 0
        while start < total, abs(samples[start]) < threshold { start += 1 }
        guard start < total else { return nil }

        let length = min(Int(0.055 * buffer.format.sampleRate), total - start)
        guard length > 64 else { return nil }

        guard let grain = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: AVAudioFrameCount(length)
        ), let destination = grain.floatChannelData else { return nil }
        grain.frameLength = AVAudioFrameCount(length)

        // 양 끝을 부드럽게 깎는다. 자른 자리를 그대로 두면 딱딱한 클릭음이 남는다.
        let fade = max(1, length / 6)
        for index in 0..<length {
            var gain: Float = 1
            if index < fade { gain = Float(index) / Float(fade) }
            if index > length - fade { gain = Float(length - index) / Float(fade) }
            destination[0][index] = samples[start + index] * gain * 0.9
        }
        return grain
    }

    // MARK: - 폴백 (톤 합성)

    private func toneBuffer(frequency: Double, duration: Double) -> AVAudioPCMBuffer? {
        let key = "\(Int(frequency))-\(Int(duration * 1000))"
        if let cached = toneCache[key] { return cached }

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
            let envelope = min(progress / 0.18, 1) * pow(1 - progress, 1.6)

            var sample = sin(2 * .pi * frequency * t)
            sample += 0.34 * sin(2 * .pi * frequency * 2 * t)
            sample += 0.12 * sin(2 * .pi * frequency * 3 * t)

            channel[n] = Float(sample * envelope * 0.16)
        }

        toneCache[key] = buffer
        return buffer
    }
}
