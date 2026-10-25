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

// MARK: - 사람 (초상화 화풍과 통일된 16×16 도트 캐릭터)

/// 사용자(후원자)·손님·서점 주인 도트 스프라이트.
/// `Portraits`(`PortraitArt.swift`)와 동일한 피부(`s`)·음영(`S`)·눈매(`e`)·옷깃(`W`) 배색 체계를 사용해
/// 마을(`VillageView`)·서재(`ShelfMap`)·서점(`BookstoreFloorMap`) 모든 맵에서 일관된 화풍을 유지한다.
enum Player {
    enum Facing { case down, up, left, right }

    static let palette: [Character: Color] = [
        "x": Color(red: 0.18, green: 0.16, blue: 0.19),
        "r": Color(red: 0.92, green: 0.82, blue: 0.42), // 후원자 모자 윗면
        "R": Color(red: 0.58, green: 0.22, blue: 0.22), // 후원자 모자 리본 띠
        "s": Color(red: 1.00, green: 0.86, blue: 0.72), // 초상화 동일 피부색
        "S": Color(red: 0.86, green: 0.68, blue: 0.54), // 초상화 동일 피부 그늘
        "e": Color(red: 0.15, green: 0.13, blue: 0.16), // 초상화 동일 눈동자
        "m": Color(red: 0.70, green: 0.38, blue: 0.34), // 입매 포인트
        "h": Color(red: 0.42, green: 0.27, blue: 0.15), // 초상화 동일 갈색 머리
        "W": Color(red: 0.96, green: 0.94, blue: 0.88), // 초상화 동일 흰 옷깃·셔츠·앞치마
        "w": Color(red: 0.68, green: 0.24, blue: 0.24), // 후원자 버건디 코트
        "b": Color(red: 0.24, green: 0.24, blue: 0.30), // 바지
        "k": Color(red: 0.32, green: 0.20, blue: 0.14), // 가죽 구두
        "o": Color(red: 0.54, green: 0.36, blue: 0.20), // 가죽 가방·뒷면 장식
    ]

    /// 밤낮에 맞춰 캐릭터 팔레트를 일관되게 보정한다.
    static func shadedPalette(_ base: [Character: Color] = palette, dark: Bool) -> [Character: Color] {
        guard dark else { return base }
        return base.reduce(into: [:]) { result, pair in
            let c = NSColor(pair.value).usingColorSpace(.deviceRGB) ?? .gray
            result[pair.key] = Color(
                red: c.redComponent * 0.68 + 0.04,
                green: c.greenComponent * 0.66 + 0.04,
                blue: c.blueComponent * 0.76 + 0.08
            )
        }
    }

    /// 서점 상단 초상화(`ShopScene`)의 주인과 동일한 갈색 가르마 머리·갈색 조끼·흰 앞치마 점원 스프라이트.
    static let shopkeeperRows: [String] = [
        "....hhhhhhhh....",
        "...hhhhhhhhhh...",
        "...hhhsssshhh...",
        "...hhsssssshh...",
        "...hhsesesshh...",
        "....ssssssss....",
        "....sSssmmSs....",
        ".....sSSSSs.....",
        "......sWWs......",
        "...cccWWWWccc...",
        "..ccccWWWWcccc..",
        "..ssccWWWWccss..",
        "....ccWWWWcc....",
        "....ccWWWWcc....",
        ".....bbbbbb.....",
        ".....kk..kk.....",
    ]

    static let shopkeeperPalette: [Character: Color] = palette.merging([
        "c": Color(red: 0.42, green: 0.22, blue: 0.16), // 초상화 `c` 와 동일한 갈색 웃옷
    ]) { $1 }

    static let downStand = [
        ".....rrrrrr.....",
        "...rrrrrrrrrr...",
        "...rRRRRRRRRr...",
        "...hhsssssshh...",
        "...hhsesesshh...",
        "...hssssSsssh...",
        "....sSssmmSs....",
        ".....sSSSSs.....",
        "...wwwWWWWwww...",
        "..wwwwWWWWwwww..",
        "..sswwwWWwwwss..",
        "....wwwwwwww....",
        "....bbbbbbbb....",
        "....bbb..bbb....",
        "....kkk..kkk....",
        "................",
    ]
    static let downWalkA = [
        ".....rrrrrr.....",
        "...rrrrrrrrrr...",
        "...rRRRRRRRRr...",
        "...hhsssssshh...",
        "...hhsesesshh...",
        "...hssssSsssh...",
        "....sSssmmSs....",
        ".....sSSSSs.....",
        "...wwwWWWWwww...",
        "..wwwwWWWWwwww..",
        "..sswwwWWwww....",
        "....wwwwwwwwss..",
        "....bbbbbbbb....",
        "...bbb....bbb...",
        "...kkk....kkk...",
        "................",
    ]
    static let downWalkB = downWalkA.map { String($0.reversed()) }

