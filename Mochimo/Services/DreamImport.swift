//
//  DreamImport.swift
//  Mochimo
//
//  꿈을 찾아서(버킷리스트 앱)에서 옮겨 오기.
//
//  꿈을 찾아서는 모찌모에 합쳐졌다. 그 앱의 마지막 판에 '모찌모로 옮기기' 가 있다. 누르면 두 앱이
//  함께 쓰는 App Group 폴더에 `DreamSeekerTransfer.json` 을 쓰고 모찌모를 연다. 모찌모는 앞으로 올 때
//  이 파일이 있으면 가져올지 묻는다. 모찌모를 아직 안 깔았으면 깐 뒤 처음 열 때 묻게 된다.
//
//  옮기는 모양:
//   - 목표            → 내 삶의 목표 (끝낸 것은 이룬 목표, 그만둔 것은 잠시 내려놓은 목표)
//   - 구체화 답        → 같은 물음의 답. '장애물은?' 의 답은 가로막는 것 하나로
//   - 마친 단계        → 그날의 기록 한 줄
//   - 남은 단계        → 기록 한 줄에 모아 둔다. 돌은 사용자가 다시 고른다 (§6 — 앱이 쪼개 주지 않는다)
//   - 기록 · 사진      → 기록과 사진
//
//  ⚠️ `DreamTransfer` 의 모양은 꿈을 찾아서의 `MochimoTransfer.swift` 와 같아야 한다. 한쪽만 바꾸지 않는다.
//

import SwiftUI
import SwiftData

struct DreamTransfer: Codable, Sendable {
    var version: Int
    var exportedAt: Date
    var goals: [Goal]

    struct Goal: Codable, Sendable {
        var id: String
        var title: String
        var added: Date
        var completed: Date?
        var stopped: Bool
        /// when · who · how · whyNot · value
        var answers: [String: String]
        var obstacles: [String]
        var doneSteps: [Step]
        var openSteps: [String]
        var records: [Record]
    }

    struct Step: Codable, Sendable {
        var title: String
        var date: Date?
    }

    struct Record: Codable, Sendable {
        var date: Date?
        var step: String?
        var text: String
        /// JPEG
        var photos: [Data]
    }
}

@MainActor
enum DreamImport {

    static let appGroup = "group.com.leeo.ReboundJournal"
    static let fileName = "DreamSeekerTransfer.json"

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }

    /// 가져올 파일이 와 있으면 그 내용.
    static func pending() -> DreamTransfer? {
        guard let url = fileURL else { return nil }
        return decode(url)
    }

    /// 같은 것을 **메인 스레드 밖에서** 읽는다. 파일에는 사진이 통째로 들어 있어 수십 MB 일 수
    /// 있는데, 앱이 켜질 때와 앞으로 올 때마다 메인에서 읽고 풀면 그동안 화면이 멈춘다. 켜지는
    /// 도중에 오래 멈추면 시스템이 앱을 끈다(0x8BADF00D). '다음에 할게요' 를 고르면 파일이 남아
    /// 매번 되풀이된다.
    static func pendingInBackground() async -> DreamTransfer? {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return await Task.detached(priority: .userInitiated) { decode(url) }.value
    }

    nonisolated private static func decode(_ url: URL) -> DreamTransfer? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DreamTransfer.self, from: data)
    }

    /// 가져오지 않기로 했거나 다 가져왔으면 파일을 지운다. 다음에 또 묻지 않게.
    static func discard() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// 옮겨 온 목표 수를 돌려준다. 이미 가져온 목표(`importedFrom`)는 건너뛴다 — 두 번 눌러도 겹치지 않는다.
    ///
    /// 디스크에 내리지 못했으면 `nil`. 그때는 **파일을 지우면 안 된다** — 옮겨 온 것은 아직 메모리에만
    /// 있어서, 파일까지 지우면 앱이 꺼질 때 버킷리스트가 통째로 사라진다. 파일을 남겨 두면 다음에
    /// 다시 묻고, 그사이 자동 저장이 됐더라도 `importedFrom` 으로 겹치지 않는다.
    @discardableResult
    static func run(_ transfer: DreamTransfer, into context: ModelContext) -> Int? {
        let already = Set(((try? context.fetch(FetchDescriptor<LifeGoalData>())) ?? []).compactMap(\.importedFrom))
        var count = 0

        for goal in transfer.goals where !already.contains(goal.id) {
            let title = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            let life = LifeGoalData(title: title, date: goal.added)
            life.importedFrom = goal.id
            life.reachedDate = goal.completed
            if goal.completed == nil && goal.stopped { life.restingDate = transfer.exportedAt }
            for question in LifeGoalQuestion.allCases {
                if let answer = goal.answers[question.rawValue] { life.setAnswer(question, answer) }
            }
            context.insert(life)
            guard let lifeID = life.id else { continue }

            for text in goal.obstacles {
                let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty { context.insert(ObstacleData(lifeGoalID: lifeID, text: clean, date: goal.added)) }
            }

            for step in goal.doneSteps {
                note(title, date: step.date ?? goal.added,
                     text: String(localized: "마친 단계: \(step.title)", locale: AppLanguage.locale), in: context)
            }

            for record in goal.records {
                let id = note(title, date: record.date ?? goal.added,
                              text: [record.step, record.text].compactMap { $0 }.filter { !$0.isEmpty }
                                .joined(separator: "\n"),
                              in: context)
                for photo in record.photos {
                    context.insert(RecordPhoto(recordID: id, data: PhotoShrinker.jpeg(photo) ?? photo,
                                               date: record.date ?? goal.added))
                }
            }

            if !goal.openSteps.isEmpty {
                let list = goal.openSteps.map { "· " + $0 }.joined(separator: "\n")
                note(title, date: transfer.exportedAt,
                     text: String(localized: "꿈을 찾아서에 적어 둔 남은 단계", locale: AppLanguage.locale) + "\n" + list,
                     in: context)
            }
            count += 1
        }
        return context.saveNow() ? count : nil
    }

    /// 삶의 목표에 남기는 기록 한 줄. 했다 · 못 했다는 비워 둔다.
    @discardableResult
    private static func note(_ lifeTitle: String, date: Date, text: String, in context: ModelContext) -> String {
        let id = UUID().uuidString
        context.insert(JournalData(
            id: id,
            date: date,
            hasDeleted: false,
            isGoalIn: nil,
            review: text.isEmpty ? nil : text,
            isRebounded: false,
            mainGoal: lifeTitle
        ))
        return id
    }
}

