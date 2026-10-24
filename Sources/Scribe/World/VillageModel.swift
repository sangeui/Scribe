import AppKit
import SwiftUI

// MARK: - 맵

enum VillageMap {
    static let tile = VillageTiles.size
    static let cols = 14
    static let rows = 12
    /// 1.5배. 레티나에서 그림 한 점이 기기 픽셀 셋이라 또렷하다.
    static let scale: CGFloat = 1.5
    static var width: Int { cols * tile }
    static var height: Int { rows * tile }

    /// 가장자리 나무(4~6행 양끝).
    static let trees: [(Int, Int)] = [(0, 5), (0, 6), (13, 5), (13, 6), (0, 8), (13, 8), (0, 10), (13, 10)]

    /// 장작더미 열. 작업실 문 오른쪽 벽 앞(3행).
    static let woodpileCol = VillageBuilding.workshop.left + 3

    /// 5시간 한도에서 남은 몫을 장작 수로. 조금이라도 남으면 하나는 있다.
    static func logs(_ fuel: LimitRow) -> Int {
        let left = min(100, max(0, 100 - fuel.percent))
        return Int((left / 100 * Double(VillageTiles.logSpots.count)).rounded(.up))
    }

    /// 서점 옆 팻말 타일.
    static let signpost = (col: VillageBuilding.bookstore.left + 3, row: 4)

    /// 살롱이 차지하는 칸(7~9행, 5~8열).
    static func insideSalon(col: Int, row: Int) -> Bool {
        (VillageBuilding.salon.top...(VillageBuilding.salon.top + 2)).contains(row) && (VillageBuilding.salon.left...(VillageBuilding.salon.left + 3)).contains(col)
    }

    /// 바닥 4~6행과 7~10행(살롱 자리 빼고). 문 줄은 문 타일만. 나무와 팻말 자리는 못 지나간다.
    static func walkable(col: Int, row: Int) -> Bool {
        guard (0..<cols).contains(col) else { return false }
        if (col, row) == signpost { return false }
        if trees.contains(where: { $0 == (col, row) }) { return false }
        if (4...6).contains(row) { return true }
        if (7...10).contains(row) {
            if VillageBuilding.salon.doorCol == col, row == VillageBuilding.salon.doorRow { return true }
            return !insideSalon(col: col, row: row)
        }
        if row == 3 { return VillageBuilding.allCases.contains { $0.top == 1 && $0.doorCol == col } }
        return false
    }

    /// 문 바로 앞 타일이면 그 건물.
    static func door(col: Int, row: Int) -> VillageBuilding? {
        VillageBuilding.allCases.first { $0.doorCol == col && $0.frontRow == row }
    }

    /// 날씨가 바꾸는 색. 더위엔 바닥이 누렇게 바래고, 눈 오는 날엔 바닥·지붕·나뭇잎이 하얗게 덮인다.
    static func palette(weather: Weather) -> [Character: Color] {
        var colors = VillageTiles.palette
        switch weather {
        case .heat:
            colors["e"] = Color(red: 0.86, green: 0.85, blue: 0.7)
            colors["f"] = Color(red: 0.7, green: 0.68, blue: 0.54)
            colors["b"] = Color(red: 0.68, green: 0.82, blue: 0.4)
        case .snow:
            colors["e"] = Color(red: 0.93, green: 0.95, blue: 0.97)
            colors["f"] = Color(red: 0.78, green: 0.82, blue: 0.88)
            colors["G"] = Color(red: 0.96, green: 0.97, blue: 0.99)
            colors["I"] = colors["G"]; colors["V"] = colors["G"]
            colors["g"] = Color(red: 0.86, green: 0.89, blue: 0.94)
            colors["i"] = Color(red: 0.88, green: 0.87, blue: 0.9)
            colors["u"] = Color(red: 0.84, green: 0.87, blue: 0.95)
            colors["b"] = Color(red: 0.86, green: 0.92, blue: 0.9)
        default: break
        }
        return colors
    }

    /// 밤에는 게임의 밤처럼 전체가 푸르게 가라앉고 창문만 불을 켠다.
    static func palette(dark: Bool, weather: Weather = .clear) -> [Character: Color] {
        let base = palette(weather: weather)
        guard dark else { return base }
        return base.reduce(into: [:]) { result, pair in
            if pair.key == "k" { result[pair.key] = pair.value; return }
            let c = NSColor(pair.value).usingColorSpace(.deviceRGB) ?? .gray
            result[pair.key] = Color(red: c.redComponent * 0.22 + 0.03, green: c.greenComponent * 0.3 + 0.05, blue: c.blueComponent * 0.48 + 0.2)
        }
    }

