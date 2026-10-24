import Foundation
import SwiftUI

// MARK: - 저장

struct WritingRecord: Codable, Sendable {
    /// 그날 본 토큰 중 가장 큰 값.
    var tokens: Int
    /// 그날 쓴 글자 수.
    var characters: Double
    /// 그날 자연재해로 잃은 글자 수. 옛 파일에는 없다.
    var lost: Double?
    /// 그날 본 읽기(입력·캐시) 토큰 중 가장 큰 값. 옛 파일에는 없다.
    var read: Int?

    /// 쓴 글자에서 잃은 글자를 뺀 것. 진행은 이 값으로 센다.
    var net: Double { characters - (lost ?? 0) }
}

/// 지금 벌어진 돌발 상황.
struct ActiveEvent: Codable, Sendable, Equatable {
    /// `AuthorEvent.id`
    let id: String
    let startedAt: Date
    let endsAt: Date
    /// 알림을 이미 보냈는지. 새로고침이나 재실행 때 같은 알림이 또 뜨지 않게.
    var notified = false
    /// 고른 원인(`AuthorEvent.causes` 의 차례). 옛 기록에는 없다.
    var cause: Int?
    /// 아이템을 거절당한 뒤 다시 쓸 수 있는 시각.
    var refusedUntil: Date?
    /// 거절당한 횟수.
    var refusals: Int?
}

/// 진행 중인 행운. 영감의 날과 손님 작가는 시간이 있고, 선금은 바로 끝나 여기 남지 않는다.
struct ActiveLuck: Codable, Sendable, Equatable {
    /// `LuckEvent.id`
    let id: String
    let startedAt: Date
    let endsAt: Date
    /// 손님 작가(`authorShort`).
    var guest: String?
}

/// 작품 하나를 탈고했을 때의 기록. 며칠 걸렸고 그동안 무슨 일이 있었는지.
struct FinishNote: Codable, Sendable, Equatable, Identifiable {
    /// `Book.file`
    let book: String
    let round: Int
    let date: Date
    /// 쓰기 시작한 날부터 탈고한 날까지.
    let days: Int
    let events: Int
    let lost: Int
    var notified: Bool?
    var dismissed: Bool?
    /// 원고를 보낸 출판사(`Publisher.rawValue`). 고르기 전엔 nil, 기한이 지나면 대형으로.
    var publisher: String?
    var publisherDue: Date?
    var id: String { "\(round)-\(book)" }
}

/// 지난 한 주(월~일) 돌아보기.
struct WeeklyReview: Codable, Sendable, Equatable {
    let weekStart: Date
    let characters: Int
    let finished: Int
    let events: Int
    let disasters: Int
    let bestDay: Date?
    let bestDayCharacters: Int
    var notified: Bool?
    var dismissed: Bool?
    /// 지난주에 팔린 부수.
    var sales: Int?
    /// 지난주 마감을 지켰는지. 과제가 없었으면 nil.
    var deadlineMet: Bool?
}

/// 판매 단계. 부수가 이 수에 닿으면 올라간다.
enum SalesTier: Int, CaseIterable, Codable, Sendable, Comparable {
    case none, firstPrint, reprint, bestseller, million

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    var copies: Int {
        switch self {
        case .none: 0
        case .firstPrint: 1_000
        case .reprint: 10_000
        case .bestseller: 100_000
        case .million: 1_000_000
        }
    }

    var title: String {
        switch self {
        case .none: "미출간"
        case .firstPrint: "초판 완판"
        case .reprint: "재판"
        case .bestseller: "베스트셀러"
        case .million: "밀리언셀러"
        }
    }

    /// 무슨 뜻인지. 단계 이름에 마우스를 올리면 보인다.
    var meaning: String {
        switch self {
        case .none: "아직 1,000부가 안 팔렸습니다"
        case .firstPrint: "1,000부를 넘겼습니다. 처음 찍은 책이 다 팔렸다는 뜻입니다"
        case .reprint: "1만 부를 넘겼습니다. 다시 찍을 만큼 팔렸다는 뜻입니다"
        case .bestseller: "10만 부를 넘겼습니다. 서점 맨 앞에 놓이는 책입니다"
        case .million: "100만 부를 넘겼습니다. 가장 높은 단계입니다"
        }
    }

    /// 단계를 넘었을 때 한마디.
    var line: String {
        switch self {
        case .none: ""
        case .firstPrint: "초판이 다 나갔습니다"
        case .reprint: "재판을 찍습니다"
        case .bestseller: "서점 진열대 맨 앞에 놓였습니다"
        case .million: "집집마다 한 권씩 있습니다"
        }
    }

    static func of(copies: Double) -> SalesTier {
        allCases.last { Double($0.copies) <= copies } ?? .none
    }
}

