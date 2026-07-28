#!/usr/bin/env swift
//
//  make_app_icon.swift
//  Rebound Journal
//
//  앱 아이콘을 코드로 그린다.
//
//  화면 속 조약돌(`PebbleShape`)과 **같은 수식**을 쓴다. 아이콘만 따로 그리면
//  둘이 조금씩 어긋나고, 그 어긋남은 "같은 캐릭터"라는 인상을 깎는다.
//
//      swift Scripts/make_app_icon.swift
//
//  얼굴 선은 화면에서보다 굵게 잡았다. 1024로 그려 홈 화면에서는 120px 안팎으로
//  줄어드는데, 화면과 같은 굵기로 두면 선이 사라진다.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - 팔레트 (PebbleTheme의 라이트 모드 값)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

// 바탕은 앱 화면(크림색)보다 깊게 깐다.
//
// 화면에서는 조약돌이 크게 놓이지만 아이콘은 홈 화면에서 손톱만 해진다.
// 화면과 같은 크림색을 깔면 돌과 바탕이 붙어 베이지 얼룩으로 보인다.
// 햇빛을 바탕으로 삼으면 대비가 생기고, "햇빛에 달궈진 조약돌"이라는
// 캐릭터 설정(§10)에도 오히려 더 맞는다.
let canvasTop = rgb(0xF7C877)
let canvasBottom = rgb(0xE29A34)
let pebbleLit = rgb(0xF8E7CB)
let pebbleMid = rgb(0xDFC095)
let pebbleShade = rgb(0xB08A5D)
let sunlight = rgb(0xFFE0A8)
let faceInk = rgb(0x7A5A38)

// MARK: - 조약돌 실루엣
//
// PebbleShape와 같은 방식: 타원의 반지름을 각도에 따라 흔들고, 그 점들을
// Catmull-Rom으로 부드럽게 이어 닫는다.

func pebblePath(center: CGPoint, rx: CGFloat, ry: CGFloat) -> CGPath {
    let steps = 32
    let points: [CGPoint] = (0..<steps).map { index in
        let angle = 2 * CGFloat.pi * CGFloat(index) / CGFloat(steps)
        let wobble: CGFloat = 1
            + 0.055 * cos(angle * 2 + 0.7)
            + 0.032 * cos(angle * 3 - 1.2)
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

        let control1 = CGPoint(
            x: start.x + (end.x - previous.x) / 6,
            y: start.y + (end.y - previous.y) / 6
        )
        let control2 = CGPoint(
            x: end.x - (next.x - start.x) / 6,
            y: end.y - (next.y - start.y) / 6
        )
        path.addCurve(to: end, control1: control1, control2: control2)
    }
    path.closeSubpath()
    return path
}

/// 위로 볼록한 호(감은 눈)와 아래로 볼록한 호(웃는 입).
func arcPath(center: CGPoint, width: CGFloat, depth: CGFloat, opensDown: Bool) -> CGPath {
    let path = CGMutablePath()
    let half = width / 2
    let lift: CGFloat = opensDown ? depth : -depth
    path.move(to: CGPoint(x: center.x - half, y: center.y))
    path.addQuadCurve(
        to: CGPoint(x: center.x + half, y: center.y),
        control: CGPoint(x: center.x, y: center.y + lift * 2)
    )
    return path
}

// MARK: - 그리기

let side: CGFloat = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let ctx = CGContext(
    data: nil,
    width: Int(side),
    height: Int(side),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("컨텍스트를 만들지 못했습니다")
}

// 화면 코드와 같은 좌표계(y가 아래로)로 뒤집어 둔다. 그래야 수식을 그대로 옮길 수 있다.
ctx.translateBy(x: 0, y: side)
ctx.scaleBy(x: 1, y: -1)

// 바탕 — 위에서 아래로 아주 옅게 깊어지는 크림색
if let background = CGGradient(
    colorsSpace: colorSpace,
    colors: [canvasTop, canvasBottom] as CFArray,
    locations: [0, 1]
) {
    ctx.drawLinearGradient(
        background,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: 0, y: side),
        options: []
    )
}

let center = CGPoint(x: side / 2, y: side * 0.505)
let rx = side * 0.352
let ry = side * 0.269

// 햇빛 — 조약돌 뒤에서 번지는 따뜻한 빛
if let glow = CGGradient(
    colorsSpace: colorSpace,
    colors: [sunlight.copy(alpha: 0.34)!, sunlight.copy(alpha: 0)!] as CFArray,
    locations: [0, 1]
) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.scaleBy(x: 1, y: 0.82)
    ctx.drawRadialGradient(
        glow,
        startCenter: .zero, startRadius: rx * 0.55,
        endCenter: .zero, endRadius: rx * 1.42,
        options: []
    )
    ctx.restoreGState()
}

// 돌 본체 — 왼쪽 위에서 해가 든다
let body = pebblePath(center: center, rx: rx, ry: ry)
ctx.saveGState()
ctx.addPath(body)
ctx.clip()
if let stone = CGGradient(
    colorsSpace: colorSpace,
    colors: [pebbleLit, pebbleMid, pebbleShade] as CFArray,
    locations: [0, 0.55, 1]
) {
    ctx.drawLinearGradient(
        stone,
        start: CGPoint(x: center.x - rx, y: center.y - ry),
        end: CGPoint(x: center.x + rx, y: center.y + ry),
        options: []
    )
}

// 표면이 매끄럽다는 걸 알려주는 반사광 한 점
if let shine = CGGradient(
    colorsSpace: colorSpace,
    colors: [rgb(0xFFFFFF, 0.55), rgb(0xFFFFFF, 0)] as CFArray,
    locations: [0, 1]
) {
    ctx.saveGState()
    ctx.translateBy(x: center.x - rx * 0.42, y: center.y - ry * 0.52)
    ctx.scaleBy(x: 1, y: 0.62)
    ctx.drawRadialGradient(
        shine,
        startCenter: .zero, startRadius: 0,
        endCenter: .zero, endRadius: rx * 0.42,
        options: []
    )
    ctx.restoreGState()
}
ctx.restoreGState()

// 얼굴 — 화면보다 굵게. 작게 줄었을 때 선이 남아 있어야 한다.
ctx.setStrokeColor(faceInk)
ctx.setLineCap(.round)

let eyeY = center.y - ry * 0.16
let eyeGap = rx * 0.42
let eyeWidth = rx * 0.24

ctx.setLineWidth(side * 0.026)
for direction in [-1.0, 1.0] as [CGFloat] {
    ctx.addPath(arcPath(
        center: CGPoint(x: center.x + direction * eyeGap, y: eyeY),
        width: eyeWidth,
        depth: eyeWidth * 0.26,
        opensDown: false
    ))
}
ctx.strokePath()

ctx.setLineWidth(side * 0.023)
ctx.addPath(arcPath(
    center: CGPoint(x: center.x, y: center.y + ry * 0.24),
    width: rx * 0.30,
    depth: rx * 0.085,
    opensDown: true
))
ctx.strokePath()

// MARK: - 저장

guard let image = ctx.makeImage() else { fatalError("이미지를 만들지 못했습니다") }

let target = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Rebound Journal/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

guard let destination = CGImageDestinationCreateWithURL(
    target as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    fatalError("저장할 곳을 열지 못했습니다: \(target.path)")
}

CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("PNG를 쓰지 못했습니다")
}

print("그렸습니다: \(target.path)")