    /// 맵에 비추는 상태. 밤인지, 작업실에 불이 켜졌는지(글 쓰는 중), 서점이 품절인지, 창고 앞 상자 수(0~3), 광고 벽보.
    struct Scene: Hashable {
        var dark = false
        var workshopLit = false
        var soldOut = false
        var crates = 1
        var poster = false
        /// 글 쓰는 중이면 굴뚝에 연기.
        var workshopSmoke = false
        var weather: Weather = .clear
        /// 작업실 앞 장작 수(0~6). 5시간 한도가 남은 만큼. 한도를 못 읽었으면 nil 이고 장작더미가 없다.
        var logs: Int?

        @MainActor
        init(progress: WritingProgress, date: Date, fuel: LimitRow? = nil) {
            logs = fuel.map(VillageMap.logs)
            weather = progress.weather
            dark = DayPart.isDark(at: date)
            workshopLit = dark && progress.activeEvent == nil
            workshopSmoke = progress.activeEvent == nil && progress.todayCharacters > 0
            soldOut = !progress.shop.reprints.isEmpty
            let items = ItemKind.allCases.reduce(0) { $0 + progress.count($1) }
            crates = items == 0 ? 0 : items <= 5 ? 1 : items <= 12 ? 2 : 3
            poster = !progress.ads.isEmpty
        }

        init() {}
    }

    /// 맵 한 장. 바닥을 깔고 위아래와 양옆에 나무를 두르고, 건물 셋을 지붕 두 줄·벽 한 줄로 세운다.
    static func rows(_ scene: Scene) -> [String] {
        var grid = [[Character]](repeating: [Character](repeating: "e", count: width), count: height)
        func stamp(_ tileRows: [String], col: Int, row: Int, swap: [Character: Character] = [:], dx offsetX: Int = 0, dy offsetY: Int = 0) {
            for (dy, line) in tileRows.enumerated() {
                for (dx, ch) in line.enumerated() where ch != "." {
                    let x = col * tile + dx + offsetX, y = row * tile + dy + offsetY
                    guard (0..<width).contains(x), (0..<height).contains(y) else { continue }
                    grid[y][x] = swap[ch] ?? ch
                }
            }
        }
        func put(_ x: Int, _ y: Int, _ ch: Character) {
            guard (0..<width).contains(x), (0..<height).contains(y) else { return }
            grid[y][x] = ch
        }
        for col in 0..<cols {
            for row in 0..<rows { stamp(VillageTiles.ground, col: col, row: row) }
            stamp(VillageTiles.tree, col: col, row: 0)
            stamp(VillageTiles.tree, col: col, row: 11)
            if col == 2 || col == 7 || col == 11 { stamp(VillageTiles.flowers, col: col, row: 6) }
            if col == 1 || col == 12 { stamp(VillageTiles.flowers, col: col, row: 9) }
            if col == 3 || col == 10 { stamp(VillageTiles.flowers, col: col, row: 10) }
        }
        for (col, row) in trees { stamp(VillageTiles.tree, col: col, row: row) }
        for building in VillageBuilding.allCases {
            let l = building.left
            // 밤에는 작업실(글 쓰는 중일 때)과 서점에 불이 켜지고 창고는 어둡다. 꺼진 창은 회색.
            let lit = scene.dark && (building == .workshop ? scene.workshopLit : building != .storage)
            let windowSwap: [Character: Character] = scene.dark && !lit ? ["k": "v"] : [:]
            stamp(building.sprite, col: l, row: building.top, swap: windowSwap)
            switch building {
            case .workshop:
                for (dx, dy) in VillageTiles.logSpots.prefix(scene.logs ?? 0) {
                    stamp(VillageTiles.log, col: woodpileCol, row: 3, dx: dx, dy: dy)
                }
            case .storage:
                if scene.crates >= 1 { stamp(VillageTiles.crate, col: l, row: 3, dx: -1, dy: 1) }
                if scene.crates >= 2 { stamp(VillageTiles.crate, col: l + 3, row: 3, dx: 1, dy: 1) }
                if scene.crates >= 3 { stamp(VillageTiles.crate, col: l, row: 3, dx: -1, dy: -6) }
            case .bookstore:
                if scene.poster { stamp(VillageTiles.poster, col: l + 3, row: 3, dx: 2, dy: 4) }
                stamp(VillageTiles.signpost, col: signpost.col, row: signpost.row)
            case .salon: break
            }
        }
        return grid.map { String($0) }
    }
}

// MARK: - 사람

/// 사용자. 모자 쓴 사람. 아래·위·왼쪽 세 방향에 서 있는 모습과 걷는 모습 둘. 오른쪽은 왼쪽을 뒤집는다.
enum Player {
    enum Facing { case down, up, left, right }