/// 판매 단계를 넘은 소식.
struct SalesNews: Codable, Sendable, Equatable, Identifiable {
    /// `Book.file`
    let book: String
    let tier: SalesTier
    let copies: Int
    let date: Date
    var notified: Bool?
    var id: String { "\(book)-\(tier.rawValue)" }
}

/// 상황이 끝나거나 아이템을 거절당했을 때 보여 주는 한 줄. 몇 분 동안 팝오버와 상시 창에 나온다.
struct EventNote: Codable, Sendable, Equatable {
    enum Kind: String, Codable, Sendable { case returned, cured, refused, luck, dilemma, review, deadline, bet, publisher, order, shop, stat }
    let text: String
    let date: Date
    /// `AuthorEvent.id`
    let event: String
    let kind: Kind
    var notified: Bool?
}

/// 지나간 돌발 상황 한 줄. 가방 화면의 "최근 돌발 상황"에 쓴다.
struct EventRecord: Codable, Sendable, Equatable, Identifiable {
    /// `AuthorEvent.id`
    let event: String
    /// 그때 쓰던 책(`Book.file`).
    let book: String?
    let startedAt: Date
    var endedAt: Date?
    /// 끝낸 아이템(`ItemKind.rawValue`). nil 이고 `endedAt` 이 있으면 시간이 지나 저절로 끝났다.
    var endedBy: String?
    /// 멈춘 동안 쓴 토큰. 이만큼은 글자가 되지 않았다.
    var pausedTokens = 0
    /// 자연재해로 잃은 글자 수. 돌발 상황이면 nil.
    var lostCharacters: Int?
    /// 자연재해 알림을 보냈는지.
    var notified: Bool?
    /// 상황의 원인과 끝난 모습.
    var cause: String?
    var outcome: String?
    /// 고유 번호. 한 갱신에서 여러 기록이 같은 시각으로 생겨도 구분한다. 옛 기록에는 없다.
    var uid: String? = UUID().uuidString

    var id: String { uid ?? "\(startedAt.timeIntervalSince1970)-\(event)" }
}

/// 원소 하나가 깨져도 나머지는 살리는 디코딩.
struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

struct WritingState: Codable, Sendable {
    /// 키는 로컬 날짜 "yyyy-MM-dd".
    var days: [String: WritingRecord] = [:]
    /// 가진 아이템. 키는 `ItemKind.rawValue`.
    var items: [String: Int] = [:]
    /// 다음 아이템까지 모은 토큰.
    var tokensTowardItem = 0
    /// 다음 돌발 상황 추첨까지 모은 토큰(100만 단위로 끊어 추첨한다).
    var tokensTowardEventRoll = 0
    var event: ActiveEvent?
    /// 돌발 상황 기록. 오래된 것부터, 최근 `maxEventLog` 개만 둔다.
    var eventLog: [EventRecord] = []
    static let maxEventLog = 50
    /// 달성한 성과. 키는 `Achievement.id`.
    var badges: [String: BadgeRecord] = [:]
    /// 성과를 한 번이라도 셌는지. 처음 셀 때 이미 이룬 것은 알리지 않는다.
    var badgesInitialized = false
    /// 가장 최근의 돌아옴·치료·거절 한 줄.
    var note: EventNote?
    /// 회차마다 쓰는 순서(책 번호). 비어 있으면 서재 순서.
    var orders: [[Int]] = []
    /// 탈고 기록(최근 것이 뒤). 팝오버 카드와 알림에 쓴다.
    var finishNotes: [FinishNote] = []
    /// 지난주 돌아보기.
    var weekly: WeeklyReview?
    /// 진행 중인 행운.
    var luck: ActiveLuck?
    /// 성과용 잡다한 셈. 키는 `WritingStore.Counter`.
    var counters: [String: Int] = [:]
    /// 탈고한 책의 판매 부수. 키는 `Book.file`. 소수점은 쌓이는 중인 부수.
    var sales: [String: Double] = [:]
    /// 날짜별로 팔린 부수(주간 돌아보기용). 키는 "yyyy-MM-dd".
    var salesByDay: [String: Double] = [:]
    /// 단계를 넘은 소식(최근 것이 뒤).
    var salesNews: [SalesNews] = []
    /// 살아 있는 보정(선택지 사건·비평). 끝난 것은 반영할 때 지운다.
    var boosts: [ActiveBoost] = []
    /// 답을 기다리는 사건.
    var dilemma: ActiveDilemma?
    /// 답한 사건 기록(최근 것이 뒤).
    var dilemmaLog: [DilemmaRecord] = []
    /// 비평(최근 것이 뒤). 아직 실리지 않은 것도 있다.
    var reviews: [Review] = []
    static let maxReviews = 60
    /// 영감 게이지에 쌓인 읽기 토큰.
    var inspiration = 0
    /// 게이지가 찼다고 알렸는지.
    var inspirationNotified: Bool?
    /// 이번 주 마감.
    var deadline: Deadline?
    /// 작업실 가구(`Furniture.id`).
    var studio: [String] = []
    /// 손님 작가와의 내기.
    var bet: ActiveBet?
    /// 서점: 이달의 책(`Book.file`)과 고른 시각, 광고(책 → 끝나는 시각), 독자 주문, 주문대로 쓴 책의 보너스(책 → 끝나는 시각).
    var featuredBook: String?
    var featuredAt: Date?
    var ads: [String: Date] = [:]
    var order: ReaderOrder?
    var orderBonus: [String: Date] = [:]
    /// 서점 사건의 보정과 기록(최근 것이 뒤, 20개까지).
    var shopBoosts: [ShopBoost] = []
    var shopLog: [ShopRecord] = []
    /// 작가별 능력치와 체력. 키는 `Book.authorShort`.
    var sheets: [String: AuthorSheet] = [:]
    /// 서점 운영(재고·자리·신뢰·정산서).
    var shop = ShopState()
    /// 마을: 오늘 풀밭에서 물건을 주웠는지(날짜), 오늘 책을 권한 날짜와 횟수.
    var pickupDay: String?
    var recommendDay: String?
    var recommendCount = 0
    /// 살롱에서 같이 쓰자고 청한 날짜.
    var inviteDay: String?

