import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CoreText

// Original geometric artwork. No SF Symbols or external image assets are copied.
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build/brand", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let space = CGColorSpaceCreateDeviceRGB()
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
func context(_ width: Int, _ height: Int) -> CGContext {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath { CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil) }
func gradient(_ ctx: CGContext, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    ctx.drawLinearGradient(CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!, start: from, end: to, options: [])
}
func png(_ image: CGImage, _ url: URL, dpi: Double? = nil) throws {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    let properties = dpi.map { [kCGImagePropertyDPIWidth: $0, kCGImagePropertyDPIHeight: $0] as CFDictionary }
    CGImageDestinationAddImage(destination, image, properties)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}
func icon(_ ctx: CGContext) {
    let tile = rounded(CGRect(x: 80, y: 80, width: 864, height: 864), 194)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: color(0.03, 0.09, 0.24, 0.24))
    ctx.addPath(tile); ctx.setFillColor(color(0.1, 0.4, 0.95)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState(); ctx.addPath(tile); ctx.clip()
    gradient(ctx, [color(0.16, 0.68, 1), color(0.13, 0.37, 0.96), color(0.25, 0.22, 0.82)], from: CGPoint(x: 120, y: 960), to: CGPoint(x: 840, y: 80))
    let light = CGGradient(colorsSpace: space, colors: [color(1, 1, 1, 0.35), color(1, 1, 1, 0)] as CFArray, locations: nil)!
    ctx.drawRadialGradient(light, startCenter: CGPoint(x: 240, y: 880), startRadius: 0, endCenter: CGPoint(x: 240, y: 880), endRadius: 630, options: [])
    ctx.restoreGState()
    ctx.addPath(tile); ctx.setStrokeColor(color(1, 1, 1, 0.22)); ctx.setLineWidth(5); ctx.strokePath()
    for (angle, dx, dy, alpha) in [(-15.0, -45.0, -35.0, 0.46), (10.0, 38.0, -6.0, 0.7), (0.0, 0.0, 20.0, 1.0)] {
        ctx.saveGState(); ctx.translateBy(x: 512 + dx, y: 512 + dy); ctx.rotate(by: angle * .pi / 180)
        let paper = rounded(CGRect(x: -202, y: -255, width: 404, height: 510), 54)
        ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 25, color: color(0.03, 0.12, 0.35, 0.22))
        ctx.addPath(paper); ctx.setFillColor(color(0.97, 0.99, 1, alpha)); ctx.fillPath()
        if angle == 0 {
            ctx.setShadow(offset: .zero, blur: 0)
            for (y, width) in [(111.0, 210.0), (61.0, 145.0)] {
                ctx.addPath(rounded(CGRect(x: -124, y: y, width: width, height: 19), 9.5))
                ctx.setFillColor(color(0.18, 0.44, 0.91, 0.23)); ctx.fillPath()
            }
            ctx.setFillColor(color(0.03, 0.7, 0.61)); ctx.fillEllipse(in: CGRect(x: 32, y: -168, width: 112, height: 112))
            ctx.setStrokeColor(color(1, 1, 1)); ctx.setLineWidth(13); ctx.setLineCap(.round); ctx.setLineJoin(.round)
            ctx.move(to: CGPoint(x: 61, y: -113)); ctx.addLine(to: CGPoint(x: 80, y: -132)); ctx.addLine(to: CGPoint(x: 117, y: -91)); ctx.strokePath()
        }
        ctx.restoreGState()
    }
}
let iconset = output.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = points * scale
        let ctx = context(size, size); ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024); icon(ctx)
        try png(ctx.makeImage()!, iconset.appendingPathComponent("icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"))
    }
}
let master = context(1024, 1024); icon(master)
try png(master.makeImage()!, output.appendingPathComponent("AppIcon.png"))

// A deterministic Finder background for the drag-to-Applications disk image.
let width = 760, height = 480, scale = 2
let bg = context(width * scale, height * scale); bg.scaleBy(x: 2, y: 2)
gradient(bg, [color(0.96, 0.98, 1), color(0.88, 0.93, 1)], from: CGPoint(x: 0, y: 480), to: CGPoint(x: 760, y: 0))
func text(_ value: String, _ size: CGFloat, _ x: CGFloat, _ y: CGFloat, _ fill: CGColor) {
    let font = CTFontCreateWithName("HelveticaNeue" as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: value, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): fill]))
    bg.textPosition = CGPoint(x: x, y: y); CTLineDraw(line, bg)
}
text("Unpile", 34, 44, 394, color(0.08, 0.15, 0.3))
text("Drag Unpile into Applications", 19, 44, 358, color(0.28, 0.37, 0.52))
text("A little less clutter. One file at a time.", 13, 44, 39, color(0.34, 0.43, 0.56))
bg.setStrokeColor(color(0.27, 0.45, 0.68, 0.55)); bg.setLineWidth(5); bg.setLineCap(.round); bg.setLineJoin(.round)
bg.move(to: CGPoint(x: 347, y: 223)); bg.addLine(to: CGPoint(x: 413, y: 223)); bg.strokePath()
bg.move(to: CGPoint(x: 395, y: 241)); bg.addLine(to: CGPoint(x: 413, y: 223)); bg.addLine(to: CGPoint(x: 395, y: 205)); bg.strokePath()
try png(bg.makeImage()!, output.appendingPathComponent("dmg-background@2x.png"), dpi: 144)
print(output.path)