    static let palette: [Character: Color] = [
        "x": Color(red: 0.2, green: 0.2, blue: 0.23),
        "r": Color(red: 0.92, green: 0.85, blue: 0.4),
        "R": Color(red: 0.2, green: 0.2, blue: 0.23),
        "s": Color(red: 0.98, green: 0.86, blue: 0.72),
        "h": Color(red: 0.2, green: 0.2, blue: 0.23),
        "w": Color(red: 0.8, green: 0.33, blue: 0.26),
        "b": Color(red: 0.25, green: 0.25, blue: 0.3),
        "k": Color(red: 0.92, green: 0.85, blue: 0.4),
        "o": Color(red: 0.72, green: 0.56, blue: 0.3),
    ]

    static let downStand = [
        "......xxxx......",
        "....xxrrrrxx....",
        "...xrrrrrrrrx...",
        "...xrrrrrrrrx...",
        "..xRRRRRRRRRRx..",
        "...xhsssssshx...",
        "...xsxssssxsx...",
        "...xssssssssx...",
        "....xsssssSx....",
        "...xxwwwwwwxx...",
        "..xsxwwwwwwxsx..",
        "..xxxwwwwwwxxx..",
        "....xbbbbbbx....",
        "....xbbxxbbx....",
        "....xkkxxkkx....",
        "....xxxxxxxx....",
    ]
    static let downWalkA = [
        "......xxxx......",
        "....xxrrrrxx....",
        "...xrrrrrrrrx...",
        "...xrrrrrrrrx...",
        "..xRRRRRRRRRRx..",
        "...xhsssssshx...",
        "...xsxssssxsx...",
        "...xssssssssx...",
        "....xsssssSx....",
        "...xxwwwwwwxx...",
        "..xsxwwwwwwxxx..",
        "..xxxwwwwwwxsx..",
        "....xbbbbbbxx...",
        "....xbbxxbbx....",
        "...xkkx.xkkx....",
        "...xxxx.xxxx....",
    ]
    static let downWalkB = downWalkA.map { String($0.reversed()) }

    static let upStand = [
        "......xxxx......",
        "....xxrrrrxx....",
        "...xrrrrrrrrx...",
        "...xrrrrrrrrx...",
        "...xrrrrrrrrx...",
        "...xhhhhhhhhx...",
        "...xhhhhhhhhx...",
        "....xhhhhhhx....",
        "....xsssssSx....",
        "...xxwwooowwx...",
        "..xsxwooooowxs..",
        "..xxxwooooowxx..",
        "....xbbooobbx...",
        "....xbbxxbbx....",
        "....xkkxxkkx....",
        "....xxxxxxxx....",
    ]
    static let upWalkA = [
        "......xxxx......",
        "....xxrrrrxx....",
        "...xrrrrrrrrx...",
        "...xrrrrrrrrx...",
        "...xrrrrrrrrx...",
        "...xhhhhhhhhx...",
        "...xhhhhhhhhx...",
        "....xhhhhhhx....",
        "....xsssssSx....",
        "...xxwwooowwx...",
        "..xsxwooooowxxx.",
        "..xxxwooooowxsx.",
        "....xbbooobbxx..",
        "....xbbxxbbx....",
        "...xkkx.xkkx....",
        "...xxxx.xxxx....",
    ]
    static let upWalkB = upWalkA.map { String($0.reversed()) }

    static let leftStand = [
        "......xxxx......",
        "....xxrrrrxx....",
        "...xrrrrrrrrx...",
        "..xrrrrrrrrrx...",
        "..xRRRRRRRRRx...",
        "...xhsssshhhx...",
        "....xxsssshx....",
        "....xssssshx....",
        "....xsssssx.....",
        "....xxwwwwxx....",
        "....xwwwwwwsx...",
        "....xwwwwwwxx...",
        ".....xbbbbbx....",
        ".....xbbbbbx....",
        ".....xkkkkkx....",
        ".....xxxxxxx....",
    ]
    static let leftWalkA = [
        "......xxxx......",
        "....xxrrrrxx....",
        "...xrrrrrrrrx...",
        "..xrrrrrrrrrx...",
        "..xRRRRRRRRRx...",
        "...xhsssshhhx...",
        "....xxsssshx....",
        "....xssssshx....",
        "....xsssssx.....",
        "....xxwwwwxx....",
        "...xswwwwwwx....",
        "....xwwwwwwx....",
        ".....xbbbbbx....",
        "....xbbbxbbbx...",
        "...xkkkxxxkkx...",
        "....xxxx.xxxx...",
    ]
    static let leftWalkB = [
        "......xxxx......",
        "....xxrrrrxx....",
        "...xrrrrrrrrx...",
        "..xrrrrrrrrrx...",
        "..xRRRRRRRRRx...",
        "...xhsssshhhx...",
        "....xxsssshx....",
        "....xssssshx....",
        "....xsssssx.....",
        "....xxwwwwxx....",
        "....xwwwwwwwsx..",
        "....xwwwwwwxx...",
        ".....xbbbbbx....",
        ".....xbbbbbx....",
        "....xkkkkkkkx...",
        ".....xxxxxxx....",
    ]

