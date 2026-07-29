//
//  EditRecordView.swift
//  Rebound Journal
//
//  남긴 기록 하나를 고치는 자리.
//
//  여기서는 조약돌이 말을 걸지 않는다. 대화는 새로 겪은 일을 꺼내는 자리고,
//  여기는 이미 적어둔 것을 손보는 자리다. 고치는데 옆에서 계속 말을 걸면
//  방해가 된다.
//
//  다만 무엇을 고칠 수 있는지는 대화와 같은 순서로 둔다 — 닿았는지, 무슨 일이
//  있었는지, 그때 기분, 다음에 해보기로 한 것. 적을 때와 고칠 때의 칸이 다르면
//  자기가 뭘 썼는지 찾기 어렵다.
//

import SwiftUI
import SwiftData

struct EditRecordView: View {

    @Environment(\.dismiss) private var dismiss

    let record: JournalData

    @State private var reached: Bool = false
    @State private var review: String = ""
    @State private var plan: String = ""
    @State private var emotionValue: Int?
    @State private var emotionWord: String?
    @State private var didLoad = false

    var body: some View {
        ZStack {
            PebbleTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        goalLine
                        reachedSection
                        textSection(
                            title: "무슨 일이 있었나요",
                            placeholder: "짧아도 괜찮아요.",
                            text: $review
                        )
                        emotionSection
                        textSection(
                            title: "다음에 해보기로 한 것",
                            placeholder: Phrasing.say("작을수록 좋아요.", "작을수록 좋아."),
                            text: $plan
                        )
                        Color.clear.frame(height: 16)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)

                ReplyOptions(choices: [
                    ReplyChoice(id: "save", label: Phrasing.say("이렇게 고칠게요", "이렇게 고칠게"), isPrimary: true)
                ]) { _ in
                    save()
                    dismiss()
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
            }
        }
        .onAppear(perform: load)
    }

    // MARK: 머리

    private var header: some View {
        HStack {
            Text("고치기")
                .font(PebbleTheme.title(20))
                .foregroundStyle(PebbleTheme.ink)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PebbleTheme.inkFaint)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, PebbleTheme.sheetHeaderTop)
    }

    /// 어느 목표의 기록인지. 이건 고치지 않는다 — 목표를 바꾸면 다른 기록이 된다.
    private var goalLine: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(when)
                .font(PebbleTheme.label(12))
                .foregroundStyle(PebbleTheme.inkFaint)
            Text(record.subGoalUnwrapped.isEmpty ? "적어둔 목표 없음" : record.subGoalUnwrapped)
                .font(PebbleTheme.body(17))
                .foregroundStyle(PebbleTheme.ink)
        }
    }

    // MARK: 칸들

    private var reachedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("그날 어땠나요")
            HStack(spacing: 8) {
                pick(title: "닿았어요", selected: reached) { reached = true }
                pick(title: "닿지 않았어요", selected: !reached) { reached = false }
            }
        }
    }

    private func textSection(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            label(title)
            SoftCard {
                TextField(placeholder, text: text, axis: .vertical)
                    .font(PebbleTheme.body(16))
                    .foregroundStyle(PebbleTheme.ink)
                    .textFieldStyle(.plain)
                    .lineLimit(2...6)
            }
        }
    }

    private var emotionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("그때 기분")

            // 대화에서 쓰는 것과 같은 눈금·낱말을 쓴다. 다른 어휘를 두면
            // 같은 감정을 두 이름으로 적게 된다.
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(ConversationScript.emotionSteps, id: \.value) { step in
                        chip(step.label, selected: emotionValue == step.value) {
                            emotionValue = (emotionValue == step.value) ? nil : step.value
                            emotionWord = nil
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
            .frame(height: 40)

            if let emotionValue {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(ConversationScript.emotionWords(for: emotionValue).prefix(9), id: \.self) { word in
                            chip(word, selected: emotionWord == word) {
                                emotionWord = (emotionWord == word) ? nil : word
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .scrollIndicators(.hidden)
                .frame(height: 40)
            }
        }
    }

    // MARK: 조각

    private func label(_ text: String) -> some View {
        Text(text)
            .font(PebbleTheme.label(13))
            .foregroundStyle(PebbleTheme.inkFaint)
    }

    private func pick(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PebbleTheme.body(15))
                .foregroundStyle(PebbleTheme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(selected ? PebbleTheme.key.opacity(0.18) : PebbleTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            selected ? PebbleTheme.key : PebbleTheme.hairline,
                            lineWidth: selected ? 1.5 : 1
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PebbleTheme.label(14))
                .foregroundStyle(PebbleTheme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(selected ? PebbleTheme.key.opacity(0.22) : PebbleTheme.surface)
                .clipShape(Capsule())
                .overlay {
                    Capsule().strokeBorder(
                        selected ? PebbleTheme.key : PebbleTheme.hairline,
                        lineWidth: 1
                    )
                }
        }
        .buttonStyle(.plain)
    }

    private var when: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 EEEE"
        return formatter.string(from: record.dateUnwrapped)
    }

    // MARK: 읽고 쓰기

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        reached = record.isGoalInUnwrapped
        review = record.review ?? ""
        plan = record.nextPlan ?? ""
        emotionValue = record.emotionValue
        emotionWord = record.emotionText
    }

    private func save() {
        record.isGoalIn = reached
        record.review = trimmed(review)
        record.nextPlan = trimmed(plan)
        record.emotionValue = emotionValue
        record.emotionText = emotionWord
        // 닿은 기록에는 미해결 표시를 남기지 않는다(기존 스키마 규약).
        record.isResolved = reached ? nil : (record.isResolved ?? false)
    }

    private func trimmed(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }
}
