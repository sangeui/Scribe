import AppKit
import SwiftUI

// MARK: - 3D 입체 픽셀아트 책 더미 (재고·품절 시각화)

/// 3/4 시점 입체 도트 책 더미: 표지 윗면(하이라이트·금/은 띠)과 두꺼운 흰색 책장 옆면(페이지 결), 어두운 책등, 바닥 그림자를 함께 그려
/// 남은 재고량(0층=빈 팔레트/품절, 1~5층=쌓인 책 높이)을 입체적으로 보여 준다.
struct PixelBookStack: View {
    let color: Color
    var stock: Int
    var tier: SalesTier = .none
    var scale: CGFloat = 1.6

    /// 재고 부수에 따른 책 더미 층수(0~5).
    static func layers(for stock: Int) -> Int {
        switch stock {
        case ..<1: 0
        case 1..<40: 1
        case 40..<150: 2
        case 150..<400: 3
        case 400..<900: 4
        default: 5
        }
    }

    var body: some View {
        let count = Self.layers(for: stock)
        let rows = Self.rows(layers: count, hasBand: tier >= .reprint)
        let bandColor: Color = tier >= .bestseller ? BadgeTier.gold.color : BadgeTier.silver.color
        let c = NSColor(color).usingColorSpace(.deviceRGB) ?? .brown
        let lightCover = Color(
            red: min(1, c.redComponent * 1.22 + 0.08),
            green: min(1, c.greenComponent * 1.22 + 0.08),
            blue: min(1, c.blueComponent * 1.22 + 0.08)
        )
        let darkSpine = Color(
            red: max(0, c.redComponent * 0.62),
            green: max(0, c.greenComponent * 0.62),
            blue: max(0, c.blueComponent * 0.62)
        )
        let palette: [Character: Color] = [
            "x": Color(red: 0.14, green: 0.13, blue: 0.16),
            "s": Color.black.opacity(0.28),
            "b": color,
            "l": lightCover,
            "d": darkSpine,
            "p": Color(red: 0.97, green: 0.95, blue: 0.89),
            "P": Color(red: 0.84, green: 0.80, blue: 0.72),
            "g": bandColor,
            "w": Color(red: 0.62, green: 0.44, blue: 0.27),
            "W": Color(red: 0.42, green: 0.28, blue: 0.16),
            "r": ChartPalette.warning,
        ]
        PixelFrame(rows: rows, scale: scale, palette: palette)
            .frame(width: CGFloat(16) * scale, height: CGFloat(16) * scale)
    }

    /// 16×16 도트 격자: 3/4 시점 입체 양장본이 1~5권 쌓인 모습(표지 윗면 + 앞·옆 페이지 단면 + 책등 + 바닥 그림자).
    private static func rows(layers: Int, hasBand: Bool) -> [String] {
        var grid = [[Character]](repeating: [Character](repeating: ".", count: 16), count: 16)
        func put(_ x: Int, _ y: Int, _ ch: Character) {
            guard (0..<16).contains(x), (0..<16).contains(y) else { return }
            grid[y][x] = ch
        }
        func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ ch: Character) {
            for yy in y..<(y + h) { for xx in x..<(x + w) { put(xx, yy, ch) } }
        }
        if layers <= 0 {
            // 품절: 입체 나무 팔레트(윗면 w + 앞면 W + 바닥 그림자 s)와 붉은 품절 팻말
            fill(2, 14, 13, 1, "s")
            fill(1, 10, 13, 4, "x")
            fill(2, 11, 11, 1, "w")
            fill(4, 11, 1, 1, "W"); fill(8, 11, 1, 1, "W")
            fill(2, 12, 11, 1, "W")
            // 경고 느낌표 배지
            fill(6, 3, 4, 7, "x")
            fill(7, 4, 2, 3, "r")
            fill(7, 8, 2, 1, "r")
            return grid.map { String($0) }
        }
        // 바닥 그림자
        fill(2, 14, 13, 1, "s")
        fill(3, 15, 11, 1, "s")