    init() {}

    private enum CodingKeys: String, CodingKey {
        case days, items, tokensTowardItem, tokensTowardEventRoll, event, eventLog, badges, badgesInitialized, note
        case orders, finishNotes, weekly, luck, counters, sales, salesByDay, salesNews, boosts, dilemma, dilemmaLog, reviews
        case inspiration, inspirationNotified, deadline, studio, bet
        case featuredBook, featuredAt, ads, order, orderBonus, shopBoosts, shopLog, sheets, shop
        case pickupDay, recommendDay, recommendCount, inviteDay
    }

    /// 새 항목이 생겨도 옛 파일을 읽을 수 있게 빠진 키는 기본값으로 둔다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        days = try c.decodeIfPresent([String: WritingRecord].self, forKey: .days) ?? [:]
        items = try c.decodeIfPresent([String: Int].self, forKey: .items) ?? [:]
        tokensTowardItem = try c.decodeIfPresent(Int.self, forKey: .tokensTowardItem) ?? 0
        tokensTowardEventRoll = try c.decodeIfPresent(Int.self, forKey: .tokensTowardEventRoll) ?? 0
        // 모르는 상황 이름이면 상황이 없는 것으로 둔다.
        let event = try? c.decodeIfPresent(ActiveEvent.self, forKey: .event)
        self.event = event.flatMap { AuthorEvents.byID($0.id) == nil ? nil : $0 }
        eventLog = ((try? c.decodeIfPresent([Lossy<EventRecord>].self, forKey: .eventLog)) ?? []).compactMap(\.value)
        if let lossy = try? c.decodeIfPresent([String: Lossy<BadgeRecord>].self, forKey: .badges) {
            badges = lossy.compactMapValues(\.value)
            badgesInitialized = (try? c.decodeIfPresent(Bool.self, forKey: .badgesInitialized)) ?? false
        } else {
            // 성과를 통째로 못 읽었으면 다시 조용히 채운다. 아니면 보상과 알림이 또 나간다.
            badges = [:]
            badgesInitialized = false
        }
        note = try? c.decodeIfPresent(EventNote.self, forKey: .note)
        orders = (try? c.decodeIfPresent([[Int]].self, forKey: .orders)) ?? []
        finishNotes = ((try? c.decodeIfPresent([Lossy<FinishNote>].self, forKey: .finishNotes)) ?? []).compactMap(\.value)
        weekly = try? c.decodeIfPresent(WeeklyReview.self, forKey: .weekly)
        luck = try? c.decodeIfPresent(ActiveLuck.self, forKey: .luck)
        counters = (try? c.decodeIfPresent([String: Int].self, forKey: .counters)) ?? [:]
        sales = (try? c.decodeIfPresent([String: Double].self, forKey: .sales)) ?? [:]
        salesByDay = (try? c.decodeIfPresent([String: Double].self, forKey: .salesByDay)) ?? [:]
        salesNews = ((try? c.decodeIfPresent([Lossy<SalesNews>].self, forKey: .salesNews)) ?? []).compactMap(\.value)
        boosts = ((try? c.decodeIfPresent([Lossy<ActiveBoost>].self, forKey: .boosts)) ?? []).compactMap(\.value)
        let dilemma = try? c.decodeIfPresent(ActiveDilemma.self, forKey: .dilemma)
        self.dilemma = dilemma.flatMap { Dilemmas.byID($0.id) == nil ? nil : $0 }
        dilemmaLog = ((try? c.decodeIfPresent([Lossy<DilemmaRecord>].self, forKey: .dilemmaLog)) ?? []).compactMap(\.value)
        reviews = ((try? c.decodeIfPresent([Lossy<Review>].self, forKey: .reviews)) ?? []).compactMap(\.value)
        inspiration = (try? c.decodeIfPresent(Int.self, forKey: .inspiration)) ?? 0
        inspirationNotified = try? c.decodeIfPresent(Bool.self, forKey: .inspirationNotified)
        deadline = try? c.decodeIfPresent(Deadline.self, forKey: .deadline)
        studio = ((try? c.decodeIfPresent([String].self, forKey: .studio)) ?? []).filter { Studio.byID($0) != nil }
        bet = try? c.decodeIfPresent(ActiveBet.self, forKey: .bet)
        featuredBook = try? c.decodeIfPresent(String.self, forKey: .featuredBook)
        featuredAt = try? c.decodeIfPresent(Date.self, forKey: .featuredAt)
        ads = (try? c.decodeIfPresent([String: Date].self, forKey: .ads)) ?? [:]
        order = try? c.decodeIfPresent(ReaderOrder.self, forKey: .order)
        orderBonus = (try? c.decodeIfPresent([String: Date].self, forKey: .orderBonus)) ?? [:]
        shopBoosts = ((try? c.decodeIfPresent([Lossy<ShopBoost>].self, forKey: .shopBoosts)) ?? []).compactMap(\.value)
        shopLog = ((try? c.decodeIfPresent([Lossy<ShopRecord>].self, forKey: .shopLog)) ?? []).compactMap(\.value)
        sheets = ((try? c.decodeIfPresent([String: Lossy<AuthorSheet>].self, forKey: .sheets)) ?? [:]).compactMapValues(\.value)
        shop = (try? c.decodeIfPresent(ShopState.self, forKey: .shop)) ?? ShopState()
        pickupDay = try? c.decodeIfPresent(String.self, forKey: .pickupDay)
        recommendDay = try? c.decodeIfPresent(String.self, forKey: .recommendDay)
        recommendCount = (try? c.decodeIfPresent(Int.self, forKey: .recommendCount)) ?? 0
        inviteDay = try? c.decodeIfPresent(String.self, forKey: .inviteDay)
    }

    /// 그날 커피·홍차로 끝낸 상황 수(카페인).
    func cups(on day: Date, calendar: Calendar = .current) -> Int {
        eventLog.filter { record in
            guard let ended = record.endedAt, let item = record.endedBy.flatMap(ItemKind.init(rawValue:)), item.role == .wake else { return false }
            return calendar.isDate(ended, inSameDayAs: day)
        }.count
    }

    /// 진행 중인 상황의 기록. 자연재해 줄은 시작과 끝이 같아 걸리지 않는다.
    var openRecordIndex: Int? {
        eventLog.lastIndex { $0.endedAt == nil }
    }

    /// 지금 상황을 끝냈다고 적는다.
    mutating func closeRecord(at date: Date, by item: ItemKind?, outcome: String? = nil) {
        guard let i = openRecordIndex else { return }
        eventLog[i].endedAt = date
        eventLog[i].endedBy = item?.rawValue
        eventLog[i].outcome = outcome
    }
}

