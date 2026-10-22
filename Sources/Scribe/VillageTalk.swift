import Foundation

// 마을에서 Return 을 눌렀을 때 나오는 말. 손님 네 사람은 저마다 이름과 말투와 걷는 버릇이 있고,
// 작가는 창가에서, 서점 주인은 진열창 너머에서, 우체통과 팻말과 상자는 지금 상태를 읽어 준다.

/// 대화 상자 한 번. 이름, 쪽(한 쪽에 한두 줄), 마지막 쪽의 선택지.
struct Dialogue: Equatable {
    struct Option: Equatable {
        let label: String
        let action: Action
    }
    enum Action: Equatable { case close, recommend, invite }

    let name: String
    let pages: [String]
    var options: [Option] = []
    var page = 0
    var selected = 0

    var isLast: Bool { page >= pages.count - 1 }
}

/// 손님 유형. 걷는 버릇은 `wait`(다음 행동까지 밀리초)와 `walkChance`.
struct Persona: Sendable {
    let name: String
    let wait: ClosedRange<Int>
    let walkChance: Double
    let lines: [String]

    static let all: [Persona] = [
        Persona(name: "단골 할아버지", wait: 1_800...4_200, walkChance: 0.3, lines: [
            "{A} 책은 젊을 때 다 읽었지. {T}(은|는) 그때도 좋았어",
            "요즘 책은 글쎄… 그래도 {T}(은|는) 다시 사 볼 만해",
            "서점 주인이 자네 얘기를 자주 하네. {R}",
            "비 오는 날엔 {T} 같은 책이 제맛이야. 오늘은 {W}(이|가)군",
            "{E} 그 일 말일세, 나도 거기 있었어",
            "천천히 쓰게. 급하게 쓴 책은 금방 티가 나",
            "손님이 많으면 좋지. 오늘 {N}부 나갔다던가",
        ]),
        Persona(name: "학생 손님", wait: 300...1_100, walkChance: 0.75, lines: [
            "{T} 벌써 {S}래요! 저도 한 권 샀어요",
            "다음 책은 뭐예요? {O}",
            "{A} 선생님 진짜 여기 사세요? 사인 받고 싶어요",
            "수업 시간에 몰래 읽다가 걸렸어요. {T}요",
            "서점 아저씨가 {F}(을|를) 진열창에 걸었더라고요. 멋있어요",
            "오늘 {W}라서 책 읽기 딱 좋은 날이에요",
            "{E} 그날 저도 줄 섰어요!",
        ]),
        Persona(name: "비평가 지망생", wait: 1_000...2_600, walkChance: 0.45, lines: [
            "{C}(이|가) {T}에 {S}(을|를) 줬더군요. 나라면 조금 다르게 썼겠지만",
            "{R} …이라고들 하는데, 글쎄요",
            "{T}의 결말은 호불호가 갈립니다. 저는 호",
            "문장이 전보다 빨라졌다는 말이 있습니다. 느낌이 옵니까?",
            "{E} 그런 소동은 책을 못 읽는 사람들이 벌이는 거죠",
            "서평은 믿지 마세요. 저만 믿으세요",
            "{A}의 문체는 흉내 내기 어렵습니다. 몇 번 해 봤습니다",
        ]),
        Persona(name: "장꾼", wait: 600...1_900, walkChance: 0.6, lines: [
            "{T} {N}부면 장사 괜찮게 되는 거지. 값은 내려도 돼",
            "품절은 곧 기회야. 재판 들어오면 내가 도매로 떼 가지",
            "{P} 그 광고 효과 있어? 내가 벽보 자리 하나 알아",
            "{E} 그런 날은 장사가 달라. 사람이 모이면 돈도 모이거든",
            "주인이 자네를 {L}(이|가)라던데. 더 올라가면 매대가 넓어져",
            "{W}에는 손님이 {Wn}. 날씨도 장사지",
            "다음 책 나오면 나한테 먼저 알려 줘. 열 권은 받아 가",
        ]),
    ]
}

@MainActor
enum VillageTalk {
    /// 손님 말. 하루와 몇 번째 말인지에 따라 돌아가며 나온다.
    static func customer(_ index: Int, progress: WritingProgress, now: Date, turn: Int, leaving: Bool) -> Dialogue {
        let persona = Persona.all[index % Persona.all.count]
        if leaving {
            return Dialogue(name: persona.name, pages: ["품절이라네요. 재판 들어오면 다시 오죠".resolvedParticles])
        }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? 0
        let line = persona.lines[(day * 3 + index * 5 + turn) % persona.lines.count]
        let pages = split(fill(line, progress: progress, now: now))
        var dialogue = Dialogue(name: persona.name, pages: pages)
        if progress.recommendationsLeft > 0, !progress.books(in: .window).isEmpty || !progress.books(in: .counter).isEmpty {
            dialogue.options = [Dialogue.Option(label: "책 권하기", action: .recommend), Dialogue.Option(label: "그냥 듣기", action: .close)]
        }
        return dialogue
    }