    /// 손님 한 사람의 생김새. 머리(위 9줄)는 방향마다 따로 그리고, 몸은 사용자 그림을 옷 색만 바꿔 쓴다.
    struct Look {
        let down: [String]
        let up: [String]
        let left: [String]
        let palette: [Character: Color]
    }

    /// `Persona.all` 과 같은 순서. 단골 할아버지, 학생 손님, 비평가 지망생, 장꾼.
    static let customers: [Look] = [
        // 납작한 사냥 모자, 흰 귀밑머리와 콧수염, 갈색 조끼.
        Look(down: [
            "................",
            ".....xxxxxx.....",
            "....xrrrrrrx....",
            "...xrrrrrrrrx...",
            "...xRRRRRRRRx...",
            "...xhsssssshx...",
            "...xsxssssxsx...",
            "...xsWWWWWWsx...",
            "....xsssssSx....",
        ], up: [
            "................",
            ".....xxxxxx.....",
            "....xrrrrrrx....",
            "...xrrrrrrrrx...",
            "...xrrrrrrrrx...",
            "...xhhhhhhhhx...",
            "...xhhhhhhhhx...",
            "....xhhhhhhx....",
            "....xsssssSx....",
        ], left: [
            "................",
            ".....xxxxxx.....",
            "....xrrrrrrx....",
            "...xrrrrrrrrx...",
            "..xRRRRRRRRx....",
            "...xhsssshhhx...",
            "....xxsssshx....",
            "....xWWsshhx....",
            "....xsssssx.....",
        ], palette: palette.merging([
            "r": Color(red: 0.55, green: 0.5, blue: 0.42), "R": Color(red: 0.4, green: 0.36, blue: 0.3),
            "h": Color(red: 0.88, green: 0.88, blue: 0.86), "W": Color(red: 0.95, green: 0.95, blue: 0.93),
            "w": Color(red: 0.55, green: 0.38, blue: 0.22), "o": Color(red: 0.55, green: 0.38, blue: 0.22),
            "b": Color(red: 0.42, green: 0.42, blue: 0.45), "k": Color(red: 0.3, green: 0.22, blue: 0.16),
        ]) { $1 }),
        // 모자 없이 까만 머리, 남색 교복, 빨간 책가방(뒤에서 보인다).
        Look(down: [
            "................",
            "................",
            ".....xxxxxx.....",
            "....xhhhhhhx....",
            "...xhhhhhhhhx...",
            "...xhhsssshhx...",
            "...xsxssssxsx...",
            "...xssssssssx...",
            "....xsssssSx....",
        ], up: [
            "................",
            "................",
            ".....xxxxxx.....",
            "....xhhhhhhx....",
            "...xhhhhhhhhx...",
            "...xhhhhhhhhx...",
            "...xhhhhhhhhx...",
            "....xhhhhhhx....",
            "....xsssssSx....",
        ], left: [
            "................",
            "................",
            ".....xxxxxx.....",
            "....xhhhhhhx....",
            "...xhhhhhhhhx...",
            "...xhssshhhhx...",
            "....xxsssshx....",
            "....xssssshx....",
            "....xsssssx.....",
        ], palette: palette.merging([
            "h": Color(red: 0.16, green: 0.16, blue: 0.2),
            "w": Color(red: 0.24, green: 0.3, blue: 0.55), "o": Color(red: 0.85, green: 0.25, blue: 0.22),
            "b": Color(red: 0.2, green: 0.24, blue: 0.42), "k": Color(red: 0.95, green: 0.95, blue: 0.95),
        ]) { $1 }),
        // 비스듬한 베레모, 둥근 안경, 검은 터틀넥.
        Look(down: [
            "................",
            "......xxxxx.....",
            "....xxrrrrrxx...",
            "...xrrrrrrrrrx..",
            "...xxxxxxxxxx...",
            "...xhsssssshx...",
            "...xsgxggxgsx...",
            "...xssssssssx...",
            "....xsssssSx....",
        ], up: [
            "................",
            "......xxxxx.....",
            "....xxrrrrrxx...",
            "...xrrrrrrrrrx..",
            "...xxxxxxxxxx...",
            "...xhhhhhhhhx...",
            "...xhhhhhhhhx...",
            "....xhhhhhhx....",
            "....xsssssSx....",
        ], left: [
            "................",
            "......xxxxx.....",
            "....xxrrrrrxx...",
            "...xrrrrrrrrrx..",
            "...xxxxxxxxxx...",
            "...xhsssshhhx...",
            "...xgxgsshhx....",
            "....xssssshx....",
            "....xsssssx.....",
        ], palette: palette.merging([
            "r": Color(red: 0.6, green: 0.16, blue: 0.2),
            "h": Color(red: 0.45, green: 0.3, blue: 0.2), "g": Color(red: 0.75, green: 0.6, blue: 0.25),
            "w": Color(red: 0.18, green: 0.18, blue: 0.21), "o": Color(red: 0.18, green: 0.18, blue: 0.21),
            "b": Color(red: 0.35, green: 0.35, blue: 0.38), "k": Color(red: 0.12, green: 0.12, blue: 0.14),
        ]) { $1 }),
        // 챙 넓은 밀짚모자, 초록 앞치마, 등에 진 보따리.
        Look(down: [
            "................",
            "......xxxx......",
            ".....xrrrrx.....",
            "....xrrrrrrx....",
            "xRRRRRRRRRRRRRRx",
            ".xxxssssssssxxx.",
            "...xsxssssxsx...",
            "...xssssssssx...",
            "....xsssssSx....",
        ], up: [
            "................",
            "......xxxx......",
            ".....xrrrrx.....",
            "....xrrrrrrx....",
            "xRRRRRRRRRRRRRRx",
            ".xxxhhhhhhhhxxx.",
            "...xhhhhhhhhx...",
            "....xhhhhhhx....",
            "....xsssssSx....",
        ], left: [
            "................",
            "......xxxx......",
            ".....xrrrrx.....",
            "....xrrrrrrx....",
            "xRRRRRRRRRRRRRRx",
            ".xxxsssshhhhxxx.",
            "....xxsssshx....",
            "....xssssshx....",
            "....xsssssx.....",
        ], palette: palette.merging([
            "r": Color(red: 0.9, green: 0.78, blue: 0.42), "R": Color(red: 0.8, green: 0.66, blue: 0.3),
            "h": Color(red: 0.35, green: 0.22, blue: 0.12), "s": Color(red: 0.86, green: 0.68, blue: 0.5),
            "w": Color(red: 0.36, green: 0.55, blue: 0.3), "o": Color(red: 0.62, green: 0.44, blue: 0.24),
            "b": Color(red: 0.4, green: 0.32, blue: 0.24), "k": Color(red: 0.3, green: 0.22, blue: 0.16),
        ]) { $1 }),
    ]

