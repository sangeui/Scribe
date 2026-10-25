import SwiftUI

/// 작가 초상화. 24×24 픽셀(그림은 `PortraitArt.swift`). 얼굴 자리가 모두 같아 표정·눈동자·장신구를 한 규칙으로 얹는다.
/// 돌발 상황 그림: q 유리·물방울, u 바다, o·O 의자 나무, y 눈빛·까마귀 눈·불꽃·해, G 연기, f 창틀, a 창밖 하늘.
enum Portraits {
    static let size = 24
    /// 눈이 있는 줄과 두 눈의 열, 입이 있는 줄.
    static let eyeRow = 10
    static let eyeColumns = (9, 14)
    static let mouthRow = 14

    static let palette: [Character: Color] = [
        "h": Color(red: 0.42, green: 0.27, blue: 0.15),
        "H": Color(red: 0.14, green: 0.11, blue: 0.11),
        "g": Color(red: 0.6, green: 0.56, blue: 0.52),
        "s": Color(red: 1.0, green: 0.86, blue: 0.72),
        "S": Color(red: 0.86, green: 0.68, blue: 0.54),
        "e": Color(red: 0.15, green: 0.13, blue: 0.16),
        "m": Color(red: 0.7, green: 0.38, blue: 0.34),
        "w": Color(red: 0.96, green: 0.94, blue: 0.88),
        "k": Color(red: 0.16, green: 0.15, blue: 0.19),
        "c": Color(red: 0.42, green: 0.22, blue: 0.16),
        "d": Color(red: 0.3, green: 0.42, blue: 0.62),
        "n": Color(red: 0.35, green: 0.7, blue: 0.35),
        "b": Color(red: 0.24, green: 0.15, blue: 0.1),
        // 돌발 상황·책상 장면에 쓰는 색
        "q": Color(red: 0.62, green: 0.84, blue: 0.98),
        "u": Color(red: 0.24, green: 0.46, blue: 0.78),
        "o": Color(red: 0.6, green: 0.4, blue: 0.22),
        "O": Color(red: 0.42, green: 0.26, blue: 0.14),
        "y": Color(red: 0.98, green: 0.84, blue: 0.4),
        "G": Color(red: 0.7, green: 0.7, blue: 0.72),
        "f": Color(red: 0.3, green: 0.2, blue: 0.12),
        "a": Color(red: 0.55, green: 0.75, blue: 0.95),
        // 장신구(`Decor`)에만 쓰는 색
        "R": Color(red: 0.8, green: 0.22, blue: 0.24),
    ]

    /// 초상화 뒤 벽 색. 작가마다 다르게.
    static func backdrop(_ author: String) -> Color {
        switch author {
        case "Shakespeare": Color(red: 0.36, green: 0.16, blue: 0.16)
        case "Dickens": Color(red: 0.2, green: 0.3, blue: 0.24)
        case "Poe": Color(red: 0.24, green: 0.22, blue: 0.3)
        case "Carroll": Color(red: 0.3, green: 0.42, blue: 0.56)
        case "Stevenson": Color(red: 0.42, green: 0.36, blue: 0.24)
        case "Wilde": Color(red: 0.34, green: 0.24, blue: 0.4)
        case "Austen": Color(red: 0.62, green: 0.5, blue: 0.48)
        case "Goethe": Color(red: 0.16, green: 0.32, blue: 0.38)
        default: Color.gray
        }
    }

    static func rows(_ author: String) -> [String] {
        switch author {
        case "Shakespeare": shakespeare
        case "Dickens": dickens
        case "Poe": poe
        case "Carroll": carroll
        case "Stevenson": stevenson
        case "Wilde": wilde
        case "Austen": austen
        case "Goethe": goethe
        default: shakespeare
        }
    }

    static let all: [(String, [String])] = [
        ("Shakespeare", shakespeare), ("Dickens", dickens), ("Poe", poe), ("Carroll", carroll),
        ("Stevenson", stevenson), ("Wilde", wilde), ("Austen", austen), ("Goethe", goethe),
    ]
}

// MARK: - 표정

/// 입과 눈 모양. 얼굴 자리가 같아 작가와 상관없이 같은 칸을 고친다.
enum Expression: Sendable, Equatable {
    case neutral, happy, frown, tired, surprised