        // 아래에서부터 한 권씩 입체 양장본(표지 윗면 2px + 페이지 두께 2px)을 쌓는다.
        for i in 0..<min(5, layers) {
            let baseY = 11 - i * 2
            let xOff = (i % 2 == 0) ? 1 : 2
            // 외곽선
            fill(xOff, baseY - 2, 12, 5, "x")
            // 윗면 표지 (하이라이트 l + 본색 b + 금/은 띠 g)
            fill(xOff + 2, baseY - 1, 9, 1, "l")
            fill(xOff + 1, baseY, 9, 1, "b")
            if hasBand {
                fill(xOff + 4, baseY - 1, 2, 2, "g")
            }
            // 좌측 둥근 책등 (d)
            put(xOff + 1, baseY - 1, "d")
            put(xOff + 1, baseY + 1, "d")
            put(xOff + 2, baseY + 1, "d")
            // 전면·우측 두꺼운 흰색 종이 단면 (p / P 결)
            fill(xOff + 3, baseY + 1, 8, 1, i % 2 == 0 ? "p" : "P")
            put(xOff + 10, baseY, "p")
        }
        return grid.map { String($0) }
    }
}

// MARK: - 3/4 시점 입체 픽셀아트 서점 실내 맵

/// 포켓몬/고전 RPG 실내 상점처럼 3/4 위쪽 시점(상판 + 전면 수직 패널 + 바닥 그림자)으로 그린 194×116 도트 서점.
/// `scale = 2.0` 정배율로 렌더링되어 `SidePanel` 내부 폭(`388pt`)에 1픽셀의 잘림이나 번짐 없이 정확히 들어맞는다.
private enum BookstoreRoom {
    static let width = 194
    static let height = 116
    static let scale: CGFloat = 2.0

    static func palette(dark: Bool) -> [Character: Color] {
        let base: [Character: Color] = [
            "w": Color(red: 0.88, green: 0.84, blue: 0.75), // 벽지 밝은 톤
            "W": Color(red: 0.80, green: 0.75, blue: 0.65), // 벽지 무늬
            "b": Color(red: 0.45, green: 0.34, blue: 0.24), // 벽 하단 몰딩
            "f": Color(red: 0.95, green: 0.91, blue: 0.83), // 타일 바닥 1 (밝은 아이보리)
            "F": Color(red: 0.90, green: 0.84, blue: 0.74), // 타일 바닥 2 (따뜻한 베이지)
            "S": Color(red: 0.72, green: 0.65, blue: 0.55), // 가구 바닥 그림자
            "c": Color(red: 0.78, green: 0.58, blue: 0.35), // 가구 상판 하이라이트
            "t": Color(red: 0.66, green: 0.47, blue: 0.26), // 가구 상판 기본 원목
            "T": Color(red: 0.48, green: 0.33, blue: 0.17), // 가구 전면 수직면 (어두운 원목)
            "d": Color(red: 0.35, green: 0.23, blue: 0.11), // 가구 전면 홈/음영
            "e": Color(red: 0.97, green: 0.95, blue: 0.89), // 매대 위 진열 매트 / 종이
            "r": Color(red: 0.76, green: 0.26, blue: 0.24), // 쇼윈도 카펫 / 출입구 매트
            "R": Color(red: 0.54, green: 0.17, blue: 0.16), // 카펫 음영
            "g": dark ? Color(red: 0.20, green: 0.28, blue: 0.45) : Color(red: 0.58, green: 0.80, blue: 0.95), // 유리창/진열 유리
            "G": dark ? Color(red: 0.32, green: 0.42, blue: 0.62) : Color(red: 0.84, green: 0.95, blue: 1.00), // 유리 반사광
            "k": Color(red: 0.96, green: 0.80, blue: 0.28), // 황동/금빛 장식
            "o": Color(red: 0.90, green: 0.48, blue: 0.18), // 주황 책/강조
            "u": Color(red: 0.32, green: 0.50, blue: 0.74), // 파란 책/점원 옷
            "p": Color(red: 0.58, green: 0.36, blue: 0.66), // 보라 책
            "l": Color(red: 0.30, green: 0.60, blue: 0.36), // 초록 책/화분 잎
            "L": Color(red: 0.20, green: 0.44, blue: 0.25), // 화분 잎 음영
            "K": Color(red: 0.96, green: 0.80, blue: 0.66), // 서점 주인 피부
            "H": Color(red: 0.34, green: 0.22, blue: 0.14), // 서점 주인 머리칼
            "s": Color(red: 0.58, green: 0.60, blue: 0.64), // 금속/회색
            "x": Color(red: 0.16, green: 0.15, blue: 0.18), // 외곽선
        ]
        guard dark else { return base }
        return base.reduce(into: [:]) { result, pair in
            if "kgGoe".contains(pair.key) { result[pair.key] = pair.value; return }
            let c = NSColor(pair.value).usingColorSpace(.deviceRGB) ?? .gray
            result[pair.key] = Color(
                red: c.redComponent * 0.62 + 0.04,
                green: c.greenComponent * 0.58 + 0.04,
                blue: c.blueComponent * 0.65 + 0.08
            )
        }
    }

