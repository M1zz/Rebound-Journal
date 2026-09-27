//
//  PebbleSnapshot.swift
//  Rebound Journal
//
//  앱이 위젯에 건네주는 한 장면. 앱과 위젯 확장이 함께 쓴다.
//
//  ---
//
//  **위젯은 아무것도 판단하지 않는다.** 문장은 전부 앱이 만들어서 여기 적어두고,
//  위젯은 그대로 그리기만 한다.
//
//  이렇게 가른 이유가 몇 개 있다.
//
//   1. 관찰은 조약돌이 한다 (§5-A). 관찰하는 곳이 둘이면 앱과 위젯이 서로 다른
//      말을 하게 되고, 그 순간 조약돌은 하나의 존재가 아니게 된다.
//   2. 말투(존댓말/반말)는 앱의 `UserDefaults`에 있다. 확장은 **다른 저장소**를
//      본다. 위젯이 직접 문장을 고르면 설정과 어긋난 말투가 나간다.
//   3. 기록은 SwiftData에 있고, 그 저장소를 앱 그룹으로 옮기면 이미 쓰고 있는
//      사용자의 데이터를 이사시켜야 한다. 위젯 하나 붙이자고 감수할 위험이 아니다.
//
//  그래서 오가는 건 이 작은 값 하나뿐이다.
//

import Foundation

struct PebbleSnapshot: Codable, Equatable {

    /// 조약돌이 위젯에서 건네는 한 마디.
    var line: String
    /// 누르면 무엇이 되는지. 앱 안의 답풍선과 같은 말투로 쓴다.
    var action: String
    var mood: PebbleMood
    /// 이 장면을 적어둔 때. **지났는지 판단하는 데 쓴다.**
    var updatedAt: Date

    // MARK: - 오가는 곳

    /// 앱과 확장이 같이 보는 저장소.
    ///
    /// 이 식별자는 개발자 계정에도 등록돼 있어야 한다. 없으면 `UserDefaults`가
    /// nil을 돌려주고, 위젯은 아래 `resting`으로 조용히 되돌아간다. 앱이
    /// 멈추지는 않는다.
    static let appGroup = "group.com.leeo.ReboundJournal"
    private static let key = "pebble.widget.snapshot"

    private static var store: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    /// 아직 아무것도 건네받지 못했을 때.
    ///
    /// 빈 화면을 두지 않는다. 위젯을 막 올려놓은 순간에도 조약돌은 거기 있어야 한다.
    static let resting = PebbleSnapshot(
        line: String(localized: "여기 있어요."),
        action: String(localized: "오늘 남기러 가기"),
        mood: .resting,
        updatedAt: .distantPast
    )

    static func save(_ snapshot: PebbleSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        store?.set(data, forKey: key)
    }

    static func load(now: Date = Date(), calendar: Calendar = .current) -> PebbleSnapshot {
        guard let data = store?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(PebbleSnapshot.self, from: data) else {
            return resting
        }
        return snapshot.stillTrue(on: now, calendar: calendar) ? snapshot : snapshot.staleForm
    }

    // MARK: - 오래된 장면

    /// 적어둔 날이 오늘인가.
    ///
    /// 위젯은 앱이 꺼져 있어도 화면에 남아 있다. 어제 적은 "오늘은 아직이네요"가
    /// 오늘 아침에도 그대로 걸려 있으면, 조약돌이 아무렇지 않게 사실이 아닌 말을
    /// 하고 있는 것이 된다. 이 앱에서 그건 단순한 오류가 아니라 신뢰의 문제다.
    func stillTrue(on now: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(updatedAt, inSameDayAs: now)
    }

    /// 날이 바뀌었을 때 물러서는 형태.
    ///
    /// 어제의 관찰을 지우기만 하고 아무 말도 하지 않는다. 모르는 것을 아는 척하지
    /// 않는 게 이 자리에서 할 수 있는 최선이다. 들어오라는 말은 남겨 둔다.
    var staleForm: PebbleSnapshot {
        PebbleSnapshot(
            line: PebbleSnapshot.resting.line,
            action: action,
            mood: .resting,
            updatedAt: updatedAt
        )
    }
}

// MARK: - 위젯을 눌렀을 때

enum PebbleLink {
    /// 위젯에서 앱으로 들어오는 길.
    static let scheme = "pebble"

    /// 오늘 얘기를 남기러 들어온다.
    static let record = URL(string: "\(scheme)://record")!

    static func isRecord(_ url: URL) -> Bool {
        url.scheme == scheme && url.host == "record"
    }
}