    /// 그림에 표정을 얹는다. 입 자리의 원래 색(피부나 수염)은 입 아랫줄에서 가져온다.
    func apply(_ rows: [String]) -> [String] {
        guard self != .neutral else { return rows }
        var grid = rows.map(Array.init)
        let (l, r) = Portraits.eyeColumns
        let eye = Portraits.eyeRow, mouth = Portraits.mouthRow
        func set(_ x: Int, _ y: Int, _ c: Character) { if grid.indices.contains(y), grid[y].indices.contains(x) { grid[y][x] = c } }
        let fill = grid[mouth + 1][11] == "m" ? "s" : grid[mouth + 1][11]
        switch self {
        case .happy:
            set(11, mouth, fill); set(12, mouth, fill)
            set(l, mouth - 1, "m"); set(r, mouth - 1, "m")
            for x in 10...13 { set(x, mouth, "m") }
        case .frown:
            set(11, mouth, fill); set(12, mouth, fill)
            for x in 10...13 { set(x, mouth - 1, "m") }
            set(l, mouth, "m"); set(r, mouth, "m")
        case .tired:
            // 눈꺼풀이 내려와 눈이 한 칸 아래, 입은 길고 납작하게.
            set(l, eye, "S"); set(r, eye, "S"); set(l, eye + 1, "e"); set(r, eye + 1, "e")
            for x in 10...13 { set(x, mouth, "m") }
        case .surprised:
            // 눈썹이 올라가고 입이 벌어진다.
            for x in [l - 1, l, l + 1, r - 1, r, r + 1] { set(x, eye - 2, "S") }
            set(11, mouth + 1, "m"); set(12, mouth + 1, "m")
        case .neutral: break
        }
        return grid.map { String($0) }
    }
}

// MARK: - 돌발 상황·기분·장면

extension Portraits {
    /// 기분과 표정까지 넣은 그림. 돌발 상황이 있으면 그것이 먼저다.
    @MainActor
    static func rows(_ author: String, event: AuthorEvent?, mood: Mood, expression: Expression = .neutral) -> [String] {
        if event != nil { return rows(author, event: event) }
        let base = expression.apply(Decor.apply(rows(author), author: author))
        switch mood {
        case .waiting:
            // 곁눈질: 눈동자가 화면 쪽(오른쪽)으로.
            return moveEyes(base, dx: 1, dy: 0)
        case .slacking:
            // 의자에 기대 창밖을 본다. 눈은 위를, 오른쪽 위에 종이비행기.
            return overlay(moveEyes(base, dx: 1, dy: -1), plane, x: 18, y: 1)
        default:
            return base
        }
    }

    private static let plane = [
        "..ww",
        ".ww.",
        "ww..",
        ".w..",
    ]

    @MainActor
    static func rows(_ author: String, event: AuthorEvent?) -> [String] {
        let base = Decor.apply(rows(author), author: author)
        guard let event else { return base }
        if event.leavesDesk { return emptyChair }
        switch event.id {
        case "nap":
            // 눈을 감고 머리 위에 Z
            return overlay(closeEyes(base), zee, x: 18, y: 2)
        case "ink":
            // 아래를 내려다본다. 쓰러진 잉크병은 책상 장면에 있다.
            return moveEyes(base, dx: 0, dy: 1)
        case "block":
            // 위를 올려다보고, 물음표와 땀방울
            return overlay(overlay(moveEyes(base, dx: 0, dy: -1), question, x: 18, y: 2), sweat, x: 6, y: 8)
        case "letter":
            // 아래를 보고, 가슴 앞에 편지
            return overlay(moveEyes(base, dx: 0, dy: 1), envelope, x: 7, y: 17)
        case "dark":
            // 어둠 속에 눈만 빛난다. 꺼진 초의 연기는 책상 장면에.
            return base.map { $0.replacingOccurrences(of: "e", with: "y") }
        case "author.Poe":
            // 오른쪽 어깨의 까마귀를 바라본다
            return overlay(moveEyes(base, dx: 1, dy: 0), raven, x: 17, y: 12)
        case "author.Stevenson":
            // 옆을 바라보고, 아래에 파도
            return overlay(moveEyes(base, dx: 1, dy: 0), waves, x: 0, y: 22)
        default:
            return base
        }
    }

