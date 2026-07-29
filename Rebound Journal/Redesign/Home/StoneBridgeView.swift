//
//  StoneBridgeView.swift
//  Rebound Journal
//
//  한 주를 징검다리로 그린다.
//
//  돌을 일직선에 늘어놓지 않고 위아래로 조금씩 어긋나게 둔다. 줄을 맞추면
//  달력 격자가 되고, 격자는 빈칸을 만들고, 빈칸은 못 지킨 날처럼 읽힌다.
//  어긋나게 놓아야 개울을 건너는 돌로 보인다.
//
//  밟지 않은 돌도 그 자리에 그대로 있다. 흐리게 그릴 뿐 지우지 않는다.
//

import SwiftUI

struct StoneBridgeView: View {

    let days: [StoneDay]
    let title: String
    let canGoForward: Bool
    var onPrevious: () -> Void
    var onNext: () -> Void
    var onSelect: (StoneDay) -> Void
    let selected: Date?

    private let stoneWidth: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ZStack {
                stream
                stones
            }
            .frame(height: 98)
        }
    }

    // MARK: 머리

    private var header: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(PebbleTheme.label(14))
                .foregroundStyle(PebbleTheme.inkFaint)

            Spacer()

            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PebbleTheme.inkFaint)
                    .frame(width: 28, height: 28)
            }
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(canGoForward ? PebbleTheme.inkFaint : PebbleTheme.hairline)
                    .frame(width: 28, height: 28)
            }
            .disabled(!canGoForward)
        }
        .padding(.horizontal, 4)
    }

    // MARK: 개울

    /// 돌이 놓인 자리. 물빛을 따로 쓰지 않고 바탕보다 한 겹 낮은 면으로만 표현한다.
    /// 파란 물을 넣으면 따뜻한 흙색 팔레트에서 혼자 튄다.
    private var stream: some View {
        // 위아래 밝기 차를 두면 어긋나게 놓인 돌들이 서로 다른 색으로 보인다.
        // 균일하게 깔고 테두리로만 면을 구분한다.
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(PebbleTheme.surfaceMuted.opacity(0.7))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(PebbleTheme.hairline.opacity(0.7), lineWidth: 1)
            }
            .frame(height: 80)
    }

    // MARK: 돌

    private var stones: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                stone(day, index: index)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 6)
    }

    private func stone(_ day: StoneDay, index: Int) -> some View {
        // 홀수 번째 돌을 살짝 내려 어긋나게 놓는다.
        let drop: CGFloat = index.isMultiple(of: 2) ? -6 : 8

        return Button {
            onSelect(day)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if day.state == .reached {
                        // 닿은 날에만 햇빛이 든다. 번지면 옆 돌과 뭉쳐 하나로 보이므로
                        // 돌 크기를 크게 벗어나지 않게 좁혀 둔다.
                        Ellipse()
                            .fill(PebbleTheme.key.opacity(0.22))
                            .frame(width: stoneWidth * 1.15, height: stoneWidth * 0.9)
                            .blur(radius: 4)
                    }

                    PebbleShape()
                        .fill(fill(for: day))
                        .frame(width: stoneWidth, height: stoneWidth * 0.76)
                        .overlay {
                            if day.state == .untouched {
                                // 밟지 않은 돌은 지우지 않고 윤곽만 남긴다.
                                PebbleShape()
                                    .stroke(PebbleTheme.inkFaint.opacity(0.35), lineWidth: 1)
                                    .frame(width: stoneWidth, height: stoneWidth * 0.76)
                            }
                        }

                    if isSelected(day) {
                        PebbleShape()
                            .stroke(PebbleTheme.key, lineWidth: 2)
                            .frame(width: stoneWidth * 1.28, height: stoneWidth * 0.98)
                    }
                }
                .frame(height: stoneWidth)

                Text(day.weekdayLabel)
                    .font(PebbleTheme.label(11))
                    .foregroundStyle(
                        day.isToday ? PebbleTheme.key : PebbleTheme.inkFaint
                    )
            }
            .offset(y: drop)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.accessibilityDescription)
        .accessibilityAddTraits(isSelected(day) ? [.isSelected] : [])
    }

    private func isSelected(_ day: StoneDay) -> Bool {
        guard let selected else { return false }
        return Calendar.current.isDate(selected, inSameDayAs: day.date)
    }

    /// 돌의 색.
    ///
    /// 닿지 못한 날에도 붉은색을 쓰지 않는다. 밝기만 다를 뿐 같은 돌이다 (§4).
    private func fill(for day: StoneDay) -> LinearGradient {
        let colors: [Color] = switch day.state {
        case .reached:
            [PebbleTheme.pebbleLit, PebbleTheme.pebbleMid, PebbleTheme.pebbleShade]
        case .recorded:
            [PebbleTheme.pebbleMid.opacity(0.75), PebbleTheme.pebbleShade.opacity(0.7)]
        case .untouched:
            [PebbleTheme.hairline.opacity(0.5), PebbleTheme.hairline.opacity(0.35)]
        case .ahead:
            [PebbleTheme.hairline.opacity(0.22), PebbleTheme.hairline.opacity(0.16)]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