    /// 작가가 창가에 나와서 하는 말. 상시 창 초상화를 눌렀을 때와 같다.
    static func author(progress: WritingProgress, now: Date, mood: Mood, turn: Int) -> Dialogue {
        guard let book = progress.book else { return Dialogue(name: "작가", pages: ["아무도 없습니다"]) }
        let rolls = (Double((turn * 7) % 10) / 10, Double((turn * 3) % 10) / 10)
        let text = Chatter.line(author: book.authorShort, progress: progress, mood: mood, now: now, pokes: min(turn, 2), rolls: rolls)
        return Dialogue(name: book.displayAuthorShort, pages: split(text))
    }

    /// 서점 주인이 진열창 너머로 하는 말. 신뢰, 진열창 책, 재고.
    static func shopkeeper(progress: WritingProgress, now: Date, turn: Int) -> Dialogue {
        let level = progress.trustLevel
        let window = progress.books(in: .window).first
        let soldOut = progress.books(in: .storage)
        var lines: [String] = []
        switch level {
        case .distant: lines.append("아직 서로 잘 모르니, 매대는 두 칸만 내드리겠습니다")
        case .acquainted: lines.append("낯이 익었습니다. 진열창을 쓰셔도 됩니다")
        case .usual: lines.append("손님들이 자네 책을 찾습니다. 나쁘지 않아요")
        case .friendly: lines.append("자네 책은 믿고 들여놓지. 매대 네 칸 쓰시게")
        case .regular: lines.append("우리 서점 간판 작가 아닌가. 뭐든 말만 하게")
        }
        if let window { lines.append("진열창엔 \(window.displayTitle)(을|를) 걸어 두었습니다. 지나는 사람마다 봅니다") }
        if let gone = soldOut.first { lines.append("\(gone.displayTitle)(은|는) 다 나갔습니다. 재판이 오면 바로 내놓지요") }
        lines.append("오늘 \(Format.integer(progress.dailySales.last?.copies ?? 0))부 나갔습니다. 이번 주 \(Format.integer(progress.weekSales))부")
        if let latest = progress.shopLog.first { lines.append(latest.text) }
        let line = lines[turn % lines.count]
        return Dialogue(name: "서점 주인", pages: split(line.resolvedParticles))
    }

    /// 우체통. 기다리는 편지.
    static func mailbox(progress: WritingProgress, now: Date) -> Dialogue {
        var pages: [String] = []
        if let order = progress.order, let book = Library.books.first(where: { $0.file == order.book }) {
            let days = max(0, Int(ceil(order.expiresAt.timeIntervalSince(now) / 86_400)))
            pages.append("독자 편지: \(book.displayTitle)(을|를) 기다린답니다. \(days)일 안에 시작해야 합니다".resolvedParticles)
        }
        if let waiting = progress.awaitingPublisher, let book = Library.books.first(where: { $0.file == waiting.book }) {
            pages.append("출판사들이 \(book.displayTitle) 원고를 두고 답을 기다립니다. 팝오버에서 고를 수 있습니다")
        }
        if let statement = progress.statementCard {
            pages.append("서점 정산서: 지난주 \(Format.integer(statement.sold))부. \"\(statement.keeperLine)\"")
        }
        if let deadline = progress.deadline, deadline.met != true, deadline.failed != true {
            pages.append("이번 주 마감: \(deadline.title). \(Format.integer(progress.deadlineProgress)) / \(Format.integer(deadline.target))")
        }
        if pages.isEmpty { pages = ["우체통이 비어 있습니다"] }
        return Dialogue(name: "우체통", pages: pages)
    }

    /// 팻말. 오늘·이번 주 판매와 품절.
    static func signpost(progress: WritingProgress, now: Date) -> Dialogue {
        var pages = ["오늘 \(Format.integer(progress.dailySales.last?.copies ?? 0))부 · 이번 주 \(Format.integer(progress.weekSales))부 · 모두 \(Format.integer(progress.totalSales))부"]
        for book in progress.books(in: .storage) {
            if let reprint = progress.reprint(for: book) {
                let hours = max(1, Int((reprint.due.timeIntervalSince(now) / 3600).rounded(.up)))
                pages.append("\(book.displayTitle) 품절. 재판 \(Format.integer(reprint.copies))부가 \(hours)시간 뒤에 들어옵니다")
            }
        }
        return Dialogue(name: "팻말", pages: pages)
    }

