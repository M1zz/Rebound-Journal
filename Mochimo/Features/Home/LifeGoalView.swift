//
//  LifeGoalView.swift
//  Mochimo
//
//  내 삶의 목표 하나 — 개울 건너편.
//
//  위에서 아래로 한 가지 흐름이다.
//
//   1. 모찌가 묻는 것     막연한 목표를 또렷하게. 한 번에 하나만 묻는다.
//   2. 가로막는 것        건너가지 못하게 하는 것들. 숫자로 재지 않는다.
//   3. 놓은 돌            장애물 하나를 줄이려고 사용자가 스스로 정한 작은 일 (§6).
//                         누르면 조약돌과 그 얘기를 한다 — 여기서부터는 원래의 모찌모다.
//   4. 지나온 기록        이 목표를 향해 남긴 것 전부. 사진도.
//
//  재촉하지 않는다. 몇 % 왔는지, 며칠 지났는지는 보여 주지 않는다 (§4·§6).
//

import SwiftUI
import SwiftData

struct LifeGoalView: View {

    let lifeGoal: LifeGoalData
    /// 놓은 돌을 눌러 조약돌과 이야기하러 갈 때.
    var onTalk: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allObstacles: [ObstacleData]
    @Query private var allStones: [SubGoalData]
    @Query(sort: \JournalData.date, order: .reverse) private var journals: [JournalData]

    @State private var answering: LifeGoalQuestion?
    @State private var skipped: Set<LifeGoalQuestion> = []
    @State private var draft = ""
    @State private var newObstacle = ""
    @State private var placingStone: AddGoalView.Stone?
    @State private var clearing: ObstacleData?
    @State private var clearedNote = ""
    @State private var isWritingNote = false
    @State private var editingRecord: JournalData?
    @State private var isRenaming = false
    @State private var newName = ""
    @State private var confirmReached = false
    @State private var confirmDelete = false
    @FocusState private var focus: Field?

    private enum Field { case answer, obstacle }

    private var id: String { lifeGoal.id ?? "" }
    private var title: String { lifeGoal.titleUnwrapped }

