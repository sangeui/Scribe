import AppKit
import SwiftUI

// 살롱. 마을 아래 살롱 문으로 들어가면 열리는 방. 탈고한 적이 있는 작가들이 긴 탁자에 둘러앉아 있다.
// ←→ 로 작가를 고르고 Return 으로 말을 건다. 작가들끼리도 가끔 말풍선을 띄운다. 하루 한 번 "같이 쓰자"고 청할 수 있다.

// MARK: - 방 그림

enum SalonRoom {
    static let cols = 14
    static let rows = 8
    static let tile = 16
    static let scale: CGFloat = 1.5
    static var width: Int { cols * tile }
    static var height: Int { rows * tile }

    /// 자리. 탁자 위쪽 넷은 아래를 보고, 아래쪽 셋은 위를 본다.
    static let seats: [(col: Int, row: Int, upper: Bool)] = [
        (3, 2, true), (5, 2, true), (7, 2, true), (9, 2, true),
        (4, 5, false), (6, 5, false), (8, 5, false),
    ]

    static let palette: [Character: Color] = [
        "w": Color(red: 0.84, green: 0.76, blue: 0.64),
        "W": Color(red: 0.76, green: 0.68, blue: 0.56),
        "b": Color(red: 0.42, green: 0.28, blue: 0.16),
        "f": Color(red: 0.62, green: 0.46, blue: 0.3),
        "F": Color(red: 0.52, green: 0.37, blue: 0.22),
        "t": Color(red: 0.56, green: 0.38, blue: 0.22),
        "T": Color(red: 0.36, green: 0.22, blue: 0.12),
        "c": Color(red: 0.4, green: 0.26, blue: 0.14),
        "r": Color(red: 0.6, green: 0.26, blue: 0.26),
        "R": Color(red: 0.44, green: 0.18, blue: 0.18),
        "k": Color(red: 0.98, green: 0.82, blue: 0.34),
        "o": Color(red: 0.9, green: 0.46, blue: 0.16),
        "s": Color(red: 0.52, green: 0.52, blue: 0.55),
        "S": Color(red: 0.36, green: 0.36, blue: 0.4),
        "u": Color(red: 0.36, green: 0.44, blue: 0.7),
        "g": Color(red: 0.32, green: 0.55, blue: 0.36),
        "x": Color(red: 0.2, green: 0.2, blue: 0.23),
        "e": Color(red: 0.95, green: 0.93, blue: 0.86),
    ]

    /// 밤에는 벽난로와 촛불 말고는 가라앉는다.
    static func palette(dark: Bool) -> [Character: Color] {
        guard dark else { return palette }
        return palette.reduce(into: [:]) { result, pair in
            if "ko".contains(pair.key) { result[pair.key] = pair.value; return }
            let c = NSColor(pair.value).usingColorSpace(.deviceRGB) ?? .gray
            result[pair.key] = Color(red: c.redComponent * 0.5 + 0.04, green: c.greenComponent * 0.45 + 0.03, blue: c.blueComponent * 0.5 + 0.08)
        }
    }

