//
//  TodayWidget.swift
//  ReboundWidget
//
//  홈 화면에 놓는 조약돌.
//
//  위젯은 앱을 열게 만드는 물건이라 대개 숫자와 진행률로 채운다. 이 앱에서는
//  그럴 수 없다. 연속 며칠, 몇 퍼센트 같은 표시는 §6이 피하려던 바로 그 압박이고,
//  홈 화면은 하루에 수십 번 스치는 자리라 압박을 놓기엔 최악의 장소다.
//
//  그래서 여기 놓는 건 조약돌 하나와 한 마디뿐이다. 재촉하지 않고 그냥 거기
//  있는 것 — 그게 §10이 말한 "조용히 곁에 있는 존재"의 홈 화면 판이다.
//
//  문장은 전부 앱이 만들어 `PebbleSnapshot`에 적어둔 것을 쓴다. 이유는 그 파일에.
//

import SwiftUI
import WidgetKit

// MARK: - 시간표

struct PebbleEntry: TimelineEntry {
    let date: Date
    let snapshot: PebbleSnapshot
}

struct PebbleProvider: TimelineProvider {

    func placeholder(in context: Context) -> PebbleEntry {
        PebbleEntry(date: Date(), snapshot: .resting)
    }

    func getSnapshot(in context: Context, completion: @escaping (PebbleEntry) -> Void) {
        completion(PebbleEntry(date: Date(), snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PebbleEntry>) -> Void) {
        let now = Date()
        let entry = PebbleEntry(date: now, snapshot: .load(now: now))

        // 자정에 한 번 깨운다.
        //
        // 앱이 기록을 남길 때마다 위젯을 다시 그리게 하지만(`WidgetCenter`), 앱을
        // 며칠 열지 않으면 그 신호가 오지 않는다. 그러면 어제의 관찰이 오늘까지
        // 걸려 있게 된다. 날이 바뀌는 순간 스스로 깨어나 물러설 수 있어야 한다.
        let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(60 * 60 * 24))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

// MARK: - 화면

struct TodayWidgetView: View {

    @Environment(\.widgetFamily) private var family
    let entry: PebbleEntry

    var body: some View {
        switch family {
        case .systemMedium: medium
        case .accessoryRectangular: rectangular
        case .accessoryCircular: circular
        case .accessoryInline: Text(entry.snapshot.action)
        default: small
        }
    }

    private var snapshot: PebbleSnapshot { entry.snapshot }

    // MARK: 홈 화면 — 작은 것

    /// 작은 칸에는 조약돌과 들어오라는 말만 둔다.
    ///
    /// 관찰 문장까지 우겨넣으면 세 줄로 잘려서 무슨 말인지 알 수 없게 되고,
    /// 읽히지 않는 글자는 압박만 남긴다. 넣을 수 없으면 뺀다.
    private var small: some View {
        VStack(spacing: 10) {
            PebbleView(mood: snapshot.mood, size: 60)
            Text(snapshot.action)
                .font(PebbleTheme.label(13))
                .foregroundStyle(PebbleTheme.key)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 홈 화면 — 넓은 것

    private var medium: some View {
        // 조약돌을 조금 줄여 글자 폭을 벌었다. 64로 두면 "3일째"가 숫자와 단위
        // 사이에서 줄바꿈돼 "…는 3 / 일째 조용하네요"로 읽힌다.
        HStack(spacing: 14) {
            PebbleView(mood: snapshot.mood, size: 54)

            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.line)
                    .font(PebbleTheme.companionFont(14))
                    .foregroundStyle(PebbleTheme.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)

                // 앱 안의 답풍선과 같은 모양으로 둔다. 홈 화면에서 누르는 것과
                // 앱에서 누르는 것이 같은 물건으로 보여야 이어진 경험이 된다.
                Text(snapshot.action)
                    .font(PebbleTheme.label(13))
                    .foregroundStyle(PebbleTheme.key)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(PebbleTheme.key.opacity(0.12))
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: 잠금 화면

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.action)
                .font(.system(size: 13, weight: .semibold))
            Text(snapshot.line)
                .font(.system(size: 13))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 잠금 화면 위젯은 시스템이 색을 입힌다. 여기서 팔레트를 우기면
        // 배경에 따라 안 보이는 순간이 생긴다.
        .widgetAccentable()
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            PebbleShape()
                .fill(.primary)
                .frame(width: 26, height: 20)
        }
    }
}

// MARK: - 등록

struct TodayWidget: Widget {

    private let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PebbleProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(PebbleTheme.canvas, for: .widget)
                // 어디를 눌러도 들어온다. 홈 화면에서 정확한 지점을 겨냥하게
                // 만들 이유가 없다.
                .widgetURL(PebbleLink.record)
        }
        .configurationDisplayName("징검돌")
        .description("조약돌이 건네는 한 마디. 눌러서 오늘 얘기를 남길 수 있어요.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}

#Preview(as: .systemMedium) {
    TodayWidget()
} timeline: {
    PebbleEntry(
        date: Date(),
        snapshot: PebbleSnapshot(
            line: "'아침 일찍 일어나기'는 오늘 아직 소식이 없어요.",
            action: "오늘 남기러 가기",
            mood: .resting,
            updatedAt: Date()
        )
    )
}