    private var obstacles: [ObstacleData] {
        allObstacles.filter { $0.lifeGoalID == id }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    private var stones: [SubGoalData] {
        allStones.filter { $0.lifeGoalID == id }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    private var records: [JournalData] {
        journals.filter { $0.isValidForDisplay && !title.isEmpty && $0.mainGoal == title }
    }

    /// 지금 물을 것. 고쳐 쓰려고 누른 게 있으면 그것, 아니면 건너뛰지 않은 첫 빈칸.
    private var asking: LifeGoalQuestion? {
        if let answering { return answering }
        guard lifeGoal.isActive else { return nil }
        return LifeGoalQuestion.allCases.first { lifeGoal.answer($0).isEmpty && !skipped.contains($0) }
    }

    var body: some View {
        ZStack {
            PebbleTheme.canvas.ignoresSafeArea()

            // 이 목표가 지워졌으면(여기서 '지우기' · 다른 창 · iCloud 동기화) 읽지 않고 닫는다.
            // 시트가 내려가는 동안에도 화면은 다시 그려지는데, 그때 지워진 모델의 속성을 읽으면
            // 앱이 죽는다 (→ PersistentModel.isGone).
            if lifeGoal.isGone {
                Color.clear.onAppear { dismiss() }
            } else {
            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        titleArea
                        if let asking { questionCard(asking) }
                        answersArea
                        obstaclesArea
                        stonesArea
                        recordsArea
                        if lifeGoal.isActive { reachedButton }
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 6)
                }
                .scrollIndicators(.hidden)
            }
            }
        }
        .presentationDragIndicator(.visible)
        .sheet(item: Binding(
            get: { placingStone.map(StoneSheetItem.init) },
            set: { if $0 == nil { placingStone = nil } }
        )) { item in
            AddGoalView(stone: item.stone)
                .arabicLayout()
        }
        .sheet(isPresented: $isWritingNote) {
            LifeNoteSheet(lifeGoalTitle: title)
                .arabicLayout()
        }
        .sheet(item: $editingRecord.droppingGone()) { record in
            EditRecordView(record: record)
                .arabicLayout()
        }
        .alert(Phrasing.say("어떻게 넘었어요?", "어떻게 넘었어?"), isPresented: Binding(
            get: { clearing != nil },
            set: { if !$0 { clearing = nil } }
        )) {
            TextField(String(localized: "한 줄이면 충분해요"), text: $clearedNote)
            Button(String(localized: "취소"), role: .cancel) { clearing = nil }
            Button(String(localized: "치웠어요")) { commitClear() }
        } message: {
            Text(Phrasing.say("나중에 다시 보면 힘이 돼요.", "나중에 다시 보면 힘이 될 거야."))
        }
        .alert(String(localized: "이름 고치기"), isPresented: $isRenaming) {
            TextField(String(localized: "삶의 목표"), text: $newName)
            Button(String(localized: "취소"), role: .cancel) { }
            Button(String(localized: "고치기")) { commitRename() }
        } message: {
            Text(Phrasing.say(
                "이 목표로 남긴 기록도 새 이름을 따라가요.",
                "이 목표로 남긴 기록도 새 이름을 따라가."
            ))
        }
        .confirmationDialog(
            Phrasing.say("건너갔어요?", "건너갔어?"),
            isPresented: $confirmReached,
            titleVisibility: .visible
        ) {
            Button(Phrasing.say("네, 이뤘어요", "응, 이뤘어")) {
                guard !lifeGoal.isGone else { return }
                withAnimation { lifeGoal.reachedDate = Date() }
                UsageReporting.log(.lifeGoalReached)
            }
            Button(String(localized: "아직이에요"), role: .cancel) { }
        } message: {
            Text(Phrasing.say(
                "이룬 목표는 지나온 길에 남아요. 놓은 돌과 기록도 그대로예요.",
                "이룬 목표는 지나온 길에 남아. 놓은 돌과 기록도 그대로야."
            ))
        }
        .confirmationDialog(
            Phrasing.say("이 삶의 목표를 지울까요?", "이 삶의 목표를 지울까?"),
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button(String(localized: "지우기"), role: .destructive) { deleteLifeGoal() }
            Button(String(localized: "취소"), role: .cancel) { }
        } message: {
            Text(Phrasing.say(
                "가로막는 것 목록은 사라지고, 남긴 기록과 놓은 돌은 그대로 둬요.",
                "가로막는 것 목록은 사라지고, 남긴 기록과 놓은 돌은 그대로 둘게."
            ))
        }
    }

    // MARK: - 머리

    private var header: some View {
        HStack {
            Text("내 삶의 목표")
                .font(PebbleTheme.label(14))
                .foregroundStyle(PebbleTheme.inkFaint)
            Spacer()
            Menu {
                Button {
                    newName = title
                    isRenaming = true
                } label: {
                    Label(String(localized: "이름 고치기"), systemImage: "pencil")
                }
                if lifeGoal.isActive {
                    Button {
                        lifeGoal.restingDate = Date()
                        dismiss()
                    } label: {
                        Label(String(localized: "잠시 내려놓기"), systemImage: "moon.zzz")
                    }
                } else {
                    Button {
                        withAnimation {
                            lifeGoal.restingDate = nil
                            lifeGoal.reachedDate = nil
                        }
                    } label: {
                        Label(String(localized: "다시 꺼내기"), systemImage: "arrow.uturn.backward")
                    }
                }
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label(String(localized: "지우기"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PebbleTheme.inkSoft)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel(Text("더 보기"))
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PebbleTheme.inkFaint)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel(Text("닫기"))
        }
        .padding(.horizontal, 18)
        .padding(.top, PebbleTheme.sheetHeaderTop)
        .padding(.bottom, 4)
    }

    private var titleArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(PebbleTheme.title(26))
                .foregroundStyle(PebbleTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let reached = lifeGoal.reachedDate {
                Label(String(localized: "\(dateText(reached))에 이뤘어요", locale: AppLanguage.locale), systemImage: "sparkles")
                    .font(PebbleTheme.label(13))
                    .foregroundStyle(PebbleTheme.key)
            } else if lifeGoal.isResting {
                Text(Phrasing.say("잠시 내려놓았어요. 언제든 다시 꺼내요.", "잠시 내려놓았어. 언제든 다시 꺼내자."))
                    .font(PebbleTheme.label(13))
                    .foregroundStyle(PebbleTheme.inkFaint)
            }
        }
    }

    // MARK: - 1. 모찌가 묻는 것

    private func questionCard(_ question: LifeGoalQuestion) -> some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    InteractivePebble(mood: .listening, size: 44)
                    Text(question.question)
                        .font(PebbleTheme.companionFont(18))
                        .foregroundStyle(PebbleTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                TextField(Phrasing.say("짧아도 괜찮아요.", "짧아도 괜찮아."), text: $draft, axis: .vertical)
                    .font(PebbleTheme.body(16))
                    .foregroundStyle(PebbleTheme.ink)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($focus, equals: .answer)
                    .padding(12)
                    .background(PebbleTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                ReplyOptions(choices: [
                    ReplyChoice(id: "save", label: Phrasing.say("이렇게 적을게요", "이렇게 적을게"), isPrimary: true),
                    ReplyChoice(id: "skip", label: Phrasing.say("나중에 할게요", "나중에 할게"))
                ]) { choice in
                    if choice.id == "save" && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lifeGoal.setAnswer(question, draft)
                        modelContext.saveNow()
                    } else if choice.id == "skip" {
                        skipped.insert(question)
                    }
                    draft = ""
                    withAnimation(.easeInOut(duration: 0.2)) { answering = nil }
                }
            }
        }
        .id(question)
        .onAppear { draft = lifeGoal.answer(question) }
    }

    @ViewBuilder
    private var answersArea: some View {
        let answered = LifeGoalQuestion.allCases.filter { !lifeGoal.answer($0).isEmpty && $0 != answering }
        if !answered.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(answered) { question in
                    Button {
                        draft = lifeGoal.answer(question)
                        withAnimation(.easeInOut(duration: 0.2)) { answering = question }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(question.label)
                                .font(PebbleTheme.label(12))
                                .foregroundStyle(PebbleTheme.inkFaint)
                            Text(lifeGoal.answer(question))
                                .font(PebbleTheme.body(15))
                                .foregroundStyle(PebbleTheme.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("눌러서 고쳐요"))
                }
            }
        }
    }

    // MARK: - 2. 가로막는 것

    private var obstaclesArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "가로막는 것"))

            if obstacles.isEmpty {
                Text(Phrasing.say(
                    "무엇이 이 목표를 막고 있어요? 돈, 시간, 용기, 함께할 사람… 떠오르는 대로 적어요.",
                    "무엇이 이 목표를 막고 있어? 돈, 시간, 용기, 함께할 사람… 떠오르는 대로 적어 봐."
                ))
                .font(PebbleTheme.body(14))
                .foregroundStyle(PebbleTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(obstacles.filter { !$0.isCleared }, id: \.persistentModelID) { obstacle in
                obstacleRow(obstacle)
            }

            if lifeGoal.isActive {
                HStack(spacing: 10) {
                    TextField(String(localized: "가로막는 것 하나"), text: $newObstacle)
                        .font(PebbleTheme.body(15))
                        .textFieldStyle(.plain)
                        .focused($focus, equals: .obstacle)
                        .submitLabel(.done)
                        .onSubmit(addObstacle)
                    Button(action: addObstacle) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(newObstacle.trimmingCharacters(in: .whitespaces).isEmpty
                                             ? PebbleTheme.hairline : PebbleTheme.key)
                    }
                    .buttonStyle(.plain)
                    .disabled(newObstacle.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel(Text("가로막는 것 더하기"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(PebbleTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(PebbleTheme.hairline, lineWidth: 1)
                }
            }

            let cleared = obstacles.filter(\.isCleared)
            if !cleared.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(cleared, id: \.persistentModelID) { obstacle in
                        clearedRow(obstacle)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func obstacleRow(_ obstacle: ObstacleData) -> some View {
        let stonesHere = stones.filter { $0.obstacleID == obstacle.id }
        return VStack(alignment: .leading, spacing: 10) {
            Text(obstacle.textUnwrapped)
                .font(PebbleTheme.body(16))
                .foregroundStyle(PebbleTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(stonesHere, id: \.persistentModelID) { stone in
                Label(stone.goalText ?? "", systemImage: "circle.fill")
                    .labelStyle(StoneLabelStyle())
            }

            if lifeGoal.isActive {
                HStack(spacing: 8) {
                    smallButton(String(localized: "돌 놓기"), systemImage: "plus", primary: true) {
                        if let obstacleID = obstacle.id {
                            placingStone = .init(lifeGoalID: id, obstacleID: obstacleID, toward: obstacle.textUnwrapped)
                        }
                    }
                    smallButton(String(localized: "치웠어요"), systemImage: "checkmark") {
                        clearedNote = ""
                        clearing = obstacle
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(PebbleTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(PebbleTheme.hairline, lineWidth: 1)
        }
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(obstacle)
            } label: {
                Label(String(localized: "지우기"), systemImage: "trash")
            }
        }
    }

    private func clearedRow(_ obstacle: ObstacleData) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PebbleTheme.sprout)
            VStack(alignment: .leading, spacing: 2) {
                Text(obstacle.textUnwrapped)
                    .font(PebbleTheme.body(15))
                    .foregroundStyle(PebbleTheme.inkSoft)
                    .strikethrough(true, color: PebbleTheme.inkFaint)
                if let note = obstacle.clearedNote, !note.isEmpty {
                    Text(note)
                        .font(PebbleTheme.body(14))
                        .foregroundStyle(PebbleTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let date = obstacle.clearedDate {
                    Text(String(localized: "\(dateText(date))에 넘었어요", locale: AppLanguage.locale))
                        .font(PebbleTheme.label(11))
                        .foregroundStyle(PebbleTheme.inkFaint)
                }
            }
        }
        .contextMenu {
            Button {
                obstacle.clearedDate = nil
                obstacle.clearedNote = nil
            } label: {
                Label(String(localized: "다시 가로막고 있어요"), systemImage: "arrow.uturn.backward")
            }
        }
    }

    // MARK: - 3. 놓은 돌

    @ViewBuilder
    private var stonesArea: some View {
        if !stones.isEmpty || lifeGoal.isActive {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(String(localized: "놓은 돌"))
                if stones.isEmpty {
                    Text(Phrasing.say(
                        "가로막는 것 하나를 골라 '돌 놓기'를 누르면, 내일 해볼 작은 일 하나를 같이 정해요.",
                        "가로막는 것 하나를 골라 '돌 놓기'를 누르면, 내일 해볼 작은 일 하나를 같이 정하자."
                    ))
                    .font(PebbleTheme.body(14))
                    .foregroundStyle(PebbleTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(stones, id: \.persistentModelID) { stone in
                    Button {
                        onTalk(stone.goalText ?? "")
                    } label: {
                        HStack(spacing: 12) {
                            Circle().fill(PebbleTheme.key).frame(width: 8, height: 8)
                            Text(stone.goalText ?? "")
                                .font(PebbleTheme.body(16))
                                .foregroundStyle(PebbleTheme.ink)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: "bubble.left")
                                .font(.system(size: 13))
                                .foregroundStyle(PebbleTheme.inkFaint)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("이 목표로 이야기해요"))
                }
                if lifeGoal.isActive && !stones.isEmpty {
                    smallButton(String(localized: "이 목표를 향해 돌 놓기"), systemImage: "plus") {
                        placingStone = .init(lifeGoalID: id, obstacleID: nil, toward: title)
                    }
                }
            }
        }
    }

    // MARK: - 4. 지나온 기록

    private var recordsArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(String(localized: "지나온 기록"))
                Spacer()
                Button {
                    isWritingNote = true
                } label: {
                    Label(String(localized: "기록 남기기"), systemImage: "square.and.pencil")
                        .font(PebbleTheme.label(13))
                        .foregroundStyle(PebbleTheme.key)
                }
                .buttonStyle(.plain)
            }

            if records.isEmpty {
                Text(Phrasing.say(
                    "놓은 돌로 이야기하거나 기록을 남기면 여기에 모여요. 사진도 붙일 수 있어요.",
                    "놓은 돌로 이야기하거나 기록을 남기면 여기에 모여. 사진도 붙일 수 있어."
                ))
                .font(PebbleTheme.body(14))
                .foregroundStyle(PebbleTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(records, id: \.persistentModelID) { record in
                recordRow(record)
            }
        }
    }

    private func recordRow(_ record: JournalData) -> some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(dateText(record.dateUnwrapped))
                        .font(PebbleTheme.label(12))
                        .foregroundStyle(PebbleTheme.inkFaint)
                    if let stone = record.subGoal, !stone.isEmpty {
                        Text(stone)
                            .font(PebbleTheme.label(12))
                            .foregroundStyle(PebbleTheme.inkSoft)
                            .lineLimit(1)
                    }
                    Spacer()
                    if record.isGoalIn == true {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(PebbleTheme.key)
                            .accessibilityLabel(Text("했어요"))
                    }
                }
                if let review = record.review, !review.isEmpty {
                    Text(review)
                        .font(PebbleTheme.body(15))
                        .foregroundStyle(PebbleTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let plan = record.nextPlan, !plan.isEmpty {
                    Label(plan, systemImage: "arrow.turn.down.right")
                        .font(PebbleTheme.body(14))
                        .foregroundStyle(PebbleTheme.inkSoft)
                }
                if let recordID = record.id {
                    RecordPhotosView(recordID: recordID)
                }
            }
        }
        .contextMenu {
            Button {
                editingRecord = record
            } label: {
                Label(String(localized: "고치기"), systemImage: "pencil")
            }
        }
        .onTapGesture { editingRecord = record }
    }

    private var reachedButton: some View {
        ReplyOptions(choices: [
            ReplyChoice(id: "reached", label: Phrasing.say("이 목표를 이뤘어요", "이 목표를 이뤘어"))
        ]) { _ in
            confirmReached = true
        }
    }

    // MARK: - 조각

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(PebbleTheme.label(13))
            .foregroundStyle(PebbleTheme.inkFaint)
    }

    private func smallButton(_ title: String, systemImage: String, primary: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(PebbleTheme.label(13))
                .foregroundStyle(primary ? PebbleTheme.onKey : PebbleTheme.key)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(primary ? PebbleTheme.key : PebbleTheme.key.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
        formatter.setLocalizedDateFormatFromTemplate(
            Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) ? "MMMd" : "yMMMd"
        )
        return formatter.string(from: date)
    }

    // MARK: - 동작

    private func addObstacle() {
        let text = newObstacle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !id.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.insert(ObstacleData(lifeGoalID: id, text: text))
        }
        newObstacle = ""
        focus = .obstacle
    }

    private func commitClear() {
        guard let clearing else { return }
        // 넘은 얘기를 적는 사이 지워진 장애물이면 건드리지 않는다.
        guard !clearing.isGone else {
            self.clearing = nil
            return
        }
        let note = clearedNote.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation {
            clearing.clearedDate = Date()
            clearing.clearedNote = note.isEmpty ? nil : note
        }
        self.clearing = nil
    }

    private func commitRename() {
        guard !lifeGoal.isGone else { return }
        let new = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let old = title
        guard !new.isEmpty, new != old else { return }
        lifeGoal.title = new
        for journal in journals where journal.mainGoal == old {
            journal.mainGoal = new
        }
        // 목표와 지난 기록의 이름이 반만 바뀐 채 꺼지면 기록이 목표와 끊긴다. 한 번에 내린다.
        modelContext.saveNow()
    }

    private func deleteLifeGoal() {
        guard !lifeGoal.isGone else { dismiss(); return }
        for obstacle in obstacles { modelContext.delete(obstacle) }
        for stone in stones {
            stone.lifeGoalID = nil
            stone.obstacleID = nil
        }
        modelContext.delete(lifeGoal)
        dismiss()
    }
}

/// `.sheet(item:)` 에 넘기려고 감싼다.
private struct StoneSheetItem: Identifiable {
    let stone: AddGoalView.Stone
    var id: String { stone.lifeGoalID + (stone.obstacleID ?? "") }
}

/// 장애물 아래 놓인 돌. 작은 점과 글.
private struct StoneLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            Circle().fill(PebbleTheme.key).frame(width: 6, height: 6)
            configuration.title
                .font(PebbleTheme.body(14))
                .foregroundStyle(PebbleTheme.inkSoft)
        }
    }
}

