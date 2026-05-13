#!/usr/bin/env swift

import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "background.png"
let appName = CommandLine.arguments.dropFirst(2).first ?? "capacity-cleaning"
let size = NSSize(width: 720, height: 420)
let image = NSImage(size: size)

image.lockFocus()

NSColor(calibratedWhite: 0.11, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .bold),
    .foregroundColor: NSColor.white
]
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.78, alpha: 1)
]
("Install \(appName)" as NSString).draw(
    in: NSRect(x: 70, y: 344, width: 580, height: 36),
    withAttributes: titleAttributes
)
("Drag the app icon to Applications" as NSString).draw(
    in: NSRect(x: 70, y: 316, width: 580, height: 24),
    withAttributes: subtitleAttributes
)

func roundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func strokeRoundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor, width: CGFloat) {
    color.setStroke()
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.lineWidth = width
    path.stroke()
}

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 270, y: 218))
arrowPath.line(to: NSPoint(x: 450, y: 218))
arrowPath.lineWidth = 9
arrowPath.lineCapStyle = .round
NSColor(calibratedRed: 0.97, green: 0.54, blue: 0.20, alpha: 1).setStroke()
arrowPath.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 450, y: 218))
arrowHead.line(to: NSPoint(x: 420, y: 240))
arrowHead.line(to: NSPoint(x: 420, y: 196))
arrowHead.close()
NSColor(calibratedRed: 0.97, green: 0.54, blue: 0.20, alpha: 1).setFill()
arrowHead.fill()

("Drop to Applications" as NSString).draw(
    in: NSRect(x: 258, y: 172, width: 220, height: 28),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
        .foregroundColor: NSColor.white
    ]
)
image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("Failed to render DMG background\n".utf8))
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))
