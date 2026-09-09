#!/usr/bin/env swift
//
//  make_moodboard.swift
//  Rebound Journal
//
//  키 컬러 후보를 실제 화면 요소에 입혀 나란히 그린다.
//
//  색은 색표로 보면 다 그럴듯하고, 화면에 놓으면 완전히 달라진다. 그래서
//  조약돌·말풍선·답풍선이라는 실제 배치 그대로 그려 비교한다.
//
//      swift Scripts/make_moodboard.swift out.png
//

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

struct Palette {
    let name: String
    let note: String
    let canvas: UInt32       // 바탕
    let surface: UInt32      // 말풍선 면
    let hairline: UInt32     // 실선
    let key: UInt32          // 키 컬러
    let ink: UInt32          // 글자
    let pebbleLit: UInt32
    let pebbleMid: UInt32
    let pebbleShade: UInt32
}

// 키(개울 물빛)는 고정하고 바탕만 바꿔 비교한다.
// 돌은 어느 경우에도 따뜻하게 둔다 — §10의 캐릭터 설정이라 여기는 안 건드린다.
let palettes: [Palette] = [
    Palette(
        name: "지금 (베이지)",
        note: "따뜻하지만 흔한 계열",
        canvas: 0xFBF8F3, surface: 0xFFFFFF, hairline: 0xDFE3E2,
        key: 0x5F8F93, ink: 0x27302F,
        pebbleLit: 0xF1E3CB, pebbleMid: 0xD6C0A0, pebbleShade: 0xAC9070
    ),
    Palette(
        name: "물안개",
        note: "개울가 이른 아침",
        canvas: 0xEFF3F3, surface: 0xFCFDFD, hairline: 0xDBE3E2,
        key: 0x5F8F93, ink: 0x232C2B,
        pebbleLit: 0xF1E3CB, pebbleMid: 0xD6C0A0, pebbleShade: 0xAC9070
    ),
    Palette(
        name: "물그림자",
        note: "한 톤 내려앉은 물빛",
        canvas: 0xE4EBEA, surface: 0xF7FAF9, hairline: 0xCFDAD8,
        key: 0x4E7F84, ink: 0x1F2A29,
        pebbleLit: 0xF3E6CF, pebbleMid: 0xD9C4A5, pebbleShade: 0xAF9474
    ),
    Palette(
        name: "돌빛",
        note: "물기 마른 자갈색",
        canvas: 0xEFEFEC, surface: 0xFCFCFB, hairline: 0xDEDEDA,
        key: 0x5F8F93, ink: 0x2A2C2B,
        pebbleLit: 0xF1E3CB, pebbleMid: 0xD6C0A0, pebbleShade: 0xAC9070
    )
]

// MARK: - 조약돌 모양 (PebbleShape와 같은 수식)