enum Writing {
    /// 100만 토큰당 글자 수.
    static let charactersPerMillionTokens = 1_000.0
}


// MARK: - 진행

struct FinishedBook: Identifiable, Sendable {
    let round: Int
    let bookIndex: Int
    let date: Date
    var id: String { "\(round)-\(bookIndex)" }
}

/// 저장된 날짜별 글자 수에서 계산한 지금 쓰는 책, 쓴 위치, 끝낸 책.
@MainActor
struct WritingProgress {
    let totalCharacters: Double
    /// 0부터 센다.
    let round: Int
    let bookIndex: Int
    /// 지금 책에서 쓴 글자 수.
    let charactersInBook: Int
    let finished: [FinishedBook]
    /// 이번 회차에 쓰는 순서(책 번호)와 지금 책의 자리.
    let roundOrder: [Int]
    let orderPosition: Int
    let nextBook: Book?
    let todayCharacters: Double
    /// 최근 7일 하루 평균.
    let recentCharactersPerDay: Double
    /// 지금 벌어진 돌발 상황. 없으면 쓰는 중.
    let activeEvent: ActiveEvent?
    let items: [ItemKind: Int]
    let tokensToNextItem: Int
    /// 돌발 상황 기록. 최근 것이 앞.
    let recentEvents: [EventRecord]
    /// 달성한 성과와 날짜.
    let badges: [String: Date]
    /// 성과 보상으로 받은 아이템 이름("커피 1, 종 2").
    let badgeRewards: [String: String]
    /// 받은 금 뱃지의 효과.
    let perks: Perks
    /// 매일 성과를 이룬 날수와 연속 일수.
    let dailyCounts: [String: (total: Int, streak: Int)]
    /// 가장 최근의 돌아옴·치료·거절 한 줄.
    let note: EventNote?
    /// 진행 중인 행운.
    let luck: ActiveLuck?
    /// 책마다 팔린 부수(`Book.file` → 부수).
    let sales: [String: Int]
    /// 아직 닫지 않은 탈고 카드(하루 동안), 전체 탈고 기록, 지난주 돌아보기(그 주 동안).
    let finishCards: [FinishNote]
    let allFinishNotes: [FinishNote]
    let weeklyCard: WeeklyReview?
    /// 답을 기다리는 사건과 답한 기록(최근 것이 앞).
    let dilemma: ActiveDilemma?
    let decisions: [DilemmaRecord]
    /// 실린 비평(최근 것이 앞).
    let reviews: [Review]
    /// 살아 있는 보정과 그 합.
    let boosts: [ActiveBoost]
    let boostSummary: Boosts
    /// 영감 게이지(0...1)와 찼는지.
    let inspirationFraction: Double
    let inspirationReady: Bool
    /// 이번 주 마감과 진행.
    let deadline: Deadline?
    let deadlineProgress: Int
    /// 오늘 날씨.
    let weather: Weather
    /// 작업실 가구와 그 효과.
    let studio: [String]
    let studioPerks: StudioPerks
    /// 손님 작가와의 내기(걸린 것, 받은 것, 하루 안에 끝난 것).
    let bet: ActiveBet?
    /// 서점: 이달의 책과 바꿀 수 있는지, 광고 끝나는 시각, 독자 주문, 최근 14일 판매(오래된 날이 앞).
    let featuredBook: String?
    let canChangeFeatured: Bool
    let ads: [String: Date]
    let order: ReaderOrder?
    let dailySales: [(day: Date, copies: Int)]
    /// 서점 사건: 살아 있는 보정과 최근 기록(최근 것이 앞).
    let shopBoosts: [ShopBoost]
    let shopLog: [ShopRecord]
    /// 서점 운영 상태와 아직 안 닫은 정산서.
    let shop: ShopState
    let statementCard: Statement?
    /// 마을: 오늘 풀밭에 주울 것이 있는지, 오늘 더 권할 수 있는 횟수.
    let pickupAvailable: Bool
    let recommendationsLeft: Int
    /// 살롱에서 오늘 청할 수 있는지(행운 없고 아직 안 청함).
    let canInvite: Bool
    /// 성과를 세는 값.
    let facts: AchievementFacts

