#!/usr/bin/env swift
// Draws HerdPet's app icon and packs it into scripts/AppIcon.icns.
//
// Ported from AgentPet's `scripts/make-icon.swift`, which HerdPet grew out of:
// a squircle in one colour with a white pawprint on it. The paw is
// `pawprint.fill`, the same SF Symbol the menu bar item uses, so the app is the
// same shape in the Dock as it is on the menu bar.
//
// The icon is code rather than a checked-in design file for the same reason
// `AgentIcons.swift` embeds its SVGs: this project carries no resource bundle
// and no asset pipeline.
//
//   make icon                    # the default colour
//   make icon COLOR=5C43DC       # any other one (no `#`: make reads it as a comment)
//
// Only the one hex is given. The gradient's two stops are derived from it, so a
// new colour cannot arrive half-applied.

import AppKit
import Foundation

_ = NSApplication.shared

let defaultHex = "#E07B00"

func parseHex(_ raw: String) -> NSColor? {
    var hex = raw.trimmingCharacters(in: .whitespaces)
    if hex.hasPrefix("#") { hex.removeFirst() }
    guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
    return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                   green: CGFloat((value >> 8) & 0xFF) / 255,
                   blue: CGFloat(value & 0xFF) / 255,
                   alpha: 1)
}

/// The two gradient stops, lighter above and deeper below, so the tile reads as
/// lit from the top the way every other icon in the Dock does.
func gradientStops(_ base: NSColor) -> (NSColor, NSColor) {
    let rgb = base.usingColorSpace(.sRGB) ?? base
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    let top = NSColor(hue: h, saturation: max(0, s * 0.90), brightness: min(1, b * 1.12), alpha: a)
    let bottom = NSColor(hue: h, saturation: min(1, s * 1.04), brightness: b * 0.84, alpha: a)
    return (top, bottom)
}

var root = "."
var hex = defaultHex
var args = Array(CommandLine.arguments.dropFirst())
while let arg = args.first {
    args.removeFirst()
    if arg == "--color" {
        guard let value = args.first else {
            FileHandle.standardError.write(Data("--color needs a hex like #E07B00\n".utf8))
            exit(2)
        }
        hex = value
        args.removeFirst()
    } else {
        root = arg
    }
}

guard let base = parseHex(hex) else {
    FileHandle.standardError.write(Data("not a colour: \(hex) — use #RRGGBB\n".utf8))
    exit(2)
}
let (top, bottom) = gradientStops(base)

func draw(size: CGFloat) {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let squircle = NSBezierPath(roundedRect: rect, xRadius: size * 0.225, yRadius: size * 0.225)
    NSGradient(colors: [top, bottom])?.draw(in: squircle, angle: -90)

    guard let symbol = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: nil) else { return }
    let config = NSImage.SymbolConfiguration(pointSize: size * 0.52, weight: .semibold)
    guard let glyph = symbol.withSymbolConfiguration(config) else { return }

    // SF Symbols draw in the current text colour, which a bitmap context has
    // none of; painting the glyph and then flooding it `.sourceAtop` is what
    // makes it white.
    let tinted = NSImage(size: glyph.size)
    tinted.lockFocus()
    NSColor.white.set()
    let glyphRect = NSRect(origin: .zero, size: glyph.size)
    glyph.draw(in: glyphRect)
    glyphRect.fill(using: .sourceAtop)
    tinted.unlockFocus()

    tinted.draw(in: NSRect(x: (size - glyph.size.width) / 2,
                           y: (size - glyph.size.height) / 2,
                           width: glyph.size.width, height: glyph.size.height),
                from: .zero, operation: .sourceOver, fraction: 1)
}

/// Every size is drawn at its own pixel dimensions rather than downscaled from
/// 1024, so the 16pt Dock icon keeps clean edges.
func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(size: CGFloat(pixels))
    NSGraphicsContext.current?.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("could not encode \(pixels)px\n".utf8))
        exit(1)
    }
    return png
}

let rootURL = URL(fileURLWithPath: root)
let iconset = rootURL.appendingPathComponent("build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try render(pixels: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(pixels: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let icns = rootURL.appendingPathComponent("scripts/AppIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else { exit(task.terminationStatus) }
print("wrote \(icns.path) in \(hex)")
