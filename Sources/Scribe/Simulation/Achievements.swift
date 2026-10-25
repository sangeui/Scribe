import SwiftUI

// 성과. 기록 파일에 있는 값만으로 셀 수 있는 것들이고, 한 번 달성하면 날짜와 함께 남는다.
// 처음 이 기능이 생겼을 때 이미 이룬 성과는 알림 없이 조용히 채운다.
// 같은 종류의 단계(원고 1만·10만·100만 자)는 `chain` 으로 묶어, 아직 못 받은 것은 다음 단계 하나만 보여 준다.
// 비밀 성과는 이루기 전에는 이름과 조건을 가린다.

enum BadgeTier: Int, Comparable, Sendable {
    case bronze, silver, gold

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    var name: String {
        switch self {
        case .bronze: "동"
        case .silver: "은"
        case .gold: "금"
        }
    }

    var color: Color {
        switch self {
        case .bronze: Color(red: 0.72, green: 0.45, blue: 0.24)
        case .silver: Color(red: 0.56, green: 0.6, blue: 0.67)
        case .gold: Color(red: 0.85, green: 0.65, blue: 0.13)
        }
    }

    /// 메달 테두리의 밝은 쪽. 금속 느낌을 조금 낸다.
    var highlight: Color {
        switch self {
        case .bronze: Color(red: 0.9, green: 0.66, blue: 0.42)
        case .silver: Color(red: 0.82, green: 0.85, blue: 0.9)
        case .gold: Color(red: 0.98, green: 0.85, blue: 0.4)
        }
    }
}

enum BadgeCategory: String, CaseIterable, Sendable {
    case writing, books, sales, bookstore, events, disasters, tokens, secret

    var title: String {
        switch self {
        case .writing: "집필"
        case .books: "탈고"
        case .sales: "판매"
        case .bookstore: "서점"
        case .events: "돌발 상황"
        case .disasters: "자연재해"
        case .tokens: "토큰"
        case .secret: "비밀"
        }
    }
}

/// 성과를 셀 때 쓰는 값. 기록 파일에서 한 번에 뽑는다.
struct AchievementFacts: Sendable {
    var totalCharacters = 0.0
    /// 오늘 쓴 글자와 토큰. 매일 초기화되는 성과가 본다.
    var todayCharacters = 0.0
    var todayTokens = 0
    /// 하루도 빠짐없이 쓴 가장 긴 날수.
    var longestStreak = 0
    /// 처음 글자를 쓴 날.
    var firstDay: Date?
    var finishedBooks = 0
    var completedRounds = 0
    /// 한 회차 안에 작품을 모두 탈고한 작가(`authorShort`).
    var completedAuthors: Set<String> = []
    var eventsSeen = 0
    var itemsUsed = 0
    var coffeeUsed = 0
    /// 아이템 없이 끝까지 기다린 상황.
    var waitedOut = 0
    /// 새벽 0~4시에 시작한 돌발 상황.
    var nightEvents = 0
    /// 하루에 가장 많이 겪은 돌발 상황.
    var mostEventsInDay = 0
    /// 하루에 커피·홍차로 끝낸 상황이 가장 많았던 날의 수.
    var mostCupsInDay = 0
    var disasters = 0
    /// 자연재해로 잃은 글자 합계.
    var lostCharacters = 0
    /// 행운을 겪은 횟수, 그중 손님 작가와 선금.
    var lucks = 0
    var guests = 0
    var advances = 0
    /// 방재 아이템으로 막은 재해.
    var shieldBlocks = 0
    /// 주말(토·일)에 쓴 글자.
    var weekendCharacters = 0.0
    /// 한 편 이상 탈고한 작가.
    var authorsFinished: Set<String> = []
    /// 판매: 모두, 가장 많이 팔린 책, 가장 많이 팔린 작가, 탈고작이 모두 재판 이상인지.
    var totalSales = 0
    var bestBookSales = 0
    var bestAuthorSales = 0
    var allReprinted = false
    /// 잡다한 셈(`WritingStore.Counter`).
    var exchanges = 0
    var persistence = 0
    var nightCharacters = 0
    var reads = 0
    var focuses = 0
    var caught = 0
    var decisions = 0
    var panned = 0
    var ignitions = 0
    var deadlinesMet = 0
    var deadlinesMissed = 0
    var betsWon = 0
    var betsLost = 0
    /// 작업실 가구 수, 써 본 출판사 수.
    var furniture = 0
    var publishersUsed = 0
    var ads = 0
    var ordersFilled = 0
    var shopEvents = 0
    var statUps = 0
    var exhaustions = 0
    var quarrels = 0
    var taps = 0
    /// 실린 비평 수와 그중 별 5개.
    var reviews = 0
    var fiveStars = 0
    /// 다섯 가지 아이템을 한꺼번에 가졌는지.
    var holdsEveryItem = false
    /// 지금 가진 커피.
    var coffeeHeld = 0

    init() {}

    @MainActor
    init(state: WritingState, finished: [FinishedBook], now: Date = Date()) {
        let days = state.days.sorted { $0.key < $1.key }
        totalCharacters = days.reduce(0) { $0 + $1.value.net }
        let today = state.days[DayKey.string(from: Calendar.current.startOfDay(for: now))]
        todayCharacters = today?.characters ?? 0
        todayTokens = today?.tokens ?? 0

        var streak = 0, previous: Date?
        let calendar = Calendar.current
        for (key, record) in days where record.characters > 0 {
            guard let date = DayKey.date(from: key) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            if weekday == 1 || weekday == 7 { weekendCharacters += record.characters }
            if firstDay == nil { firstDay = date }
            if let previous, calendar.dateComponents([.day], from: previous, to: date).day == 1 {
                streak += 1
            } else {
                streak = 1
            }
            longestStreak = max(longestStreak, streak)
            previous = date
        }

        finishedBooks = finished.count
        authorsFinished = Set(finished.map { Library.books[$0.bookIndex].authorShort })
        // 회차 수: 그 회차의 작품을 모두 탈고했으면 한 바퀴.
        completedRounds = Dictionary(grouping: finished, by: \.round).values.filter { $0.count >= Library.books.count }.count
        let done = Set(finished.map { "\($0.round)-\($0.bookIndex)" })
        for round in Set(finished.map(\.round)) {
            for author in Library.authors {
                let indices = Library.books.indices.filter { Library.books[$0].authorShort == author }
                if !indices.isEmpty, indices.allSatisfy({ done.contains("\(round)-\($0)") }) {
                    completedAuthors.insert(author)
                }
            }
        }

        var perDay: [String: Int] = [:]
        for record in state.eventLog {
            if record.event.hasPrefix("luck.") {
                lucks += 1
                if record.event == Lucks.guest.id { guests += 1 }
                if record.event == Lucks.advance.id { advances += 1 }
                continue
            }
            if let lost = record.lostCharacters {
                disasters += 1
                lostCharacters += lost
                if record.endedBy != nil { shieldBlocks += 1 }
                continue
            }
            eventsSeen += 1
            perDay[DayKey.string(from: record.startedAt), default: 0] += 1
            if (0..<4).contains(calendar.component(.hour, from: record.startedAt)) { nightEvents += 1 }
            if let item = record.endedBy {
                itemsUsed += 1
                if ItemKind(rawValue: item)?.role == .wake { coffeeUsed += 1 }
            } else if record.endedAt != nil {
                waitedOut += 1
            }
        }
        mostEventsInDay = perDay.values.max() ?? 0
        var cupsPerDay: [String: Int] = [:]
        for record in state.eventLog {
            guard let ended = record.endedAt, let item = record.endedBy.flatMap(ItemKind.init(rawValue:)), item.role == .wake else { continue }
            cupsPerDay[DayKey.string(from: ended), default: 0] += 1
        }
        mostCupsInDay = cupsPerDay.values.max() ?? 0
        holdsEveryItem = ItemRole.allCases.allSatisfy { role in role.kinds.contains { state.items[$0.rawValue, default: 0] > 0 } }
        totalSales = Int(state.sales.values.reduce(0, +))
        bestBookSales = Int(state.sales.values.max() ?? 0)
        var byAuthor: [String: Double] = [:]
        for (file, copies) in state.sales {
            if let book = Library.books.first(where: { $0.file == file }) { byAuthor[book.authorShort, default: 0] += copies }
        }
        bestAuthorSales = Int(byAuthor.values.max() ?? 0)
        let finishedFiles = Set(finished.map { Library.books[$0.bookIndex].file })
        allReprinted = !finishedFiles.isEmpty && finishedFiles.allSatisfy { SalesTier.of(copies: state.sales[$0, default: 0]) >= .reprint }
        exchanges = state.counters[WritingStore.Counter.exchanges.rawValue, default: 0]
        persistence = state.counters[WritingStore.Counter.persistence.rawValue, default: 0]
        nightCharacters = state.counters[WritingStore.Counter.nightCharacters.rawValue, default: 0]
        reads = state.counters[WritingStore.Counter.reads.rawValue, default: 0]
        focuses = state.counters[WritingStore.Counter.focuses.rawValue, default: 0]
        caught = state.counters[WritingStore.Counter.caught.rawValue, default: 0]
        decisions = state.counters[WritingStore.Counter.decisions.rawValue, default: 0]
        ignitions = state.counters[WritingStore.Counter.ignitions.rawValue, default: 0]
        deadlinesMet = state.counters[WritingStore.Counter.deadlinesMet.rawValue, default: 0]
        deadlinesMissed = state.counters[WritingStore.Counter.deadlinesMissed.rawValue, default: 0]
        betsWon = state.counters[WritingStore.Counter.betsWon.rawValue, default: 0]
        betsLost = state.counters[WritingStore.Counter.betsLost.rawValue, default: 0]
        furniture = state.studio.count
        ads = state.counters[WritingStore.Counter.ads.rawValue, default: 0]
        ordersFilled = state.counters[WritingStore.Counter.ordersFilled.rawValue, default: 0]
        shopEvents = state.counters[WritingStore.Counter.shopEvents.rawValue, default: 0]
        statUps = state.counters[WritingStore.Counter.statUps.rawValue, default: 0]
        exhaustions = state.counters[WritingStore.Counter.exhaustions.rawValue, default: 0]
        publishersUsed = Publisher.allCases.filter { state.counters[WritingStore.Counter.publishers.rawValue + "." + $0.rawValue] != nil }.count
        panned = state.counters[WritingStore.Counter.panned.rawValue, default: 0]
        quarrels = state.counters[WritingStore.Counter.quarrels.rawValue, default: 0]
        taps = state.counters[WritingStore.Counter.taps.rawValue, default: 0]
        let published = state.reviews.filter { $0.published == true }
        reviews = published.count
        fiveStars = published.filter { $0.stars == 5 }.count
        coffeeHeld = ItemRole.wake.kinds.reduce(0) { $0 + state.items[$1.rawValue, default: 0] }
    }
}