    /// 이 책에 걸린 서점 보정의 곱(전체 보정 포함).
    func shopMultiplier(for book: Book) -> Double {
        shopBoosts.filter { $0.book == nil || $0.book == book.file }.reduce(1.0) { $0 * $1.value }
    }

    func adEnds(for book: Book) -> Date? { ads[book.file].flatMap { $0 > Date() ? $0 : nil } }
    var canAdvertise: Bool { Balance.adCost.allSatisfy { count($0.0) >= $0.1 } }
    /// 서점 운영: 재고, 자리, 재판, 신뢰 단계.
    func stock(of book: Book) -> Int { shop.stock(of: book.file) }
    func slot(of book: Book) -> ShopSlot? { shop.slot(of: book.file, window: featuredBook) }
    func reprint(for book: Book) -> ShopState.Reprint? { shop.reprints[book.file] }
    var trustLevel: TrustLevel { shop.level }
    func isPinned(_ book: Book) -> Bool { shop.pinned[book.file] != nil }
    func isBenched(_ book: Book) -> Bool { shop.benched[book.file] != nil }
    /// 자리별 책(진열창, 매대, 서가, 창고). 서가는 많이 팔린 순서.
    func books(in slot: ShopSlot) -> [Book] {
        let done = Set(finished.map(\.bookIndex)).map { Library.books[$0] }
        let picked = done.filter { self.slot(of: $0) == slot }
        switch slot {
        case .counter: return shop.counter.compactMap { f in picked.first { $0.file == f } }
        default: return picked.sorted { (sales(of: $0), $1.file) > (sales(of: $1), $0.file) }
        }
    }
    /// 이번 주(월요일부터) 팔린 부수.
    var weekSales: Int {
        let start = WritingStore.weekStart(of: Date())
        return dailySales.filter { $0.day >= start }.reduce(0) { $0 + $1.copies }
    }