    static let upStand = [
        ".....rrrrrr.....",
        "...rrrrrrrrrr...",
        "...rRRRRRRRRr...",
        "...hhhhhhhhhh...",
        "...hhhhhhhhhh...",
        "...hhhhhhhhhh...",
        "....hhhhhhhh....",
        ".....sSSSSs.....",
        "...wwwWWWWwww...",
        "..wwwwoooowwww..",
        "..sswwoooowwss..",
        "....wwooooww....",
        "....bbbbbbbb....",
        "....bbb..bbb....",
        "....kkk..kkk....",
        "................",
    ]
    static let upWalkA = [
        ".....rrrrrr.....",
        "...rrrrrrrrrr...",
        "...rRRRRRRRRr...",
        "...hhhhhhhhhh...",
        "...hhhhhhhhhh...",
        "...hhhhhhhhhh...",
        "....hhhhhhhh....",
        ".....sSSSSs.....",
        "...wwwWWWWwww...",
        "..wwwwoooowwww..",
        "..sswwooooww....",
        "....wwoooowwss..",
        "....bbbbbbbb....",
        "...bbb....bbb...",
        "...kkk....kkk...",
        "................",
    ]
    static let upWalkB = upWalkA.map { String($0.reversed()) }

    static let leftStand = [
        ".....rrrrrr.....",
        "...rrrrrrrrrr...",
        "..rRRRRRRRRRr...",
        "...hhsssshhhh...",
        "...heses.hhhh...",
        "....ssssShhh....",
        "....sSmmSSh.....",
        ".....sSSSs......",
        "....wwWWwwww....",
        "...wwwwwwwww....",
        "...wwwsswwww....",
        "....wwwwwwww....",
        ".....bbbbbb.....",
        ".....bbbbbb.....",
        ".....kkkkkk.....",
        "................",
    ]
    static let leftWalkA = [
        ".....rrrrrr.....",
        "...rrrrrrrrrr...",
        "..rRRRRRRRRRr...",
        "...hhsssshhhh...",
        "...heses.hhhh...",
        "....ssssShhh....",
        "....sSmmSSh.....",
        ".....sSSSs......",
        "....wwWWwwww....",
        "...sswwwwwww....",
        "....wwwwwwww....",
        "....wwwwwwww....",
        ".....bbbbbb.....",
        "....bbb..bbb....",
        "...kkk....kkk...",
        "................",
    ]
    static let leftWalkB = [
        ".....rrrrrr.....",
        "...rrrrrrrrrr...",
        "..rRRRRRRRRRr...",
        "...hhsssshhhh...",
        "...heses.hhhh...",
        "....ssssShhh....",
        "....sSmmSSh.....",
        ".....sSSSs......",
        "....wwWWwwww....",
        "....wwwwwwwss...",
        "....wwwwwwww....",
        "....wwwwwwww....",
        ".....bbbbbb.....",
        "....bbb..bbb....",
        "....kkk..kkk....",
        "................",
    ]

    /// 손님 한 사람의 생김새. 머리(위 8줄)는 방향마다 따로 그리고, 몸은 사용자 그림을 옷 색만 바꿔 쓴다.
    struct Look {
        let down: [String]
        let up: [String]
        let left: [String]
        let palette: [Character: Color]
    }