    /// 초상화 뒤 책상 장면. 왼쪽 위 창문에 그때의 하늘(해·달·비·눈), 책상에 잉크병과 초.
    /// 상황에 따라 잉크병이 쓰러지고 초가 꺼진다. 초상화의 빈 칸으로 비쳐 보인다.
    static func scene(dayPart: DayPart?, weather: Weather?, event: AuthorEvent?, furniture: [String] = []) -> [String] {
        var g = Array(repeating: Array(repeating: Character("."), count: size), count: size)
        func put(_ x: Int, _ y: Int, _ c: Character) { if (0..<size).contains(x), (0..<size).contains(y) { g[y][x] = c } }
        let dark = dayPart?.isDark ?? false
        // 작업실 가구. 책장은 오른쪽 위, 커튼은 창 양옆, 난로는 왼쪽 벽, 탁상등은 책상 오른쪽, 안락의자는 어깨 뒤, 고양이는 창턱.
        if furniture.contains("shelf") {
            for y in 1...9 { for x in 17...23 { put(x, y, (x == 17 || x == 23 || y == 1 || y == 4 || y == 7 || y == 9) ? "f" : ".") } }
            for (i, c) in "dckhn".enumerated() { put(18 + i, 2, c); put(18 + i, 3, c) }
            for (i, c) in "hndkc".enumerated() { put(18 + i, 5, c); put(18 + i, 6, c) }
            for (i, c) in "kcdh".enumerated() { put(18 + i, 8, c) }
        }
        if furniture.contains("curtain") {
            for y in 0...9 { put(0, y, "R"); put(8, y, "R") }
            put(0, 10, "R"); put(8, 10, "R")
        }
        if furniture.contains("stove") {
            for y in 11...16 { for x in 0...2 { put(x, y, "k") } }
            put(1, 13, "y"); put(1, 14, "o"); put(0, 14, "y"); put(2, 14, "y")
            put(1, 9, "G"); put(1, 10, "G")
        }
        if furniture.contains("chair") {
            for x in [4, 5, 6, 17, 18, 19] { put(x, 15, "o"); put(x, 16, "O") }
        }
        // 창문: 틀 1~7열 1~8행, 유리 2~6열 2~7행, 가운데 살.
        for y in 1...8 { for x in 1...7 { put(x, y, (x == 1 || x == 7 || y == 1 || y == 8 || x == 4 || y == 5) ? "f" : "a") } }
        switch weather {
        case .rain, .storm:
            for (x, y) in [(2, 3), (3, 6), (5, 2), (6, 4), (2, 7), (6, 7), (5, 6)] { put(x, y, "q") }
            if weather == .storm { put(5, 2, "y"); put(5, 3, "y"); put(6, 4, "y") }
        case .snow:
            for (x, y) in [(2, 2), (5, 3), (3, 6), (6, 6), (2, 7)] { put(x, y, "w") }
        default:
            if dark {
                put(5, 2, "w"); put(6, 2, "w"); put(6, 3, "w")  // 달
            } else if weather != .fog && weather != .cloudy {
                put(5, 2, "y"); put(6, 2, "y"); put(5, 3, "y"); put(6, 3, "y")  // 해
                if weather == .heat { put(5, 4, "y"); put(6, 4, "y") }
            }
        }
        // 책상: 20행이 윗면, 아래는 앞판.
        for x in 0..<size { put(x, 20, "o"); put(x, 21, "O"); put(x, 22, "O"); put(x, 23, "O") }
        // 왼쪽 잉크병(쓰러지면 옆으로 눕고 잉크가 번진다), 오른쪽 초(어두우면 불이 켜지고, 꺼지면 연기).
        if event?.id == "ink" {
            put(0, 19, "k"); put(1, 19, "k"); put(2, 19, "k"); put(1, 20, "u"); put(2, 20, "u"); put(0, 20, "u")
        } else {
            put(1, 17, "q"); put(2, 17, "q"); put(1, 18, "k"); put(2, 18, "k"); put(1, 19, "k"); put(2, 19, "k")
        }
        put(21, 19, "o"); put(22, 19, "o"); put(23, 19, "o")
        put(22, 16, "w"); put(22, 17, "w"); put(22, 18, "w")
        if event?.id == "dark" {
            put(22, 14, "G"); put(21, 13, "G"); put(22, 12, "G")
        } else if dark {
            put(22, 15, "y"); put(22, 14, "o")
        }
        if furniture.contains("lamp") {
            // 탁상등: 갓과 대. 어두우면 켜진다.
            let shade: Character = dark && event?.id != "dark" ? "y" : "w"
            for x in 18...20 { put(x, 14, shade) }
            put(19, 13, shade); put(19, 15, "O"); put(19, 16, "O"); put(18, 17, "O"); put(19, 17, "O"); put(20, 17, "O")
        }
        if furniture.contains("cat") {
            // 창턱의 고양이. 창밖을 본다.
            put(2, 5, "H"); put(4, 5, "H"); put(2, 6, "H"); put(3, 6, "H"); put(4, 6, "H"); put(3, 5, "H")
            put(2, 7, "H"); put(3, 7, "H"); put(4, 7, "H"); put(5, 7, "H"); put(6, 6, "H")
        }
        return g.map { String($0) }
    }

