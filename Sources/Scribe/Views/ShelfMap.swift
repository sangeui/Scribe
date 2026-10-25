import AppKit
import SwiftUI

// MARK: - 픽셀아트 후원자의 서재 (삼면 3D 책장 + 중앙 집무실)

/// 16-bit RPG 3/4 시점의 후원자 서재(`LibraryRoomMapView`).
/// 상단 뒷벽(4칸)과 좌·우측 벽(각 2칸)을 둘러싼 삼면 입체 원목 책장에 전체 장서(`Library.books`)가 작가별(`Library.authors`)로 묶여
/// 동적 배분되어 꽂히므로, 향후 작가나 작품 수가 늘어나도 고정 이름표 없이 자연스럽게 확장된다.
struct LibraryRoomMapView: View {
    let progress: WritingProgress
    let selectedBookIndex: Int
    let expandedAuthor: String?
    let decorTick: Int
    var onSelectAuthor: (String, Int) -> Void

    private static let width = 194
    private static let height = 116
    private static let scale: CGFloat = 2.0

    fileprivate struct CaseSlot {
        let index: Int
        let x: Int
        let y: Int
        let w: Int
        let h: Int
        let isSideWall: Bool
    }

    /// 서가 한 칸에 배정된 장서 묶음(작가 수와 무관하게 전체 장서를 작가 순으로 8개 서가에 동적 배분).
    fileprivate struct BaySection {
        let slot: CaseSlot
        let authors: [String]
        let books: [(offset: Int, element: Book)]
    }

    /// 삼면 서가 배치: 상단 뒷벽 4칸(0~3), 좌측 벽 2칸(4~5), 우측 벽 2칸(6~7).
    private static let slots: [CaseSlot] = [
        CaseSlot(index: 0, x: 32,  y: 2,  w: 32, h: 35, isSideWall: false),
        CaseSlot(index: 1, x: 65,  y: 2,  w: 32, h: 35, isSideWall: false),
        CaseSlot(index: 2, x: 98,  y: 2,  w: 32, h: 35, isSideWall: false),
        CaseSlot(index: 3, x: 131, y: 2,  w: 32, h: 35, isSideWall: false),
        CaseSlot(index: 4, x: 2,   y: 20, w: 29, h: 42, isSideWall: true),
        CaseSlot(index: 5, x: 2,   y: 65, w: 29, h: 42, isSideWall: true),
        CaseSlot(index: 6, x: 163, y: 20, w: 29, h: 42, isSideWall: true),
        CaseSlot(index: 7, x: 163, y: 65, w: 29, h: 42, isSideWall: true),
    ]

    /// 전체 작가(`Library.authors`)와 작품(`Library.books`)을 작가별 연속 구역으로 묶어 삼면 8개 서가에 동적 배분한다.
    private func buildBaySections() -> [BaySection] {
        let allAuthors = Library.authors
        let bayCount = Self.slots.count
        var groupedAuthors = Array(repeating: [String](), count: bayCount)
        for (aIdx, author) in allAuthors.enumerated() {
            let targetBay = min(bayCount - 1, (aIdx * bayCount) / max(1, allAuthors.count))
            groupedAuthors[targetBay].append(author)
        }
        return Self.slots.map { slot in
            let bayAuths = groupedAuthors[slot.index]
            let bayBooks = bayAuths.flatMap { author in
                Library.books.enumerated().filter { $0.element.authorShort == author }
            }
            return BaySection(slot: slot, authors: bayAuths, books: bayBooks)
        }
    }