    /// `Persona.all` 과 같은 순서: 단골 할아버지, 학생 손님, 비평가 지망생, 장꾼.
    /// 모두 `Portraits` 와 동일한 부드러운 피부(`s`)·음영(`S`)·눈동자(`e`) 화풍으로 통일.
    static let customers: [Look] = [
        // 0: 단골 할아버지 — 헌팅캡, 흰 귀밑머리와 콧수염, 트위드 조끼
        Look(down: [
            "................",
            "....rrrrrrrr....",
            "...rRRRRRRRRr...",
            "...hhsssssshh...",
            "...hhsesesshh...",
            "...hssssSsssh...",
            "...hsWWWWWWsh...",
            "....sSSSSSSs....",
        ], up: [
            "................",
            "....rrrrrrrr....",
            "...rRRRRRRRRr...",
            "...hhhhhhhhhh...",
            "...hhhhhhhhhh...",
            "...hhhhhhhhhh...",
            "....hhhhhhhh....",
            ".....sSSSSs.....",
        ], left: [
            "................",
            "....rrrrrrrr....",
            "..rRRRRRRRRRr...",
            "...hhsssshhhh...",
            "...heses.hhhh...",
            "....ssssShhh....",
            "...WWWsSSSh.....",
            ".....sSSSs......",
        ], palette: palette.merging([
            "r": Color(red: 0.55, green: 0.48, blue: 0.38), "R": Color(red: 0.38, green: 0.32, blue: 0.25),
            "h": Color(red: 0.88, green: 0.86, blue: 0.82), "W": Color(red: 0.96, green: 0.95, blue: 0.92),
            "w": Color(red: 0.52, green: 0.36, blue: 0.22), "o": Color(red: 0.44, green: 0.30, blue: 0.18),
            "b": Color(red: 0.36, green: 0.36, blue: 0.40), "k": Color(red: 0.26, green: 0.18, blue: 0.12),
        ]) { $1 }),
        // 1: 학생 손님 — 단정한 검은 단발머리, 남색 교복 코트와 흰 칼라, 빨간 책가방
        Look(down: [
            "................",
            "....hhhhhhhh....",
            "...hhhhhhhhhh...",
            "...hhhsssshhh...",
            "...hhsesesshh...",
            "...hhsssSsshh...",
            "....sSssmmSs....",
            ".....sSSSSs.....",
        ], up: [
            "................",
            "....hhhhhhhh....",
            "...hhhhhhhhhh...",
            "...hhhhhhhhhh...",
            "...hhhhhhhhhh...",
            "...hhhhhhhhhh...",
            "....hhhhhhhh....",
            ".....sSSSSs.....",
        ], left: [
            "................",
            "....hhhhhhhh....",
            "...hhhhhhhhhh...",
            "...hhsssshhhh...",
            "...heses.hhhh...",
            "....ssssShhh....",
            "....sSmmSSh.....",
            ".....sSSSs......",
        ], palette: palette.merging([
            "h": Color(red: 0.16, green: 0.15, blue: 0.20),
            "w": Color(red: 0.24, green: 0.34, blue: 0.58), "o": Color(red: 0.80, green: 0.24, blue: 0.22),
            "b": Color(red: 0.18, green: 0.22, blue: 0.38), "k": Color(red: 0.28, green: 0.20, blue: 0.16),
        ]) { $1 }),
        // 2: 비평가 지망생 — 자주빛 베레모, 금테 안경, 차콜 코트
        Look(down: [
            ".....rrrrrr.....",
            "...rrrrrrrrrr...",
            "...hhhhhhhhhh...",
            "...hhsssssshh...",
            "...hgsesessgh...",
            "...hssssSsssh...",
            "....sSssmmSs....",
            ".....sSSSSs.....",
        ], up: [
            ".....rrrrrr.....",
            "...rrrrrrrrrr...",
            "...hhhhhhhhhh...",
            "...hhhhhhhhhh...",
            "...hhhhhhhhhh...",
            "...hhhhhhhhhh...",
            "....hhhhhhhh....",
            ".....sSSSSs.....",
        ], left: [
            ".....rrrrrr.....",
            "...rrrrrrrrrr...",
            "...hhhhhhhhhh...",
            "...hhsssshhhh...",
            "...geses.hhhh...",
            "....ssssShhh....",
            "....sSmmSSh.....",
            ".....sSSSs......",
        ], palette: palette.merging([
            "r": Color(red: 0.62, green: 0.18, blue: 0.24),
            "h": Color(red: 0.42, green: 0.27, blue: 0.15), "g": Color(red: 0.86, green: 0.72, blue: 0.28),
            "w": Color(red: 0.24, green: 0.24, blue: 0.29), "o": Color(red: 0.20, green: 0.20, blue: 0.25),
            "b": Color(red: 0.32, green: 0.32, blue: 0.36), "k": Color(red: 0.16, green: 0.14, blue: 0.16),
        ]) { $1 }),
        // 3: 장꾼 — 챙 넓은 밀짚모자, 초록 외투와 보따리
        Look(down: [
            "....rrrrrrrr....",
            "..rrrrrrrrrrrr..",
            ".rRRRRRRRRRRRRr.",
            "...hhsssssshh...",
            "...hhsesesshh...",
            "...hssssSsssh...",
            "....sSssmmSs....",
            ".....sSSSSs.....",
        ], up: [
            "....rrrrrrrr....",
            "..rrrrrrrrrrrr..",
            ".rRRRRRRRRRRRRr.",
            "...hhhhhhhhhh...",
            "...hhhhhhhhhh...",
            "...hhhhhhhhhh...",
            "....hhhhhhhh....",
            ".....sSSSSs.....",
        ], left: [
            "....rrrrrrrr....",
            "..rrrrrrrrrrrr..",
            ".rRRRRRRRRRRRRr.",
            "...hhsssshhhh...",
            "...heses.hhhh...",
            "....ssssShhh....",
            "....sSmmSSh.....",
            ".....sSSSs......",
        ], palette: palette.merging([
            "r": Color(red: 0.90, green: 0.78, blue: 0.42), "R": Color(red: 0.74, green: 0.58, blue: 0.26),
            "h": Color(red: 0.35, green: 0.22, blue: 0.12),
            "w": Color(red: 0.30, green: 0.52, blue: 0.32), "o": Color(red: 0.62, green: 0.44, blue: 0.24),
            "b": Color(red: 0.38, green: 0.30, blue: 0.22), "k": Color(red: 0.28, green: 0.20, blue: 0.14),
        ]) { $1 }),
    ]

    /// 손님 그림. 몸은 사용자 그림, 위 8줄은 그 사람의 머리.
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
