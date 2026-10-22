import AppKit
import SwiftUI

// 화면에 쓰는 픽셀 그림 도구: 글자 격자를 비트맵으로 바꿔 보간 없이 키운다.

/// 글자 격자 → 비트맵. 같은 격자와 색이면 한 번만 만든다.
/// `Image` 를 보간 없이 확대하면 어떤 배율에서도 픽셀이 또렷하고 사각형 사이 줄이 안 생긴다.
@MainActor
enum PixelImages {
    private struct Key: Hashable {
        let rows: [String]
        let palette: [Character: Color]
    }

    private static var cache: [Key: CGImage] = [:]

    static func image(rows: [String], palette: [Character: Color]) -> CGImage? {
        let key = Key(rows: rows, palette: palette)
        if let cached = cache[key] { return cached }
        let width = rows.first?.count ?? 0, height = rows.count
        guard width > 0, height > 0 else { return nil }
        var rgba: [Character: (UInt8, UInt8, UInt8)] = [:]
        for (ch, color) in palette {
            let c = NSColor(color).usingColorSpace(.deviceRGB) ?? .gray
            rgba[ch] = (UInt8(c.redComponent * 255), UInt8(c.greenComponent * 255), UInt8(c.blueComponent * 255))
        }
        var data = [UInt8](repeating: 0, count: width * height * 4)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                guard let (r, g, b) = rgba[ch] else { continue }
                let i = (y * width + x) * 4
                data[i] = r; data[i + 1] = g; data[i + 2] = b; data[i + 3] = 255
            }
        }
        guard let context = CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let image = context.makeImage() else { return nil }
        if cache.count > 400 { cache.removeAll() }
        cache[key] = image
        return image
    }
}

/// 픽셀 격자 한 장. `scale` 은 픽셀 하나의 포인트 크기.
struct PixelFrame: View {
    let rows: [String]
    var scale: CGFloat = 1
    var palette: [Character: Color]

