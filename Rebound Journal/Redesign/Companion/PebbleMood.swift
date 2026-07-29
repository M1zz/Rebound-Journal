//
//  PebbleMood.swift
//  Rebound Journal
//
//  조약돌의 표정. 설계 고찰 §10에 따라 "판단하지 않는 존재"여야 하므로,
//  실망·걱정처럼 사용자를 평가하는 표정은 의도적으로 두지 않았다.
//  조약돌은 기뻐하거나, 가만히 곁에 있거나, 듣거나, 생각할 뿐이다.
//

import Foundation

/// 원시값을 둔 이유는 위젯 때문이다. 표정을 앱과 위젯 사이로 옮기려면 글로
/// 적을 수 있어야 하고, 그러면 `Codable`이 저절로 따라온다.
enum PebbleMood: String, Equatable, Codable {
    /// 기본. 조용히 곁에 있는 상태.
    case resting
    /// 사용자가 말하는 동안 귀 기울이는 상태.
    case listening
    /// 답을 정리하는 동안. 눈을 살짝 감는다.
    case thinking
    /// 사용자가 무언가 해냈을 때. 유일하게 크게 웃는 표정.
    case warm

    /// 호흡 애니메이션 주기(초). 들을 때 조금 느려져 차분해 보인다.
    var breathPeriod: Double {
        switch self {
        case .resting: 3.6
        case .listening: 4.4
        case .thinking: 2.8
        case .warm: 2.4
        }
    }

    /// 눈 곡선의 휘어짐. 양수면 웃는 눈.
    var eyeCurve: CGFloat {
        switch self {
        case .resting: 0.10
        case .listening: 0.04
        case .thinking: 0.34
        case .warm: 0.42
        }
    }

    /// 입 곡선의 휘어짐.
    var mouthCurve: CGFloat {
        switch self {
        case .resting: 0.30
        case .listening: 0.16
        case .thinking: 0.12
        case .warm: 0.85
        }
    }

    /// 뒤쪽 햇빛 글로우 세기.
    var glow: Double {
        switch self {
        case .resting: 0.30
        case .listening: 0.44
        case .thinking: 0.24
        case .warm: 0.62
        }
    }
}
