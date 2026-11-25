//
//  RecordPhotos.swift
//  Mochimo
//
//  기록에 붙인 사진. 어느 기록이든 붙일 수 있다 — 대화를 마친 자리, 고치기, 삶의 목표의 기록.
//
//  사진은 `RecordPhoto` 모델로 iCloud 에 함께 넘어간다. 그래서 넣기 전에 긴 변을 1600 으로 줄인다.
//  원본을 그대로 넣으면 기록 하나가 몇 MB 가 되고, 동기화가 그 무게를 매번 진다.
//

import SwiftUI
import SwiftData
import PhotosUI
import ImageIO

// MARK: - 줄이기

enum PhotoShrinker {
    static let longEdge: CGFloat = 1600

    /// 사진 데이터를 긴 변 1600, JPEG 로 줄인다. 읽을 수 없는 데이터면 nil.
    static func jpeg(_ data: Data) -> Data? {
        #if canImport(UIKit)
        // 읽히기는 했는데 크기가 0 인 그림이 있다. 그대로 가면 0×0 으로 그리다 죽는다.
        guard let image = UIImage(data: data), image.size.width >= 1, image.size.height >= 1 else { return nil }
        let scale = min(1, longEdge / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
        #else
        guard let image = NSImage(data: data),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              cg.width > 0, cg.height > 0 else { return nil }
        let scale = min(1, longEdge / CGFloat(max(cg.width, cg.height)))
        let width = Int(CGFloat(cg.width) * scale), height = Int(CGFloat(cg.height) * scale)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let small = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: small).representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        #endif
    }

    static func image(_ data: Data?) -> Image? {
        guard let data else { return nil }
        #if canImport(UIKit)
        return UIImage(data: data).map(Image.init(uiImage:))
        #else
        return NSImage(data: data).map(Image.init(nsImage:))
        #endif
    }

    /// 목록에 놓는 작은 그림. 76pt 칸에 1600px 원본을 통째로 풀면 한 장에 10MB 가까이 들고,
    /// 화면이 다시 그려질 때마다 또 푼다 — 사진이 많은 기록에서 메모리가 차 앱이 꺼진다.
    /// ImageIO 로 작게만 풀고, 한 번 푼 것은 쥐고 있다(메모리가 모자라면 시스템이 비운다).
    static func thumbnail(_ data: Data?, key: String, maxPixel: Int = 240) -> Image? {
        let cacheKey = "\(key)|\(maxPixel)" as NSString
        if let cached = thumbnails.object(forKey: cacheKey) {
            return Image(decorative: cached.image, scale: 1)
        }
        guard let data, !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let small = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceShouldCacheImmediately: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxPixel
              ] as CFDictionary) else { return nil }
        thumbnails.setObject(Thumbnail(small), forKey: cacheKey)
        return Image(decorative: small, scale: 1)
    }

    private final class Thumbnail {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }

    private static let thumbnails: NSCache<NSString, Thumbnail> = {
        let cache = NSCache<NSString, Thumbnail>()
        cache.countLimit = 200
        return cache
    }()
}

/// 크게 볼 사진 한 장. 모델이 아니라 **그때의 데이터**를 쥔다 — 보는 사이 사진이 지워지면
/// (다른 기기에서 지운 것이 동기화로 오는 때도) 지워진 모델의 속성을 읽다 앱이 죽는다.
struct ViewedPhoto: Identifiable {
    let id: String
    let data: Data?
}

// MARK: - 기록 하나의 사진들

/// 기록 하나에 붙은 사진을 가로로 늘어놓는다. `editable` 이면 더하고 뺄 수 있다.
struct RecordPhotosView: View {
    let recordID: String
    var editable = false

    @Environment(\.modelContext) private var modelContext
    @Query private var photos: [RecordPhoto]
    @State private var picked: [PhotosPickerItem] = []
    @State private var viewing: ViewedPhoto?

    init(recordID: String, editable: Bool = false) {
        self.recordID = recordID
        self.editable = editable
        _photos = Query(filter: #Predicate<RecordPhoto> { $0.recordID == recordID },
                        sort: \.date)
    }

    var body: some View {
        if !photos.isEmpty || editable {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(photos, id: \.persistentModelID) { photo in
                        thumbnail(photo)
                    }
                    if editable { addButton }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .onChange(of: picked) { _, items in add(items) }
            .sheet(item: $viewing) { photo in
                PhotoViewer(photo: photo)
            }
        }
    }

    private func thumbnail(_ photo: RecordPhoto) -> some View {
        let key = photo.id ?? "\(photo.persistentModelID.hashValue)"
        return Button {
            viewing = ViewedPhoto(id: key, data: photo.data)
        } label: {
            (PhotoShrinker.thumbnail(photo.data, key: key) ?? Image(systemName: "photo"))
                .resizable()
                .scaledToFill()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("사진"))
        .contextMenu {
            if editable {
                Button(role: .destructive) {
                    modelContext.delete(photo)
                } label: {
                    Label("사진 빼기", systemImage: "trash")
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if editable {
                Button {
                    modelContext.delete(photo)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(PebbleTheme.onKey, PebbleTheme.ink.opacity(0.6))
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .padding(4)
                .accessibilityLabel(Text("사진 빼기"))
            }
        }
    }

    private var addButton: some View {
        PhotosPicker(selection: $picked, matching: .images) {
            VStack(spacing: 4) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 18))
                Text("사진")
                    .font(PebbleTheme.label(11))
            }
            .foregroundStyle(PebbleTheme.key)
            .frame(width: 76, height: 76)
            .background(PebbleTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityLabel(Text("사진 붙이기"))
    }

    private func add(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        picked = []
        Task {
            for item in items {
                guard let raw = try? await item.loadTransferable(type: Data.self),
                      let data = PhotoShrinker.jpeg(raw) else { continue }
                modelContext.insert(RecordPhoto(recordID: recordID, data: data))
            }
        }
    }
}

/// 사진 한 장을 크게.
private struct PhotoViewer: View {
    let photo: ViewedPhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            (PhotoShrinker.image(photo.data) ?? Image(systemName: "photo"))
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("닫기"))
            .padding()
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 420)
        #endif
    }
}

enum RecordPhotoCleanup {
    /// 기록을 지울 때 붙은 사진도 같이 지운다. 남겨 두면 보이지 않는 사진이 iCloud 를 차지한다.
    static func deletePhotos(of recordID: String?, in context: ModelContext) {
        guard let recordID else { return }
        let photos = (try? context.fetch(FetchDescriptor<RecordPhoto>(
            predicate: #Predicate { $0.recordID == recordID }))) ?? []
        photos.forEach(context.delete)
    }
}