/// 금 뱃지가 주는 작은 효과. 받은 뱃지의 효과를 모두 합쳐 `Perks` 가 된다.
enum Perk: Sendable, Equatable {
    /// 100만 토큰당 글자 수를 이 비율만큼 더.
    case characters(Double)
    /// 아이템 하나에 드는 토큰에 곱한다.
    case itemTokens(Double)
    /// 돌발 상황 확률에 곱한다.
    case eventChance(Double)
    /// 돌발 상황 지속 시간에 곱한다.
    case eventDuration(Double)
    /// 그 작가의 작품을 쓰는 동안 돌발 상황 지속 시간에 곱한다.
    case authorEventDuration(String, Double)
    /// 아이템 거절 확률에서 뺀다.
    case refusal(Double)
    /// 거절당한 뒤 기다리는 시간에 곱한다.
    case refusalWait(Double)
    /// 자연재해로 잃는 글자에 곱한다.
    case disasterLoss(Double)

    @MainActor
    var text: String {
        switch self {
        case .characters(let r): "100만 토큰당 글자 \(Int((r * 100).rounded()))% 더"
        case .itemTokens(let m): "아이템에 드는 토큰 \(Int(((1 - m) * 100).rounded()))% 줄어듦"
        case .eventChance(let m): "돌발 상황 확률 \(Int(((1 - m) * 100).rounded()))% 줄어듦"
        case .eventDuration(let m): "돌발 상황 \(Int(((1 - m) * 100).rounded()))% 짧아짐"
        case .authorEventDuration(let author, let m):
            "\(Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author) 작품을 쓸 때 돌발 상황 \(Int(((1 - m) * 100).rounded()))% 짧아짐"
        case .refusal(let d): "아이템 거절 확률 \(Int((d * 100).rounded()))%p 줄어듦"
        case .refusalWait(let m): "거절당한 뒤 기다리는 시간 \(Int(((1 - m) * 100).rounded()))% 줄어듦"
        case .disasterLoss(let m): "자연재해로 잃는 원고 \(Int(((1 - m) * 100).rounded()))% 줄어듦"
        }
    }

    /// 진열대 칸에 들어가는 짧은 설명.
    @MainActor
    var shortText: String {
        switch self {
        case .characters(let r): "집필 속도 \(Int((r * 100).rounded()))% 증가"
        case .itemTokens(let m): "아이템 토큰 \(Int(((1 - m) * 100).rounded()))% 절감"
        case .eventChance(let m): "돌발 상황 \(Int(((1 - m) * 100).rounded()))% 감소"
        case .eventDuration(let m): "상황 시간 \(Int(((1 - m) * 100).rounded()))% 단축"
        case .authorEventDuration(let author, let m):
            "\(Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author) 상황 \(Int(((1 - m) * 100).rounded()))% 단축"
        case .refusal(let d): "거절 확률 \(Int((d * 100).rounded()))%p 감소"
        case .refusalWait(let m): "거절 대기 \(Int(((1 - m) * 100).rounded()))% 단축"
        case .disasterLoss(let m): "재해 손실 \(Int(((1 - m) * 100).rounded()))% 감소"
        }
    }
}

/// 받은 금 뱃지의 기본 효과와 훈장 진열대(최대 3칸)에 장식한 뱃지의 진열 효과를 모두 합친 것. `WritingStore` 가 계산할 때 쓴다.
struct Perks: Sendable, Equatable {
    static let maxEquipped = 3

    var characterBonus = 0.0
    var itemTokens = 1.0
    var eventChance = 1.0
    var eventDuration = 1.0
    var authorEventDuration: [String: Double] = [:]
    var refusalDelta = 0.0
    var refusalWait = 1.0
    var disasterLoss = 1.0

    init() {}

    /// 매일 초기화되는 성과의 효과는 그날 이룬 것만 센다. 진열대에 꽂은 뱃지(최대 3개)는 `slotPerk` 가 추가로 더해진다.
    @MainActor
    init(badges: [String: BadgeRecord], equipped: [String] = [], now: Date = Date()) {
        for (id, record) in badges {
            guard let achievement = Achievements.byID(id), let perk = achievement.perk else { continue }
            if achievement.daily, !Calendar.current.isDate(record.date, inSameDayAs: now) { continue }
            apply(perk)
        }
        var seen: Set<String> = []
        for id in equipped.prefix(Self.maxEquipped) where seen.insert(id).inserted {
            guard let record = badges[id], let achievement = Achievements.byID(id) else { continue }
            if achievement.daily, !Calendar.current.isDate(record.date, inSameDayAs: now) { continue }
            apply(achievement.slotPerk)
        }
    }

    private mutating func apply(_ perk: Perk) {
        switch perk {
        case .characters(let r): characterBonus += r
        case .itemTokens(let m): itemTokens *= m
        case .eventChance(let m): eventChance *= m
        case .eventDuration(let m): eventDuration *= m
        case .authorEventDuration(let author, let m): authorEventDuration[author, default: 1] *= m
        case .refusal(let d): refusalDelta += d
        case .refusalWait(let m): refusalWait *= m
        case .disasterLoss(let m): disasterLoss *= m
        }
    }

    /// 이 작가의 작품을 쓸 때 돌발 상황 지속 배수.
    func eventDuration(author: String?) -> Double {
        eventDuration * (author.flatMap { authorEventDuration[$0] } ?? 1)
    }
}