    /// 방 한 장. 벽지 두 줄, 벽난로, 책장 둘, 나무 바닥, 양탄자, 긴 탁자와 의자 일곱, 촛대.
    static func rows(fire: Bool) -> [String] {
        var grid = [[Character]](repeating: [Character](repeating: "f", count: width), count: height)
        func put(_ x: Int, _ y: Int, _ ch: Character) {
            guard (0..<width).contains(x), (0..<height).contains(y) else { return }
            grid[y][x] = ch
        }
        func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ ch: Character) {
            for yy in y..<(y + h) { for xx in x..<(x + w) { put(xx, yy, ch) } }
        }
        func box(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ ch: Character, _ o: Character = "x") {
            fill(x, y, w, h, ch); fill(x, y, w, 1, o); fill(x, y + h - 1, w, 1, o); fill(x, y, 1, h, o); fill(x + w - 1, y, 1, h, o)
        }
        // 바닥 널빤지: 8px 마다 가로선, 엇갈린 세로 이음새.
        for y in 0..<height where y % 8 == 7 { fill(0, y, width, 1, "F") }
        for y in stride(from: 0, to: height, by: 8) {
            for x in stride(from: (y / 8) % 2 == 0 ? 0 : 16, to: width, by: 32) { fill(x, y, 1, 7, "F") }
        }
        // 벽: 위 두 줄. 줄무늬 벽지와 굽도리.
        fill(0, 0, width, 30, "w")
        for x in stride(from: 3, to: width, by: 6) { fill(x, 0, 1, 30, "W") }
        fill(0, 30, width, 2, "b")
        fill(0, 32, width, 1, "x")
        // 벽난로(가운데): 돌 틀, 안쪽 어둡게, 불.
        box(88, 2, 48, 30, "s")
        for y in stride(from: 4, to: 30, by: 4) { for x in stride(from: 90 + (y / 4 % 2) * 4, to: 134, by: 8) { fill(x, y, 3, 1, "S") } }
        fill(98, 10, 28, 22, "x")
        fill(88, 2, 48, 3, "S"); fill(86, 0, 52, 2, "x")
        if fire {
            fill(104, 24, 16, 6, "o"); fill(108, 20, 8, 5, "o"); fill(110, 16, 4, 5, "k"); fill(106, 27, 12, 2, "k")
            put(103, 22, "o"); put(120, 23, "o"); put(112, 13, "k")
        }
        fill(100, 29, 24, 3, "S")
        // 책장 둘: 왼쪽과 오른쪽 벽.
        for x0 in [16, 176] {
            box(x0, 4, 32, 28, "T")
            for (i, y) in [7, 14, 21].enumerated() {
                fill(x0 + 1, y, 30, 1, "t")
                for (j, ch) in Array("rugkurgeur").enumerated() {
                    if (i + j) % 3 != 2 { fill(x0 + 2 + j * 3, y + 1, 2, 5, ch) }
                }
            }
        }
        // 양탄자와 긴 탁자(2~11열, 3~4행).
        box(32, 44, 160, 44, "r", "R")
        fill(34, 46, 156, 1, "R"); fill(34, 85, 156, 1, "R")
        box(48, 50, 128, 30, "t", "T")
        fill(49, 51, 126, 2, "e")
        // 촛대 셋.
        for x in [72, 112, 152] {
            fill(x, 58, 2, 10, "s"); fill(x - 1, 56, 4, 2, "k"); put(x, 54, "o")
        }
        // 의자: 위쪽 넷(2행), 아래쪽 셋(5행).
        for seat in seats {
            let x = seat.col * tile + 3, y = seat.row * tile + (seat.upper ? 2 : 4)
            box(x, y, 10, 12, "c")
            fill(x + 1, y + 1, 8, 2, "t")
        }
        return grid.map { String($0) }
    }
}

// MARK: - 상태

/// 살롱 안. 고른 작가, 대화, 작가들끼리의 말풍선.
@Observable
@MainActor
final class SalonState {
    var selected = 0
    var dialogue: Dialogue?
    /// 작가들끼리의 말. (자리 번호, 말, 사라지는 시각)
    var bubble: (seat: Int, text: String, until: Date)?
    /// 화면이 대화를 만들어 줘야 하는 자리. 화면이 읽고 비운다.
    var pendingTalk: Int?
    var pendingAction: Dialogue.Action?
    var talkTurn = 0
    /// 지금 앉아 있는 작가(`authorShort`). 화면이 채운다.
    var seated: [String] = []
    private var chatter: Task<Void, Never>?

    func enter() {
        selected = 0
        dialogue = nil
        bubble = nil
    }

    func leave() {
        chatter?.cancel()
        chatter = nil
        dialogue = nil
        bubble = nil
    }