    static func rows(counterSlots: Int, shelfBookCount: Int, hasSoldOut: Bool) -> [String] {
        var grid = [[Character]](repeating: [Character](repeating: "f", count: width), count: height)
        func put(_ x: Int, _ y: Int, _ ch: Character) {
            guard (0..<width).contains(x), (0..<height).contains(y) else { return }
            grid[y][x] = ch
        }
        func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ ch: Character) {
            for yy in y..<(y + h) { for xx in x..<(x + w) { put(xx, yy, ch) } }
        }
        func box(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ ch: Character, _ o: Character = "x") {
            fill(x, y, w, h, ch)
            fill(x, y, w, 1, o); fill(x, y + h - 1, w, 1, o)
            fill(x, y, 1, h, o); fill(x + w - 1, y, 1, h, o)
        }

        // 1. 체크무늬 타일 바닥 (8×8 격자) + 벽 아래 그림자
        for y in 26..<height {
            for x in 0..<width {
                let checker = ((x / 8) + (y / 8)) % 2 == 1
                grid[y][x] = checker ? "F" : "f"
            }
        }
        fill(0, 26, width, 2, "S")

        // 2. 뒷벽 (y: 0..<26): 고전 다이아몬드 격자 벽지와 하단 몰딩
        fill(0, 0, width, 23, "w")
        for y in 2..<22 {
            for x in 0..<width where (x + y) % 6 == 0 || (x - y + 60) % 6 == 0 {
                put(x, y, "W")
            }
        }
        fill(0, 23, width, 2, "b")
        fill(0, 25, width, 1, "x")

        // 3. 상단 좌측: 전면 쇼윈도 유리창 (x: 8..<74, y: 2..<25) + 입체 쇼윈도 진열 단상 (y: 26..<46)
        box(8, 2, 66, 23, "T", "x")
        fill(9, 3, 64, 1, "c")
        for pane in 0..<2 {
            let px = 11 + pane * 31
            box(px, 5, 29, 17, "g", "x")
            // 대각선 유리 반사광
            for d in 0..<10 {
                put(px + 3 + d, 7 + d, "G")
                put(px + 4 + d, 7 + d, "G")
                put(px + 8 + d, 7 + d, "G")
            }
        }
        // 쇼윈도 앞 입체 단상 (상판 y: 27..<39, 전면 수직 패널 y: 39..<45, 바닥 그림자 y: 45..<47)
        fill(12, 45, 62, 2, "S")
        box(10, 27, 62, 13, "r", "x")
        fill(11, 28, 60, 1, "k")
        box(12, 29, 58, 9, "R", "k")
        // 단상 전면 입체 나무 벽면 (4칸 패널)
        box(10, 39, 62, 6, "T", "x")
        for p in 0..<4 {
            box(12 + p * 15, 40, 13, 4, "d", "t")
        }

        // 4. 상단 우측: 6연속 입체 원목 책장 (x: 84..<186, y: 1..<28) — 참고 이미지 우상단과 동일한 3D 구조
        fill(86, 28, 102, 2, "S")
        for b in 0..<6 {
            let bx = 84 + b * 17
            // 책장 상단 천장면(입체 두께)
            box(bx, 1, 17, 5, "t", "x")
            fill(bx + 1, 2, 15, 1, "c")
            // 책장 본체(3단 선반 홈 + 하단 걸레받이)
            box(bx, 5, 17, 23, "T", "x")
            for (tierIdx, sy) in [7, 13, 19].enumerated() {
                fill(bx + 2, sy, 13, 4, "x") // 깊은 선반 안쪽 그림자
                fill(bx + 1, sy + 4, 15, 1, "c") // 선반 나무 판
                // 선반 안의 알록달록한 책등 도트
                let bookCols: [Character] = ["r", "u", "l", "k", "p", "o", "e"]
                let mutedCols: [Character] = ["T", "d", "c", "b"]
                let activeShelf = (b * 3 + tierIdx) < max(4, min(18, shelfBookCount + 4))
                for cx in stride(from: bx + 2, to: bx + 14, by: 2) {
                    let ch = activeShelf
                        ? bookCols[(b + tierIdx + cx) % bookCols.count]
                        : mutedCols[(b + tierIdx + cx) % mutedCols.count]
                    let h = ((cx + tierIdx) % 3 == 0) ? 3 : 4
                    fill(cx, sy + (4 - h), 1, h, ch)
                }
            }
            // 책장 하단 전면 입체 받침대
            fill(bx + 1, 25, 15, 2, "d")
        }