struct Achievement: Identifiable, Sendable {
    let id: String
    let title: String
    /// 달성 조건.
    let detail: String
    let tier: BadgeTier
    let category: BadgeCategory
    let icon: [String]
    /// (지금 값, 목표). 지금 값이 목표에 닿으면 달성.
    let measure: @Sendable (AchievementFacts) -> (Double, Double)
    /// 진행 막대에 숫자를 쓸지(참/거짓 조건은 쓰지 않는다).
    var countable = true
    /// 같은 단계 묶음. 못 받은 것은 묶음마다 다음 단계 하나만 보여 준다.
    var chain: String?
    /// 메달에 아이콘 대신 그릴 작가 초상화.
    var portrait: String?
    /// 금·은 뱃지가 달성 즉시 상시로 주는 기본 효과.
    var perk: Perk?
    /// 매일 초기화된다. 날마다 다시 이룰 수 있고, 보상은 그때마다 1개, 효과는 그날만이다.
    var daily = false
    /// 달성하면 해금되는 후원자 칭호(사용자에게 부여되는 호칭).
    var patronTitle: String? = nil

    var isSecret: Bool { category == .secret }
    /// 이루면 받는 아이템 수. 동 1, 은 2, 금 3. 매일 성과는 늘 1.
    var rewardCount: Int { daily ? 1 : tier.rawValue + 1 }

    /// 훈장 진열대(3칸)에 장식했을 때 발휘되는 진열 효과. 모든 등급(동·은·금)의 뱃지가 분야별 효과를 가진다.
    var slotPerk: Perk {
        if let author = portrait {
            return .authorEventDuration(author, 0.90)
        }
        switch (category, tier) {
        case (.writing, .bronze): return .characters(0.02)
        case (.writing, .silver): return .characters(0.03)
        case (.writing, .gold): return .characters(0.05)
        case (.books, .bronze): return .refusal(0.02)
        case (.books, .silver): return .refusal(0.03)
        case (.books, .gold): return .refusal(0.05)
        case (.sales, .bronze), (.tokens, .bronze): return .itemTokens(0.97)
        case (.sales, .silver), (.tokens, .silver): return .itemTokens(0.95)
        case (.sales, .gold), (.tokens, .gold): return .itemTokens(0.93)
        case (.bookstore, .bronze): return .refusalWait(0.92)
        case (.bookstore, .silver): return .refusalWait(0.88)
        case (.bookstore, .gold): return .refusalWait(0.82)
        case (.events, .bronze): return .eventDuration(0.95)
        case (.events, .silver): return .eventDuration(0.92)
        case (.events, .gold): return .eventDuration(0.88)
        case (.disasters, .bronze): return .disasterLoss(0.85)
        case (.disasters, .silver): return .disasterLoss(0.75)
        case (.disasters, .gold): return .disasterLoss(0.65)
        case (.secret, .bronze): return .eventChance(0.96)
        case (.secret, .silver): return .eventChance(0.93)
        case (.secret, .gold): return .eventChance(0.90)
        }
    }

    func progress(_ facts: AchievementFacts) -> (current: Double, target: Double) { measure(facts) }
    func isMet(_ facts: AchievementFacts) -> Bool { let p = measure(facts); return p.0 >= p.1 }
}

enum Achievements {
    private static func flag(_ value: Bool) -> (Double, Double) { (value ? 1 : 0, 1) }

