import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CoreText

// Synthetic local QA files only; never point this tool at Downloads.
let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build/Unpile Demo Files", isDirectory: true)
let manager = FileManager.default
let marker = root.appendingPathComponent(".unpile-fixture")
if manager.fileExists(atPath: root.path) && !manager.fileExists(atPath: marker.path) {
    fatalError("Refusing to use an existing directory without the Unpile fixture marker")
}
try manager.createDirectory(at: root, withIntermediateDirectories: true)
try Data("Unpile synthetic fixtures v1".utf8).write(to: marker)

let width = 960, height = 520
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
    space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let colors = [CGColor(red: 0.96, green: 0.83, blue: 0.75, alpha: 1), CGColor(red: 0.63, green: 0.78, blue: 0.91, alpha: 1)] as CFArray
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: height), options: [])
func mountain(_ points: [(Double, Double)], color: CGColor) {
    context.setFillColor(color)
    context.beginPath()
    context.move(to: CGPoint(x: 0, y: 0))
    for (x, y) in points { context.addLine(to: CGPoint(x: x * Double(width), y: y * Double(height))) }
    context.addLine(to: CGPoint(x: width, y: 0))
    context.closePath(); context.fillPath()
}
mountain([(0, 0.3), (0.16, 0.64), (0.3, 0.38), (0.48, 0.82), (0.7, 0.45), (0.87, 0.7), (1, 0.33)], color: CGColor(red: 0.46, green: 0.59, blue: 0.62, alpha: 1))
mountain([(0, 0.35), (0.25, 0.6), (0.47, 0.25), (0.8, 0.52), (1, 0.32)], color: CGColor(red: 0.23, green: 0.41, blue: 0.46, alpha: 1))
let pngURL = root.appendingPathComponent("Mountain-study.png")
let destination = CGImageDestinationCreateWithURL(pngURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Unable to create fixture image") }

let pdfURL = root.appendingPathComponent("Workshop-notes.pdf")
var page = CGRect(x: 0, y: 0, width: 480, height: 620)
let pdf = CGContext(pdfURL as CFURL, mediaBox: &page, nil)!
pdf.beginPDFPage(nil)
pdf.setFillColor(CGColor(gray: 1, alpha: 1)); pdf.fill(page)
let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
let text = NSAttributedString(string: "Workshop notes — synthetic demo", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
pdf.textPosition = CGPoint(x: 32, y: 550)
CTLineDraw(CTLineCreateWithAttributedString(text), pdf)
pdf.setFillColor(CGColor(gray: 0.82, alpha: 1))
for row in 0..<14 { pdf.fill(CGRect(x: 32, y: 500 - row * 23, width: row % 4 == 0 ? 280 : 390, height: 3)) }
pdf.endPDFPage(); pdf.closePDF()

let paging = CGContext(root.appendingPathComponent("Paging-demo.pdf") as CFURL, mediaBox: &page, nil)!
for index in 1...3 {
    paging.beginPDFPage(nil)
    paging.setFillColor(CGColor(gray: 1, alpha: 1)); paging.fill(page)
    paging.textPosition = CGPoint(x: 32, y: 550)
    let title = NSAttributedString(string: "Synthetic page \(index) of 3", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
    CTLineDraw(CTLineCreateWithAttributedString(title), paging)
    paging.endPDFPage()
}
paging.closePDF()

// Five seconds of silent PCM audio; no recording or microphone access.
var wav = Data("RIFF".utf8)
func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
    var bytes = value.littleEndian
    withUnsafeBytes(of: &bytes) { wav.append(contentsOf: $0) }
}
appendLittleEndian(UInt32(80_036)); wav.append(Data("WAVEfmt ".utf8))
appendLittleEndian(UInt32(16)); appendLittleEndian(UInt16(1)); appendLittleEndian(UInt16(1))
appendLittleEndian(UInt32(8_000)); appendLittleEndian(UInt32(16_000))
appendLittleEndian(UInt16(2)); appendLittleEndian(UInt16(16))
wav.append(Data("data".utf8)); appendLittleEndian(UInt32(80_000)); wav.append(Data(repeating: 0, count: 80_000))
try wav.write(to: root.appendingPathComponent("Silence-demo.wav"))

for (name, text) in [("Ideas-draft.txt", "Synthetic notes for UI testing.\n"), ("sample-data.csv", "item,count\nnotebooks,3\npencils,8\n"), ("Assets.zip", "Synthetic unsupported-preview fixture"), ("incomplete.crdownload", "Incomplete synthetic fixture"), (".hidden-demo.txt", "Hidden synthetic fixture")] {
    try Data(text.utf8).write(to: root.appendingPathComponent(name))
}
try manager.createDirectory(at: root.appendingPathComponent("Nested folder"), withIntermediateDirectories: true)
let link = root.appendingPathComponent("Linked-image.png")
if !manager.fileExists(atPath: link.path) { try manager.createSymbolicLink(at: link, withDestinationURL: pngURL) }
let ownedNames = [".unpile-fixture", "Mountain-study.png", "Workshop-notes.pdf", "Paging-demo.pdf", "Silence-demo.wav", "Ideas-draft.txt", "sample-data.csv", "Assets.zip", "incomplete.crdownload", ".hidden-demo.txt", "Nested folder"]
for name in ownedNames {
    let url = root.appendingPathComponent(name)
    try manager.setAttributes([.modificationDate: Date().addingTimeInterval(-30 * 86_400)], ofItemAtPath: url.path)
}
print(root.path)