// MARK: - 가져올지 묻는 화면

struct DreamImportSheet: View {
    let transfer: DreamTransfer
    /// 가져온 뒤 '내 목표' 를 열 때.
    var onShowGoals: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var imported: Int?

    var body: some View {
        ZStack {
            PebbleTheme.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 12)
                InteractivePebble(mood: .warm, size: 96)
                    .frame(maxWidth: .infinity)

                Text(message)
                    .font(PebbleTheme.companionFont(20))
                    .foregroundStyle(PebbleTheme.ink)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                if imported == nil {
                    Text(Phrasing.say(
                        "목표는 '내 삶의 목표'로, 장애물 · 기록 · 사진도 함께 와요. 남은 단계는 기록에 모아 둘게요. 그중 무엇을 돌로 놓을지는 같이 골라요.",
                        "목표는 '내 삶의 목표'로, 장애물 · 기록 · 사진도 함께 와. 남은 단계는 기록에 모아 둘게. 그중 무엇을 돌로 놓을지는 같이 고르자."
                    ))
                    .font(PebbleTheme.body(15))
                    .foregroundStyle(PebbleTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if imported == nil {
                    ReplyOptions(choices: [
                        ReplyChoice(id: "import", label: Phrasing.say("옮길게요", "옮길게"), isPrimary: true),
                        ReplyChoice(id: "later", label: Phrasing.say("다음에 할게요", "다음에 할게")),
                        ReplyChoice(id: "no", label: Phrasing.say("안 옮길래요", "안 옮길래"))
                    ]) { choice in
                        switch choice.id {
                        case "import":
                            if let count = DreamImport.run(transfer, into: modelContext) {
                                DreamImport.discard()
                                withAnimation { imported = count }
                            } else {
                                // 저장하지 못했다. 파일은 남겨 두고 닫는다 — 저장 실패는 맨 바깥 화면이
                                // 알리고(→ StoreFallback), 다음에 앱이 앞으로 올 때 다시 묻는다.
                                dismiss()
                            }
                        case "no":
                            DreamImport.discard()
                            dismiss()
                        default:
                            dismiss()
                        }
                    }
                } else {
                    ReplyOptions(choices: [
                        ReplyChoice(id: "goals", label: Phrasing.say("내 삶의 목표 볼게요", "내 삶의 목표 볼게"), isPrimary: true)
                    ]) { _ in
                        dismiss()
                        onShowGoals()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .interactiveDismissDisabled(imported == nil)
    }

    private var message: String {
        if let imported {
            return imported == 0
                ? Phrasing.say("이미 다 옮겨 와 있었어요.", "이미 다 옮겨 와 있었어.")
                : Phrasing.say(
                    String(localized: "목표 \(imported)개를 옮겨 왔어요. 이제 여기서 같이 건너가요.", locale: AppLanguage.locale),
                    String(localized: "목표 \(imported)개를 옮겨 왔어. 이제 여기서 같이 건너가자.", locale: AppLanguage.locale)
                )
        }
        return Phrasing.say(
            String(localized: "꿈을 찾아서에서 목표 \(transfer.goals.count)개가 왔어요. 내 삶의 목표로 옮길까요?", locale: AppLanguage.locale),
            String(localized: "꿈을 찾아서에서 목표 \(transfer.goals.count)개가 왔어. 내 삶의 목표로 옮길까?", locale: AppLanguage.locale)
        )
    }
}