    private static let base: [Achievement] = [
        // 집필
        Achievement(id: "first_line", title: "첫 문장", detail: "첫 글자를 쓰세요", tier: .bronze, category: .writing,
                    icon: PixelIcon.quill, measure: { (min($0.totalCharacters, 1), 1) }, countable: false,
                    patronTitle: "첫 원고의 마중물"),
        Achievement(id: "chars_10k", title: "원고 1만 자", detail: "모두 1만 자를 쓰세요", tier: .bronze, category: .writing,
                    icon: PixelIcon.page, measure: { ($0.totalCharacters, 10_000) }, chain: "chars",
                    patronTitle: "성실한 지필묵 후원자"),
        Achievement(id: "chars_100k", title: "원고 10만 자", detail: "모두 10만 자를 쓰세요", tier: .silver, category: .writing,
                    icon: PixelIcon.page, measure: { ($0.totalCharacters, 100_000) }, chain: "chars",
                    patronTitle: "꺼지지 않는 서재의 등불"),
        Achievement(id: "chars_1m", title: "원고 100만 자", detail: "모두 100만 자를 쓰세요", tier: .gold, category: .writing,
                    icon: PixelIcon.page, measure: { ($0.totalCharacters, 1_000_000) }, chain: "chars", perk: .characters(0.05),
                    patronTitle: "대문호들의 든든한 메세나"),
        Achievement(id: "chars_5m", title: "원고 500만 자", detail: "모두 500만 자를 쓰세요", tier: .gold, category: .writing,
                    icon: PixelIcon.page, measure: { ($0.totalCharacters, 5_000_000) }, chain: "chars", perk: .characters(0.10),
                    patronTitle: "불멸의 문학사 후원자"),
        Achievement(id: "day_10k", title: "부지런한 하루", detail: "오늘 1만 자를 쓰세요", tier: .bronze, category: .writing,
                    icon: PixelIcon.bolt, measure: { ($0.todayCharacters, 10_000) }, chain: "day", daily: true),
        Achievement(id: "day_100k", title: "폭풍 집필", detail: "오늘 10만 자를 쓰세요", tier: .gold, category: .writing,
                    icon: PixelIcon.bolt, measure: { ($0.todayCharacters, 100_000) }, chain: "day", perk: .itemTokens(0.9), daily: true),
        Achievement(id: "streak_7", title: "일주일 개근", detail: "7일 내리 하루도 빠짐없이 쓰세요", tier: .silver, category: .writing,
                    icon: PixelIcon.calendar, measure: { (Double($0.longestStreak), 7) }, chain: "streak",
                    patronTitle: "매일 찾아오는 후원인"),
        Achievement(id: "streak_30", title: "한 달 개근", detail: "30일 내리 하루도 빠짐없이 쓰세요", tier: .gold, category: .writing,
                    icon: PixelIcon.calendar, measure: { (Double($0.longestStreak), 30) }, chain: "streak", perk: .eventChance(0.8),
                    patronTitle: "한결같은 문학의 벗"),
        Achievement(id: "night_10k", title: "밤의 작가", detail: "밤 10시부터 새벽 5시 사이에 모두 1만 자를 쓰세요", tier: .silver,
                    category: .writing, icon: PixelIcon.candle, measure: { (Double($0.nightCharacters), 10_000) },
                    patronTitle: "심야 집필실의 등불지기"),
        Achievement(id: "weekend_10k", title: "주말 작가", detail: "주말에 모두 1만 자를 쓰세요", tier: .bronze, category: .writing,
                    icon: PixelIcon.calendar, measure: { ($0.weekendCharacters, 10_000) },
                    patronTitle: "휴일 서재의 산책 동무"),
        Achievement(id: "streak_100", title: "백일", detail: "100일 내리 하루도 빠짐없이 쓰세요", tier: .gold, category: .writing,
                    icon: PixelIcon.calendar, measure: { (Double($0.longestStreak), 100) }, chain: "streak", perk: .eventDuration(0.75),
                    patronTitle: "백일의 서약을 지킨 후견인"),
        // 탈고
        Achievement(id: "first_book", title: "첫 탈고", detail: "작품 하나를 끝까지 쓰세요", tier: .silver, category: .books,
                    icon: PixelIcon.book, measure: { (Double($0.finishedBooks), 1) }, countable: false, chain: "books",
                    patronTitle: "초판본의 첫 후원자"),
        Achievement(id: "books_5", title: "다섯 권", detail: "작품 다섯 편을 탈고하세요", tier: .silver, category: .books,
                    icon: PixelIcon.book, measure: { (Double($0.finishedBooks), 5) }, chain: "books",
                    patronTitle: "작은 문고의 설립자"),
        Achievement(id: "books_10", title: "열 권", detail: "작품 열 편을 탈고하세요", tier: .gold, category: .books,
                    icon: PixelIcon.book, measure: { (Double($0.finishedBooks), 10) }, chain: "books", perk: .refusal(0.05),
                    patronTitle: "황금 서재의 관장"),
        Achievement(id: "books_25", title: "스물다섯 권", detail: "작품 스물다섯 편을 탈고하세요", tier: .gold, category: .books,
                    icon: PixelIcon.book, measure: { (Double($0.finishedBooks), 25) }, chain: "books", perk: .refusal(0.05),
                    patronTitle: "왕립 문학 총서의 편찬자"),
        Achievement(id: "round_1", title: "서재 완주", detail: "서재의 모든 작품을 한 바퀴 다 쓰세요", tier: .gold, category: .books,
                    icon: PixelIcon.trophy, measure: { (Double($0.completedRounds), 1) }, countable: false, chain: "rounds", perk: .itemTokens(0.9),
                    patronTitle: "전집 시대를 연 대후원자"),
        Achievement(id: "round_2", title: "두 바퀴", detail: "서재를 두 바퀴 다 쓰세요", tier: .gold, category: .books,
                    icon: PixelIcon.trophy, measure: { (Double($0.completedRounds), 2) }, countable: false, chain: "rounds", perk: .characters(0.05),
                    patronTitle: "시대를 초월한 문학의 수호자"),
        Achievement(id: "all_authors", title: "팔방미인", detail: "작가 8명의 작품을 한 편씩은 탈고하세요", tier: .gold, category: .books,
                    icon: PixelIcon.star, measure: { (Double($0.authorsFinished.count), 8) }, perk: .eventDuration(0.9),
                    patronTitle: "여덟 문호의 살롱 주인장"),
        // 판매
        Achievement(id: "sales_1k", title: "첫 천 부", detail: "책 한 권이 1,000부 팔리게 하세요", tier: .bronze, category: .sales,
                    icon: PixelIcon.coin, measure: { (Double($0.bestBookSales), 1_000) }, chain: "sales",
                    patronTitle: "동네 서점의 첫 투자자"),
        Achievement(id: "sales_10k", title: "재판", detail: "책 한 권이 1만 부 팔리게 하세요", tier: .silver, category: .sales,
                    icon: PixelIcon.coin, measure: { (Double($0.bestBookSales), 10_000) }, chain: "sales",
                    patronTitle: "인쇄기를 돌리는 후원자"),
        Achievement(id: "sales_100k", title: "베스트셀러", detail: "책 한 권이 10만 부 팔리게 하세요", tier: .gold, category: .sales,
                    icon: PixelIcon.coin, measure: { (Double($0.bestBookSales), 100_000) }, chain: "sales", perk: .itemTokens(0.95),
                    patronTitle: "런던 출판가의 큰손"),
        Achievement(id: "sales_1m", title: "밀리언셀러", detail: "책 한 권이 100만 부 팔리게 하세요", tier: .gold, category: .sales,
                    icon: PixelIcon.trophy, measure: { (Double($0.bestBookSales), 1_000_000) }, chain: "sales", perk: .characters(0.05),
                    patronTitle: "세기를 뒤흔든 출판 메세나"),
        Achievement(id: "readers_100k", title: "십만 독자", detail: "모든 책을 합쳐 10만 부 팔리게 하세요", tier: .silver, category: .sales,
                    icon: PixelIcon.pages, measure: { (Double($0.totalSales), 100_000) }, chain: "readers",
                    patronTitle: "십만 독자를 잇는 가교"),
        Achievement(id: "readers_1m", title: "백만 독자", detail: "모든 책을 합쳐 100만 부 팔리게 하세요", tier: .gold, category: .sales,
                    icon: PixelIcon.pages, measure: { (Double($0.totalSales), 1_000_000) }, chain: "readers", perk: .eventChance(0.9),
                    patronTitle: "백만 독자를 이끈 대후원자"),
        Achievement(id: "author_sales_100k", title: "인기 작가", detail: "한 작가의 책이 모두 10만 부 팔리게 하세요", tier: .silver, category: .sales,
                    icon: PixelIcon.star, measure: { (Double($0.bestAuthorSales), 100_000) },
                    patronTitle: "스타 작가를 키워 낸 후원자"),
        Achievement(id: "all_reprint", title: "전작 재판", detail: "탈고한 책이 모두 재판(1만 부)을 찍게 하세요", tier: .silver, category: .sales,
                    icon: PixelIcon.book, measure: { flag($0.allReprinted) }, countable: false,
                    patronTitle: "전작 재판을 이끈 후원인"),
        Achievement(id: "ignite_3", title: "불씨", detail: "영감 게이지를 채워 영감의 날을 세 번 켜세요", tier: .silver, category: .writing,
                    icon: PixelIcon.star, measure: { (Double($0.ignitions), 3) },
                    patronTitle: "영감에 불을 지피는 후원자"),
        Achievement(id: "deadline_1", title: "마감 사수", detail: "출판사 마감을 지키세요", tier: .bronze, category: .writing,
                    icon: PixelIcon.letter, measure: { (Double($0.deadlinesMet), 1) }, countable: false, chain: "deadline",
                    patronTitle: "마감 시계를 챙기는 후견인"),
        Achievement(id: "deadline_5", title: "믿을 만한 작가", detail: "출판사 마감을 다섯 번 지키세요", tier: .silver, category: .writing,
                    icon: PixelIcon.letter, measure: { (Double($0.deadlinesMet), 5) }, chain: "deadline", perk: .refusal(0.03),
                    patronTitle: "출판계가 신뢰하는 후견인"),
        Achievement(id: "five_stars", title: "별 다섯", detail: "비평에서 별 5개를 받으세요", tier: .silver, category: .bookstore,
                    icon: PixelIcon.star, measure: { (Double($0.fiveStars), 1) }, countable: false,
                    patronTitle: "평단이 경외하는 안목의 후원자"),
        Achievement(id: "reviews_10", title: "스크랩북", detail: "비평 열 편을 모으세요", tier: .bronze, category: .bookstore,
                    icon: PixelIcon.page, measure: { (Double($0.reviews), 10) },
                    patronTitle: "문예지 스크랩북의 수집가"),
        Achievement(id: "housewarming", title: "집들이", detail: "작업실 가구를 하나 들이세요", tier: .bronze, category: .events,
                    icon: PixelIcon.lamp, measure: { (Double($0.furniture), 1) }, countable: false, chain: "studio",
                    patronTitle: "따뜻한 집필실의 마련자"),
        Achievement(id: "studio_full", title: "안락한 작업실", detail: "작업실 가구 여섯을 모두 들이세요", tier: .silver, category: .events,
                    icon: PixelIcon.lamp, measure: { (Double($0.furniture), 6) }, chain: "studio", perk: .itemTokens(0.95),
                    patronTitle: "완벽한 서재의 건축가"),
        Achievement(id: "order_1", title: "독자의 부탁", detail: "독자가 주문한 책을 기한 안에 쓰기 시작하세요", tier: .bronze, category: .sales,
                    icon: PixelIcon.letter, measure: { (Double($0.ordersFilled), 1) }, countable: false,
                    patronTitle: "독자의 편지를 전하는 후원자"),
        Achievement(id: "shop_20", title: "단골 서점", detail: "서점에서 일어난 일을 스무 번 겪으세요", tier: .silver, category: .sales,
                    icon: PixelIcon.bag, measure: { (Double($0.shopEvents), 20) },
                    patronTitle: "거리 서점의 든든한 뒷배"),
        Achievement(id: "ads_3", title: "광고주", detail: "서점에 광고를 세 번 거세요", tier: .bronze, category: .sales,
                    icon: PixelIcon.horn, measure: { (Double($0.ads), 3) },
                    patronTitle: "소문난 문학 선전가"),
        Achievement(id: "publishers_3", title: "출판사 세 곳", detail: "대형·문예·독립 출판사에 한 번씩 원고를 보내세요", tier: .bronze, category: .sales,
                    icon: PixelIcon.letter, measure: { (Double($0.publishersUsed), 3) },
                    patronTitle: "출판계의 발 넓은 중개자"),
        Achievement(id: "decided", title: "결단", detail: "선택지가 있는 사건에 답하세요", tier: .bronze, category: .bookstore,
                    icon: PixelIcon.letter, measure: { (Double($0.decisions), 1) }, countable: false, chain: "decided",
                    patronTitle: "고민을 함께 나누는 조언자"),
        Achievement(id: "decided_10", title: "편집장", detail: "선택지가 있는 사건에 열 번 답하세요", tier: .silver, category: .bookstore,
                    icon: PixelIcon.letter, measure: { (Double($0.decisions), 10) }, chain: "decided", perk: .refusal(0.03),
                    patronTitle: "원고의 길을 밝히는 편집 고문"),
        Achievement(id: "reader", title: "독자", detail: "원고 읽기 창에서 지금까지 쓴 원고를 읽으세요", tier: .bronze, category: .books,
                    icon: PixelIcon.pages, measure: { (Double($0.reads), 1) }, countable: false,
                    patronTitle: "행간을 아끼는 첫 독자"),
        Achievement(id: "focus", title: "편애", detail: "서재에서 한 작가의 작품을 몰아 쓰게 하세요", tier: .bronze, category: .books,
                    icon: PixelIcon.book, measure: { (Double($0.focuses), 1) }, countable: false,
                    patronTitle: "열렬한 전담 후원자"),
        // 돌발 상황
        Achievement(id: "first_event", title: "뜻밖의 손님", detail: "돌발 상황을 처음 겪으세요", tier: .bronze, category: .events,
                    icon: PixelIcon.door, measure: { (Double($0.eventsSeen), 1) }, countable: false,
                    patronTitle: "작가의 투정을 받아 주는 이"),
        Achievement(id: "item_used", title: "임기응변", detail: "아이템으로 돌발 상황을 끝내세요", tier: .bronze, category: .events,
                    icon: PixelIcon.bell, measure: { (Double($0.itemsUsed), 1) }, countable: false,
                    patronTitle: "적재적소의 보급관"),
        Achievement(id: "coffee_10", title: "커피 열 잔", detail: "커피나 홍차로 졸음을 열 번 쫓으세요", tier: .silver, category: .events,
                    icon: PixelIcon.cup, measure: { (Double($0.coffeeUsed), 10) },
                    patronTitle: "다정한 다과 보급관"),
        Achievement(id: "patience_5", title: "기다림", detail: "아이템 없이 돌발 상황 다섯 번을 끝까지 기다리세요", tier: .silver,
                    category: .events, icon: PixelIcon.hourglass, measure: { (Double($0.waitedOut), 5) },
                    patronTitle: "과묵하고 너그러운 후원자"),
        Achievement(id: "collector", title: "수집가", detail: "여섯 가지 역할의 아이템을 한꺼번에 가지세요", tier: .silver, category: .events,
                    icon: PixelIcon.candle, measure: { flag($0.holdsEveryItem) }, countable: false,
                    patronTitle: "만물상 창고지기 후원자"),
        Achievement(id: "exchange_5", title: "교환상", detail: "아이템을 다섯 번 바꾸세요", tier: .bronze, category: .events,
                    icon: PixelIcon.horn, measure: { (Double($0.exchanges), 5) },
                    patronTitle: "알뜰한 보급품 조달자"),
        Achievement(id: "persistence_3", title: "끈기", detail: "거절당한 뒤 다시 권해 세 번 통하세요", tier: .silver, category: .events,
                    icon: PixelIcon.hourglass, measure: { (Double($0.persistence), 3) },
                    patronTitle: "작가의 고집을 꺾는 설득가"),
        Achievement(id: "guests_3", title: "손님 많은 집", detail: "손님 작가를 세 번 맞으세요", tier: .silver, category: .events,
                    icon: PixelIcon.door, measure: { (Double($0.guests), 3) },
                    patronTitle: "문인들의 사랑방 주인"),
        Achievement(id: "advance_3", title: "선금의 맛", detail: "출판사 선금을 세 번 받으세요", tier: .bronze, category: .events,
                    icon: PixelIcon.coin, measure: { (Double($0.advances), 3) },
                    patronTitle: "통 큰 선금 집행자"),
        // 자연재해
        Achievement(id: "survivor", title: "재해 생존", detail: "자연재해를 겪고도 계속 쓰세요", tier: .bronze, category: .disasters,
                    icon: PixelIcon.flame, measure: { (Double($0.disasters), 1) }, countable: false, chain: "disasters",
                    patronTitle: "원고 뭉치를 건져 낸 은인"),
        Achievement(id: "disasters_5", title: "불굴", detail: "자연재해를 다섯 번 겪으세요", tier: .gold, category: .disasters,
                    icon: PixelIcon.flame, measure: { (Double($0.disasters), 5) }, chain: "disasters", perk: .disasterLoss(0.5),
                    patronTitle: "폭풍우를 막아 서는 방패"),
        Achievement(id: "lost_10k", title: "잿더미에서", detail: "자연재해로 모두 1만 자를 잃고도 쓰세요", tier: .silver, category: .disasters,
                    icon: PixelIcon.wind, measure: { (Double($0.lostCharacters), 10_000) },
                    patronTitle: "잿더미 속 원고의 복원자"),
        Achievement(id: "shield_1", title: "대비", detail: "금고나 사본으로 자연재해를 한 번 막으세요", tier: .silver, category: .disasters,
                    icon: PixelIcon.safe, measure: { (Double($0.shieldBlocks), 1) }, countable: false,
                    patronTitle: "철통같은 원고 금고지기"),
        // 토큰
        Achievement(id: "tokens_100m", title: "1억 토큰의 날", detail: "오늘 토큰 1억 개를 쓰세요", tier: .silver, category: .tokens,
                    icon: PixelIcon.bolt, measure: { (Double($0.todayTokens), 100_000_000) }, chain: "tokens", daily: true),
        Achievement(id: "tokens_500m", title: "5억 토큰의 날", detail: "오늘 토큰 5억 개를 쓰세요", tier: .gold, category: .tokens,
                    icon: PixelIcon.bolt, measure: { (Double($0.todayTokens), 500_000_000) }, chain: "tokens", perk: .refusalWait(0.5), daily: true),
        Achievement(id: "tokens_1b", title: "10억 토큰의 날", detail: "오늘 토큰 10억 개를 쓰세요", tier: .gold, category: .tokens,
                    icon: PixelIcon.bolt, measure: { (Double($0.todayTokens), 1_000_000_000) }, chain: "tokens", perk: .itemTokens(0.9), daily: true),
        // 비밀. 이루기 전에는 가린다.
        Achievement(id: "owl", title: "올빼미", detail: "새벽 0~4시에 돌발 상황을 겪으세요", tier: .silver, category: .secret,
                    icon: PixelIcon.candle, measure: { (Double($0.nightEvents), 1) }, countable: false,
                    patronTitle: "새벽녘 촛불을 켜 두는 이"),
        Achievement(id: "busy_day", title: "다사다난", detail: "하루에 돌발 상황을 세 번 겪으세요", tier: .silver, category: .secret,
                    icon: PixelIcon.bell, measure: { (Double($0.mostEventsInDay), 3) }, countable: false,
                    patronTitle: "소란스러운 작업실의 중재자"),
        Achievement(id: "hoard", title: "비축", detail: "커피와 홍차를 다섯 잔 쌓아 두세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.cup, measure: { (Double($0.coffeeHeld), 5) }, countable: false,
                    patronTitle: "찻잎과 원두의 비축가"),
        Achievement(id: "lucky", title: "행운아", detail: "행운을 다섯 번 겪으세요", tier: .silver, category: .secret,
                    icon: PixelIcon.coin, measure: { (Double($0.lucks), 5) }, countable: false,
                    patronTitle: "행운을 불러오는 복덩이 후원자"),
        Achievement(id: "caught", title: "들켰다", detail: "농땡이 부리는 작가를 열 번 들키게 하세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.door, measure: { (Double($0.caught), 10) }, countable: false,
                    patronTitle: "발소리 없이 다가오는 감독관"),
        Achievement(id: "veteran", title: "산전수전", detail: "돌발 상황을 스무 번 겪으세요", tier: .gold, category: .secret,
                    icon: PixelIcon.door, measure: { (Double($0.eventsSeen), 20) }, countable: false, perk: .eventChance(0.9),
                    patronTitle: "괴짜 문호들의 노련한 후견인"),
        Achievement(id: "missed_3", title: "펑크", detail: "출판사 마감을 세 번 어기세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.letter, measure: { (Double($0.deadlinesMissed), 3) }, countable: false,
                    patronTitle: "마감 독촉장을 대신 받는 이"),
        Achievement(id: "caffeine", title: "카페인", detail: "하루에 커피·홍차를 일곱 잔 권하세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.cup, measure: { (Double($0.mostCupsInDay), 7) }, countable: false,
                    patronTitle: "잠 못 드는 밤의 카페인 공급자"),
        Achievement(id: "gambler", title: "도박사", detail: "손님 작가와의 내기에서 세 번 이기세요", tier: .silver, category: .secret,
                    icon: PixelIcon.coin, measure: { (Double($0.betsWon), 3) }, countable: false,
                    patronTitle: "승부사 기질의 후원자"),
        Achievement(id: "busted", title: "쪽박", detail: "손님 작가와의 내기에서 세 번 지세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.coin, measure: { (Double($0.betsLost), 3) }, countable: false,
                    patronTitle: "수업료를 아끼지 않는 후원자"),
        Achievement(id: "panned", title: "혹평", detail: "쓰는 중인 작가가 별 2개 이하 비평을 받게 하세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.page, measure: { (Double($0.panned), 1) }, countable: false,
                    patronTitle: "혹평에도 흔들리지 않는 버팀목"),
        Achievement(id: "quarrels_5", title: "앙숙", detail: "손님 작가와 다섯 번 말다툼하게 하세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.horn, measure: { (Double($0.quarrels), 5) }, countable: false,
                    patronTitle: "문호들의 말다툼 구경꾼"),
        Achievement(id: "poked", title: "참견", detail: "상시 창의 초상화를 서른 번 누르세요", tier: .bronze, category: .secret,
                    icon: PixelIcon.bell, measure: { (Double($0.taps), 30) }, countable: false,
                    patronTitle: "작가의 어깨를 두드리는 후원자"),
    ]