    /// 손님 그림. 몸은 사용자 그림, 위 9줄은 그 사람의 머리.
    static func customerRows(_ index: Int, facing: Facing, step: Int) -> [String] {
        let look = customers[index % customers.count]
        let body = rows(facing: facing, step: step)
        let head = switch facing {
        case .down: look.down
        case .up: look.up
        case .left: look.left
        case .right: look.left.map { String($0.reversed()) }
        }
        return head + body.dropFirst(head.count)
    }

    /// 방향과 걸음(0 서 있음, 1·2 걷는 중)에 맞는 그림.
    static func rows(facing: Facing, step: Int) -> [String] {
        switch facing {
        case .down: step == 0 ? downStand : step == 1 ? downWalkA : downWalkB
        case .up: step == 0 ? upStand : step == 1 ? upWalkA : upWalkB
        case .left: step == 0 ? leftStand : step == 1 ? leftWalkA : leftWalkB
        case .right: (step == 0 ? leftStand : step == 1 ? leftWalkA : leftWalkB).map { String($0.reversed()) }
        }
    }
}

// MARK: - 걷기

/// 사람 자리와 방향. 타일 사이를 픽셀로 걸어간다. 한 칸에 0.17초, 앞 반은 걷는 그림, 뒤 반은 서 있는 그림(게임의 걸음 리듬).
@Observable
@MainActor
final class VillageState {
    /// 서 있거나 가고 있는 목표 타일.
    var col = 7
    var row = 5
    /// 지금 자리(타일 단위, 소수). 걷는 동안 col·row 로 다가간다.
    var x = 7.0
    var y = 5.0
    var facing: Player.Facing = .down
    /// 0 이면 서 있고 1·2 면 걷는 그림.
    var step = 0

    enum Key { case up, down, left, right, enter, escape }

    private var held: Key?
    private var walker: Task<Void, Never>?
    private var moving = false
    private var alternate = false
    static let stepSeconds = 0.17
    /// 문에 들어갈 때 부른다.
    var onEnter: (@MainActor (VillageBuilding) -> Void)?
    /// 문을 열고 들어가는 중인 건물. 문이 열리고 화면이 어두워진다.
    var entering: VillageBuilding?