        // 5. 중앙 홀 좌측: 입체 평대 매대 쇼케이스 (x: 10..<128, y: 52..<87)
        // 참고 이미지 좌측 매대처럼 상판(유리/매트) + 두꺼운 4칸 원목 수직 앞면 + 바닥 그림자
        fill(12, 85, 118, 2, "S")
        fill(128, 55, 2, 32, "S")
        // (a) 매대 상판 (y: 52..<75)
        box(10, 52, 118, 24, "t", "x")
        fill(11, 53, 116, 1, "c")
        box(13, 55, 112, 18, "g", "T") // 푸른빛 유리/쇼케이스 상판
        fill(14, 56, 110, 1, "G")
        // 슬롯별 3D 계단식 원목 독서대/진열 트레이 (2~5칸)
        let slots = max(2, min(5, counterSlots))
        let slotW = 20
        let gap = 2
        let totalSpan = slots * slotW + (slots - 1) * gap
        let startX = 14 + (110 - totalSpan) / 2
        for i in 0..<slots {
            let sx = startX + i * (slotW + gap)
            fill(sx + 1, 70, slotW, 1, "d")
            box(sx, 57, slotW, 13, "t", "x")
            fill(sx + 1, 58, slotW - 2, 1, "c")
            box(sx + 2, 59, slotW - 4, 8, "d", "T")
            put(sx + 3, 60, "k"); put(sx + slotW - 4, 60, "k")
            fill(sx + 1, 67, slotW - 2, 2, "T")
        }
        // (b) 매대 전면 수직 입체 캐비닛 벽 (y: 75..<85, 5칸 입체 패널)
        box(10, 75, 118, 10, "T", "x")
        fill(11, 76, 116, 1, "t")
        for p in 0..<5 {
            let px = 12 + p * 23
            box(px, 77, 21, 6, "d", "x")
            fill(px + 1, 78, 19, 1, "T")
            fill(px + 9, 79, 3, 1, "k") // 황동 손잡이
        }

        // 6. 우측 중앙: L자형 입체 계산대 (x: 138..<186, y: 34..<74) + 서점 주인
        // 세로 기둥부 (x: 138..<150, y: 34..<64) + 가로 전면부 (x: 138..<186, y: 56..<73)
        fill(140, 73, 48, 2, "S")
        box(138, 34, 12, 30, "t", "x")
        fill(139, 35, 10, 1, "c")
        // 가로 상판 (y: 56..<64)
        box(138, 56, 48, 9, "t", "x")
        fill(139, 57, 46, 1, "c")
        put(138, 56, "t"); fill(139, 56, 10, 1, "t") // L자 연결부
        // L자 계산대 전면 수직 패널 (y: 64..<73, 3칸 패널)
        box(138, 64, 48, 9, "T", "x")
        for p in 0..<3 {
            box(140 + p * 15, 66, 13, 5, "d", "x")
            fill(141 + p * 15, 67, 11, 1, "T")
        }
        // 금전등록기(포스기) 입체 도트 (x: 140..<148, y: 46..<54)
        box(140, 46, 8, 8, "e", "x")
        fill(141, 47, 6, 2, "g")
        fill(141, 50, 6, 2, "s")

        // 7. 우측 하단: 입체 창고 나무 상자·팔레트 (x: 138..<174, y: 82..<106)
        // 좌측 큰 입체 나무 상자 (윗면 c/t + 전면 T/d + 그림자 S)
        fill(140, 103, 18, 2, "S")
        box(138, 84, 18, 9, "c", "x") // 상자 윗면
        fill(139, 88, 16, 1, "t")
        box(138, 92, 18, 11, "t", "x") // 상자 앞면
        fill(139, 96, 16, 1, "T"); fill(139, 99, 16, 1, "T")
        if hasSoldOut {
            // 품절 시: 우측에 텅 빈 나무 팔레트와 붉은 경고 표지판
            fill(159, 103, 16, 2, "S")
            box(158, 96, 16, 7, "t", "x")
            fill(159, 98, 14, 1, "d"); fill(159, 100, 14, 1, "d")
            box(162, 85, 8, 10, "r", "x")
            fill(165, 87, 2, 4, "e"); fill(165, 92, 2, 1, "e")
        } else {
            // 평소: 우측에도 쌓인 2단 입체 상자
            fill(159, 103, 16, 2, "S")
            box(158, 87, 15, 7, "c", "x")
            box(158, 93, 15, 10, "t", "x")
            fill(159, 97, 13, 1, "T")
        }