    /// 출판사를 아직 안 고른 탈고 기록.
    var awaitingPublisher: FinishNote? { finishCards.first { $0.publisher == nil } }

    var dilemmaKind: Dilemma? { dilemma.flatMap { Dilemmas.byID($0.id) } }
    /// 이 책의 가장 최근 비평.
    func review(of book: Book) -> Review? { reviews.first { $0.book == book.file } }

    var event: AuthorEvent? { activeEvent.flatMap { AuthorEvents.byID($0.id) } }
    var luckEvent: LuckEvent? { luck.flatMap { Lucks.byID($0.id) } }
    /// 모두 팔린 부수.
    var totalSales: Int { sales.values.reduce(0, +) }
    func sales(of book: Book) -> Int { sales[book.file] ?? 0 }
    func salesTier(of book: Book) -> SalesTier { SalesTier.of(copies: Double(sales(of: book))) }
    /// 손님 작가가 있으면 그 작가.
    var guestAuthor: String? { luck?.guest }
    /// 카페인: 오늘 커피·홍차로 끝낸 상황 수와, 손이 떨리는지(`Balance.caffeineCups` 이상).
    let cupsToday: Int
    var caffeinated: Bool { cupsToday >= Balance.caffeineCups }
    /// 표정. 카페인이면 눈이 커지고, 하루 안의 자기 비평에 웃거나 찡그리고, 재해 직후엔 찡그리고, 새벽엔 피곤하다.
    let expression: Expression
    /// 지금 작가의 능력치·체력과 그 배수, 다음 능력치까지 남은 토큰, 지쳤는지(체력이 `Balance.staminaTiredBelow` 아래).
    let sheet: AuthorSheet
    let sheets: [String: AuthorSheet]
    let statPerks: StatPerks
    let tokensToNextStat: Int
    let tired: Bool
    func sheet(for author: String) -> AuthorSheet { sheets[author] ?? AuthorSheet() }
    func finishNote(for book: Book) -> FinishNote? { allFinishNotes.last { $0.book == book.file } }
    /// 그 역할의 아이템을 모두 센다.
    func count(role: ItemRole) -> Int { role.kinds.reduce(0) { $0 + count($1) } }
    /// 그 역할로 쓸 아이템. 기본 아이템부터, 없으면 다음 것.
    func item(for role: ItemRole) -> ItemKind? { role.kinds.first { count($0) > 0 } }
    /// 지금 상황을 끝낼 아이템.
    var cureItem: ItemKind? { event.flatMap { item(for: $0.cure.role) } }
    /// 지금 상황을 끝낼 아이템 수(역할 합계).
    var cureCount: Int { event.map { count(role: $0.cure.role) } ?? 0 }
    /// 지금 상황의 원인 한 줄.
    var cause: String? {
        guard let event, let i = activeEvent?.cause, event.causes.indices.contains(i) else { return nil }
        return event.causes[i]
    }
    /// 아이템을 거절당해 다시 쓸 수 있는 시각(아직 안 지났으면).
    func refusedUntil(now: Date = Date()) -> Date? {
        guard let until = activeEvent?.refusedUntil, until > now else { return nil }
        return until
    }
    /// `seconds` 안의 한 줄 메모.
    func recentNote(within seconds: TimeInterval, now: Date = Date()) -> EventNote? {
        guard let note, now.timeIntervalSince(note.date) < seconds else { return nil }
        return note
    }
    /// `seconds` 안에 일어난 가장 최근 자연재해.
    func recentDisaster(within seconds: TimeInterval, now: Date = Date()) -> EventRecord? {
        recentEvents.first { $0.lostCharacters != nil && now.timeIntervalSince($0.startedAt) < seconds }
    }
    func count(_ item: ItemKind) -> Int { items[item] ?? 0 }

    var book: Book? { Library.books.indices.contains(bookIndex) ? Library.books[bookIndex] : nil }
    /// 이번 회차에 탈고한 수.
    var finishedInRound: Int { finished.filter { $0.round == round }.count }
    /// 이번 회차 순서에서 이 책의 자리(0부터). 없으면 nil.
    func position(of bookIndex: Int) -> Int? { roundOrder.firstIndex(of: bookIndex) }
    /// 이번 회차에 아직 안 쓴 책(순서대로).
    var pendingInRound: [Int] { Array(roundOrder.dropFirst(orderPosition + 1)) }
    var fraction: Double {
        guard let book, book.characters > 0 else { return 0 }
        return Double(charactersInBook) / Double(book.characters)
    }
    var daysToFinish: Int? {
        guard let book, recentCharactersPerDay > 0 else { return nil }
        return Int((Double(book.characters - charactersInBook) / recentCharactersPerDay).rounded(.up))
    }