    /// 앞에 선 것. Return 을 누르면 말을 건다.
    enum Target: Equatable { case npc(Int), window, mailbox, signpost, crates, shopWindow, pickup, woodpile }
    /// 작업실 앞에 장작더미가 있는지. 한도를 읽었을 때만 있다.
    var woodpile = false
    /// 열려 있는 대화 상자.
    var dialogue: Dialogue?
    /// 화면이 대화를 만들어 줘야 하는 대상. 화면이 읽고 비운다.
    var pendingInteraction: Target?
    /// 대화의 선택지 결과. 화면이 읽고 비운다.
    var pendingAction: Dialogue.Action?
    /// 오늘 풀밭에 떨어진 물건의 타일.
    var pickupTile: (col: Int, row: Int)?
    /// 몇 번째 말인지. 같은 사람에게 거듭 말을 걸면 다른 말이 나온다.
    var talkTurn = 0

    /// 바라보는 타일에 있는 것.
    var target: Target? {
        let (dx, dy) = Self.offset(of: facing)
        return thing(at: col + dx, row + dy)
    }

    /// 그 타일에 있는 것. 손님, 3행 벽의 창문·우체통·상자·진열창, 팻말, 풀밭의 물건.
    func thing(at col: Int, _ row: Int) -> Target? {
        if let npc = npcs.first(where: { $0.col == col && $0.row == row }) { return .npc(npc.id) }
        if row == 3 {
            switch col {
            case VillageBuilding.workshop.left: return .window
            case VillageBuilding.workshop.left + 1: return .mailbox
            case VillageMap.woodpileCol: return woodpile ? .woodpile : nil
            case VillageBuilding.storage.left, VillageBuilding.storage.left + 3: return .crates
            case VillageBuilding.bookstore.left, VillageBuilding.bookstore.left + 1: return .shopWindow
            default: return nil
            }
        }
        if (col, row) == VillageMap.signpost { return .signpost }
        if let tile = pickupTile, tile == (col, row) { return .pickup }
        return nil
    }

    /// 사람이 들어갈 수 있는 타일. 맵이 막지 않고 손님도 없다.
    func open(_ col: Int, _ row: Int) -> Bool {
        VillageMap.walkable(col: col, row: row) && !npcs.contains { $0.col == col && $0.row == row }
    }

    /// 서점 앞 손님. 제자리 둘레를 어슬렁거린다.
    struct NPC: Identifiable {
        let id: Int
        var col: Int
        var row: Int
        var x: Double
        var y: Double
        var facing: Player.Facing = .down
        var step = 0
        var home: Int
        var nextAt: ContinuousClock.Instant = .now
        var from: (Double, Double)?
        var startedAt: ContinuousClock.Instant = .now
        var alternate = false
    }
    var npcs: [NPC] = []
    private var npcLoop: Task<Void, Never>?
    static let npcStepSeconds = 0.3

    /// 손님 수를 맞춘다. 늘면 서점 앞 왼쪽에 세우고, 줄면 뒤에서부터 뺀다.
    func setCustomers(_ count: Int, leaving: Bool) {
        let door = VillageBuilding.bookstore.doorCol
        while npcs.count > count { npcs.removeLast() }
        while npcs.count < count {
            let i = npcs.count
            let col = door - 1 - i
            npcs.append(NPC(id: i, col: col, row: 4, x: Double(col), y: 4, facing: leaving ? .down : .right, home: col,
                            nextAt: .now + .milliseconds(Persona.all[i % Persona.all.count].wait.lowerBound + i * 300)))
        }
        if !npcs.isEmpty, npcLoop == nil { startNPCs() }
        if npcs.isEmpty { npcLoop?.cancel(); npcLoop = nil }
    }