    var body: some View {
        let width = CGFloat(rows.first?.count ?? 0) * scale
        let height = CGFloat(rows.count) * scale
        Group {
            if let image = PixelImages.image(rows: rows, palette: palette) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - 픽셀 아이콘

/// 한 색으로 찍는 작은 픽셀 아이콘. SF Symbols 대신 쓴다. `#` 이 칠해진 칸이다.
enum PixelIcon {
    static let chevronDown = [
        "#.......#",
        ".#.....#.",
        "..#...#..",
        "...#.#...",
        "....#....",
    ]
    static let warning = [
        "..#..",
        "..#..",
        "..#..",
        "..#..",
        "..#..",
        ".....",
        "..#..",
    ]
    static let refresh = [
        "..#####..",
        ".#.....#.",
        "#.......#",
        "#......##",
        "#.....###",
        "#....####",
        "#........",
        ".#.....#.",
        "..#####..",
    ]
    static let gear = [
        "...###...",
        ".##...##.",
        ".#.....#.",
        "#..###..#",
        "#..#.#..#",
        "#..###..#",
        ".#.....#.",
        ".##...##.",
        "...###...",
    ]
}

/// `PixelIcon` 의 격자를 `color` 로 그린다. 기본은 글자색.
struct PixelIconView: View {
    let rows: [String]
    var color: Color = .primary
    var scale: CGFloat = 1.5

    var body: some View {
        PixelFrame(rows: rows, scale: scale, palette: ["#": color])
    }
}

/// 메뉴바 아이콘 프레임(16×13). 쓰는 중이면 깃펜이 오른쪽으로 움직이며 잉크 줄을 긋고,
/// 멈추면 깃펜이 그대로 서 있고 "z" 가 작아졌다 커졌다 한다.
enum MenuBarFrames {
    private static let quill = [
        "........###",
        "......#####",
        ".....#####.",
        "....#####..",
        "...####....",
        "...###.....",
        "..##.......",
        ".#.........",
        "#..........",
    ]
    private static let smallZ = [
        "...",
        "###",
        ".#.",
        "###",
    ]
    private static let bigZ = [
        "####",
        "..#.",
        ".#..",
        "####",
    ]

    private static func compose(nibX: Int, lift: Int, line: Bool, z: [String]?) -> [String] {
        let width = 16, height = 13
        var grid = Array(repeating: Array(repeating: Character("."), count: width), count: height)
        func put(_ x: Int, _ y: Int) { if x >= 0, x < width, y >= 0, y < height { grid[y][x] = "#" } }
        // 깃펜 끝(왼쪽 아래)이 (nibX, 10 - lift). 줄은 그 바로 아래 11행.
        for (y, row) in quill.enumerated() {
            for (x, ch) in row.enumerated() where ch == "#" { put(nibX + x, 2 - lift + y) }
        }
        if line {
            for x in 0..<max(0, nibX) where x % 3 != 2 { put(x, 11) }
        }
        if let z {
            for (y, row) in z.enumerated() {
                for (x, ch) in row.enumerated() where ch == "#" { put(12 + x, y) }
            }
        }
        return grid.map { String($0) }
    }

    static let writing: [[String]] = [
        compose(nibX: 0, lift: 0, line: true, z: nil),
        compose(nibX: 2, lift: 1, line: true, z: nil),
        compose(nibX: 3, lift: 0, line: true, z: nil),
        compose(nibX: 5, lift: 1, line: true, z: nil),
    ]

    static let paused: [[String]] = [
        compose(nibX: 0, lift: 0, line: false, z: smallZ),
        compose(nibX: 0, lift: 0, line: false, z: bigZ),
    ]

    /// 서 있는 깃펜 하나. 농땡이 중에 쓴다.
    static let standing: [String] = compose(nibX: 2, lift: 0, line: false, z: nil)

    /// 돌발 상황이면 그 상황 아이콘(9×9)과 서 있는 깃펜을 번갈아 보여 준다.
    static func paused(icon: [String]) -> [[String]] {
        var grid = Array(repeating: Array(repeating: Character("."), count: 16), count: 13)
        for (y, row) in icon.enumerated() {
            for (x, ch) in row.enumerated() where ch == "#" {
                let gx = 3 + x, gy = 2 + y
                if gy < 13, gx < 16 { grid[gy][gx] = "#" }
            }
        }
        return [grid.map { String($0) }, compose(nibX: 2, lift: 0, line: false, z: nil)]
    }
}

/// 메뉴바 템플릿 아이콘. 칸 하나를 1.5pt 로 그려 24×19.5pt 가 된다.
/// 작은 비트맵을 늘리면 1칸짜리 선이 번져 흐리게 보여서, 칸마다 사각형을 직접 칠한다.
@MainActor
func menuBarIcon(event: AuthorEvent?, slacking: Bool = false, tick: Int, sparkle: Bool = false, tremble: Bool = false) -> NSImage {
    let frames = event.map { MenuBarFrames.paused(icon: $0.icon) } ?? (slacking ? [MenuBarFrames.standing] : MenuBarFrames.writing)
    // 멈춤은 천천히 바뀌도록 네 틱(1.2초)에 한 번 넘긴다.
    let index = (event != nil ? tick / 4 : tick) % frames.count
    var rows = frames[index]
    // 탈고 직후엔 오른쪽 위에서 별이 반짝이고, 카페인이 돌면 한 칸씩 떨린다.
    if sparkle {
        let star = tick % 2 == 0 ? ["#.#", ".#.", "#.#"] : [".#.", "###", ".#."]
        rows = Portraits.overlay(rows, star, x: 12, y: 0)
    }
    if tremble, tick % 2 == 0 {
        rows = rows.map { String($0.dropFirst()) + "." }
    }
    return MenuBarImages.image(rows)
}

@MainActor
private enum MenuBarImages {
    static let cell: CGFloat = 1.5
    private static var cache: [[String]: NSImage] = [:]

    static func image(_ rows: [String]) -> NSImage {
        if let cached = cache[rows] { return cached }
        let width = CGFloat(rows.first?.count ?? 0) * cell, height = CGFloat(rows.count) * cell
        let image = NSImage(size: NSSize(width: width, height: height), flipped: true) { _ in
            NSGraphicsContext.current?.shouldAntialias = false
            NSColor.black.setFill()
            for (y, row) in rows.enumerated() {
                for (x, ch) in row.enumerated() where ch == "#" {
                    NSRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell).fill()
                }
            }
            return true
        }
        image.isTemplate = true
        cache[rows] = image
        return image
    }
}