    /// 장면 위에 초상화를 얹는다.
    static func compose(scene: [String], portrait: [String]) -> [String] { overlay(scene, portrait, x: 0, y: 0) }

    /// 서점 장면. 작가 책상 장면의 창문·책장·탁상등을 빌리고, 왼쪽에 책장을 하나 더, 가운데 앞치마를 두른 주인, 아래에 계산대.
    static func shopScene(dayPart: DayPart?, weather: Weather?) -> [String] {
        var rows = scene(dayPart: dayPart, weather: weather, event: nil, furniture: ["shelf", "lamp"])
        // 왼쪽 책장(창문 아래)
        let leftShelf = [
            "fffffff",
            "fdckhnf",
            "fdckhnf",
            "fffffff",
            "fhndkcf",
            "fhndkcf",
            "fffffff",
            "fkcdh.f",
            "fffffff",
        ]
        rows = overlay(rows, leftShelf, x: 0, y: 10)
        // 주인: 머리, 얼굴, 앞치마 두른 몸
        let keeper = [
            "..hhhh..",
            ".hhhhhh.",
            ".hssssh.",
            ".hsesesh",
            "..ssssS.",
            "..sSSss.",
            "...ss...",
            ".ccwwwcc",
            "ccccwwcc",
            "cccwwwcc",
            "cccwwwcc",
            "cccwwwcc",
        ]
        rows = overlay(rows, keeper, x: 8, y: 7)
        return rows
    }

    /// 어두운 때(저녁·밤)인지. 상시 창 초상화가 가라앉고 촛불이 켜진다.
    static func isNight(_ date: Date) -> Bool { DayPart.current(date).isDark }

    /// 그때의 색. 밤에는 가라앉고, 촛불이 꺼지면 어둡다. 창밖 하늘(`a`)은 때와 날씨대로.
    static func palette(event: AuthorEvent?, dayPart: DayPart?, weather: Weather?) -> [Character: Color] {
        var colors = palette
        colors["a"] = sky(dayPart: dayPart, weather: weather)
        let dark = event?.id == "dark"
        let night = dayPart?.isDark ?? false
        guard dark || night else { return colors }
        return colors.reduce(into: [:]) { result, pair in
            if dark, pair.key == "y" || pair.key == "G" || pair.key == "a" || pair.key == "f" { result[pair.key] = pair.value; return }
            if night, pair.key == "a" || pair.key == "y" { result[pair.key] = pair.value; return }
            let c = NSColor(pair.value).usingColorSpace(.deviceRGB) ?? .gray
            let k: (CGFloat, CGFloat, CGFloat) = dark ? (0.3, 0.3, 0.36) : (0.82, 0.8, 0.86)
            result[pair.key] = Color(red: c.redComponent * k.0, green: c.greenComponent * k.1, blue: c.blueComponent * k.2)
        }
    }

    /// 예전 호출. 때를 모르면 밤 여부만 본다.
    static func palette(for event: AuthorEvent?, night: Bool = false) -> [Character: Color] {
        palette(event: event, dayPart: night ? .night : nil, weather: nil)
    }

    /// 창밖 하늘 색.
    static func sky(dayPart: DayPart?, weather: Weather?) -> Color {
        switch weather {
        case .fog: return Color(red: 0.72, green: 0.72, blue: 0.74)
        case .storm: return Color(red: 0.3, green: 0.33, blue: 0.42)
        case .rain, .cloudy: return (dayPart?.isDark ?? false) ? Color(red: 0.1, green: 0.11, blue: 0.18) : Color(red: 0.6, green: 0.65, blue: 0.72)
        default: break
        }
        switch dayPart {
        case .dawn: return Color(red: 0.85, green: 0.65, blue: 0.7)
        case .morning: return Color(red: 0.78, green: 0.86, blue: 0.95)
        case .day, .none: return Color(red: 0.55, green: 0.75, blue: 0.95)
        case .dusk: return Color(red: 0.95, green: 0.6, blue: 0.35)
        case .evening: return Color(red: 0.2, green: 0.22, blue: 0.4)
        case .night: return Color(red: 0.08, green: 0.09, blue: 0.16)
        }
    }

