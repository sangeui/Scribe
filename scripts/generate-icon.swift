// 앱 아이콘을 만든다: 짙은 남색 바탕에 깃펜과 잉크 줄 도트.
// 사용: swift scripts/generate-icon.swift <출력.icns>
import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"

// 16×16. q 깃털(크림), Q 깃털 그늘, n 펜대, i 잉크 줄, d 잉크 방울
let art = [
    "................",
    "...........qqq..",
    "..........qqqqq.",
    ".........qqqqqq.",
    "........qqqqqQ..",
    ".......qqqqQQ...",
    "......qqqqQQ....",
    ".....qqqQQQ.....",
    "....qqqQQ.......",
    "...qqQQ.........",
    "...nn...........",
    "..nn............",
    ".nn.............",
    ".d..............",
    "..iii.iii.ii....",
    "................",
]
let palette: [Character: NSColor] = [
    "q": NSColor(red: 0.97, green: 0.94, blue: 0.86, alpha: 1),
    "Q": NSColor(red: 0.82, green: 0.76, blue: 0.64, alpha: 1),
    "n": NSColor(red: 0.62, green: 0.5, blue: 0.36, alpha: 1),
    "i": NSColor(red: 0.6, green: 0.72, blue: 0.9, alpha: 1),
    "d": NSColor(red: 0.6, green: 0.72, blue: 0.9, alpha: 1),
]

func render(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let s = size / 1024
    // macOS 아이콘 모양: 가장자리를 비운 둥근 사각형
    let inset = 100 * s
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let shape = NSBezierPath(roundedRect: rect, xRadius: 185 * s, yRadius: 185 * s)
    shape.addClip()
    NSGradient(starting: NSColor(red: 0.2, green: 0.26, blue: 0.42, alpha: 1),
               ending: NSColor(red: 0.1, green: 0.13, blue: 0.24, alpha: 1))!
        .draw(in: rect, angle: -90)
    NSGraphicsContext.current?.imageInterpolation = .none
    let cell = (rect.width * 0.78) / 16
    let originX = rect.midX - cell * 8
    let originY = rect.midY - cell * 8
    for (row, line) in art.enumerated() {
        for (col, ch) in line.enumerated() {
            guard let color = palette[ch] else { continue }
            color.setFill()
            // 행 0 이 위. NSImage 좌표는 아래가 0 이라 뒤집는다.
            NSRect(x: originX + CGFloat(col) * cell, y: originY + CGFloat(15 - row) * cell, width: cell, height: cell).fill()
        }
    }
    image.unlockFocus()
    return image
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                   ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    let image = render(size: CGFloat(px))
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent("icon_\(name).png"))
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", output]
try! task.run()
task.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print("wrote \(output)")