    private static let authorPatronTitles: [String: String] = [
        "Shakespeare": "스트랫퍼드 극단의 후원 귀족",
        "Dickens": "런던 연재소설의 큰손",
        "Poe": "볼티모어 심야 서재의 후견인",
        "Carroll": "옥스퍼드 정원의 다과 후원자",
        "Doyle": "베이커가 221B의 단골 의뢰인",
        "Stevenson": "보물섬 항해의 투자자",
        "Austen": "햄프셔 응접실의 후견인",
        "Goethe": "바이마르 궁정의 문학 벗",
        "Wilde": "런던 사교계의 탐미 후원자",
    ]

    /// 작가마다 전집 하나. 메달에는 그 작가의 초상화가 들어간다.
    @MainActor
    private static func authorBadges() -> [Achievement] {
        Library.authors.map { author in
            let name = Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author
            return Achievement(id: "author_\(author)", title: "\(name) 전집", detail: "\(name)의 작품을 한 회차 안에 모두 탈고하세요",
                               tier: .gold, category: .books, icon: PixelIcon.star,
                               measure: { flag($0.completedAuthors.contains(author)) }, countable: false, portrait: author,
                               perk: .authorEventDuration(author, 0.85),
                               patronTitle: authorPatronTitles[author] ?? "\(name) 전집의 후견인")
        }
    }