    /// 벽 색. 촛불이 꺼지면 어둡게.
    static func backdrop(_ author: String, event: AuthorEvent?) -> Color {
        switch event?.id {
        case "dark": Color(red: 0.07, green: 0.07, blue: 0.1)
        // 까마귀가 보이게 달빛 든 창가처럼 밝게
        case "author.Poe": Color(red: 0.5, green: 0.54, blue: 0.66)
        default: backdrop(author)
        }
    }

    private static func closeEyes(_ rows: [String]) -> [String] {
        rows.map { $0.replacingOccurrences(of: "e", with: "S") }
    }

    /// 눈동자를 옮긴다. 원래 자리는 피부로 채운다.
    private static func moveEyes(_ rows: [String], dx: Int, dy: Int) -> [String] {
        var grid = rows.map(Array.init)
        let eyes = grid.indices.flatMap { y in grid[y].indices.filter { grid[y][$0] == "e" }.map { (x: $0, y: y) } }
        for eye in eyes { grid[eye.y][eye.x] = "s" }
        for eye in eyes {
            let x = eye.x + dx, y = eye.y + dy
            if grid.indices.contains(y), grid[y].indices.contains(x) { grid[y][x] = "e" }
        }
        return grid.map { String($0) }
    }

    /// `art` 의 `.` 이 아닌 칸을 (x, y) 에 덮어 그린다.
    static func overlay(_ rows: [String], _ art: [String], x: Int, y: Int) -> [String] {
        var grid = rows.map(Array.init)
        for (dy, line) in art.enumerated() {
            for (dx, ch) in line.enumerated() where ch != "." {
                let gx = x + dx, gy = y + dy
                if grid.indices.contains(gy), grid[gy].indices.contains(gx) { grid[gy][gx] = ch }
            }
        }
        return grid.map { String($0) }
    }

    private static let zee = [
        "www.",
        "..w.",
        "www.",
        "....",
        "..ww",
        "...w",
        "..ww",
    ]
    private static let question = [
        "www",
        "..w",
        ".ww",
        ".w.",
        "...",
        ".w.",
    ]
    private static let sweat = [
        "q",
        "q",
    ]
    /// 흰 옷깃 위에서도 보이게 회색 테두리를 두른다.
    private static let envelope = [
        "GGGGGGGGGG",
        "GwGwwwwGwG",
        "GwwGwwGwwG",
        "GwwwGGwwwG",
        "GGGGGGGGGG",
    ]
    private static let raven = [
        "..HH.",
        ".GyHH",
        "..HHH",
        ".HHHH",
        "HHHHH",
    ]
    private static let waves = [
        "q..qq..qq..qq..qq..qq..q",
        "uuuuuuuuuuuuuuuuuuuuuuuu",
    ]
}

/// 둥근 사각형에 담은 초상화. `scale` 은 16픽셀 시절의 크기 기준이라 그대로 두면 창 크기가 안 바뀐다(한 변 = 16 × scale).
struct PortraitFrame: View {
    let author: String
    var scale: CGFloat = 3
    /// 돌발 상황이면 그 상황 그림.
    var event: AuthorEvent? = nil
    var expression: Expression = .neutral
    /// 책상 장면(창문·초)을 뒤에 그릴지. 큰 초상화에만.
    var scene = false
    var furniture: [String] = []

    var body: some View {
        let side = 16 * scale
        let dayPart = scene ? DayPart.current() : nil
        let weather = scene ? Weather.of(Date()) : nil
        let portrait = Portraits.rows(author, event: event, mood: .focused, expression: expression)
        let rows = scene ? Portraits.compose(scene: Portraits.scene(dayPart: dayPart, weather: weather, event: event?.leavesDesk == true ? nil : event, furniture: furniture), portrait: portrait) : portrait
        PixelFrame(rows: rows, scale: side / CGFloat(Portraits.size), palette: Portraits.palette(event: event, dayPart: dayPart, weather: weather))
            .frame(width: side, height: side)
            .background(Portraits.backdrop(author, event: event))
            .clipShape(RoundedRectangle(cornerRadius: side * 0.22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: side * 0.22, style: .continuous).stroke(.white.opacity(0.12)))
    }
}

/// 하루를 여섯 때로 나눈다. 상시 창 바탕에 그때의 색이 옅게 깔리고, 어두운 때는 글자와 고리를 밝은 쪽으로 바꾼다.
enum DayPart: String, CaseIterable, Sendable {
    case dawn, morning, day, dusk, evening, night