    /// 손님들이 때때로 돌아서거나 한 칸 걷는다. 집 둘레 두 칸 안에서만, 문 앞과 사람·다른 손님 자리는 피한다.
    private func startNPCs() {
        npcLoop?.cancel()
        npcLoop = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                let now = ContinuousClock.now
                for i in self.npcs.indices {
                    var npc = self.npcs[i]
                    if let from = npc.from {
                        let t = min(1, (now - npc.startedAt) / .seconds(Self.npcStepSeconds))
                        npc.x = from.0 + (Double(npc.col) - from.0) * t
                        npc.y = from.1 + (Double(npc.row) - from.1) * t
                        npc.step = t < 0.5 ? (npc.alternate ? 1 : 2) : 0
                        let persona = Persona.all[npc.id % Persona.all.count]
                        if t >= 1 { npc.from = nil; npc.step = 0; npc.nextAt = now + .milliseconds(Int.random(in: persona.wait)) }
                    } else if now >= npc.nextAt, self.dialogue == nil {
                        let persona = Persona.all[npc.id % Persona.all.count]
                        let dirs: [(Int, Int, Player.Facing)] = [(0, -1, .up), (0, 1, .down), (-1, 0, .left), (1, 0, .right)]
                        let (dx, dy, facing) = dirs[Int.random(in: 0..<4)]
                        npc.facing = facing
                        let next = (npc.col + dx, npc.row + dy)
                        let taken = (next.0 == self.col && next.1 == self.row) || self.npcs.contains { $0.id != npc.id && $0.col == next.0 && $0.row == next.1 }
                        let doorFront = VillageBuilding.allCases.contains { $0.doorCol == next.0 && $0.frontRow == next.1 }
                        if Double.random(in: 0..<1) < persona.walkChance, VillageMap.walkable(col: next.0, row: next.1), abs(next.0 - npc.home) <= 2, next.1 >= 4, !taken, !doorFront {
                            npc.from = (npc.x, npc.y)
                            npc.col = next.0
                            npc.row = next.1
                            npc.startedAt = now
                            npc.alternate.toggle()
                        } else {
                            npc.nextAt = now + .milliseconds(Int.random(in: persona.wait))
                        }
                    }
                    self.npcs[i] = npc
                }
            }
        }
    }

    /// 방향키를 눌렀다. 바라보는 쪽이 다르면 먼저 돌아서고, 누르고 있는 동안 쉬지 않고 걷는다.
    func press(_ key: Key) {
        // 대화 상자가 열려 있으면 그 안에서만 움직인다.
        if var open = dialogue {
            switch key {
            case .enter:
                if !open.isLast { open.page += 1; dialogue = open }
                else if !open.options.isEmpty { pendingAction = open.options[open.selected].action; dialogue = nil }
                else { dialogue = nil }
            case .left: open.selected = max(0, open.selected - 1); dialogue = open
            case .right: open.selected = min(max(0, open.options.count - 1), open.selected + 1); dialogue = open
            case .escape: dialogue = nil
            default: break
            }
            return
        }
        guard [.up, .down, .left, .right].contains(key) else {
            if key == .enter, !moving, entering == nil { act() }
            return
        }
        held = key
        if moving { return }
        let turned = facing != direction(of: key)
        facing = direction(of: key)
        walker?.cancel()
        walker = Task { [weak self] in
            if turned { try? await Task.sleep(for: .milliseconds(40)) }
            await self?.walk()
        }
    }

    /// 방향키를 뗐다. 가던 칸까지는 간다.
    func release(_ key: Key) {
        if held == key { held = nil }
    }

    var isEntering: Bool { entering != nil }

    /// 창을 떠나면 그 자리에 선다. 손님들도 멈춘다.
    func stop() {
        held = nil
        walker?.cancel()
        walker = nil
        npcLoop?.cancel()
        npcLoop = nil
        moving = false
        entering = nil
        dialogue = nil
        x = Double(col)
        y = Double(row)
        step = 0
    }

    /// 맵이 다시 보이면 손님들이 다시 움직인다.
    func resume() {
        if !npcs.isEmpty, npcLoop == nil { startNPCs() }
    }

    /// 문을 열고 한 칸 올라가 들어간다. 0.35초 뒤에 `onEnter`.
    private func enter(_ building: VillageBuilding) async {
        entering = building
        held = nil
        let from = Double(row)
        let start = ContinuousClock.now
        var t = 0.0
        while t < 1, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(12))
            t = min(1, (start.duration(to: .now)) / .seconds(0.35))
            y = from - t
            step = t < 0.5 ? 1 : (t < 0.9 ? 2 : 0)
        }
        onEnter?(building)
    }

    /// Return. 바라보는 것이 있으면 말을 걸고, 없으면 옆에 있는 것 쪽으로 돌아서 말을 건다.
    /// 그것도 없이 문 앞이면 어느 쪽을 보고 있든 들어간다.
    private func act() {
        if facing == .up, let building = VillageMap.door(col: col, row: row) {
            walker?.cancel()
            walker = Task { [weak self] in await self?.enter(building) }
            return
        }
        if let target {
            interact(target)
            return
        }
        if let (side, thing) = nearby {
            facing = side
            interact(thing)
            return
        }
        if let building = VillageMap.door(col: col, row: row) {
            facing = .up
            walker?.cancel()
            walker = Task { [weak self] in await self?.enter(building) }
        }
    }

    /// 바로 옆 칸에 있는 것과 그쪽 방향. 위, 왼쪽, 오른쪽, 아래 순서로 본다.
    var nearby: (Player.Facing, Target)? {
        for side in [Player.Facing.up, .left, .right, .down] {
            let (dx, dy) = Self.offset(of: side)
            if let thing = thing(at: col + dx, row + dy) { return (side, thing) }
        }
        return nil
    }

    private func interact(_ target: Target) {
        if target == .pickup { pickupTile = nil }
        pendingInteraction = target
    }

    /// 맵을 클릭했다. 땅이면 그 칸까지 걸어가고, 사람이나 물건이면 그 앞까지 가서 말을 건다.
    func walk(toward col: Int, _ row: Int) {
        guard dialogue == nil, entering == nil else { return }
        let thing = thing(at: col, row)
        var goals: [(Int, Int)]
        if let thing, thing != .pickup {
            goals = [Player.Facing.down, .up, .left, .right].map { side in
                let (dx, dy) = Self.offset(of: side)
                return (col + dx, row + dy)
            }
        } else {
            goals = [(col, row)]
        }
        goals = goals.filter { open($0.0, $0.1) && $0.1 >= 4 || ($0.0, $0.1) == (self.col, self.row) }
        guard let path = path(to: goals) else { return }
        held = nil
        walker?.cancel()
        walker = Task { [weak self] in
            guard let self else { return }
            for next in path.dropFirst() {
                // 걷는 동안 방향키를 누르면 그 키로 넘긴다.
                if self.held != nil { await self.walk(); return }
                guard !Task.isCancelled else { return }
                // 손님이 길을 막으면 길을 다시 찾는다.
                guard self.open(next.0, next.1) else { self.walk(toward: col, row); return }
                if await self.move(to: next) { return }
            }
            if let thing, thing != .pickup {
                self.facing = Self.facing(from: (self.col, self.row), to: (col, row))
                self.interact(thing)
            }
        }
    }

    /// 지금 자리에서 `goals` 가운데 가장 가까운 칸까지의 길. 바닥(4~6행)으로만 간다. 지금 자리가 처음이다.
    private func path(to goals: [(Int, Int)]) -> [(Int, Int)]? {
        let start = (col, row)
        var previous: [Int: Int] = [:]
        var queue = [start]
        func key(_ p: (Int, Int)) -> Int { p.1 * VillageMap.cols + p.0 }
        previous[key(start)] = -1
        var i = 0
        while i < queue.count {
            let here = queue[i]
            i += 1
            if goals.contains(where: { $0 == here }) {
                var path = [here]
                var k = previous[key(here)]!
                while k >= 0 {
                    path.append((k % VillageMap.cols, k / VillageMap.cols))
                    k = previous[k]!
                }
                return path.reversed()
            }
            for side in [Player.Facing.up, .down, .left, .right] {
                let (dx, dy) = Self.offset(of: side)
                let next = (here.0 + dx, here.1 + dy)
                guard next.1 >= 4, open(next.0, next.1), previous[key(next)] == nil else { continue }
                previous[key(next)] = key(here)
                queue.append(next)
            }
        }
        return nil
    }

    private func direction(of key: Key) -> Player.Facing {
        switch key {
        case .up: .up
        case .down: .down
        case .left: .left
        default: .right
        }
    }

    private static func offset(of facing: Player.Facing) -> (Int, Int) {
        switch facing {
        case .up: (0, -1)
        case .down: (0, 1)
        case .left: (-1, 0)
        case .right: (1, 0)
        }
    }

    private static func facing(from: (Int, Int), to: (Int, Int)) -> Player.Facing {
        if to.1 < from.1 { return .up }
        if to.1 > from.1 { return .down }
        return to.0 < from.0 ? .left : .right
    }

    /// 누르고 있는 동안 한 칸씩 이어서 걷는다. 문 앞에서 위면 들어간다. 막히면 그 자리에서 바라만 본다.
    private func walk() async {
        while let key = held, !Task.isCancelled {
            facing = direction(of: key)
            if key == .up, let building = VillageMap.door(col: col, row: row) {
                await enter(building)
                return
            }
            let (dx, dy) = Self.offset(of: facing)
            let next = (col + dx, row + dy)
            guard open(next.0, next.1) else {
                step = 0
                try? await Task.sleep(for: .milliseconds(60))
                continue
            }
            if await move(to: next) { return }
        }
        step = 0
    }

    /// 옆 칸으로 한 걸음. 풀밭의 물건을 밟아 주웠으면 true.
    private func move(to next: (Int, Int)) async -> Bool {
        facing = Self.facing(from: (col, row), to: next)
        let from = (Double(col), Double(row))
        col = next.0
        row = next.1
        moving = true
        alternate.toggle()
        let start = ContinuousClock.now
        var t = 0.0
        while t < 1, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(12))
            t = min(1, (ContinuousClock.now - start) / .seconds(Self.stepSeconds))
            x = from.0 + (Double(next.0) - from.0) * t
            y = from.1 + (Double(next.1) - from.1) * t
            step = t < 0.5 ? (alternate ? 1 : 2) : 0
        }
        x = Double(col)
        y = Double(row)
        step = 0
        moving = false
        if let tile = pickupTile, tile.col == col, tile.row == row {
            pickupTile = nil
            held = nil
            pendingInteraction = .pickup
            return true
        }
        return false
    }

    /// 그 건물 문 앞에 선다.
    func stand(at building: VillageBuilding) {
        walker?.cancel()
        moving = false
        held = nil
        col = building.doorCol
        row = building.frontRow
        x = Double(col)
        y = Double(row)
        facing = .down
        step = 0
        entering = nil
    }
}