    @MainActor
    static let all: [Achievement] = {
        var list = base
        let insertAt = list.firstIndex { $0.id == "round_1" }.map { $0 + 1 } ?? list.count
        list.insert(contentsOf: authorBadges(), at: insertAt)
        return list
    }()

    @MainActor
    static func byID(_ id: String) -> Achievement? { all.first { $0.id == id } }

    /// 매일 초기화되는 성과.
    @MainActor
    static var dailies: [Achievement] { all.filter(\.daily) }

    /// 해금된 후원자 칭호가 담긴 성과 목록(높은 등급 우선).
    @MainActor
    static func unlockedPatronAchievements(earned: (Achievement) -> Bool) -> [Achievement] {
        all.filter { !$0.daily && $0.patronTitle != nil && earned($0) }
            .sorted { a, b in
                if a.tier.rawValue != b.tier.rawValue { return a.tier.rawValue > b.tier.rawValue }
                return false
            }
    }

    /// 아직 못 받은 것 가운데 보여 줄 것(매일 성과는 뺀다). 단계 묶음은 다음 단계 하나만.
    @MainActor
    static func nextGoals(earned: (Achievement) -> Bool) -> [Achievement] {
        var seenChains: Set<String> = []
        return all.filter { a in
            guard !a.daily, !earned(a) else { return false }
            guard let chain = a.chain else { return true }
            return seenChains.insert(chain).inserted
        }
    }
}

/// 달성한 성과 하나.
struct BadgeRecord: Codable, Sendable, Equatable {
    let date: Date
    var notified: Bool
    /// 보상으로 받은 아이템(`ItemKind.rawValue`). 처음 조용히 채운 것은 없다.
    var reward: [String]?
    /// 매일 성과: 지금까지 이룬 날수와 연속 일수.
    var count: Int?
    var streak: Int?
}

extension PixelIcon {
    static let book = [
        ".#######.",
        "##.....##",
        "##.###.##",
        "##.....##",
        "##.###.##",
        "##.....##",
        "##.....##",
        ".#######.",
        "..#...#..",
    ]
    static let star = [
        "....#....",
        "....#....",
        "...###...",
        "#########",
        ".#######.",
        "..#####..",
        "..##.##..",
        ".##...##.",
        ".#.....#.",
    ]
    static let trophy = [
        "#########",
        "##.###.##",
        "##.###.##",
        ".#######.",
        "..#####..",
        "...###...",
        "....#....",
        "...###...",
        "..#####..",
    ]
    static let calendar = [
        ".#.....#.",
        "#########",
        "#########",
        "#.......#",
        "#.#.#.#.#",
        "#.......#",
        "#.#.#.#.#",
        "#.......#",
        "#########",
    ]
    static let hourglass = [
        "#########",
        ".#.....#.",
        "..#...#..",
        "...###...",
        "....#....",
        "...#.#...",
        "..#.#.#..",
        ".#.###.#.",
        "#########",
    ]
    static let bolt = [
        ".....##..",
        "....##...",
        "...##....",
        "..######.",
        ".....##..",
        "....##...",
        "...##....",
        "..##.....",
        ".##......",
    ]
    static let question = [
        "..#####..",
        ".##...##.",
        ".##...##.",
        "......##.",
        ".....##..",
        "....##...",
        "....##...",
        ".........",
        "....##...",
    ]
}

// MARK: - 화면

/// 메달 모양. 묶음마다 다르다. 집필은 원, 탈고는 방패, 판매는 동전(겹테), 돌발 상황은 육각, 자연재해는 둥근 네모, 토큰은 마름모, 비밀은 원.
struct MedalShape: Shape {
    let category: BadgeCategory

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: 0.5, dy: 0.5)
        switch category {
        case .books:
            var p = Path()
            p.move(to: CGPoint(x: r.minX + r.width * 0.5, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.22), control: CGPoint(x: r.maxX - r.width * 0.1, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.55))
            p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.1))
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.55), control: CGPoint(x: r.minX, y: r.maxY - r.height * 0.1))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.22))
            p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: CGPoint(x: r.minX + r.width * 0.1, y: r.minY))
            p.closeSubpath()
            return p
        case .events:
            var p = Path()
            for i in 0..<6 {
                let a = CGFloat(i) * .pi / 3 - .pi / 6
                let pt = CGPoint(x: r.midX + cos(a) * r.width / 2, y: r.midY + sin(a) * r.height / 2)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.closeSubpath()
            return p
        case .disasters:
            return Path(roundedRect: r, cornerRadius: r.width * 0.26, style: .continuous)
        case .tokens:
            var p = Path()
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.midY))
            p.closeSubpath()
            return p
        default:
            return Path(ellipseIn: r)
        }
    }
}

/// 메달. 받았으면 등급 색 테두리에 아이콘(또는 작가 초상화), 아직이면 회색, 비밀이면 물음표. 모양은 묶음마다(`MedalShape`).
struct BadgeMedal: View {
    let achievement: Achievement
    let unlocked: Bool
    var size: CGFloat = 46

    var body: some View {
        let tier = achievement.tier
        let ring = max(2, size * 0.065)
        let shape = MedalShape(category: achievement.category)
        ZStack {
            shape.fill(unlocked ? tier.color.opacity(0.16) : Color.secondary.opacity(0.08))
            if unlocked {
                // 금속 느낌: 왼쪽 위가 밝다.
                shape.fill(RadialGradient(colors: [.white.opacity(0.28), .clear], center: UnitPoint(x: 0.3, y: 0.25), startRadius: 0, endRadius: size * 0.6))
                shape.stroke(
                    AngularGradient(colors: [tier.color, tier.highlight, tier.color, tier.highlight, tier.color],
                                    center: .center, angle: .degrees(-40)),
                    lineWidth: ring)
                if achievement.category == .sales {
                    // 동전: 안쪽 겹테
                    shape.stroke(tier.color.opacity(0.5), lineWidth: max(1, ring * 0.4)).padding(ring * 2.2)
                }
            } else {
                shape.stroke(Color.secondary.opacity(0.25), lineWidth: 1.5)
            }
            if !unlocked, achievement.isSecret {
                PixelIconView(rows: PixelIcon.question, color: .secondary.opacity(0.5), scale: size / 18)
            } else if let author = achievement.portrait {
                PortraitFrame(author: author, scale: size * 0.62 / 16)
                    .clipShape(Circle())
                    .saturation(unlocked ? 1 : 0)
                    .opacity(unlocked ? 1 : 0.45)
            } else {
                PixelIconView(rows: achievement.icon, color: unlocked ? tier.color : .secondary.opacity(0.45), scale: size / 18)
            }
        }
        .frame(width: size, height: size)
    }
}