    static func current(_ date: Date = Date()) -> DayPart {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<8: .dawn
        case 8..<12: .morning
        case 12..<17: .day
        case 17..<19: .dusk
        case 19..<22: .evening
        default: .night
        }
    }

    var title: String {
        L10n.tr({ switch self {
        case .dawn: "새벽"
        case .morning: "아침"
        case .day: "낮"
        case .dusk: "해 질 녘"
        case .evening: "저녁"
        case .night: "밤"
        } }())
    }

    /// 바탕에 입히는 색. 불투명도까지 넣었다.
    var tint: Color {
        switch self {
        case .dawn: Color(red: 0.8, green: 0.6, blue: 0.78).opacity(0.18)
        case .morning: Color(red: 1.0, green: 0.9, blue: 0.6).opacity(0.14)
        case .day: Color(red: 0.65, green: 0.82, blue: 1.0).opacity(0.08)
        case .dusk: Color(red: 1.0, green: 0.62, blue: 0.32).opacity(0.18)
        case .evening: Color(red: 0.08, green: 0.08, blue: 0.14).opacity(0.38)
        case .night: Color(red: 0.0, green: 0.0, blue: 0.02).opacity(0.5)
        }
    }

    /// 바탕이 어두워지는 때. 그 위의 글자와 고리는 어두운 모드 색을 쓴다.
    var isDark: Bool { self == .evening || self == .night }

    /// 그 시각의 바탕 색조. 시각마다 정한 색 사이를 분 단위로 이어 붙여 하루 내내 조금씩 바뀐다.
    /// 해 뜨는 때와 지는 때는 현재 시간대의 천문 일출·일몰 시각을 따른다.
    static func tint(at date: Date, calendar: Calendar = .current) -> Color {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(comps.hour ?? 12) + Double(comps.minute ?? 0) / 60
        let (sunrise, sunset) = Celestial.sunTimes(on: date, calendar: calendar)
        // (시각, 빨강, 초록, 파랑, 불투명도). 아침 쪽은 해 뜨는 때에, 저녁 쪽은 해 지는 때에 맞춰 옮긴다.
        let keys: [(Double, Double, Double, Double, Double)] = [
            (0, 0.02, 0.02, 0.08, 0.55),
            (max(0.5, sunrise - 1.4), 0.02, 0.02, 0.10, 0.55),
            (sunrise - 0.8, 0.45, 0.30, 0.55, 0.38),
            (sunrise, 0.95, 0.60, 0.55, 0.32),
            (sunrise + 1.5, 1.00, 0.85, 0.55, 0.24),
            (sunrise + 3.5, 0.92, 0.93, 0.80, 0.16),
            (13, 0.60, 0.80, 1.00, 0.16),
            (sunset - 2.5, 0.88, 0.86, 0.65, 0.16),
            (sunset - 0.5, 1.00, 0.60, 0.30, 0.32),
            (sunset + 0.5, 0.85, 0.40, 0.45, 0.38),
            (sunset + 1.5, 0.20, 0.18, 0.45, 0.44),
            (sunset + 3.0, 0.08, 0.08, 0.20, 0.50),
            (23, 0.03, 0.03, 0.10, 0.55),
            (24, 0.02, 0.02, 0.08, 0.55),
        ].sorted { $0.0 < $1.0 }
        var lower = keys[0], upper = keys[keys.count - 1]
        for (i, key) in keys.enumerated() where key.0 <= hour {
            lower = key
            upper = i + 1 < keys.count ? keys[i + 1] : key
        }
        let span = max(0.001, upper.0 - lower.0)
        let t = max(0, min(1, (hour - lower.0) / span))
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
        return Color(red: mix(lower.1, upper.1), green: mix(lower.2, upper.2), blue: mix(lower.3, upper.3)).opacity(mix(lower.4, upper.4))
    }

    /// 그 시각에 바탕이 어두운지. 해 진 뒤 한 시간 반부터 해 뜨기 한 시간 전까지.
    static func isDark(at date: Date, calendar: Calendar = .current) -> Bool {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(comps.hour ?? 12) + Double(comps.minute ?? 0) / 60
        let (sunrise, sunset) = Celestial.sunTimes(on: date, calendar: calendar)
        return hour >= sunset + 1.5 || hour < sunrise - 1.0
    }

    /// 유리를 다시 만들 간격(10분). 색조만 바꾸면 유리가 전 색을 그대로 들고 있어서 때때로 새로 만든다.
    static func tintKey(at date: Date) -> Int { Int(date.timeIntervalSinceReferenceDate / 600) }
}
