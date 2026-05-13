#!/usr/bin/env swift

import AppKit
import Foundation

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.iconset")
let fileManager = FileManager.default
try? fileManager.removeItem(at: outputDirectory)
try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let sizes: [(name: String, points: CGFloat, scale: CGFloat)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2)
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.22
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.05, dy: size * 0.05), xRadius: radius, yRadius: radius)
    NSColor(calibratedRed: 0.07, green: 0.50, blue: 0.54, alpha: 1).setFill()
    background.fill()

    let inset = size * 0.18
    let chartRect = rect.insetBy(dx: inset, dy: inset)
    let center = NSPoint(x: chartRect.midX, y: chartRect.midY)
    let radiusChart = chartRect.width * 0.36

    NSColor.white.withAlphaComponent(0.95).setStroke()
    let circle = NSBezierPath(ovalIn: NSRect(
        x: center.x - radiusChart,
        y: center.y - radiusChart,
        width: radiusChart * 2,
        height: radiusChart * 2
    ))
    circle.lineWidth = max(3, size * 0.055)
    circle.stroke()

    let wedge = NSBezierPath()
    wedge.move(to: center)
    wedge.line(to: NSPoint(x: center.x, y: center.y + radiusChart))
    wedge.appendArc(withCenter: center, radius: radiusChart, startAngle: 90, endAngle: -38, clockwise: true)
    wedge.close()
    NSColor(calibratedWhite: 0.10, alpha: 0.95).setFill()
    wedge.fill()
    NSColor.white.withAlphaComponent(0.95).setStroke()
    wedge.lineWidth = max(2, size * 0.035)
    wedge.stroke()

    let sparklePath = NSBezierPath()
    let sparkleCenter = NSPoint(x: size * 0.70, y: size * 0.72)
    let sparkle = size * 0.055
    sparklePath.move(to: NSPoint(x: sparkleCenter.x, y: sparkleCenter.y + sparkle))
    sparklePath.line(to: NSPoint(x: sparkleCenter.x + sparkle, y: sparkleCenter.y))
    sparklePath.line(to: NSPoint(x: sparkleCenter.x, y: sparkleCenter.y - sparkle))
    sparklePath.line(to: NSPoint(x: sparkleCenter.x - sparkle, y: sparkleCenter.y))
    sparklePath.close()
    NSColor(calibratedRed: 0.98, green: 0.58, blue: 0.20, alpha: 1).setFill()
    sparklePath.fill()

    image.unlockFocus()
    return image
}

for item in sizes {
    let pixelSize = item.points * item.scale
    let image = drawIcon(size: pixelSize)
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        FileHandle.standardError.write(Data("Failed to render \(item.name)\n".utf8))
        exit(1)
    }
    try png.write(to: outputDirectory.appendingPathComponent(item.name))
}