    /// 키. 대화 중이면 그 안에서, 아니면 ←→ 로 고르고 Return 으로 말을 건다.
    func press(_ key: VillageState.Key) {
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
        guard !seated.isEmpty else { return }
        switch key {
        case .left, .up: selected = (selected + seated.count - 1) % seated.count
        case .right, .down: selected = (selected + 1) % seated.count
        case .enter: pendingTalk = selected
        case .escape: break
        }
    }

    /// 작가들끼리 가끔 한마디씩. 7초마다 둘을 골라 말다툼 문구를 번갈아 띄운다.
    func startChatter(pairs: @escaping @MainActor (Int, Int) -> (String, String)) {
        chatter?.cancel()
        guard seated.count >= 2 else { return }
        chatter = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            while let self, !Task.isCancelled {
                if self.dialogue == nil, self.seated.count >= 2 {
                    let a = Int.random(in: 0..<self.seated.count)
                    var b = Int.random(in: 0..<self.seated.count)
                    if b == a { b = (a + 1) % self.seated.count }
                    let (first, second) = pairs(a, b)
                    self.bubble = (a, first, Date().addingTimeInterval(3.5))
                    try? await Task.sleep(for: .seconds(3.5))
                    guard !Task.isCancelled else { return }
                    if self.dialogue == nil { self.bubble = (b, second, Date().addingTimeInterval(3.5)) }
                    try? await Task.sleep(for: .seconds(3.5))
                    self.bubble = nil
                }
                try? await Task.sleep(for: .seconds(Double.random(in: 5...9)))
            }
        }
    }
}

// MARK: - 말

@MainActor
enum SalonTalk {
    /// 앉은 작가. 탈고한 적이 있는 작가 가운데 지금 쓰는 작가와 손님 작가는 빼고, 서재 순서대로.
    static func seated(_ progress: WritingProgress) -> [String] {
        let done = Set(progress.finished.map { Library.books[$0.bookIndex].authorShort })
        let away: Set<String> = [progress.book?.authorShort, progress.guestAuthor].compactMap { $0 }.reduce(into: []) { $0.insert($1) }
        return Library.authors.filter { done.contains($0) && !away.contains($0) }.prefix(SalonRoom.seats.count).map { $0 }
    }

    static func name(_ author: String) -> String {
        Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author
    }

    /// 작가에게 말을 걸었을 때. 자기 책, 지금 쓰는 작가, 그 작가다운 말, 살롱 잡담을 돌아가며.
    static func author(_ author: String, progress: WritingProgress, now: Date, mood: Mood, turn: Int) -> Dialogue {
        var pool: [String] = []
        let mine = Library.books.filter { $0.authorShort == author && progress.sales(of: $0) > 0 }
            .sorted { progress.sales(of: $0) > progress.sales(of: $1) }
        if let best = mine.first {
            let tier = progress.salesTier(of: best)
            pool.append("\(best.displayTitle)(이|가) \(Format.integer(progress.sales(of: best)))부라니. \(tier == .none ? "아직 시작이오" : "\(tier.title)이라는 말을 들었소")")
            if let review = progress.review(of: best) {
                pool.append(review.stars >= 4 ? "\(review.critic)(이|가) \(best.displayTitle)에 \(review.starText)(을|를) 줬다지. 그 사람 안목이 있소"
                            : "\(review.critic)(이|가) \(best.displayTitle)에 \(review.starText)(을|를) 줬다더군. 그 사람 책은 읽어 봤소?")
            }
        }
        if let current = progress.book?.authorShort {
            let exchange = Quarrels.exchange(host: author, guest: current, rolls: (Double((turn * 7) % 10) / 10, 0.3))
            pool.append("\(name(current))(이|가) 쓰는 중이라지. 전해 주시오. \(exchange.host)")
            if let book = progress.book {
                pool.append("\(book.displayTitle)(은|는) \(Format.percent(progress.fraction * 100))까지 갔다던데. \(progress.fraction > 0.7 ? "끝이 보이겠군" : "아직 멀었군")")
            }
        }
        pool.append(Chatter.line(author: author, progress: progress, mood: mood, now: now, pokes: 1,
                                 rolls: (Double((turn * 3) % 10) / 10, Double((turn * 7) % 10) / 10)))
        if let title = progress.patronTitle {
            pool.append("오, \(title)께서 직접 살롱까지 걸음하셨구려. 늘 원고지와 차를 대 주시니 고맙소")
            pool.append("우리끼리도 방금 \(title) 이야기를 하던 참이었소. 자리가 비었으니 앉으시오")
        }
        pool.append(contentsOf: [
            "여기 커피는 늘 식어 있소. 그래도 오지",
            "벽난로 자리는 내가 먼저 앉았소",
            "오늘 \(progress.weather.title)(이|가)군. 글 쓰기엔 \(progress.weather == .rain ? "좋은" : "그런") 날씨요",
            "살롱이 조용한 날은 다들 쓰고 있다는 뜻이오",
        ])
        let line = pool[(turn + author.count) % pool.count]
        var dialogue = Dialogue(name: name(author), pages: VillageTalk.split(line.resolvedParticles))
        if progress.canInvite {
            dialogue.options = [Dialogue.Option(label: "같이 쓰자고 청하기", action: .invite), Dialogue.Option(label: "그냥 듣기", action: .close)]
        }
        return dialogue
    }

