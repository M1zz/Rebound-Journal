//
//  MoodDrawing.swift
//  Mochimo
//
//  아이패드: 그날 기분을 펜슬로 그려 남긴다.
//
//  말로 옮기기 어려운 날이 있다. 눈금을 고른 뒤 낙서 한 장을 덧붙일 수 있게 했다.
//
//  그림은 기록(SwiftData) 안에 넣지 않고 기록 ID 이름의 PNG 로 기기 안에 둔다.
//  기록 모델은 iCloud 로 동기화되고 있어 칸을 늘리면 기존 사용자 기록과 CloudKit 스키마를
//  같이 옮겨야 한다. 그림은 그린 기기에서 다시 보는 것으로 충분하다.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
#if os(iOS)
import PencilKit
#endif

enum MoodDrawingStore {

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("MoodDrawings", isDirectory: true)
    }

    private static func url(for journalID: String) -> URL {
        directory.appendingPathComponent("\(journalID).png")
    }

    static func save(_ png: Data, for journalID: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? png.write(to: url(for: journalID), options: .atomic)
    }

    static func image(for journalID: String?) -> Image? {
        guard let journalID else { return nil }
        let path = url(for: journalID).path
        #if canImport(UIKit)
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: image)
        #else
        guard let image = NSImage(contentsOfFile: path) else { return nil }
        return Image(nsImage: image)
        #endif
    }

    static func delete(for journalID: String?) {
        guard let journalID else { return }
        try? FileManager.default.removeItem(at: url(for: journalID))
    }

    /// 펜슬로 그릴 수 있는 기기인지. 그리는 단추는 아이패드에만 선다.
    static var canDraw: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }
}

/// 기록 옆에 붙는 작은 그림.
struct MoodDrawingThumbnail: View {
    let journalID: String?
    var height: CGFloat = 90

    var body: some View {
        if let image = MoodDrawingStore.image(for: journalID) {
            image
                .resizable()
                .scaledToFit()
                .frame(maxHeight: height)
                .padding(8)
                .background(PebbleTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel(Text("그날 그린 기분"))
        }
    }
}

#if os(iOS)
/// 그리는 판. 다 그리면 PNG 로 넘긴다. 아무것도 안 그리고 닫으면 nil.
struct MoodCanvasSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var drawing = PKDrawing()
    var onDone: (Data?) -> Void

    var body: some View {
        NavigationStack {
            CanvasRepresentable(drawing: $drawing)
                .background(PebbleTheme.surface)
                .navigationTitle(Text(Phrasing.say("오늘 기분을 그려요", "오늘 기분을 그려 봐")))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "취소")) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(Phrasing.say("이걸로 할게요", "이걸로 할게")) {
                            onDone(png())
                            dismiss()
                        }
                        .disabled(drawing.strokes.isEmpty)
                    }
                }
        }
    }

    private func png() -> Data? {
        guard !drawing.strokes.isEmpty else { return nil }
        let bounds = drawing.bounds.insetBy(dx: -16, dy: -16)
        // 어두운 화면에서 그려도 밝은 판 위에서 다시 보이게, 라이트 모양으로 굳힌다.
        var image: UIImage!
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: bounds, scale: 2)
        }
        return image.pngData()
    }
}

private struct CanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = PKInkingTool(.pen, color: .label, width: 4)
        canvas.delegate = context.coordinator
        context.coordinator.picker.setVisible(true, forFirstResponder: canvas)
        context.coordinator.picker.addObserver(canvas)
        DispatchQueue.main.async { canvas.becomeFirstResponder() }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(drawing: $drawing) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let picker = PKToolPicker()
        var drawing: Binding<PKDrawing>
        init(drawing: Binding<PKDrawing>) { self.drawing = drawing }
        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) { drawing.wrappedValue = canvas.drawing }
    }
}
#endif
