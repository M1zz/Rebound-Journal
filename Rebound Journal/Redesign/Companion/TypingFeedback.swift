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

    /// 사용자 말풍선이 올라올 때의 세기. 한 번뿐이라 조금 또렷하게 준다.
    private static let tapIntensity: Float = 0.75

    /// 초당 진동 횟수 상한. 이보다 촘촘하면 톡톡이 아니라 지잉으로 뭉개진다.
    private static let maxHapticsPerSecond: Double = 14

    private var engine: CHHapticEngine?
    private var tickPlayer: CHHapticPatternPlayer?
    private var tapPlayer: CHHapticPatternPlayer?
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
        play(.typing)
    }

    /// 문장이 끝났거나 사용자가 건너뛰었을 때.
    func end() {
        PebbleVoice.shared.stop()
        ticksSinceHaptic = 0
    }

    // MARK: - 사용자 말풍선

    /// 사용자가 답해서 자기 말풍선이 올라올 때.
    ///
    /// 조약돌 말풍선은 글자마다 톡톡 오지만 사용자 말풍선은 한 번에 나타난다.
    /// 여기에 아무 촉감이 없으면 대화의 한쪽만 손에 닿는 느낌이 든다.
    /// 여러 번이 아니라 한 번, 대신 조금 또렷하게.
    func tap() {
        guard isHapticEnabled else { return }

        guard supportsHaptics else {
            fallback.impactOccurred(intensity: CGFloat(Self.tapIntensity))
            fallback.prepare()
            return
        }

        prepareEngine()
        play(.bubble)
    }

    // MARK: - CoreHaptics

    /// 촉감의 종류. 되살릴 때 어느 패턴을 다시 만들어야 하는지 알아야 한다.
    private enum Feel {
        case typing   // 글자마다 톡톡
        case bubble   // 말풍선 하나가 올라올 때 한 번
    }

    private func player(for feel: Feel) -> CHHapticPatternPlayer? {
        switch feel {
        case .typing: tickPlayer
        case .bubble: tapPlayer
        }
    }

    private func prepareEngine() {
        if let engine {
            // 백그라운드에 다녀오거나 녹음으로 오디오 세션이 바뀌면 엔진이 멈춘다.
            try? engine.start()
            // 엔진이 한 번 멈추면 플레이어도 무효가 된다. 여기서 다시 만들지 않으면
            // 엔진만 살아나고 플레이어는 nil로 남아, 이후 모든 말풍선에서 진동이
            // 조용히 사라진다. 첫 문장만 진동이 오던 원인이 이것이었다.
            if tickPlayer == nil || tapPlayer == nil { rebuildPlayers() }
            return
        }

        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            // 문장 사이 잠깐의 공백에 엔진이 꺼지면 첫 톡이 늦게 온다.
            engine.isAutoShutdownEnabled = false

            // 시스템이 엔진을 리셋하거나 멈추면 플레이어가 무효가 된다.
            // 둘 다 nil로 두고, 다음 촉감 요청에서 새로 만든다.
            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.tickPlayer = nil
                    self.tapPlayer = nil
                    try? self.engine?.start()
                    self.rebuildPlayers()
                }
            }
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in
                    self?.tickPlayer = nil
                    self?.tapPlayer = nil
                }
            }

            try engine.start()
            self.engine = engine
            rebuildPlayers()
        } catch {
            // 촉감은 부가적인 요소다. 실패해도 대화는 그대로 진행되어야 한다.
            engine = nil
            tickPlayer = nil
            tapPlayer = nil
        }
    }

    /// 톡 하나짜리 패턴들. 매번 새로 만들지 않고 다시 돌려 쓴다.
    private func rebuildPlayers() {
        tickPlayer = makePlayer(intensity: Self.intensity)
        tapPlayer = makePlayer(intensity: Self.tapIntensity)
    }

    private func makePlayer(intensity: Float) -> CHHapticPatternPlayer? {
        guard let engine else { return nil }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: Self.sharpness)
            ],
            relativeTime: 0
        )
        return try? engine.makePlayer(with: CHHapticPattern(events: [event], parameters: []))
    }

    private func play(_ feel: Feel) {
        if player(for: feel) == nil { prepareEngine() }
        guard let ready = player(for: feel) else { return }

        do {
            try ready.start(atTime: CHHapticTimeImmediate)
        } catch {
            // 엔진이 죽어 있었다. 되살리고 이번 촉감을 바로 다시 시도한다.
            // 다음 글자로 미루면 실패한 진동 하나가 그대로 사라진다.
            try? engine?.start()
            rebuildPlayers()
            try? player(for: feel)?.start(atTime: CHHapticTimeImmediate)
        }
    }

    private func shutdown() {
        tickPlayer = nil
        tapPlayer = nil
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