// MARK: - 기록 남기기

/// 삶의 목표에 기록 하나를 남긴다. 했다 · 못 했다를 묻지 않는다 — 그날 있었던 일과 사진.
struct LifeNoteSheet: View {
    let lifeGoalTitle: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var text = ""
    @State private var recordID = UUID().uuidString
    @State private var saved = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            PebbleTheme.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PebbleTheme.inkFaint)
                            .frame(width: 40, height: 40)
                    }
                    .accessibilityLabel(Text("닫기"))
                }

                Text(Phrasing.say(
                    String(localized: "'\(lifeGoalTitle)'에 대해 남기고 싶은 게 있어요?"),
                    String(localized: "'\(lifeGoalTitle)'에 대해 남기고 싶은 게 있어?")
                ))
                .font(PebbleTheme.companionFont(20))
                .foregroundStyle(PebbleTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

                SoftCard {
                    TextField(Phrasing.say("있었던 일, 떠오른 생각, 무엇이든요.", "있었던 일, 떠오른 생각, 무엇이든."),
                              text: $text, axis: .vertical)
                        .font(PebbleTheme.body(16))
                        .foregroundStyle(PebbleTheme.ink)
                        .textFieldStyle(.plain)
                        .lineLimit(3...8)
                        .focused($focused)
                }

                RecordPhotosView(recordID: recordID, editable: true)

                Spacer()

                ReplyOptions(choices: [
                    ReplyChoice(id: "save", label: Phrasing.say("남길게요", "남길게"), isPrimary: true)
                ]) { _ in
                    save()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onAppear { focused = true }
        .onDisappear {
            // 남기지 않고 닫았으면 먼저 붙여 둔 사진도 거둔다.
            if !saved { RecordPhotoCleanup.deletePhotos(of: recordID, in: modelContext) }
        }
    }

    private func save() {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = recordID
        let hasPhotos = ((try? modelContext.fetchCount(FetchDescriptor<RecordPhoto>(
            predicate: #Predicate { $0.recordID == id }))) ?? 0) > 0
        guard !clean.isEmpty || hasPhotos else { dismiss(); return }
        modelContext.insert(JournalData(
            id: recordID,
            date: Date(),
            hasDeleted: false,
            // 했다 · 못 했다를 묻지 않은 기록. 매듭짓지 못한 일로 세지 않는다.
            isGoalIn: nil,
            review: clean.isEmpty ? nil : clean,
            isRebounded: false,
            mainGoal: lifeGoalTitle
        ))
        saved = true
        // 적은 글과 붙인 사진을 바로 디스크에 내린다.
        modelContext.saveNow()
        dismiss()
    }
}

// MARK: - 삶의 목표 적기

/// 언젠가 꼭 이루고 싶은 것 하나를 적는다. 크게 적어도 된다 — 쪼개는 건 가로막는 것을 꺼낸 다음이다.
///
/// 개수 제한이 없다. 매일 묻는 건 그 아래 놓은 돌이라, 여기서 막을 까닭이 없다.
struct AddLifeGoalView: View {
    var onCreated: (LifeGoalData) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            PebbleTheme.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PebbleTheme.inkFaint)
                            .frame(width: 40, height: 40)
                    }
                    .accessibilityLabel(Text("닫기"))
                }

                InteractivePebble(mood: .warm, size: 96)
                    .frame(maxWidth: .infinity)

                Text(Phrasing.say("언젠가 꼭 이루고 싶은 게 뭐예요?", "언젠가 꼭 이루고 싶은 게 뭐야?"))
                    .font(PebbleTheme.companionFont(21))
                    .foregroundStyle(PebbleTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                SoftCard {
                    TextField(Phrasing.say("크게 적어도 괜찮아요. 오로라 보기, 책 한 권 쓰기처럼요.",
                                           "크게 적어도 괜찮아. 오로라 보기, 책 한 권 쓰기처럼."),
                              text: $title, axis: .vertical)
                        .font(PebbleTheme.body(17))
                        .foregroundStyle(PebbleTheme.ink)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .focused($focused)
                        .submitLabel(.done)
                }

                Spacer()

                if !trimmed.isEmpty {
                    ReplyOptions(choices: [
                        ReplyChoice(id: "save", label: Phrasing.say("이걸로 적을게요", "이걸로 적을게"), isPrimary: true)
                    ]) { _ in
                        save()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onAppear { focused = true }
    }

    private var trimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        guard !trimmed.isEmpty else { return }
        let life = LifeGoalData(title: trimmed)
        modelContext.insert(life)
        modelContext.saveNow()
        UsageReporting.log(.lifeGoalCreated)
        dismiss()
        onCreated(life)
    }
}