func pebblePath(center: CGPoint, rx: CGFloat, ry: CGFloat) -> CGPath {
    let steps = 32
    let points: [CGPoint] = (0..<steps).map { index in
        let angle = 2 * CGFloat.pi * CGFloat(index) / CGFloat(steps)
        let wobble: CGFloat = 1 + 0.055 * cos(angle * 2 + 0.7) + 0.032 * cos(angle * 3 - 1.2)
        let settle: CGFloat = 1 - 0.07 * max(0, sin(angle))
        let radius = wobble * settle
        return CGPoint(
            x: center.x + rx * radius * cos(angle),
            y: center.y + ry * radius * sin(angle)
        )
    }
    let path = CGMutablePath()
    path.move(to: points[0])
    for index in 0..<points.count {
        let previous = points[(index - 1 + points.count) % points.count]
        let start = points[index]
        let end = points[(index + 1) % points.count]
        let next = points[(index + 2) % points.count]
        path.addCurve(
            to: end,
            control1: CGPoint(x: start.x + (end.x - previous.x) / 6, y: start.y + (end.y - previous.y) / 6),
            control2: CGPoint(x: end.x - (next.x - start.x) / 6, y: end.y - (next.y - start.y) / 6)
        )
    }
    path.closeSubpath()
    return path
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func draw(_ text: String, at point: CGPoint, size: CGFloat, color: CGColor, bold: Bool, in ctx: CGContext) {
    let font = CTFontCreateWithName(
        (bold ? "AppleSDGothicNeo-Bold" : "AppleSDGothicNeo-Regular") as CFString,
        size, nil
    )
    let line = CTLineCreateWithAttributedString(NSAttributedString(
        string: text,
        attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
        ]
    ))
    ctx.saveGState()
    ctx.textMatrix = .identity
    ctx.translateBy(x: point.x, y: point.y)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

// MARK: - 한 칸 그리기

func drawMock(_ palette: Palette, in frame: CGRect, ctx: CGContext) {
    // 이름표
    draw(palette.name, at: CGPoint(x: frame.minX, y: frame.minY - 34),
         size: 26, color: rgb(0x1A1A1A), bold: true, in: ctx)
    draw(palette.note, at: CGPoint(x: frame.minX, y: frame.minY - 10),
         size: 17, color: rgb(0x8A8A8A), bold: false, in: ctx)

    // 화면 바탕
    ctx.saveGState()
    ctx.addPath(roundedRect(frame, 28))
    ctx.clip()
    ctx.setFillColor(rgb(palette.canvas))
    ctx.fill(frame)

    // 조약돌 (키 컬러 후광)
    let center = CGPoint(x: frame.midX, y: frame.minY + 132)
    let rx: CGFloat = 84, ry: CGFloat = 64
    if let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                             colors: [rgb(palette.key, 0.26), rgb(palette.key, 0)] as CFArray,
                             locations: [0, 1]) {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.scaleBy(x: 1, y: 0.8)
        ctx.drawRadialGradient(glow, startCenter: .zero, startRadius: rx * 0.6,
                               endCenter: .zero, endRadius: rx * 1.5, options: [])
        ctx.restoreGState()
    }
    ctx.saveGState()
    ctx.addPath(pebblePath(center: center, rx: rx, ry: ry))
    ctx.clip()
    if let stone = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [rgb(palette.pebbleLit), rgb(palette.pebbleMid), rgb(palette.pebbleShade)] as CFArray,
                              locations: [0, 0.55, 1]) {
        ctx.drawLinearGradient(stone,
                               start: CGPoint(x: center.x - rx, y: center.y - ry),
                               end: CGPoint(x: center.x + rx, y: center.y + ry), options: [])
    }
    ctx.restoreGState()

    // 조약돌 말풍선 둘 (왼쪽)
    ctx.setLineWidth(2)
    for (index, width) in [CGFloat(300), CGFloat(214)].enumerated() {
        let bubble = CGRect(x: frame.minX + 26, y: frame.minY + 244 + CGFloat(index) * 74,
                            width: width, height: 58)
        ctx.setFillColor(rgb(palette.surface))
        ctx.addPath(roundedRect(bubble, 20)); ctx.fillPath()
        ctx.setStrokeColor(rgb(palette.hairline))
        ctx.addPath(roundedRect(bubble, 20)); ctx.strokePath()
        // 글줄 시늉
        ctx.setFillColor(rgb(palette.ink, 0.62))
        ctx.fill(CGRect(x: bubble.minX + 22, y: bubble.midY - 6, width: width - 68, height: 11))
    }

    // 답풍선 — 채운 것(키) + 테두리만(키)
    let filled = CGRect(x: frame.maxX - 214, y: frame.minY + 402, width: 188, height: 58)
    ctx.setFillColor(rgb(palette.key))
    ctx.addPath(roundedRect(filled, 20)); ctx.fillPath()
    ctx.setFillColor(rgb(0xFFFFFF, 0.92))
    ctx.fill(CGRect(x: filled.minX + 30, y: filled.midY - 6, width: 128, height: 11))

    let outlined = CGRect(x: frame.maxX - 180, y: frame.minY + 476, width: 154, height: 58)
    ctx.setFillColor(rgb(palette.surface))
    ctx.addPath(roundedRect(outlined, 20)); ctx.fillPath()
    ctx.setStrokeColor(rgb(palette.key, 0.7))
    ctx.setLineWidth(3)
    ctx.addPath(roundedRect(outlined, 20)); ctx.strokePath()
    ctx.setFillColor(rgb(palette.ink, 0.62))
    ctx.fill(CGRect(x: outlined.minX + 26, y: outlined.midY - 6, width: 96, height: 11))

    // 키 컬러 색표
    let swatch = CGRect(x: frame.minX + 26, y: frame.maxY - 74, width: 48, height: 48)
    ctx.setFillColor(rgb(palette.key))
    ctx.addPath(roundedRect(swatch, 12)); ctx.fillPath()
    ctx.restoreGState()

    draw(String(format: "#%06X", palette.key),
         at: CGPoint(x: frame.minX + 86, y: frame.maxY - 40),
         size: 19, color: rgb(0x6A6A6A), bold: false, in: ctx)
}

// MARK: - 전체

let width: CGFloat = 1160
let height: CGFloat = 1420
guard let ctx = CGContext(data: nil, width: Int(width), height: Int(height),
                          bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("컨텍스트 실패")
}
ctx.translateBy(x: 0, y: height)
ctx.scaleBy(x: 1, y: -1)

ctx.setFillColor(rgb(0xF2F2F2))
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

draw("징검돌 — 바탕색 후보 (키는 물빛 고정)", at: CGPoint(x: 48, y: 62), size: 34, color: rgb(0x1A1A1A), bold: true, in: ctx)

let cardWidth: CGFloat = 500
let cardHeight: CGFloat = 590
for (index, palette) in palettes.enumerated() {
    let column = CGFloat(index % 2), row = CGFloat(index / 2)
    let frame = CGRect(
        x: 48 + column * (cardWidth + 64),
        y: 148 + row * (cardHeight + 96),
        width: cardWidth, height: cardHeight
    )
    drawMock(palette, in: frame, ctx: ctx)
}

guard let image = ctx.makeImage() else { fatalError("이미지 실패") }
let target = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "moodboard.png")
guard let dest = CGImageDestinationCreateWithURL(target as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("저장 실패")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("PNG 실패") }
print("그렸습니다: \(target.path)")