    var body: some View {
        let dark = DayPart.isDark(at: Date())
        let s = Self.scale
        let w = CGFloat(Self.width) * s
        let h = CGFloat(Self.height) * s
        let sections = buildBaySections()
        let selectedBook = Library.books.indices.contains(selectedBookIndex) ? Library.books[selectedBookIndex] : Library.books[0]
        let activeColorCh = Self.brightChar(for: selectedBook.authorShort)

        ZStack(alignment: .topLeading) {
            PixelFrame(
                rows: Self.rows(sections: sections, progress: progress, activeColorCh: activeColorCh),
                scale: s,
                palette: Self.palette(dark: dark)
            )

            // 중앙 독서 책상 뒤 후원자(사용자 캐릭터 — 마을·서점과 동일한 외형)
            patronDeskOverlay(selectedBook: selectedBook, dark: dark, scale: s)

            // 삼면 8개 입체 서가 인터랙티브 구역 (고정 작가 이름표 없이 깔끔하게 표시)
            ForEach(sections, id: \.slot.index) { section in
                bookcaseOverlay(section: section, dark: dark, scale: s)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(red: 0.22, green: 0.18, blue: 0.15), lineWidth: 2)
        )
        .frame(maxWidth: .infinity)
    }

    private static func isDone(index: Int, progress: WritingProgress) -> Bool {
        if case .done = BookStatus(index: index, progress: progress) { return true }
        return false
    }

