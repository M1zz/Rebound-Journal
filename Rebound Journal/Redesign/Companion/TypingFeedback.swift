//
//  TypingFeedback.swift
//  Rebound Journal
//
//  글자가 하나씩 찍힐 때의 소리와 촉감을 한자리에서 낸다.
//
//  타이핑·소리·진동이 따로 놀면 조약돌이 말하는 게 아니라 화면이 글자를 뿌리는
//  것처럼 보인다. 셋을 한 호출로 묶어 어긋날 여지를 없앤다.
//
//  촉감은 CoreHaptics로 낸다. `UIImpactFeedbackGenerator`로는 세기만 조절할 수
//  있고 날카로움(sharpness)을 못 건드려서, 타건감이 아니라 뭉근한 울림이 된다.
//  키보드를 치는 느낌은 짧고 또렷해야 나온다.
//
//  주의: 시뮬레이터에는 햅틱 하드웨어가 없어 아무 진동도 나지 않는다.
//  촉감 확인은 반드시 실기기에서 해야 한다.
//

import CoreHaptics
import Foundation
import UIKit

@MainActor
final class TypingFeedback {

    static let shared = TypingFeedback()

    /// 진동은 소리와 따로 끌 수 있어야 한다. 소리는 껐지만 촉감은 남기고 싶은
    /// 자리(늦은 밤, 조용한 곳)가 이 앱에서는 오히려 흔하다.
    var isHapticEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.hapticKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.hapticKey)
            if !newValue { shutdown() }
        }
    }

    private static let hapticKey = "pebble.haptics.enabled"

    /// 한 번의 톡. 손끝에 닿되 알림처럼 도드라지지는 않는 세기.
    private static let intensity: Float = 0.55
    /// 날카로움. 높을수록 짧고 또렷해 타건감에 가까워진다.
    private static let sharpness: Float = 0.85

    /// 초당 진동 횟수 상한. 이보다 촘촘하면 톡톡이 아니라 지잉으로 뭉개진다.
    private static let maxHapticsPerSecond: Double = 14

    private var engine: CHHapticEngine?
    private var tickPlayer: CHHapticPatternPlayer?
    private var ticksSinceHaptic = 0
    private var hapticEvery = 1

    /// CoreHaptics를 못 쓰는 자리(하드웨어 없음)에서의 대비책.
    private let fallback = UIImpactFeedbackGenerator(style: .rigid)

    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    private init() {}

    // MARK: - 한 문장

    /// 타이핑 시작 직전에 부른다.
    func begin(step: Double) {
        // 글자 간격이 촘촘할수록 진동은 더 띄엄띄엄 준다.
        hapticEvery = max(1, Int((1 / Self.maxHapticsPerSecond / max(step, 0.001)).rounded(.up)))
        ticksSinceHaptic = 0

        guard isHapticEnabled else { return }
        if supportsHaptics {
            prepareEngine()
        } else {
            fallback.prepare()
        }
    }

    /// 글자 하나가 나타날 때마다 부른다.
    func tick(_ character: Character, progress: Double, step: Double) {
        PebbleVoice.shared.blip(for: character, progress: progress, step: step)

        guard isHapticEnabled, character.isSoundable else { return }

        ticksSinceHaptic += 1
        guard ticksSinceHaptic >= hapticEvery else { return }
        ticksSinceHaptic = 0

        guard supportsHaptics else {
            fallback.impactOccurred(intensity: CGFloat(Self.intensity))
            fallback.prepare()
            return
        }
        playTick()
    }

    /// 문장이 끝났거나 사용자가 건너뛰었을 때.
    func end() {
        PebbleVoice.shared.stop()
        ticksSinceHaptic = 0
    }

    // MARK: - CoreHaptics

    private func prepareEngine() {
        if let engine {
            // 백그라운드에 다녀오면 엔진이 멈춰 있을 수 있다.
            try? engine.start()
            return
        }

        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            // 문장 사이 잠깐의 공백에 엔진이 꺼지면 첫 톡이 늦게 온다.
            engine.isAutoShutdownEnabled = false

            // 시스템이 엔진을 리셋하면 플레이어도 무효가 된다. 둘 다 다시 만든다.
            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.tickPlayer = nil
                    try? self.engine?.start()
                    self.tickPlayer = self.makeTickPlayer()
                }
            }
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in
                    self?.tickPlayer = nil
                }
            }

            try engine.start()
            self.engine = engine
            self.tickPlayer = makeTickPlayer()
        } catch {
            // 촉감은 부가적인 요소다. 실패해도 대화는 그대로 진행되어야 한다.
            engine = nil
            tickPlayer = nil
        }
    }

    /// 톡 하나짜리 패턴. 매번 새로 만들지 않고 다시 돌려 쓴다.
    private func makeTickPlayer() -> CHHapticPatternPlayer? {
        guard let engine else { return nil }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: Self.intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: Self.sharpness)
            ],
            relativeTime: 0
        )
        return try? engine.makePlayer(with: CHHapticPattern(events: [event], parameters: []))
    }

    private func playTick() {
        if tickPlayer == nil {
            prepareEngine()
        }
        do {
            try tickPlayer?.start(atTime: CHHapticTimeImmediate)
        } catch {
            // 엔진이 죽었으면 한 번만 되살리고 다음 글자에서 다시 시도한다.
            tickPlayer = nil
            try? engine?.start()
            tickPlayer = makeTickPlayer()
        }
    }

    private func shutdown() {
        tickPlayer = nil
        engine?.stop()
        engine = nil
    }
}

private extension Character {
    /// 공백과 구두점에서는 촉감도 쉰다. 소리가 쉬는 자리와 같아야 어긋나 보이지 않는다.
    var isSoundable: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return !CharacterSet.whitespacesAndNewlines.contains(scalar)
            && !CharacterSet.punctuationCharacters.contains(scalar)
    }
}