        // 8. 하단 중앙: 붉은 출입구 매트 (x: 78..<116, y: 106..<115) & 양옆 입체 화분
        box(78, 106, 38, 8, "r", "R")
        fill(80, 107, 34, 1, "e")
        fill(80, 112, 34, 1, "e")
        for px in [6, 176] {
            // 화분 잎(l/L) + 화분 몸통(t/T)
            fill(px + 2, 109, 10, 2, "S")
            box(px + 1, 95, 10, 8, "l", "x")
            fill(px + 2, 96, 3, 3, "G"); fill(px + 6, 99, 4, 3, "L")
            box(px + 2, 102, 8, 7, "t", "x")
            fill(px + 3, 104, 6, 4, "T")
        }

        return grid.map { String($0) }
    }
}

// MARK: - 서점 화면 내 픽셀아트 미니맵 및 진열대

extension BookstoreContent {
    /// 서점 3/4 시점 입체 픽셀아트 미니맵 + 구역별 도트 책 더미 진열 현황.
    var stand: some View {
        Group {
            if ranked.isEmpty {
                VStack(spacing: 8) {
                    pixelMapCanvas(windowBooks: [], counterBooks: [], shelfBooks: [], storageBooks: [], maxSlots: progress.trustLevel.counterSlots)
                    Text("탈고한 책이 여기 놓입니다. 첫 책을 끝내면 서점이 문을 엽니다.")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            } else {
                let windowBooks = progress.books(in: .window)
                let counterBooks = progress.books(in: .counter)
                let shelfBooks = progress.books(in: .shelf)
                let storageBooks = progress.books(in: .storage)
                let maxCounterSlots = progress.trustLevel.counterSlots

                VStack(alignment: .leading, spacing: 8) {
                    pixelMapCanvas(
                        windowBooks: windowBooks,
                        counterBooks: counterBooks,
                        shelfBooks: shelfBooks,
                        storageBooks: storageBooks,
                        maxSlots: maxCounterSlots
                    )
                    zoneSummaryStrip(
                        windowBooks: windowBooks,
                        counterBooks: counterBooks,
                        shelfBooks: shelfBooks,
                        storageBooks: storageBooks,
                        maxSlots: maxCounterSlots
                    )
                }
            }
        }
    }

    /// 388×232pt 정배율(2x) 입체 픽셀아트 서점 미니맵. 모든 라벨과 도트 책 더미를 캔버스 내부 좌표에 여유 있게 배치해 잘림을 방지한다.
    private func pixelMapCanvas(
        windowBooks: [Book],
        counterBooks: [Book],
        shelfBooks: [Book],
        storageBooks: [Book],
        maxSlots: Int
    ) -> some View {
        let dark = DayPart.isDark(at: now)
        let s = BookstoreRoom.scale
        let w = CGFloat(BookstoreRoom.width) * s
        let h = CGFloat(BookstoreRoom.height) * s
        let rows = BookstoreRoom.rows(counterSlots: maxSlots, shelfBookCount: shelfBooks.count, hasSoldOut: !storageBooks.isEmpty)
        let slots = max(2, min(5, maxSlots))
        let slotW = 20
        let gap = 2
        let totalSpan = slots * slotW + (slots - 1) * gap
        let startX = 14 + (110 - totalSpan) / 2

        return ZStack(alignment: .topLeading) {
            PixelFrame(rows: rows, scale: s, palette: BookstoreRoom.palette(dark: dark))

            // 1. 좌측 상단: 전면 쇼윈도 단상 위 대표 도서 입체 책 더미
            if let featured = windowBooks.first {
                let idx = Library.books.firstIndex { $0.file == featured.file } ?? 0
                let isSelected = shownBook?.file == featured.file
                Button { picked = idx } label: {
                    PixelBookStack(color: featured.spineColor, stock: progress.stock(of: featured), tier: progress.salesTier(of: featured), scale: 1.5)
                        .padding(1)
                        .background(
                            isSelected ? BadgeTier.gold.color.opacity(0.24) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelected ? BadgeTier.gold.color : Color.clear, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .offset(x: 33 * s, y: 21 * s)
                .hint(featured.displayTitle,
                      [L10n.tr("진열창 대표 도서 (+30% 판매) · 누적 \(Format.integer(progress.sales(of: featured)))부 · 재고 \(Format.integer(progress.stock(of: featured)))부")],
                      symbol: "star.fill")
            }

            // 2. 중앙 좌측: 입체 평대 매대 슬롯별 3D 도트 책 더미
            ForEach(0..<slots, id: \.self) { slotIdx in
                let sx = CGFloat(startX + slotIdx * (slotW + gap)) * s
                if slotIdx < counterBooks.count {
                    let book = counterBooks[slotIdx]
                    let bookIdx = Library.books.firstIndex { $0.file == book.file } ?? 0
                    let isSelected = shownBook?.file == book.file
                    let stock = progress.stock(of: book)
                    Button { picked = bookIdx } label: {
                        PixelBookStack(color: book.spineColor, stock: stock, tier: progress.salesTier(of: book), scale: 1.45)
                            .padding(1)
                            .background(
                                isSelected ? BadgeTier.gold.color.opacity(0.24) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(isSelected ? BadgeTier.gold.color : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .offset(x: sx + 2, y: 52 * s)
                    .hint(book.displayTitle,
                          [L10n.tr("평대 매대 \(slotIdx + 1)번 칸 · 누적 \(Format.integer(progress.sales(of: book)))부 판매 · 재고 \(Format.integer(stock))부")],
                          symbol: "tablecells.fill")
                }
            }

            // 3. 우측 중앙 계산대 안쪽: 초상화(`ShopScene`)와 동일한 화풍의 서점 주인
            PixelFrame(
                rows: Array(Player.shopkeeperRows.prefix(14)),
                scale: s,
                palette: Player.shadedPalette(Player.shopkeeperPalette, dark: dark)
            )
            .offset(x: 158 * s, y: 42 * s)
            .hint(
                L10n.isEnglish ? "Bookstore Keeper · \(progress.trustLevel.title)" : "서점 주인 · 신뢰 \(progress.trustLevel.title)",
                [L10n.isEnglish ? "Arranges the window and display table every morning." : "매일 아침 진열창과 평대 매대를 정성껏 꾸립니다."],
                symbol: "person.fill"
            )

            // 4. 서점을 방문한 후원자(사용자 캐릭터) — 마을·서재와 동일한 외형
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(dark ? 0.35 : 0.20))
                    .frame(width: 11 * s, height: 4 * s)
                    .offset(y: 6 * s)
                PixelFrame(
                    rows: Player.rows(facing: .up, step: 0),
                    scale: s,
                    palette: Player.shadedPalette(dark: dark)
                )
            }
            .offset(x: 26 * s, y: 83 * s)

            // 5. 서점을 구경하는 손님 도트 NPC — 초상화 화풍과 통일된 16×16 캐릭터
            ForEach(0..<customerPreviewCount, id: \.self) { npcIdx in
                let positions: [(CGFloat, CGFloat, Player.Facing)] = [
                    (96, 30, .up),
                    (66, 83, .up),
                    (114, 83, .left)
                ]
                let pos = positions[npcIdx % positions.count]
                ZStack {
                    Ellipse()
                        .fill(Color.black.opacity(dark ? 0.35 : 0.20))
                        .frame(width: 11 * s, height: 4 * s)
                        .offset(y: 6 * s)
                    PixelFrame(
                        rows: Player.customerRows(npcIdx, facing: pos.2, step: 0),
                        scale: s,
                        palette: Player.shadedPalette(Player.customers[npcIdx % Player.customers.count].palette, dark: dark)
                    )
                }
                .offset(x: pos.0 * s, y: pos.1 * s)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color(red: 0.2, green: 0.2, blue: 0.23), lineWidth: 2))
    }

    private var customerPreviewCount: Int {
        let stocked = !progress.books(in: .window).isEmpty || !progress.books(in: .counter).isEmpty || !progress.books(in: .shelf).isEmpty
        guard stocked else { return 0 }
        return min(3, 1 + progress.shopBoosts.filter { $0.value > 1 }.count + progress.ads.count)
    }

    /// 픽셀 미니맵 아래에서 모든 진열 구역(진열창·평대·서가·창고)의 책을 입체 책 더미 아이콘과 함께 클릭해 고를 수 있는 목록.
    private func zoneSummaryStrip(
        windowBooks: [Book],
        counterBooks: [Book],
        shelfBooks: [Book],
        storageBooks: [Book],
        maxSlots: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(ShopSlot.allCases, id: \.self) { slot in
                let books = progress.books(in: slot)
                if !books.isEmpty || slot == .counter || (slot == .window && progress.trustLevel.hasWindow) {
                    HStack(alignment: .top, spacing: 8) {
                        slotLabel(slot, count: books.count, maxSlots: maxSlots)
                        FlowLayout(spacing: 5) {
                            Group {
                                ForEach(books, id: \.file) { book in
                                    stackedChip(book)
                                }
                                if books.isEmpty {
                                    Text(slot == .window ? L10n.tr("비어 있음") : L10n.tr("빈 칸"))
                                        .font(.caption2).foregroundStyle(.tertiary).padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func slotLabel(_ slot: ShopSlot, count: Int, maxSlots: Int) -> some View {
        let text = slot == .counter ? L10n.tr("매대 \(count)/\(maxSlots)") : slot.title
        let hint: [String] = switch slot {
        case .window: ["진열창에 걸린 책은 \(Int((Balance.windowSales - 1) * 100))% 더 팔립니다. 신뢰가 '안면' 이상이어야 쓸 수 있고 하루에 한 번 바꿉니다."]
        case .counter: ["매대 책은 제값에 팔립니다. 칸 수는 주인의 신뢰에 달렸습니다(\(maxSlots)칸). 비면 주인이 잘 팔릴 책으로 채우고, 아침마다 다시 정리합니다."]
        case .shelf: ["서가 책은 \(Int(Balance.shelfSales * 100))%만 팔립니다. 직접 내린 책은 이레 동안 주인이 다시 올리지 않습니다."]
        case .storage: ["재고가 떨어진 책. 재판이 들어오면 다시 자리를 잡습니다."]
        }
        return HStack(spacing: 3) {
            Symbol(name: slot.symbol, size: 9)
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 58, alignment: .leading)
        .padding(.vertical, 5)
        .hint(slot.title, hint, symbol: slot.symbol)
    }

    /// 입체 도트 책 더미(`PixelBookStack`)가 포함된 서점 도서 칩: 쌓인 높이로 재고 여유와 품절 여부를 즉시 보여 준다.
    private func stackedChip(_ book: Book) -> some View {
        let index = Library.books.firstIndex { $0.file == book.file } ?? 0
        let slot = progress.slot(of: book)
        let selected = shownBook?.file == book.file
        let soldOut = slot == .storage
        let stock = progress.stock(of: book)
        let sales = progress.sales(of: book)
        let featured = progress.featuredBook == book.file
        let advertised = progress.adEnds(for: book) != nil
        let pinned = progress.isPinned(book)

        return Button { picked = index } label: {
            HStack(spacing: 5) {
                PixelBookStack(color: book.spineColor, stock: soldOut ? 0 : max(1, stock), tier: progress.salesTier(of: book), scale: 1.0)
                Text(book.displayTitle)
                    .font(.caption.weight(selected ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(soldOut ? .secondary : .primary)
                Text(soldOut ? L10n.tr("품절") : Format.short(sales))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(soldOut ? ChartPalette.warning : .secondary)
                if featured { Symbol(name: "star.fill", size: 8, color: BadgeTier.gold.color) }
                if advertised { Symbol(name: "megaphone.fill", size: 8, color: ChartPalette.warning) }
                if pinned { Symbol(name: "pin.fill", size: 7, color: .secondary) }
            }
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(selected ? Color.primary.opacity(scheme == .dark ? 0.16 : 0.1) : Color.secondary.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.primary.opacity(0.28) : .clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .hint(book.displayTitle,
              [soldOut
                  ? L10n.tr("품절 (재판 입고 대기) · 누적 \(Format.integer(sales))부 판매")
                  : L10n.tr("재고 \(Format.integer(stock))부 · 누적 \(Format.integer(sales))부 판매")],
              symbol: slot?.symbol ?? "book.closed")
    }
}