/// 팝오버 옆에 여는 성과 화면.
struct BadgePanel: View {
    @Bindable var store: UsageStore
    var scrollable = true

    var body: some View {
        if let progress = store.writing {
            BadgeContent(progress: progress, scrollable: scrollable,
                         onToggleBadge: { store.toggleBadge($0) },
                         onSelectPatron: { store.selectPatronTitle($0) })
        } else {
            ProgressView()
        }
    }
}

struct BadgeContent: View {
    let progress: WritingProgress
    var scrollable = true
    var onToggleBadge: @MainActor (String) -> Void = { _ in }
    var onSelectPatron: @MainActor (String?) -> Void = { _ in }
    /// 목표 묶음 가운데 보여 주는 것. nil 이면 처음 묶음.
    @State private var category: BadgeCategory?
    /// 받은 뱃지를 다 펼쳤는지. 기본은 최근 10개.
    @State private var showsAllBadges = false
    /// 후원자 칭호 선택 서랍을 펼쳤는지.
    @State private var showsPatronPicker = false

    var body: some View {
        if scrollable { ScrollView { content } } else { content }
    }

    /// 기록을 읽기만 하는 실행(`--snapshot`)은 성과를 적지 않으니, 조건을 채운 것도 달성으로 보여 준다.
    /// 매일 성과는 오늘 이뤘는지 본다.
    private func earned(_ a: Achievement) -> Bool {
        if a.daily { return earnedToday(a) }
        return progress.badges[a.id] != nil || a.isMet(progress.facts)
    }
    private func earnedToday(_ a: Achievement) -> Bool {
        (progress.badges[a.id].map { Calendar.current.isDateInToday($0) } ?? false) || a.isMet(progress.facts)
    }
    private func date(_ a: Achievement) -> Date { progress.badges[a.id] ?? .now }

