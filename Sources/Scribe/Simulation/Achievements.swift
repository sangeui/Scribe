import SwiftUI

// 성과. 기록 파일에 있는 값만으로 셀 수 있는 것들이고, 한 번 달성하면 날짜와 함께 남는다.
// 처음 이 기능이 생겼을 때 이미 이룬 성과는 알림 없이 조용히 채운다.
// 같은 종류의 단계(원고 1만·10만·100만 자)는 `chain` 으로 묶어, 아직 못 받은 것은 다음 단계 하나만 보여 준다.
// 비밀 성과는 이루기 전에는 이름과 조건을 가린다.

enum BadgeTier: Int, Comparable, Sendable {
    case bronze, silver, gold

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    var name: String {
        L10n.tr({ switch self {
        case .bronze: "동"
        case .silver: "은"
        case .gold: "금"
        } }())
    }

    var color: Color {
        switch self {
        case .bronze: Color(red: 0.62, green: 0.43, blue: 0.29)
        case .silver: Color(red: 0.52, green: 0.55, blue: 0.60)
        case .gold: Color(red: 0.72, green: 0.57, blue: 0.26)
        }
    }

    /// 메달 테두리의 밝은 쪽. 금속 느낌을 조금 낸다.
    var highlight: Color {
        switch self {
        case .bronze: Color(red: 0.78, green: 0.59, blue: 0.43)
        case .silver: Color(red: 0.75, green: 0.78, blue: 0.82)
        case .gold: Color(red: 0.85, green: 0.73, blue: 0.44)
        }
    }
}

enum BadgeCategory: String, CaseIterable, Sendable {
    case writing, books, sales, bookstore, events, disasters, tokens, secret

    var title: String {
        L10n.tr({ switch self {
        case .writing: "집필"
        case .books: "탈고"
        case .sales: "판매"
        case .bookstore: "서점"
        case .events: "돌발 상황"
        case .disasters: "자연재해"
        case .tokens: "토큰"
        case .secret: "비밀"
        } }())
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
        L10n.tr({ switch self {
        case .characters(let r): "100만 토큰당 글자 \(Int((r * 100).rounded()))% 더"
        case .itemTokens(let m): "아이템에 드는 토큰 \(Int(((1 - m) * 100).rounded()))% 줄어듦"
        case .eventChance(let m): "돌발 상황 확률 \(Int(((1 - m) * 100).rounded()))% 줄어듦"
        case .eventDuration(let m): "돌발 상황 \(Int(((1 - m) * 100).rounded()))% 짧아짐"
        case .authorEventDuration(let author, let m):
            "\(Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author) 작품을 쓸 때 돌발 상황 \(Int(((1 - m) * 100).rounded()))% 짧아짐"
        case .refusal(let d): "아이템 거절 확률 \(Int((d * 100).rounded()))%p 줄어듦"
        case .refusalWait(let m): "거절당한 뒤 기다리는 시간 \(Int(((1 - m) * 100).rounded()))% 줄어듦"
        case .disasterLoss(let m): "자연재해로 잃는 원고 \(Int(((1 - m) * 100).rounded()))% 줄어듦"
        } }())
    }

    /// 진열대 칸에 들어가는 짧은 설명.
    @MainActor
    var shortText: String {
        L10n.tr({ switch self {
        case .characters(let r): "집필 속도 \(Int((r * 100).rounded()))% 증가"
        case .itemTokens(let m): "아이템 토큰 \(Int(((1 - m) * 100).rounded()))% 절감"
        case .eventChance(let m): "돌발 상황 \(Int(((1 - m) * 100).rounded()))% 감소"
        case .eventDuration(let m): "상황 시간 \(Int(((1 - m) * 100).rounded()))% 단축"
        case .authorEventDuration(let author, let m):
            "\(Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author) 상황 \(Int(((1 - m) * 100).rounded()))% 단축"
        case .refusal(let d): "거절 확률 \(Int((d * 100).rounded()))%p 감소"
        case .refusalWait(let m): "거절 대기 \(Int(((1 - m) * 100).rounded()))% 단축"
        case .disasterLoss(let m): "재해 손실 \(Int(((1 - m) * 100).rounded()))% 감소"
        } }())
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
    let rawTitle: String
    /// 달성 조건.
    let rawDetail: String
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
    var rawPatronTitle: String? = nil

    var title: String { L10n.tr(rawTitle) }
    var detail: String { L10n.tr(rawDetail) }
    var patronTitle: String? { rawPatronTitle.map { L10n.tr($0) } }

    init(
        id: String,
        title: String,
        detail: String,
        tier: BadgeTier,
        category: BadgeCategory,
        icon: [String],
        measure: @escaping @Sendable (AchievementFacts) -> (Double, Double),
        countable: Bool = true,
        chain: String? = nil,
        portrait: String? = nil,
        perk: Perk? = nil,
        daily: Bool = false,
        patronTitle: String? = nil
    ) {
        self.id = id
        self.rawTitle = title
        self.rawDetail = detail
        self.tier = tier
        self.category = category
        self.icon = icon
        self.measure = measure
        self.countable = countable
        self.chain = chain
        self.portrait = portrait
        self.perk = perk
        self.daily = daily
        self.rawPatronTitle = patronTitle
    }

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