    @ViewBuilder
    private func patronDeskOverlay(selectedBook: Book, dark: Bool, scale s: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // 마을(`VillageView`)·서점(`BookstoreFloorMap`)과 완전히 동일한 후원자(사용자) 도트 캐릭터
            PixelFrame(
                rows: Array(Player.rows(facing: .down, step: 0).prefix(13)),
                scale: s,
                palette: Player.shadedPalette(dark: dark)
            )
            .offset(x: 18 * s, y: 9 * s)
        }
        .frame(width: 52 * s, height: 38 * s, alignment: .topLeading)
        .offset(x: 71 * s, y: 34 * s)
        .hint(
            L10n.isEnglish ? "The Patron's Reading Desk" : "후원자의 독서 책상",
            [
                L10n.isEnglish
                    ? "Currently inspecting '\(selectedBook.displayTitle)' by \(selectedBook.displayAuthor)."
                    : "현재 \(selectedBook.displayAuthor)의 『\(selectedBook.displayTitle)』 원고를 펼쳐 두고 감상 중입니다.",
                L10n.isEnglish
                    ? "Click any bookcase along the three walls to browse that section of the collection."
                    : "삼면(좌·상·우)에 배치된 책장을 눌러 서가 구역별 장서를 살펴볼 수 있습니다."
            ],
            symbol: "book.pages"
        )
    }

    @ViewBuilder
    private func bookcaseOverlay(section: BaySection, dark: Bool, scale s: CGFloat) -> some View {
        let slot = section.slot
        let works = section.books
        let doneWorks = works.filter { Self.isDone(index: $0.offset, progress: progress) }
        let firstBook = works.first?.element
        let isSelected = works.contains { $0.offset == selectedBookIndex }
            || (expandedAuthor != nil && section.authors.contains(expandedAuthor!))
        let hasWindow = doneWorks.contains { progress.slot(of: $0.element) == .window }
        let hasCounter = doneWorks.contains { progress.slot(of: $0.element) == .counter }
        let totalStock = doneWorks.reduce(0) { $0 + progress.stock(of: $1.element) }
        let allSoldOut = !doneWorks.isEmpty && totalStock <= 0
        let bestTier = doneWorks.map { progress.salesTier(of: $0.element) }.max() ?? .none

        // 같은 서가를 다시 누르면 그 서가에 속한 다음 작가/도서로 순환 선택
        let targetBook: (offset: Int, element: Book)? = {
            guard !works.isEmpty else { return nil }
            if let currentPos = works.firstIndex(where: { $0.offset == selectedBookIndex }) {
                return works[(currentPos + 1) % works.count]
            }
            if let writingWork = works.first(where: { $0.offset == progress.bookIndex }) { return writingWork }
            if let winWork = doneWorks.first(where: { progress.slot(of: $0.element) == .window }) { return winWork }
            if let bestDone = doneWorks.max(by: { progress.sales(of: $0.element) < progress.sales(of: $1.element) }) { return bestDone }
            return works.first
        }()

        let boxW = CGFloat(slot.w) * s
        let boxH = CGFloat(slot.h) * s

        Button {
            if let target = targetBook {
                onSelectAuthor(target.element.authorShort, target.offset)
            }
        } label: {
            ZStack(alignment: .topLeading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(BadgeTier.gold.color, lineWidth: 2)
                        .background(BadgeTier.gold.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .frame(width: boxW, height: boxH)
                }

                // 탈고 도서가 있으면 책장 발치 마루에 입체 도트 책 더미 표시
                if !doneWorks.isEmpty {
                    PixelBookStack(
                        color: firstBook?.spineColor ?? .secondary,
                        stock: allSoldOut ? 0 : max(1, totalStock),
                        tier: bestTier,
                        scale: 1.15
                    )
                    .offset(
                        x: slot.isSideWall ? (boxW - 18) / 2 : boxW - 20,
                        y: boxH - 18
                    )
                }
            }
            .frame(width: boxW, height: boxH, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: CGFloat(slot.x) * s, y: CGFloat(slot.y) * s)
        .hint(
            sectionTitle(section: section),
            sectionHintLines(works: works, doneWorks: doneWorks, totalStock: totalStock, hasWindow: hasWindow, hasCounter: hasCounter),
            symbol: "books.vertical"
        )
    }

    private func sectionTitle(section: BaySection) -> String {
        let names = section.authors.map { auth in
            Library.books.first { $0.authorShort == auth }?.displayAuthor ?? auth
        }
        if names.isEmpty {
            return L10n.isEnglish ? "Shelf #\(section.slot.index + 1)" : "제\(section.slot.index + 1)서가"
        }
        return names.joined(separator: " · ")
    }

    private func sectionHintLines(
        works: [(offset: Int, element: Book)],
        doneWorks: [(offset: Int, element: Book)],
        totalStock: Int,
        hasWindow: Bool,
        hasCounter: Bool
    ) -> [String] {
        var lines: [String] = [
            L10n.tr("배치 도서 \(works.count)편 중 \(doneWorks.count)편 탈고")
        ]
        if !doneWorks.isEmpty {
            let sold = doneWorks.reduce(0) { $0 + progress.sales(of: $1.element) }
            lines.append(L10n.tr("누적 \(Format.integer(sold))부 판매 · 서점 총 재고 \(Format.integer(totalStock))부"))
            if hasWindow {
                lines.append(L10n.isEnglish ? "Includes a book featured in the Bookstore Show Window (+30%)." : "서점 전면 진열창(+30%)에 걸린 대표작이 포함된 서가입니다.")
            } else if hasCounter {
                lines.append(L10n.isEnglish ? "Includes a book displayed on the Central Table (100%)." : "서점 중앙 평대 매대(100%)에 진열된 작품이 포함된 서가입니다.")
            }
        }
        lines.append(L10n.isEnglish ? "Click to inspect or cycle through books shelved in this section." : "누르면 이 서가에 꽂힌 작품과 문호 정보를 차례로 살펴봅니다.")
        return lines
    }

    // MARK: - 삼면 책장 후원자 서재 도트 맵 생성

    private static func brightChar(for authorShort: String) -> Character {
        let chars: [Character] = ["0", "1", "2", "3", "4", "5", "6", "7"]
        if let idx = Library.authors.firstIndex(of: authorShort) {
            return chars[idx % chars.count]
        }
        return chars[abs(authorShort.hashValue) % chars.count]
    }

    private static func mutedChar(for authorShort: String) -> Character {
        let chars: [Character] = ["a", "b", "d", "e", "h", "i", "j", "l"]
        if let idx = Library.authors.firstIndex(of: authorShort) {
            return chars[idx % chars.count]
        }
        return chars[abs(authorShort.hashValue) % chars.count]
    }

    private static func palette(dark: Bool) -> [Character: Color] {
        let base: [Character: Color] = [
            // 벽면·바닥 타일·그림자
            "w": Color(red: 0.82, green: 0.74, blue: 0.62), // 상단 클래식 벽지 (밝은 톤)
            "W": Color(red: 0.74, green: 0.66, blue: 0.54), // 상단 클래식 벽지 (세로 스트라이프)
            "B": Color(red: 0.38, green: 0.24, blue: 0.14), // 월넛 걸레받이 몰딩
            "f": Color(red: 0.64, green: 0.47, blue: 0.31), // 원목 헤링본 타일 (밝은 칸)
            "F": Color(red: 0.56, green: 0.40, blue: 0.25), // 원목 헤링본 타일 (어두운 칸)
            "S": Color(red: 0.38, green: 0.26, blue: 0.16), // 가구 바닥 그림자
            // 3D 원목 책장·책상 재질
            "L": Color(red: 0.80, green: 0.60, blue: 0.38), // 가구 상판 하이라이트 모서리
            "t": Color(red: 0.62, green: 0.42, blue: 0.24), // 가구 상판·선반 밝은 원목
            "c": Color(red: 0.48, green: 0.31, blue: 0.17), // 가구 전면 수직 입체 패널 (밝은 면)
            "m": Color(red: 0.36, green: 0.22, blue: 0.12), // 가구 전면 수직 입체 패널 (음영·홈)
            "T": Color(red: 0.26, green: 0.16, blue: 0.09), // 가구 깊은 구조물 틀
            "N": Color(red: 0.15, green: 0.10, blue: 0.08), // 책장 선반 내부 깊은 음영
            "x": Color(red: 0.13, green: 0.11, blue: 0.12), // 외곽선
            // 양탄자·소품·조명
            "r": Color(red: 0.62, green: 0.19, blue: 0.21), // 페르시아 양탄자 주홍
            "R": Color(red: 0.44, green: 0.12, blue: 0.15), // 페르시아 양탄자 테두리
            "k": Color(red: 0.94, green: 0.78, blue: 0.30), // 황동 램프·금박 장식
            "Y": Color(red: 0.97, green: 0.94, blue: 0.85), // 펼쳐진 원고지·책 페이지 단면
            "g": Color(red: 0.22, green: 0.46, blue: 0.30), // 책상 녹색 가죽 매트·화분 잎
            "G": Color(red: 0.14, green: 0.32, blue: 0.20), // 화분 짙은 잎
            "u": Color(red: 0.30, green: 0.52, blue: 0.74), // 지구본 바다
            // 작가별 탈고 완료 양장본 색 (`0`~`7` 선명한 원색)
            "0": Color(red: 0.72, green: 0.20, blue: 0.26), // 크림슨
            "1": Color(red: 0.24, green: 0.52, blue: 0.34), // 포레스트 그린
            "2": Color(red: 0.32, green: 0.34, blue: 0.54), // 미드나잇 네이비
            "3": Color(red: 0.34, green: 0.58, blue: 0.86), // 세룰리안 블루
            "4": Color(red: 0.74, green: 0.50, blue: 0.22), // 앰버 브라운
            "5": Color(red: 0.58, green: 0.36, blue: 0.72), // 로열 퍼플
            "6": Color(red: 0.84, green: 0.54, blue: 0.64), // 로즈 핑크
            "7": Color(red: 0.24, green: 0.56, blue: 0.62), // 청록
            // 작가별 미탈고 전집 실루엣 색 (`a`~`l` 작가별 톤 다운된 고서 색)
            "a": Color(red: 0.40, green: 0.16, blue: 0.18),
            "b": Color(red: 0.17, green: 0.29, blue: 0.21),
            "d": Color(red: 0.20, green: 0.21, blue: 0.32),
            "e": Color(red: 0.20, green: 0.33, blue: 0.48),
            "h": Color(red: 0.42, green: 0.29, blue: 0.16),
            "i": Color(red: 0.34, green: 0.22, blue: 0.42),
            "j": Color(red: 0.48, green: 0.32, blue: 0.38),
            "l": Color(red: 0.17, green: 0.32, blue: 0.36),
        ]
        guard dark else { return base }
        return base.reduce(into: [:]) { result, pair in
            if pair.key == "k" || pair.key == "Y" {
                result[pair.key] = pair.value
                return
            }
            let c = NSColor(pair.value).usingColorSpace(.deviceRGB) ?? .gray
            result[pair.key] = Color(red: c.redComponent * 0.58 + 0.04,
                                     green: c.greenComponent * 0.54 + 0.04,
                                     blue: c.blueComponent * 0.60 + 0.08)
        }
    }

    private static func rows(sections: [BaySection], progress: WritingProgress, activeColorCh: Character) -> [String] {
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

        // 1) 8×8 체크무늬 원목 마루 타일
        for y in 0..<height {
            for x in 0..<width {
                let tileX = x / 8
                let tileY = y / 8
                if (tileX + tileY) % 2 == 1 {
                    put(x, y, "F")
                }
            }
        }

        // 2) 상단 클래식 스트라이프 벽면 (y: 0..<24) + 걸레받이 + 바닥 그림자
        fill(0, 0, width, 22, "w")
        for x in stride(from: 4, to: width, by: 6) {
            fill(x, 0, 2, 22, "W")
        }
        fill(0, 22, width, 2, "B")
        fill(0, 24, width, 2, "S")

        // 좌·우·하단 외벽 몰딩 테두리
        fill(0, 0, 2, height, "B")
        fill(width - 2, 0, 2, height, "B")
        fill(0, height - 2, width, 2, "B")

        // 3) 상단 뒷벽 4칸 입체 책장 (서가 0~3)
        for idx in 0..<4 where idx < sections.count {
            let section = sections[idx]
            let slot = section.slot
            let bx = slot.x
            let by = slot.y
            let bw = slot.w
            let bh = 25
            let bayBooks = section.books
            let fallbackAuthor = section.authors.first ?? "Shakespeare"

            fill(bx + 1, by + bh, bw, 2, "S")
            box(bx, by, bw, bh, "T", "x")
            fill(bx + 1, by + 1, bw - 2, 2, "t")
            fill(bx + 1, by + 1, bw - 2, 1, "L")
            fill(bx + 1, by + 3, bw - 2, 1, "c")

            var bookCursor = 0
            for sy in [by + 5, by + 11, by + 17] {
                fill(bx + 2, sy, bw - 4, 4, "N")
                fill(bx + 1, sy + 4, bw - 2, 2, "t")
                for col in 0..<6 {
                    let sx = bx + 3 + col * 4 + (col >= 3 ? 2 : 0)
                    if bookCursor < bayBooks.count {
                        let entry = bayBooks[bookCursor]
                        let bCh = brightChar(for: entry.element.authorShort)
                        let mCh = mutedChar(for: entry.element.authorShort)
                        if isDone(index: entry.offset, progress: progress) {
                            fill(sx, sy, 3, 4, bCh)
                            put(sx + 1, sy, "Y")
                            put(sx + 1, sy + 2, "k")
                        } else {
                            fill(sx, sy + 1, 3, 3, mCh)
                            put(sx + 1, sy + 2, "c")
                        }
                    } else {
                        let mCh = mutedChar(for: fallbackAuthor)
                        fill(sx, sy + 2, 2, 2, mCh)
                    }
                    bookCursor += 1
                }
            }

            fill(bx + 1, by + bh - 3, bw - 2, 2, "c")
            for px in stride(from: bx + 6, to: bx + bw - 3, by: 6) {
                fill(px, by + bh - 3, 1, 2, "m")
            }
        }

        // 4) 좌측 벽 2칸(서가 4~5) & 우측 벽 2칸(서가 6~7) 3/4 시점 측면 입체 서가
        for idx in 4..<8 where idx < sections.count {
            let section = sections[idx]
            let slot = section.slot
            let bx = slot.x
            let by = slot.y
            let bw = slot.w
            let bh = 38
            let bayBooks = section.books
            let fallbackAuthor = section.authors.first ?? "Stevenson"

            if idx < 6 {
                fill(bx + bw, by + 2, 2, bh, "S")
            } else {
                fill(bx - 2, by + 2, 2, bh, "S")
            }
            fill(bx + 1, by + bh, bw, 2, "S")

            box(bx, by, bw, bh, "T", "x")
            fill(bx + 1, by + 1, bw - 2, 3, "t")
            fill(bx + 1, by + 1, bw - 2, 1, "L")
            fill(bx + 1, by + 4, bw - 2, 1, "c")

            var bookCursor = 0
            for sy in [by + 6, by + 13, by + 20] {
                fill(bx + 2, sy, bw - 4, 5, "N")
                fill(bx + 1, sy + 5, bw - 2, 2, "t")
                for col in 0..<5 {
                    let sx = bx + 4 + col * 4 + (col >= 3 ? 1 : 0)
                    if bookCursor < bayBooks.count {
                        let entry = bayBooks[bookCursor]
                        let bCh = brightChar(for: entry.element.authorShort)
                        let mCh = mutedChar(for: entry.element.authorShort)
                        if isDone(index: entry.offset, progress: progress) {
                            fill(sx, sy + 1, 3, 4, bCh)
                            put(sx + 1, sy + 1, "Y")
                            put(sx + 1, sy + 3, "k")
                        } else {
                            fill(sx, sy + 2, 3, 3, mCh)
                            put(sx + 1, sy + 3, "c")
                        }
                    } else {
                        let mCh = mutedChar(for: fallbackAuthor)
                        fill(sx, sy + 3, 2, 2, mCh)
                    }
                    bookCursor += 1
                }
            }

            fill(bx + 1, by + 27, bw - 2, 10, "c")
            fill(bx + 1, by + 27, bw - 2, 1, "m")
            for pCol in 0..<3 {
                let px = bx + 2 + pCol * 8
                box(px, by + 28, 8, 8, "c", "m")
                put(px + 3, by + 31, "k")
            }
        }

        // 5) 중앙 페르시아 양탄자 (x: 48..<146, y: 44..<94)
        box(48, 44, 98, 50, "r", "x")
        box(50, 46, 94, 46, "r", "k")
        box(53, 49, 88, 40, "R", "r")
        for (cx, cy) in [(52, 48), (139, 48), (52, 87), (139, 87)] {
            fill(cx, cy, 3, 2, "k")
        }

        // 6) 후원자의 지구본 (양탄자 좌상단, x: 54, y: 50)
        fill(55, 61, 8, 2, "S")
        box(56, 59, 6, 3, "c", "x")
        fill(58, 57, 2, 2, "k")
        box(55, 50, 8, 8, "u", "k")
        fill(57, 52, 3, 2, "g")
        fill(59, 54, 2, 2, "g")

        // 7) 독서용 가죽 안락의자 (양탄자 우측, x: 130, y: 56)
        fill(131, 69, 11, 2, "S")
        box(130, 56, 11, 13, "0", "x")
        fill(132, 58, 7, 6, "r")
        fill(132, 64, 7, 4, "c")

        // 8) 중앙 후원자의 3D 마호가니 독서 책상 (x: 72..<122, y: 56..<78)
        fill(74, 77, 48, 3, "S")
        box(72, 56, 50, 11, "t", "x")
        fill(73, 57, 48, 1, "L")
        box(80, 58, 34, 7, "g", "T")
        fill(75, 58, 4, 3, "k")
        fill(76, 61, 2, 2, "c")
        box(91, 59, 12, 6, activeColorCh, "x")
        fill(92, 60, 4, 4, "Y")
        fill(97, 60, 4, 4, "Y")
        put(96, 60, activeColorCh)
        fill(116, 60, 3, 3, "x")
        put(117, 59, "k")

        box(72, 66, 50, 11, "c", "x")
        fill(73, 66, 48, 1, "m")
        box(74, 67, 13, 9, "c", "m")
        put(80, 70, "k"); put(80, 73, "k")
        fill(88, 67, 18, 9, "N")
        box(107, 67, 13, 9, "c", "m")
        put(113, 70, "k"); put(113, 73, "k")

        // 9) 하단 좌·우 화분과 출입구 레드 카펫 매트
        for px in [35, 149] {
            fill(px + 1, 108, 9, 2, "S")
            box(px, 97, 10, 7, "g", "G")
            fill(px + 2, 98, 6, 4, "G")
            box(px + 2, 103, 6, 5, "c", "x")
        }
        box(78, 107, 38, 8, "r", "R")
        fill(81, 109, 32, 4, "k")
        fill(82, 110, 30, 2, "r")

        return grid.map { String($0) }
    }
}
