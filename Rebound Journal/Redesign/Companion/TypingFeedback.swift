//
//  TypingFeedback.swift
//  Rebound Journal
//
//  글자가 하나씩 찍힐 때의 소리와 촉감을 한자리에서 낸다.
//
//  타이핑·소리·진동이 따로 놀면 조약돌이 말하는 게 아니라 화면이 글자를 뿌리는
//  것처럼 보인다. 셋을 한 호출로 묶어 어긋날 여지를 없앤다.
//

import Foundation
import UIKit

@MainActor
final class TypingFeedback {

    static let shared = TypingFeedback()

    /// 진동은 소리와 따로 끌 수 있어야 한다. 소리는 껐지만 촉감은 남기고 싶은
    /// 자리(늦은 밤, 조용한 곳)가 이 앱에서는 오히려 흔하다.
    var isHapticEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.hapticKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.hapticKey) }
    }

    private static let hapticKey = "pebble.haptics.enabled"

    /// 진동은 아주 약하게. 글자마다 또렷하게 울리면 알림처럼 느껴져서 말맛이 죽는다.
    private static let intensity: CGFloat = 0.32

    /// 초당 진동 횟수 상한. 이보다 촘촘하면 톡톡이 아니라 지잉으로 뭉개진다.
    private static let maxHapticsPerSecond: Double = 9

    private let generator = UIImpactFeedbackGenerator(style: .soft)
    private var ticksSinceHaptic = 0
    private var hapticEvery = 1

    private init() {}

    // MARK: - 한 문장

    /// 타이핑 시작 직전에 부른다.
    func begin(step: Double) {
        // 글자 간격이 촘촘할수록 진동은 더 띄엄띄엄 준다.
        hapticEvery = max(1, Int((1 / Self.maxHapticsPerSecond / max(step, 0.001)).rounded(.up)))
        ticksSinceHaptic = 0
        if isHapticEnabled { generator.prepare() }
    }

    /// 글자 하나가 나타날 때마다 부른다.
    func tick(_ character: Character, progress: Double, step: Double) {
        PebbleVoice.shared.blip(for: character, progress: progress, step: step)

        guard isHapticEnabled, character.isSoundable else { return }

        ticksSinceHaptic += 1
        guard ticksSinceHaptic >= hapticEvery else { return }
        ticksSinceHaptic = 0

        generator.impactOccurred(intensity: Self.intensity)
        // 다음 톡을 위해 미리 깨워 둔다. 준비 없이 부르면 첫 진동이 늦게 온다.
        generator.prepare()
    }

    /// 문장이 끝났거나 사용자가 건너뛰었을 때.
    func end() {
        PebbleVoice.shared.stop()
        ticksSinceHaptic = 0
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