    /// 작가들끼리. 말다툼 문구를 그대로 쓴다.
    static func pair(_ a: String, _ b: String) -> (String, String) {
        let exchange = Quarrels.exchange(host: a, guest: b, rolls: (Double.random(in: 0..<1), Double.random(in: 0..<1)))
        return (exchange.host, exchange.guest)
    }
}

// MARK: - 화면

struct SalonView: View {
    let progress: WritingProgress
    let state: SalonState
    var animated = true
    var date = Date()
    var mood: Mood = .focused
    /// 그 작가에게 같이 쓰자고 청한다. 결과 한 줄.
    var onInvite: @MainActor (String) -> String? = { _ in nil }
    var onLeave: @MainActor () -> Void = {}

    var body: some View {
        let dark = DayPart.isDark(at: date)
        let scale = SalonRoom.scale
        let tile = CGFloat(SalonRoom.tile) * scale
        let seated = SalonTalk.seated(progress)
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                PixelFrame(rows: SalonRoom.rows(fire: true), scale: scale, palette: SalonRoom.palette(dark: dark))
                // 앉은 작가들. 초상화 그대로, 위쪽은 아래를 본다.
                ForEach(Array(seated.enumerated()), id: \.offset) { i, author in
                    let seat = SalonRoom.seats[i]
                    let on = i == state.selected
                    PixelFrame(rows: Portraits.rows(author, event: nil, mood: .focused, expression: on ? .happy : .neutral), scale: scale,
                               palette: Portraits.palette(event: nil, dayPart: dark ? .night : .day, weather: nil))
                        .position(x: CGFloat(seat.col) * tile + tile / 2 + 4, y: CGFloat(seat.row) * tile + tile / 2 - 2)
                    // 위쪽 줄은 벽에 붙어 있어 말풍선과 표시를 머리 아래(탁자 위)에, 아래쪽 줄은 머리 위에 둔다.
                    let below = seat.upper
                    let markY = below ? CGFloat(seat.row) * tile + tile * 1.45 : CGFloat(seat.row) * tile - tile * 0.7
                    if on, state.dialogue == nil {
                        ActionPrompt(symbol: "bubble.left", label: "말 걸기", animated: animated, tailUp: below)
                            .position(x: CGFloat(seat.col) * tile + tile / 2 + 4, y: markY)
                    }
                    // 말풍선은 표시보다 한 칸 더 멀리(위쪽 줄은 탁자 가운데, 아래쪽 줄은 탁자 위) 두어 겹치지 않는다.
                    if let bubble = state.bubble, bubble.seat == i, state.dialogue == nil {
                        SpeechBubble(text: bubble.text, tailUp: below)
                            .frame(maxWidth: 150)
                            .position(x: min(max(CGFloat(seat.col) * tile + tile / 2 + 4, 80), CGFloat(SalonRoom.width) * scale - 80),
                                      y: below ? CGFloat(seat.row) * tile + tile * 2.45 : CGFloat(seat.row) * tile - tile * 1.55)
                            .transition(.opacity)
                    }
                }
                if seated.isEmpty {
                    Text("아직 아무도 없습니다.\n첫 책을 탈고하면 그 작가가 옵니다.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                        .position(x: CGFloat(SalonRoom.width) * scale / 2, y: CGFloat(SalonRoom.height) * scale * 0.55)
                }
                if let dialogue = state.dialogue {
                    DialogueBox(dialogue: dialogue)
                        .frame(width: CGFloat(SalonRoom.width) * scale - 12)
                        .offset(x: 6, y: CGFloat(SalonRoom.height) * scale - 58)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: CGFloat(SalonRoom.width) * scale, height: CGFloat(SalonRoom.height) * scale)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Color(red: 0.2, green: 0.2, blue: 0.23), lineWidth: 2))
            .onAppear {
                state.seated = seated
                if animated { state.startChatter { a, b in SalonTalk.pair(seated[a], seated[b]) } }
            }
            .onChange(of: seated) { _, now in
                state.seated = now
                state.selected = min(state.selected, max(0, now.count - 1))
                if animated { state.startChatter { a, b in SalonTalk.pair(now[a], now[b]) } }
            }
            .onChange(of: state.pendingTalk) { _, seat in
                guard let seat, seated.indices.contains(seat) else { return }
                state.pendingTalk = nil
                state.talkTurn += 1
                state.dialogue = SalonTalk.author(seated[seat], progress: progress, now: date, mood: mood, turn: state.talkTurn)
            }
            .onChange(of: state.pendingAction) { _, action in
                guard let action else { return }
                state.pendingAction = nil
                if action == .invite, seated.indices.contains(state.selected) {
                    let author = seated[state.selected]
                    state.dialogue = Dialogue(name: SalonTalk.name(author), pages: [onInvite(author) ?? "오늘은 이미 누군가를 청했습니다"])
                }
            }
            .animation(.easeOut(duration: 0.18), value: state.dialogue)
            .animation(.easeOut(duration: 0.25), value: state.bubble?.text)
            .onTapGesture { location in
                if state.dialogue != nil { state.press(.enter); return }
                let col = Int(location.x / tile), row = Int(location.y / tile)
                if let i = seated.indices.first(where: { abs(SalonRoom.seats[$0].col - col) <= 1 && abs(SalonRoom.seats[$0].row - row) <= 1 }) {
                    if state.selected == i { state.pendingTalk = i } else { state.selected = i }
                }
            }
            HStack(spacing: 10) {
                Symbol(name: "arrow.left.arrow.right", size: 10)
                Text(help).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 0)
                Text(state.dialogue == nil ? "Esc 나가기" : "Esc 대화 닫기").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}

extension SalonView {
    /// 아래 안내 줄.
    private var help: String {
        guard let dialogue = state.dialogue else { return "← → 로 작가를 고르고 Return 으로 말을 겁니다." }
        if dialogue.isLast, !dialogue.options.isEmpty { return "← → 로 고르고, Return 으로 정합니다." }
        return "Return 으로 다음 말을 봅니다."
    }
}

/// 작가들끼리의 말풍선. 작고 흰 상자, 아래 꼬리.
struct SpeechBubble: View {
    let text: String
    var tailUp = false

    var body: some View {
        VStack(spacing: 0) {
            if tailUp { Triangle().fill(Color.white.opacity(0.95)).frame(width: 7, height: 4).rotationEffect(.degrees(180)) }
            Text(text)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(red: 0.2, green: 0.2, blue: 0.23), lineWidth: 1.5))
            if !tailUp { Triangle().fill(Color.white.opacity(0.95)).frame(width: 7, height: 4) }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