    /// 창고 상자. 아이템.
    static func crates(progress: WritingProgress) -> Dialogue {
        let held = ItemKind.allCases.filter { progress.count($0) > 0 }
        guard !held.isEmpty else { return Dialogue(name: "상자", pages: ["상자가 비어 있습니다. 토큰 \(Format.tokens(Balance.tokensPerItem))개마다 하나씩 들어옵니다"]) }
        let list = held.map { "\($0.shortTitle) \(progress.count($0))" }.joined(separator: " · ")
        return Dialogue(name: "상자", pages: [list, "다음 아이템까지 \(Format.tokens(progress.tokensToNextItem))개. 창고 문으로 들어가면 쓸 수 있습니다"])
    }

    /// 작업실 앞 장작더미. 5시간 한도가 남은 몫과 새로 채워지는 때.
    static func woodpile(_ fuel: LimitRow, now: Date) -> Dialogue {
        let left = Int(min(100, max(0, 100 - fuel.percent)).rounded())
        let logs = VillageMap.logs(fuel)
        let look = switch logs {
        case 0: "장작이 다 떨어졌습니다. 난로가 식었습니다"
        case 1...2: "장작이 몇 개 안 남았습니다. 아껴 때야겠습니다"
        case 3...4: "장작이 절반쯤 남았습니다"
        default: "장작이 넉넉하게 쌓여 있습니다"
        }
        var pages = [look, "5시간 한도가 \(left)% 남았습니다"]
        if let reset = fuel.resetsAt, reset > now {
            pages[1] += ". \(reset.formatted(date: .omitted, time: .shortened))에 새 장작이 들어옵니다"
        }
        return Dialogue(name: "장작더미", pages: pages)
    }

    // MARK: 채우기

    /// {T} 진열창 책 또는 많이 팔린 책, {A} 그 작가, {S} 서평 별, {N} 오늘 부수, {W} 날씨, {E} 최근 사건, {O} 독자 주문, {R} 풍문 한 줄, {C} 비평가, {F} 진열창 책, {P} 광고 책, {L} 신뢰 단계, {Wn} 날씨에 따른 손님.
    private static func fill(_ line: String, progress: WritingProgress, now: Date) -> String {
        let top = progress.books(in: .window).first ?? progress.books(in: .counter).first ?? Library.books.first { progress.sales(of: $0) > 0 } ?? Library.books[0]
        let review = progress.review(of: top)
        let gossip = Gossip.lines(progress: progress, now: now)
        let ordered = progress.order.flatMap { o in Library.books.first { $0.file == o.book } }
        let weatherCustomers: String = switch progress.weather {
        case .rain, .storm: "줄어"
        case .snow: "안 와"
        case .heat: "낮엔 안 와"
        case .fog: "길을 잃어"
        default: "많아"
        }
        var text = line
        let pairs: [(String, String)] = [
            ("{T}", top.displayTitle), ("{A}", top.displayAuthorShort),
            ("{S}", review.map { "별 \($0.stars)개" } ?? "서평 전"),
            ("{N}", Format.integer(progress.dailySales.last?.copies ?? 0)),
            ("{Wn}", weatherCustomers), ("{W}", progress.weather.title),
            ("{E}", progress.shopLog.first.map { $0.text + "." } ?? "요즘 조용하죠."),
            ("{O}", ordered.map { "\($0.displayTitle) 나온다면서요?" } ?? "아직 소문이 없네요"),
            ("{R}", gossip.first ?? "별 소문은 없습니다"),
            ("{C}", review?.critic ?? "비평가"),
            ("{F}", progress.books(in: .window).first?.displayTitle ?? "아무것도"),
            ("{P}", progress.ads.keys.first.flatMap { f in Library.books.first { $0.file == f }?.displayTitle } ?? "광고도 없고"),
            ("{L}", progress.trustLevel.title),
        ]
        for (key, value) in pairs { text = text.replacingOccurrences(of: key, with: value) }
        return text.resolvedParticles
    }

    /// 긴 말은 문장 단위로 쪽을 나눈다(한 쪽 60자쯤).
    static func split(_ text: String) -> [String] {
        let sentences = text.split(whereSeparator: { ". ".contains($0) && $0 == "." }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var pages: [String] = []
        var current = ""
        for sentence in sentences {
            let piece = sentence.hasSuffix("?") || sentence.hasSuffix("!") ? sentence : sentence
            if current.isEmpty { current = piece }
            else if current.count + piece.count + 2 <= 60 { current += ". " + piece }
            else { pages.append(current); current = piece }
        }
        if !current.isEmpty { pages.append(current) }
        return pages.isEmpty ? [text] : pages
    }
}