    private var content: some View {
        let unlocked = Achievements.all.filter { !$0.daily && earned($0) }.sorted { date($0) > date($1) }
        let goals = Achievements.nextGoals(earned: earned)
        let perks = Achievements.all.filter(earned).compactMap { a in a.perk.map { (a, $0) } }
        let secrets = goals.filter(\.isSecret)
        return VStack(alignment: .leading, spacing: 20) {
            header(unlocked)
            patronAndShowcaseCard(unlocked)
            if !perks.isEmpty {
                section("금·은 뱃지 상시 효과") {
                    FlowLayout(spacing: 6) {
                        ForEach(perks, id: \.0.id) { a, perk in
                            HStack(spacing: 5) {
                                BadgeMedal(achievement: a, unlocked: true, size: 16)
                                Text(perk.text).font(.caption2)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(BadgeTier.gold.color.opacity(0.1), in: Capsule())
                            .hint(a.title, [perk.text + (a.daily ? " (오늘만)" : " (계속)"), a.detail], symbol: "star")
                        }
                    }
                }
            }
            section("오늘") {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Achievements.dailies) { a in
                        dailyCell(a).frame(maxWidth: .infinity)
                    }
                }
            }
            if !unlocked.isEmpty {
                section("받은 뱃지 \(unlocked.count) · 눌러서 진열대에 장식") {
                    VStack(alignment: .leading, spacing: 0) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 12) {
                            ForEach(Array(unlocked.prefix(10))) { a in
                                badgeCell(a)
                            }
                        }
                        if unlocked.count > 10 {
                            Collapsible(progress: showsAllBadges ? 1 : 0, topSpacing: 12) {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 12) {
                                    ForEach(Array(unlocked.dropFirst(10))) { a in
                                        badgeCell(a)
                                    }
                                }
                            }
                            Button(showsAllBadges ? "최근 10개만" : "모두 보기 \(unlocked.count)개") { showsAllBadges.toggle() }
                                .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                    }
                }
            }
            // 다음 목표: 묶음을 골라 하나씩만 본다. 다 늘어놓으면 스크롤이 너무 길다.
            let categories = BadgeCategory.allCases.filter { c in c != .secret && goals.contains { $0.category == c } }
            if let current = category.flatMap({ categories.contains($0) ? $0 : nil }) ?? categories.first {
                section("다음 목표") {
                    FlowLayout(spacing: 6) {
                        Group {
                            ForEach(categories, id: \.self) { c in
                                let count = goals.filter { $0.category == c }.count
                                Button { category = c } label: {
                                    Text("\(c.title) \(count)")
                                        .font(.caption.weight(c == current ? .semibold : .regular))
                                        .padding(.horizontal, 9).padding(.vertical, 4)
                                        .foregroundStyle(c == current ? Color(nsColor: .windowBackgroundColor) : .primary)
                                        .background(c == current ? Color.primary.opacity(0.85) : Color.secondary.opacity(0.1), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    let items = goals.filter { $0.category == current }
                    VStack(spacing: 0) {
                        ForEach(items) { a in
                            goalRow(a)
                            if a.id != items.last?.id { Divider().opacity(0.4).padding(.leading, 40) }
                        }
                    }
                    .padding(.horizontal, 10)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            if !secrets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("비밀 성과 \(secrets.count)개").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    FlowLayout(spacing: 6) {
                        ForEach(secrets) { a in BadgeMedal(achievement: a, unlocked: false, size: 24) }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy(duration: 0.24, extraBounce: 0), value: showsAllBadges)
        .animation(.snappy(duration: 0.24, extraBounce: 0), value: showsPatronPicker)
        .animation(.snappy(duration: 0.22, extraBounce: 0), value: progress.equippedBadges)
        .animation(.easeOut(duration: 0.18), value: category)
    }

    /// 후원자 칭호와 3칸 훈장 진열대를 묶은 상단 카드.
    private func patronAndShowcaseCard(_ unlocked: [Achievement]) -> some View {
        let patronOptions = Achievements.unlockedPatronAchievements(earned: earned)
        let activePatron = progress.patronAchievement ?? patronOptions.first
        let equipped = progress.equippedBadges.compactMap { Achievements.byID($0) }
        return VStack(alignment: .leading, spacing: 12) {
            patronHeaderSection(activePatron: activePatron, patronOptions: patronOptions)
            Divider().opacity(0.45)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("훈장 진열대").font(.caption.weight(.semibold))
                    Text("\(equipped.count) / \(Perks.maxEquipped)칸")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(equipped.isEmpty ? "받은 뱃지를 눌러 최대 3개까지 장식하세요" : "진열한 뱃지는 분야별 효과를 발휘합니다")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    ForEach(0..<Perks.maxEquipped, id: \.self) { index in
                        if index < equipped.count {
                            showcaseSlot(equipped[index])
                        } else {
                            emptyShowcaseSlot
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(BadgeTier.gold.color.opacity(0.22), lineWidth: 1))
    }

    private func patronHeaderSection(activePatron: Achievement?, patronOptions: [Achievement]) -> some View {
        let hintLines: [String] = {
            if let active = activePatron {
                return [
                    "\"\(active.patronTitle ?? "")\" (\(active.title) 달성 보상)",
                    "집필 화면과 문학 살롱, 마을에서 작가와 주민들이 후원자님을 이 칭호로 기억합니다."
                ]
            }
            return ["성과를 달성하면 문호들을 후원하는 사용자 전용 칭호가 해금됩니다."]
        }()
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Symbol(name: "seal.fill", size: 13, color: activePatron?.tier.color ?? BadgeTier.gold.color)
                VStack(alignment: .leading, spacing: 1) {
                    Text("후원자 칭호").font(.caption2).foregroundStyle(.secondary)
                    Text(activePatron?.patronTitle ?? "첫 성과를 달성하면 칭호가 열립니다")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                if patronOptions.count > 1 {
                    Button { showsPatronPicker.toggle() } label: {
                        HStack(spacing: 4) {
                            Text(showsPatronPicker ? "접기" : "칭호 변경 \(patronOptions.count)")
                                .font(.caption2.weight(.medium))
                            Symbol(name: "chevron.down", size: 8)
                                .rotationEffect(.degrees(showsPatronPicker ? 180 : 0))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .hint("후원자 칭호", hintLines, symbol: "seal")
            if patronOptions.count > 1 {
                Collapsible(progress: showsPatronPicker ? 1 : 0, topSpacing: 10) {
                    FlowLayout(spacing: 6) {
                        ForEach(patronOptions) { a in
                            if let title = a.patronTitle {
                                patronOptionChip(a, title: title, isSelected: activePatron?.id == a.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private func patronOptionChip(_ a: Achievement, title: String, isSelected: Bool) -> some View {
        Button {
            onSelectPatron(a.id)
        } label: {
            HStack(spacing: 5) {
                Circle().fill(a.tier.color).frame(width: 6, height: 6)
                Text(title)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 9).padding(.vertical, 5)
            .foregroundStyle(isSelected ? .primary : .secondary)
            .background(isSelected ? a.tier.color.opacity(0.22) : Color.secondary.opacity(0.09), in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? a.tier.color.opacity(0.6) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .hint("\(title) · \(a.tier.name)", ["달성 성과: \(a.title) (\(a.detail))", "누르면 이 후원자 칭호를 패용합니다."], symbol: "seal")
    }

    private func showcaseSlot(_ a: Achievement) -> some View {
        Button { onToggleBadge(a.id) } label: {
            VStack(spacing: 5) {
                BadgeMedal(achievement: a, unlocked: true, size: 36)
                Text(a.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(a.slotPerk.shortText)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(a.tier.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8).padding(.horizontal, 6)
            .background(a.tier.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(a.tier.color.opacity(0.38), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .hint("\(a.title) · 진열 중", [a.detail, "진열 효과: \(a.slotPerk.text)", "누르면 진열대에서 내립니다."], symbol: "rosette")
    }

    private var emptyShowcaseSlot: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                Symbol(name: "rosette", size: 12, color: .secondary.opacity(0.3))
            }
            .frame(width: 36, height: 36)
            Text("빈 진열대")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.65))
            Text("뱃지 선택")
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8).padding(.horizontal, 6)
        .background(Color.secondary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(Color.secondary.opacity(0.18)))
    }

    private func badgeCell(_ a: Achievement) -> some View {
        let isEquipped = progress.equippedBadges.contains(a.id)
        let hintTitle = isEquipped ? "\(a.title) · \(a.tier.name) (진열 중)" : "\(a.title) · \(a.tier.name)"
        var hintLines: [String] = [
            a.detail,
            "\(date(a).formatted(.dateTime.year().month(.defaultDigits).day())) 달성",
            "진열 효과: \(a.slotPerk.text)"
        ]
        if let perk = a.perk {
            hintLines.append("상시 효과: \(perk.text)")
        }
        if let patron = a.patronTitle {
            hintLines.append("후원자 칭호: \"\(patron)\"")
        }
        if let reward = progress.badgeRewards[a.id] {
            hintLines.append("받음: \(reward)")
        }
        hintLines.append(isEquipped ? "누르면 훈장 진열대에서 내립니다." : "누르면 훈장 진열대에 장식합니다.")
        return Button { onToggleBadge(a.id) } label: {
            VStack(spacing: 4) {
                BadgeMedal(achievement: a, unlocked: true, size: 44)
                    .overlay(alignment: .topTrailing) {
                        if isEquipped {
                            equippedBadgeMark
                        }
                    }
                Text(a.title)
                    .font(.caption2.weight(isEquipped ? .semibold : .medium))
                    .foregroundStyle(isEquipped ? a.tier.color : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hint(hintTitle, hintLines, symbol: "rosette")
    }

    private var equippedBadgeMark: some View {
        Circle()
            .fill(BadgeTier.gold.color)
            .frame(width: 14, height: 14)
            .overlay(Symbol(name: "checkmark", size: 7, color: .white))
            .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
            .offset(x: 2, y: -2)
    }

    /// 제목, 받은 수, 등급별 수, 전체 진행 띠.
    private func header(_ unlocked: [Achievement]) -> some View {
        let total = Achievements.all.filter { !$0.daily }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("성과").font(.headline)
                Text("\(unlocked.count) / \(total)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 10) {
                    ForEach([BadgeTier.gold, .silver, .bronze], id: \.self) { tier in
                        HStack(spacing: 4) {
                            Circle().fill(tier.color).frame(width: 8, height: 8)
                            Text("\(unlocked.filter { $0.tier == tier }.count)")
                                .font(.caption.monospacedDigit().weight(.medium))
                        }
                    }
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.12))
                    Capsule().fill(BadgeTier.gold.color)
                        .frame(width: max(3, geo.size.width * CGFloat(unlocked.count) / CGFloat(max(1, total))))
                }
            }
            .frame(height: 4)
        }
    }

    private func section(_ title: String, @ViewBuilder body: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            body()
        }
    }

    /// 매일 성과 한 칸: 오늘 진행이 메달 둘레의 고리로, 아래에 이름과 연속 일수.
    private func dailyCell(_ a: Achievement) -> some View {
        let p = a.progress(progress.facts)
        let fraction = p.target > 0 ? min(1, p.current / p.target) : 0
        let today = earnedToday(a)
        let count = progress.dailyCounts[a.id]
        let subtitle = count.map { $0.streak > 1 ? "\($0.streak)일째" : "\($0.total)번" } ?? "\(Self.short(p.current))"
        var hintLines: [String] = [
            a.detail,
            "오늘 \(Self.short(p.current)) / \(Self.short(p.target))" + (count.map { " · 지금까지 \($0.total)번" } ?? "")
        ]
        if let perk = a.perk {
            hintLines.append("효과(그날만): \(perk.text)")
        }
        return VStack(spacing: 5) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.12), lineWidth: 3)
                Circle().trim(from: 0, to: CGFloat(fraction))
                    .stroke(a.tier.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                BadgeMedal(achievement: a, unlocked: today, size: 36)
            }
            .frame(width: 48, height: 48)
            Text(a.title).font(.caption2.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
        .hint(a.title, hintLines, symbol: "sun.max")
    }

    /// 다음 목표 한 줄: 메달, 등급 점, 이름, 조건, 오른쪽에 진행. 효과는 마우스를 올리면.
    private func goalRow(_ a: Achievement) -> some View {
        let p = a.progress(progress.facts)
        let fraction = p.target > 0 ? min(1, p.current / p.target) : 0
        var hintLines: [String] = [a.detail]
        if a.countable {
            hintLines.append("\(Self.short(p.current)) / \(Self.short(p.target))")
        }
        hintLines.append("진열 효과: \(a.slotPerk.text)")
        if let perk = a.perk {
            hintLines.append("상시 효과: \(perk.text)")
        }
        if let patron = a.patronTitle {
            hintLines.append("칭호 보상: \"\(patron)\"")
        }
        if a.chain != nil {
            hintLines.append("이루면 다음 단계가 나옵니다.")
        }
        return HStack(spacing: 10) {
            BadgeMedal(achievement: a, unlocked: false, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Circle().fill(a.tier.color).frame(width: 6, height: 6)
                    Text(a.title).font(.callout.weight(.medium))
                    if a.perk != nil {
                        Text("★").font(.caption2).foregroundStyle(BadgeTier.gold.color)
                    }
                }
                Text(a.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if a.countable {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(Self.short(p.current)) / \(Self.short(p.target))")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.12))
                        Capsule().fill(a.tier.color).frame(width: max(3, 64 * fraction))
                    }
                    .frame(width: 64, height: 3)
                }
            }
        }
        .padding(.vertical, 8)
        .hint("\(a.title) · \(a.tier.name)", hintLines, symbol: "flag")
    }

    private static func short(_ value: Double) -> String {
        value >= 1_000 ? Format.tokens(Int(value)) : Format.integer(Int(value))
    }
}

/// 줄 바꿈하는 가로 배치. 효과 칩에 쓴다.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 368
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