    init(state: WritingState, now: Date = Date()) {
        let books = Library.books
        let n = books.count
        let records = state.days.sorted { $0.key < $1.key }
        // 회차마다 쓰는 순서. 저장된 순서가 있으면 유효한 앞부분을 살리고 새로 추가된 책은 뒤에 이어 붙인다.
        func order(_ round: Int) -> [Int] {
            if round < state.orders.count {
                var seen = Set<Int>()
                var valid = state.orders[round].filter { $0 >= 0 && $0 < n && seen.insert($0).inserted }
                if !valid.isEmpty {
                    if valid.count < n {
                        valid.append(contentsOf: (0..<n).filter { !seen.contains($0) })
                    }
                    return valid
                }
            }
            return Array(0..<n)
        }

        var cumulative = 0.0
        var finished: [FinishedBook] = []
        var round = 0, position = 0, intoBook = 0.0
        if n > 0 {
            for (key, record) in records where record.characters > 0 || (record.lost ?? 0) > 0 {
                guard let date = DayKey.date(from: key) else { continue }
                cumulative += record.net
                intoBook = max(0, intoBook + record.net)
                while intoBook >= Double(books[order(round)[position]].characters) {
                    intoBook -= Double(books[order(round)[position]].characters)
                    finished.append(FinishedBook(round: round, bookIndex: order(round)[position], date: date))
                    position += 1
                    if position == n { position = 0; round += 1 }
                }
            }
        }
        totalCharacters = cumulative
        self.finished = finished
        self.round = round
        roundOrder = n > 0 ? order(round) : []
        orderPosition = position
        bookIndex = n > 0 ? roundOrder[position] : 0
        charactersInBook = Int(intoBook)
        nextBook = n > 0 ? (position + 1 < n ? books[roundOrder[position + 1]] : books[order(round + 1)[0]]) : nil

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        todayCharacters = state.days[DayKey.string(from: today)]?.characters ?? 0
        // 최근 7일 평균. 쓰기 시작한 지 7일이 안 됐으면 시작한 날부터의 날수로 나눈다.
        // 첫날에 7로 나누면 탈고 예상일이 일곱 배로 늘어난다.
        let firstDay = records.first { $0.value.characters > 0 }.flatMap { DayKey.date(from: $0.key) }
        let daysSinceStart = firstDay.map { (calendar.dateComponents([.day], from: $0, to: today).day ?? 0) + 1 } ?? 7
        let window = min(7, max(1, daysSinceStart))
        let recentKeys = (0..<window).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            .map { DayKey.string(from: $0) }
        recentCharactersPerDay = recentKeys.reduce(0.0) { $0 + (state.days[$1]?.net ?? 0) } / Double(window)

        activeEvent = state.event
        var items: [ItemKind: Int] = [:]
        for (key, count) in state.items { if let kind = ItemKind(rawValue: key), count > 0 { items[kind] = count } }
        self.items = items
        var currentSheet = AuthorSheet()
        if Library.books.indices.contains(bookIndex), let saved = state.sheets[Library.books[bookIndex].authorShort] { currentSheet = saved }
        let currentPerks = StatPerks(currentSheet)
        sheet = currentSheet
        sheets = state.sheets
        statPerks = currentPerks
        tokensToNextStat = max(0, Balance.statTokens - currentSheet.tokensTowardStat)
        tired = currentSheet.stamina < currentPerks.staminaMax * Balance.staminaTiredBelow
        tokensToNextItem = max(0, Int(Double(Balance.tokensPerItem) * Perks(badges: state.badges, now: now).itemTokens * currentPerks.itemTokens) - state.tokensTowardItem)
        recentEvents = state.eventLog.reversed()
        badges = state.badges.mapValues(\.date)
        badgeRewards = state.badges.compactMapValues { record in
            guard let reward = record.reward, !reward.isEmpty else { return nil }
            var counts: [ItemKind: Int] = [:]
            for raw in reward { if let kind = ItemKind(rawValue: raw) { counts[kind, default: 0] += 1 } }
            return ItemKind.allCases.compactMap { kind in counts[kind].map { n in "\(kind.shortTitle) \(n)" } }.joined(separator: ", ")
        }
        perks = Perks(badges: state.badges, now: now)
        dailyCounts = state.badges.compactMapValues { record in record.count.map { (total: $0, streak: record.streak ?? 1) } }
        note = state.note
        luck = state.luck.flatMap { $0.endsAt > now ? $0 : nil }
        sales = state.sales.mapValues { Int($0) }
        finishCards = state.finishNotes.filter { $0.dismissed != true && now.timeIntervalSince($0.date) < 86_400 }
        allFinishNotes = state.finishNotes
        weeklyCard = state.weekly.flatMap { $0.dismissed != true && $0.weekStart == WritingStore.weekStart(of: now) ? $0 : nil }
        dilemma = state.dilemma.flatMap { $0.expiresAt > now ? $0 : nil }
        decisions = state.dilemmaLog.reversed()
        reviews = state.reviews.filter { $0.published == true }.reversed()
        boosts = state.boosts.filter { $0.endsAt > now }
        boostSummary = Boosts(state.boosts, now: now)
        inspirationFraction = min(1, Double(state.inspiration) / Double(Balance.inspirationGaugeTokens))
        inspirationReady = state.inspiration >= Balance.inspirationGaugeTokens && state.luck == nil
        let thisWeek = WritingStore.weekStart(of: now)
        // 지킨 과제는 하루 동안만 보여 준다. 그 뒤로는 다음 월요일까지 줄이 없다.
        deadline = state.deadline.flatMap { d in
            guard d.weekStart == thisWeek else { return nil }
            // 지킨 시각이 없는 옛 기록도 지난 것으로 본다.
            if d.met == true, now.timeIntervalSince(d.metAt ?? .distantPast) >= 86_400 { return nil }
            return d
        }
        if let deadline = state.deadline, deadline.weekStart == thisWeek {
            switch deadline.kind {
            case .characters:
                deadlineProgress = Int(state.days.reduce(0.0) { sum, pair in
                    guard let date = DayKey.date(from: pair.key), date >= thisWeek else { return sum }
                    return sum + pair.value.net
                })
            case .finish: deadlineProgress = finished.count
            case .sales:
                deadlineProgress = Int(state.salesByDay.reduce(0.0) { sum, pair in
                    guard let date = DayKey.date(from: pair.key), date >= thisWeek else { return sum }
                    return sum + pair.value
                })
            }
        } else {
            deadlineProgress = 0
        }
        weather = Weather.of(now)
        studio = state.studio
        studioPerks = StudioPerks(owned: state.studio)
        bet = state.bet.flatMap { b in
            if let at = b.resolvedAt { return now.timeIntervalSince(at) < 86_400 && b.accepted == true ? b : nil }
            return b
        }
        featuredBook = state.featuredBook
        canChangeFeatured = state.featuredBook == nil || state.featuredAt.map { now.timeIntervalSince($0) >= TimeInterval(Balance.featuredHours) * 3600 } ?? true
        ads = state.ads.filter { $0.value > now }
        self.order = state.order.flatMap { $0.fulfilled == nil && $0.expiresAt > now ? $0 : nil }
        shopBoosts = state.shopBoosts.filter { $0.endsAt > now }
        shop = state.shop
        statementCard = state.shop.statements.last.flatMap { $0.dismissed != true && now.timeIntervalSince($0.weekStart) < 14 * 86_400 ? $0 : nil }
        let todayKey = DayKey.string(from: Calendar.current.startOfDay(for: now))
        pickupAvailable = state.pickupDay != todayKey
        canInvite = state.inviteDay != todayKey && state.luck == nil
        recommendationsLeft = state.recommendDay == todayKey ? max(0, Balance.recommendPerDay - state.recommendCount) : Balance.recommendPerDay
        shopLog = state.shopLog.reversed()
        let dayStart = Calendar.current.startOfDay(for: now)
        dailySales = (0..<14).reversed().compactMap { back -> (Date, Int)? in
            guard let day = Calendar.current.date(byAdding: .day, value: -back, to: dayStart) else { return nil }
            return (day, Int(state.salesByDay[DayKey.string(from: day)] ?? 0))
        }
        cupsToday = state.cups(on: now)
        expression = {
            if state.cups(on: now) >= Balance.caffeineCups { return .surprised }
            if let review = state.reviews.last(where: { $0.published == true && $0.affected == true }), now.timeIntervalSince(review.date) < 86_400 {
                if review.stars >= 4 { return .happy }
                if review.stars <= 2 { return .frown }
            }
            if let note = state.note, now.timeIntervalSince(note.date) < 180 {
                if note.kind == .cured { return .happy }
                if note.kind == .refused { return .frown }
            }
            if state.eventLog.last(where: { $0.lostCharacters != nil }).map({ now.timeIntervalSince($0.startedAt) < 3600 }) == true { return .frown }
            if let luck = state.luck, luck.endsAt > now, luck.id == Lucks.inspiration.id { return .happy }
            if currentSheet.stamina < StatPerks(currentSheet).staminaMax * Balance.staminaTiredBelow { return .tired }
            if (0..<5).contains(Calendar.current.component(.hour, from: now)) { return .tired }
            return .neutral
        }()
        facts = AchievementFacts(state: state, finished: finished, now: now)
    }
}
