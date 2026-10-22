import Foundation
import SwiftUI

/// 날짜별 기록의 키. 로컬 날짜 "yyyy-MM-dd".
enum DayKey {
    nonisolated static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(from date: Date) -> String { formatter.string(from: date) }
    static func date(from key: String) -> Date? { formatter.date(from: key) }
}

// MARK: - 서재

/// `Books/manifest.json` 한 줄. 원문은 Project Gutenberg 의 퍼블릭 도메인 텍스트에서 안내문을 뗀 것이다.
struct Book: Codable, Sendable, Identifiable {
    let file: String
    /// 원서의 작가와 제목. 초상화·색을 고르는 열쇠로 쓰고 화면에는 한국어 이름을 쓴다.
    let author: String
    let title: String
    let titleKo: String?
    let authorKo: String?
    /// 희곡처럼 줄바꿈을 살려 보여 줄 작품.
    let preserveLines: Bool
    let characters: Int

    var id: String { file }
    var displayTitle: String { titleKo ?? title }
    var displayAuthor: String { authorKo ?? author }
    /// "에드거 앨런 포" → "포"
    var displayAuthorShort: String { displayAuthor.split(separator: " ").last.map(String.init) ?? displayAuthor }

    /// 작가 성. 좁은 자리에서 쓴다.
    var authorShort: String { author.split(separator: " ").last.map(String.init) ?? author }

    /// 책등 색. 작가마다 하나.
    var spineColor: Color {
        switch authorShort {
        case "Shakespeare": Color(red: 0.55, green: 0.15, blue: 0.2)
        case "Dickens": Color(red: 0.2, green: 0.35, blue: 0.25)
        case "Poe": Color(red: 0.18, green: 0.18, blue: 0.24)
        case "Carroll": Color(red: 0.3, green: 0.5, blue: 0.75)
        case "Stevenson": Color(red: 0.6, green: 0.42, blue: 0.2)
        case "Wilde": Color(red: 0.45, green: 0.3, blue: 0.55)
        case "Austen": Color(red: 0.75, green: 0.55, blue: 0.6)
        case "Goethe": Color(red: 0.2, green: 0.45, blue: 0.5)
        default: Color.gray
        }
    }
}

/// 앱에 넣은 원문. 작가가 번갈아 나오도록 순서가 정해져 있고, 끝나면 처음부터 다시 쓴다.
@MainActor
enum Library {
    /// 앱 번들의 `Resources/Books`, 없으면(`swift run`) 저장소의 `Books`.
    static let directory: URL? = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Books"),
           FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path) {
            return url
        }
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Books")
        return FileManager.default.fileExists(atPath: repo.appendingPathComponent("manifest.json").path) ? repo : nil
    }()

    static let books: [Book] = {
        guard let directory,
              let data = try? Data(contentsOf: directory.appendingPathComponent("manifest.json")),
              let books = try? JSONDecoder().decode([Book].self, from: data) else { return [] }
        // 분량 0인 책은 글자 없이 탈고돼 버리니 뺀다.
        return books.filter { $0.characters > 0 }
    }()

    /// 작가 순서(처음 나오는 순).
    static let authors: [String] = {
        var seen = Set<String>()
        return books.map(\.authorShort).filter { seen.insert($0).inserted }
    }()

    /// 한 바퀴(모든 책) 글자 수.
    static let roundCharacters: Int = books.reduce(0) { $0 + $1.characters }

    /// `starts[i]` 는 한 바퀴 안에서 `books[i]` 가 시작하는 글자 위치. 마지막 원소는 한 바퀴 길이.
    static let starts: [Int] = books.reduce(into: [0]) { $0.append($0.last! + $1.characters) }

    /// 읽어 둔 원문. 글자 배열 대신 문자열을 그대로 두고(글자당 1바이트쯤), 64글자마다 자리를 적어 둬 n번째 글자를 빨리 찾는다.
    struct BookText {
        let string: String
        /// `checkpoints[k]` 는 64k번째 글자의 자리.
        let checkpoints: [String.Index]
        let count: Int
        static let stride = 64

        init(_ string: String) {
            self.string = string
            var marks: [String.Index] = []
            marks.reserveCapacity(string.utf8.count / Self.stride + 1)
            var i = string.startIndex, n = 0
            while i != string.endIndex {
                if n % Self.stride == 0 { marks.append(i) }
                i = string.index(after: i)
                n += 1
            }
            checkpoints = marks
            count = n
        }

        /// n번째 글자의 자리. 가까운 표시에서 64글자 안으로 걷는다.
        func index(at n: Int) -> String.Index {
            let n = min(max(0, n), count)
            if n == count { return string.endIndex }
            let k = n / Self.stride
            return string.index(checkpoints[k], offsetBy: n - k * Self.stride)
        }
    }

    /// 읽어 둔 책. 쓰는 책과 읽기 창에 연 책 정도만 남기고(`cacheLimit`) 오래된 것은 비운다.
    private static var texts: [String: BookText] = [:]
    private static var recent: [String] = []
    static let cacheLimit = 2

    /// 원문. 번들에서는 `.z`(zlib 로 압축) 로, 저장소에서는 그대로 읽는다. 한 번 읽으면 기억한다.
    static func text(of book: Book) -> BookText? {
        if let cached = texts[book.file] {
            recent.removeAll { $0 == book.file }
            recent.append(book.file)
            return cached
        }
        guard let directory, let string = load(book.file, in: directory) else { return nil }
        let text = BookText(string)
        texts[book.file] = text
        recent.append(book.file)
        while recent.count > cacheLimit, let old = recent.first {
            recent.removeFirst()
            texts[old] = nil
        }
        return text
    }

    /// 지금 읽어 둔 책 수(확인용).
    static var cachedCount: Int { texts.count }

    private static func load(_ file: String, in directory: URL) -> String? {
        autoreleasepool {
            let plain = directory.appendingPathComponent(file)
            if let string = try? String(contentsOf: plain, encoding: .utf8) { return string }
            let packed = directory.appendingPathComponent(file + ".z")
            guard let data = try? Data(contentsOf: packed), let raw = try? (data as NSData).decompressed(using: .zlib) else { return nil }
            return String(data: raw as Data, encoding: .utf8)
        }
    }

    /// 압축(zlib). 빌드 스크립트와 확인용 실행이 쓴다.
    static func pack(_ string: String) -> Data? {
        (try? (Data(string.utf8) as NSData).compressed(using: .zlib)) as Data?
    }

    /// `book` 의 앞 `count` 글자.
    static func prefix(of book: Book, count: Int) -> String {
        guard let text = text(of: book) else { return "" }
        return String(text.string[..<text.index(at: count)])
    }

    /// `book` 의 앞 `count` 글자 중 끝 `tail` 글자.
    static func tail(of book: Book, upTo count: Int, length tail: Int) -> String {
        guard let text = text(of: book) else { return "" }
        let end = min(max(0, count), text.count)
        let startAt = max(0, end - tail)
        let endIndex = text.index(at: end)
        var start = text.index(at: startAt)
        // 잘린 낱말로 시작하지 않게 다음 공백까지 건너뛴다.
        if startAt > 0, let space = text.string[start..<endIndex].firstIndex(where: { $0 == " " || $0 == "\n" }) {
            start = text.string.index(after: space)
        }
        return String(text.string[start..<endIndex])
    }
}

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

/// 날짜별로 쓴 글자를 파일에 두고, 늘어난 토큰만 글자로 바꾼다.
@MainActor
final class WritingStore {
    private(set) var state: WritingState
    private let url: URL
    private let persist: Bool
    /// 파일이 없을 때 처음 한 번만 참. 그때까지 쓴 토큰은 글자로 바꾸지 않는다.
    private var needsBaseline: Bool

    /// 기록 파일 자리. `~/Library/Application Support/<앱 이름>/writing.json`
    static let defaultURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = support.appendingPathComponent("Scribe")
        // 앱 이름이 Columbus 였을 때의 기록을 한 번 옮겨 온다. 백업과 옛 탐험 기록(journey.json)도 같이.
        let old = support.appendingPathComponent("Columbus")
        let fm = FileManager.default
        if !fm.fileExists(atPath: folder.path), fm.fileExists(atPath: old.path) {
            try? fm.moveItem(at: old, to: folder)
        }
        return folder.appendingPathComponent("writing.json")
    }()

    init(url: URL? = nil, persist: Bool = true) {
        self.url = url ?? Self.defaultURL
        self.persist = persist
        let backup = self.url.deletingPathExtension().appendingPathExtension("backup.json")
        if let data = try? Data(contentsOf: self.url) {
            do {
                state = try JSONDecoder().decode(WritingState.self, from: data)
                needsBaseline = false
            } catch {
                if persist {
                    let aside = self.url.deletingPathExtension()
                        .appendingPathExtension("broken-\(Int(Date().timeIntervalSince1970)).json")
                    try? FileManager.default.moveItem(at: self.url, to: aside)
                    NSLog("writing.json 을 읽지 못해 %@ 로 옮겼습니다: %@", aside.lastPathComponent, "\(error)")
                }
                // 깨졌으면 직전 백업을 쓴다. 그것도 안 되면 빈 기록으로 시작하되, 지난 토큰이 글자가 되지 않게 기준선을 다시 잡는다.
                if let backupData = try? Data(contentsOf: backup), let restored = try? JSONDecoder().decode(WritingState.self, from: backupData) {
                    state = restored
                    needsBaseline = false
                    NSLog("writing.backup.json 에서 되살렸습니다")
                } else {
                    state = WritingState()
                    needsBaseline = true
                }
                // 깨진 파일을 옮긴 직후의 첫 저장은 백업을 덮어쓰지 않는다(마지막 정상 백업을 지킨다).
                skipBackupOnce = true
            }
        } else {
            state = WritingState()
            needsBaseline = true
        }
    }

    /// 다음 저장에서 백업 복사를 건너뛴다.
    private var skipBackupOnce = false

    /// 0..<1 난수. 확인용 실행은 정해진 값을 넣는다.
    var random: () -> Double = { Double.random(in: 0..<1) }
    /// 새 토큰 100만 개마다 돌발 상황이 생길 확률. 확인용 실행은 0 을 넣는다.
    var eventChance = Balance.eventChancePerMillion
    /// 아이템을 거절할 확률. 확인용 실행에서 바꾼다.
    var refusalChance = Balance.refusalChance
    /// 성과 보상 아이템을 줄지. 확인용 실행에서 아이템 수를 셀 때는 끈다.
    var badgeRewards = true
    /// 새 토큰 100만 개마다 자연재해가 생길 확률. 확인용 실행은 0 을 넣는다.
    var disasterChance = Balance.disasterChancePerMillion
    /// 새 토큰 100만 개마다 행운이 생길 확률. 확인용 실행은 0 을 넣는다.
    var luckChance = Balance.luckChancePerMillion
    /// 새 토큰 100만 개마다 선택지가 있는 사건이 생길 확률. 확인용 실행은 0 을 넣는다.
    var dilemmaChance = Balance.dilemmaChancePerMillion

    /// 에이전트 데이터 소스를 바꿨을 때. 지금까지 쓴 글자 수는 그대로 두고 날짜별 토큰 기준선만 새 소스에 맞춘다.
    func rebaseline() {
        needsBaseline = true
    }

    /// 스캔한 일별 토큰을 반영한다. 늘어난 토큰만 글자가 된다.
    /// 처음 만들어질 때는 그때까지의 토큰을 모두 본 것으로 적는다. 아니면 지난 몇 달 치 토큰으로 모든 책이 한 번에 끝난다.
    ///
    /// 순서: ① 끝날 시각이 지난 상황을 끝낸다(앱을 껐다 켜도 오래전에 끝난 상황이 토큰을 삼키지 않게)
    /// ② 상황이 없을 때만 글자를 더한다 ③ 토큰을 본 것으로 적는다 ④ 아이템을 센다(멈춘 동안도) ⑤ 새 상황을 추첨한다.
    func apply(days: [DayUsage], now: Date = Date(), author: String? = nil) -> WritingProgress {
        let baseline = needsBaseline
        needsBaseline = false
        var changed = baseline
        if baseline {
            let incoming = Dictionary(uniqueKeysWithValues: days.map { (DayKey.string(from: $0.day), $0) })
            for key in state.days.keys {
                let d = incoming[key]
                state.days[key]?.tokens = d?.tokens ?? 0
                state.days[key]?.read = d?.read ?? 0
            }
        }
        let before = WritingProgress(state: state, now: now)
        let finishedBefore = before.finished.count
        let currentAuthor = before.book?.authorShort
        if Self.staminaEnabled, recoverStamina(now: now) { changed = true }
        if let luck = state.luck, now >= luck.endsAt {
            state.luck = nil
            if let kind = Lucks.byID(luck.id) {
                state.note = EventNote(text: Lucks.endText(kind), date: luck.endsAt, event: luck.id, kind: .luck, notified: true)
            }
            changed = true
        }
        if let active = state.event, now >= active.endsAt {
            state.event = nil
            let text = AuthorEvents.byID(active.id).flatMap { $0.pick($0.returns, random()) } ?? "다시 자리에 앉아 펜을 듭니다"
            state.note = EventNote(text: text, date: active.endsAt, event: active.id, kind: .returned)
            state.closeRecord(at: active.endsAt, by: nil, outcome: text)
            // 탈진에서 깨면 체력이 반은 돌아와 있다.
            if active.id == AuthorEvents.exhausted.id, let currentAuthor {
                var sheet = state.sheets[currentAuthor] ?? AuthorSheet()
                sheet.stamina = max(sheet.stamina, StatPerks(sheet).staminaMax * 0.5)
                sheet.staminaAt = now
                state.sheets[currentAuthor] = sheet
            }
            changed = true
        }
        if state.boosts.contains(where: { $0.endsAt <= now }) {
            state.boosts.removeAll { $0.endsAt <= now }
            changed = true
        }
        // 답이 없는 사건은 시간이 지나면 작가가 알아서 고른다.
        if let pending = state.dilemma, now >= pending.expiresAt, let dilemma = Dilemmas.byID(pending.id) {
            choose(min(dilemma.options.count - 1, Int(random() * Double(dilemma.options.count))), now: pending.expiresAt, auto: true)
            changed = true
        }
        if publishReviews(now: now) { changed = true }
        if settleUnchosenPublishers(now: now) { changed = true }
        if state.ads.contains(where: { $0.value <= now }) { state.ads = state.ads.filter { $0.value > now }; changed = true }
        if state.shopBoosts.contains(where: { $0.endsAt <= now }) { state.shopBoosts.removeAll { $0.endsAt <= now }; changed = true }
        if Self.stockEnabled, tendShop(now: now) { changed = true }
        let live = Boosts(state.boosts, now: now)
        let weather = Weather.of(now)
        let studio = StudioPerks(owned: state.studio)
        let hourNow = Calendar.current.component(.hour, from: now)
        let night = hourNow >= 22 || hourNow < 5
        let sheetPerks = StatPerks(currentAuthor.flatMap { state.sheets[$0] })
        var newTokens = 0
        var newRead = 0
        for day in days where day.tokens > 0 {
            let key = DayKey.string(from: day.day)
            var record = state.days[key] ?? WritingRecord(tokens: 0, characters: 0)
            // 읽기 토큰은 글자와 따로 센다. 처음 보는 날은 기준만 적는다.
            if let seen = record.read, day.read > seen, !baseline { newRead += day.read - seen }
            if record.read == nil || day.read > record.read! {
                record.read = day.read
                state.days[key] = record
                changed = true
            }
            guard day.tokens > record.tokens else { continue }
            let delta = day.tokens - record.tokens
            if !baseline && state.event == nil {
                let inspired = state.luck?.id == Lucks.inspiration.id ? Balance.inspirationMultiplier : 1
                let tired = Self.staminaEnabled && currentAuthor.flatMap { state.sheets[$0] }.map { $0.stamina < sheetPerks.staminaMax * Balance.staminaTiredBelow } == true
                let added = Double(delta) / 1_000_000 * Writing.charactersPerMillionTokens * (1 + perks.characterBonus) * inspired * live.characters
                    * weather.characters * (night ? studio.nightCharacters : 1) * sheetPerks.characters * (tired ? Balance.staminaTiredMultiplier : 1)
                record.characters += added
                let hour = Calendar.current.component(.hour, from: now)
                if hour >= 22 || hour < 5 { state.counters[Counter.nightCharacters.rawValue, default: 0] += Int(added) }
                if Self.staminaEnabled, let currentAuthor { wear(author: currentAuthor, tokens: delta, now: now) }
            }
            record.tokens = day.tokens
            state.days[key] = record
            if !baseline { newTokens += delta }
            if !baseline, state.event != nil, let i = state.openRecordIndex { state.eventLog[i].pausedTokens += delta }
            changed = true
        }
        if newRead > 0 {
            let gauge = state.inspiration
            state.inspiration = min(Balance.inspirationGaugeTokens, state.inspiration + Int(Double(newRead) * sheetPerks.inspiration))
            if gauge < Balance.inspirationGaugeTokens, state.inspiration >= Balance.inspirationGaugeTokens { state.inspirationNotified = false }
            changed = true
        }
        if newTokens > 0 {
            sell(tokens: newTokens, now: now)
            state.tokensTowardItem += newTokens
            let perItem = Int(Double(Balance.tokensPerItem) * perks.itemTokens * sheetPerks.itemTokens)
            while state.tokensTowardItem >= perItem {
                state.tokensTowardItem -= perItem
                giveRandomItem()
            }
            if persist { rollEvent(newTokens: newTokens, now: now, author: author) }
        }
        if changed { noteFinishes(since: finishedBefore, now: now) }
        // 내기와 독자 주문은 방금 더한 글자까지 세어 매긴다.
        if resolveBet(now: now) { changed = true }
        if checkOrder(now: now) { changed = true }
        noteWeek(now: now)
        if Self.stockEnabled, settleWeek(now: now) { changed = true }
        // 마감은 토큰이 없어도 본다. 주가 바뀌면 지난 과제를 매기고 새 과제를 내야 한다.
        if checkDeadline(now: now) { changed = true }
        if changed { save(now: now) }
        return WritingProgress(state: state, now: now)
    }

    // MARK: 마을

    /// 풀밭에 떨어진 물건을 줍는다. 하루에 한 번. 주운 아이템 이름을 돌려준다.
    @discardableResult
    func pickup(now: Date = Date()) -> ItemKind? {
        let today = DayKey.string(from: Calendar.current.startOfDay(for: now))
        guard state.pickupDay != today else { return nil }
        state.pickupDay = today
        guard let kind = giveRandomItem() else { save(now: now); return nil }
        state.counters[Counter.pickups.rawValue, default: 0] += 1
        state.note = EventNote(text: "풀밭에서 \(kind.title)(을|를) 주웠습니다".resolvedParticles, date: now, event: "pickup", kind: .shop, notified: true)
        save(now: now)
        return kind
    }

    /// 손님에게 책을 권한다. 하루 세 번까지. 진열창·매대 책 가운데 하나가 몇 부 팔리고 신뢰가 조금 오른다. 판 책과 부수를 돌려준다.
    @discardableResult
    func recommend(now: Date = Date()) -> (Book, Int)? {
        let today = DayKey.string(from: Calendar.current.startOfDay(for: now))
        if state.recommendDay != today { state.recommendDay = today; state.recommendCount = 0 }
        guard state.recommendCount < Balance.recommendPerDay else { return nil }
        let progress = WritingProgress(state: state, now: now)
        let shelf = progress.books(in: .window) + progress.books(in: .counter)
        guard !shelf.isEmpty else { return nil }
        let book = shelf[min(shelf.count - 1, Int(random() * Double(shelf.count)))]
        let copies = min(state.shop.stock(of: book.file), Balance.recommendCopies.lowerBound + Int(random() * Double(Balance.recommendCopies.upperBound - Balance.recommendCopies.lowerBound)))
        guard copies > 0 else { return nil }
        state.recommendCount += 1
        state.sales[book.file, default: 0] += Double(copies)
        state.salesByDay[today, default: 0] += Double(copies)
        if Self.stockEnabled {
            state.shop.stock[book.file, default: 0] -= Double(copies)
            state.shop.noteSold(book.file, copies: Double(copies), now: now)
            state.shop.adjustTrust(Balance.trustRecommend, reason: "손님에게 \(book.displayTitle)(을|를) 권해 팔았음".resolvedParticles, now: now)
            if state.shop.stock(of: book.file) <= 0 { soldOut(book.file, now: now) }
        }
        state.counters[Counter.recommendations.rawValue, default: 0] += 1
        state.note = EventNote(text: "권한 \(book.displayTitle)(을|를) 손님이 \(copies)부 사 갔습니다".resolvedParticles, date: now, event: "recommend", kind: .shop, notified: true)
        save(now: now)
        return (book, copies)
    }

    /// 살롱에서 작가에게 같이 쓰자고 청한다. 하루 한 번, 행운이 없을 때만. 매력이 높을수록 잘 응한다.
    /// 응하면 그 작가가 손님 작가로 온다. (응했는지, 한 줄)을 돌려준다. 오늘 이미 청했으면 nil.
    @discardableResult
    func invite(_ author: String, now: Date = Date()) -> (accepted: Bool, text: String)? {
        let today = DayKey.string(from: Calendar.current.startOfDay(for: now))
        guard state.inviteDay != today, state.luck == nil else { return nil }
        state.inviteDay = today
        let name = Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author
        let current = WritingProgress(state: state, now: now).book?.authorShort
        let charm = (current.flatMap { state.sheets[$0] } ?? AuthorSheet()).level(.charm)
        let chance = min(Balance.inviteMaxChance, Balance.inviteBaseChance + Double(charm) * Balance.inviteCharmBonus)
        state.counters[Counter.invites.rawValue, default: 0] += 1
        if random() < chance {
            grant(Lucks.guest, now: now, author: current, invited: author)
            return (true, "\(name)(이|가) 외투를 집어 듭니다. \"그럼 가 볼까요\" 작업실로 같이 갑니다".resolvedParticles)
        }
        save(now: now)
        let excuses = ["오늘은 여기가 좋소. 내일 다시 물어보시오", "지금 쓰는 게 있어서. 다음에", "커피를 다 마시고 나면 생각해 보지", "\(name)(은|는) 고개만 젓습니다"]
        return (false, excuses[min(excuses.count - 1, Int(random() * Double(excuses.count)))].resolvedParticles)
    }

    // MARK: 체력과 능력치

    /// 지금 작가의 능력치 배수.
    private func sheetPerks(now: Date) -> StatPerks {
        StatPerks((WritingProgress(state: state, now: now).book?.authorShort).flatMap { state.sheets[$0] })
    }

    /// 모든 작가의 체력이 시간만큼 돌아온다. 밤(22~5시)과 쉬는 동안(상황 중)은 두 배. 바뀐 게 있으면 true.
    private func recoverStamina(now: Date) -> Bool {
        var changed = false
        let hour = Calendar.current.component(.hour, from: now)
        let rate = Balance.staminaRecoveryPerHour * ((hour >= 22 || hour < 5) || state.event != nil ? 2 : 1)
        for (author, var sheet) in state.sheets {
            let cap = StatPerks(sheet).staminaMax
            guard sheet.stamina < cap else { continue }
            let hours = max(0, now.timeIntervalSince(sheet.staminaAt ?? now) / 3600)
            sheet.stamina = min(cap, sheet.stamina + hours * rate)
            sheet.staminaAt = now
            state.sheets[author] = sheet
            changed = true
        }
        return changed
    }

    /// 글을 쓴 만큼 체력이 줄고 능력치 토큰이 쌓인다. 0이 되면 탈진, 토큰이 차면 능력치 하나가 1 오른다.
    private func wear(author: String, tokens: Int, now: Date) {
        var sheet = state.sheets[author] ?? AuthorSheet()
        let perks = StatPerks(sheet)
        if sheet.staminaAt == nil { sheet.staminaAt = now }
        sheet.stamina -= Double(tokens) / 1_000_000 * Balance.staminaPerMillion * perks.staminaDrain
        sheet.tokensTowardStat += tokens
        let name = Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author
        while sheet.tokensTowardStat >= Balance.statTokens {
            sheet.tokensTowardStat -= Balance.statTokens
            let open = Stat.allCases.filter { sheet.level($0) < Balance.statMax }
            guard !open.isEmpty else { break }
            let stat = open[min(open.count - 1, Int(statRandom() * Double(open.count)))]
            sheet.stats[stat.rawValue] = sheet.level(stat) + 1
            state.counters[Counter.statUps.rawValue, default: 0] += 1
            state.note = EventNote(text: Format.resolve("\(name)의 \(stat.title)(이|가) \(sheet.level(stat))(이|가) 됐습니다. \(stat.raisedLine)"),
                                   date: now, event: stat.rawValue, kind: .stat, notified: true)
        }
        if sheet.stamina <= 0 {
            sheet.stamina = 0
            state.sheets[author] = sheet
            if state.event == nil {
                state.counters[Counter.exhaustions.rawValue, default: 0] += 1
                start(AuthorEvents.exhausted, now: now, author: author, minutes: Double(Balance.exhaustedMinutes))
            }
            return
        }
        state.sheets[author] = sheet
    }

    // MARK: 영감 게이지

    /// 게이지가 찼을 때 영감의 날을 켠다. 행운이 진행 중이면 그대로다.
    @discardableResult
    func igniteInspiration(now: Date = Date()) -> WritingProgress {
        guard state.inspiration >= Balance.inspirationGaugeTokens, state.luck == nil else { return WritingProgress(state: state) }
        state.inspiration = 0
        state.inspirationNotified = nil
        state.counters[Counter.ignitions.rawValue, default: 0] += 1
        grant(Lucks.inspiration, now: now)
        return WritingProgress(state: state)
    }

    /// 게이지가 찼는데 아직 알리지 않았으면 true. 알리고 나면 `markInspirationNotified`.
    var inspirationReadyUnnotified: Bool { state.inspiration >= Balance.inspirationGaugeTokens && state.inspirationNotified == false }

    func markInspirationNotified() {
        state.inspirationNotified = true
        save()
    }

    // MARK: 마감

    /// 이번 주 과제의 진행.
    func deadlineProgress(_ deadline: Deadline, now: Date) -> Int {
        switch deadline.kind {
        case .characters:
            return Int(state.days.reduce(0.0) { sum, pair in
                guard let date = DayKey.date(from: pair.key), date >= deadline.weekStart else { return sum }
                return sum + pair.value.net
            })
        case .finish:
            return WritingProgress(state: state, now: now).finished.count
        case .sales:
            return Int(state.salesByDay.reduce(0.0) { sum, pair in
                guard let date = DayKey.date(from: pair.key), date >= deadline.weekStart else { return sum }
                return sum + pair.value
            })
        }
    }

    /// 새 주면 지난 과제를 매기고 새 과제를 낸다. 진행 중인 과제가 목표에 닿으면 바로 지킨 것으로 적고 보상한다. 바뀐 게 있으면 true.
    /// 확인용 실행이 마감을 끌 때.
    nonisolated(unsafe) static var deadlinesEnabled = true
    /// 확인용 실행이 서점 사건과 독자 주문의 추첨을 끌 때. 직접 부르는 것(`happenInShop`, `offerOrder`)은 그대로 된다.
    nonisolated(unsafe) static var shopEnabled = true
    /// 확인용 실행이 체력과 능력치를 끌 때. 켜 두면 큰 토큰을 넣는 확인마다 탈진이 끼어든다.
    nonisolated(unsafe) static var staminaEnabled = true
    /// 확인용 실행이 재고·자리·신뢰·정산서를 끌 때. 켜 두면 판매가 재고에 막혀 다른 확인의 숫자가 달라진다.
    nonisolated(unsafe) static var stockEnabled = true
    /// 오르는 능력치를 고르는 주사위. 다른 추첨과 섞이지 않게 따로 둔다.
    var statRandom: () -> Double = { Double.random(in: 0..<1) }

    @discardableResult
    private func checkDeadline(now: Date) -> Bool {
        guard Self.deadlinesEnabled else { return false }
        let before = state.deadline
        let thisWeek = Self.weekStart(of: now)
        if let old = state.deadline, old.weekStart != thisWeek {
            if old.met != true, old.failed != true {
                state.deadline?.failed = true
                state.deadline?.resultNotified = false
                state.boosts.append(ActiveBoost(kind: .refusal, value: Balance.deadlinePenalty,
                                                endsAt: now.addingTimeInterval(TimeInterval(Balance.deadlinePenaltyHours) * 3600), source: "마감 펑크"))
                state.note = EventNote(text: Deadlines.failedLines[min(Deadlines.failedLines.count - 1, Int(random() * Double(Deadlines.failedLines.count)))],
                                       date: now, event: "deadline", kind: .deadline, notified: true)
                state.counters[Counter.deadlinesMissed.rawValue, default: 0] += 1
                state.weekly?.deadlineMet = false
            } else if old.met == true {
                state.weekly?.deadlineMet = true
            }
            // 매긴 결과는 알리고 나서 새 과제로 바꾼다. 알림 전이면 다음 반영 때.
            if state.deadline?.resultNotified == false { return state.deadline != before }
            state.deadline = nil
        }
        if state.deadline == nil, state.days.values.contains(where: { $0.characters > 0 }) {
            let progress = WritingProgress(state: state, now: now)
            let lastWeek = state.weekly.flatMap { $0.weekStart == thisWeek ? $0 : nil }
            let fallback = Int(progress.recentCharactersPerDay * 7)
            let remaining = progress.book.map { $0.characters - progress.charactersInBook } ?? 0
            state.deadline = Deadlines.assign(weekStart: thisWeek, lastWeekCharacters: lastWeek?.characters ?? fallback,
                                              lastWeekSales: lastWeek?.sales ?? 0, remainingInBook: remaining,
                                              finished: progress.finished.count, book: progress.book?.file, roll: random())
            state.deadline?.notified = false
        }
        guard let deadline = state.deadline, deadline.weekStart == thisWeek, deadline.met != true,
              deadlineProgress(deadline, now: now) >= deadline.target else { return state.deadline != before }
        state.deadline?.met = true
        state.deadline?.metAt = now
        state.deadline?.resultNotified = false
        for _ in 0..<Balance.deadlineItems { giveRandomItem() }
        state.boosts.append(ActiveBoost(kind: .sales, value: Balance.deadlineSalesBoost,
                                        endsAt: now.addingTimeInterval(TimeInterval(Balance.deadlineBoostHours) * 3600), source: "마감 사수"))
        state.note = EventNote(text: Deadlines.metLines[min(Deadlines.metLines.count - 1, Int(random() * Double(Deadlines.metLines.count)))],
                               date: now, event: "deadline", kind: .deadline, notified: true)
        state.counters[Counter.deadlinesMet.rawValue, default: 0] += 1
        return true
    }

    /// 알릴 마감: 새로 낸 과제이거나 결과(지킴·펑크)가 난 것.
    var unnotifiedDeadline: Deadline? {
        guard let d = state.deadline else { return nil }
        return d.notified == false || d.resultNotified == false ? d : nil
    }

    func markDeadlineNotified() {
        guard state.deadline != nil else { return }
        state.deadline?.notified = true
        if state.deadline?.resultNotified == false { state.deadline?.resultNotified = true }
        save()
    }

    /// 탈고한 책이 팔린다. 새 토큰 100만 개마다 책 한 권에 기본 `Balance.copiesPerMillion` 부.
    /// 탈고한 지 한 달 안은 신간이라 최대 3배, 손님 작가가 와 있으면 입소문으로 2배, 날마다 조금 흔들린다.
    private func sell(tokens: Int, now: Date) {
        let progress = WritingProgress(state: state, now: now)
        guard !progress.finished.isEmpty else { return }
        // 책마다 처음 탈고한 날.
        var firstFinish: [String: Date] = [:]
        for done in progress.finished {
            let file = Library.books[done.bookIndex].file
            if firstFinish[file] == nil { firstFinish[file] = done.date }
        }
        let millions = Double(tokens) / 1_000_000
        let guestBoost = state.luck?.id == Lucks.guest.id ? Balance.guestSalesMultiplier : 1
        let jitter = 0.8 + random() * 0.4
        let live = Boosts(state.boosts, now: now)
        var sold = 0.0
        let shelf = StudioPerks(owned: state.studio).sales
        for (file, date) in firstFinish {
            let days = max(0, now.timeIntervalSince(date) / 86_400)
            // 출판사에 따라 신간 기간과 신간 보정이 다르다. 안 골랐으면 대형으로 본다.
            let publisher = state.finishNotes.last { $0.book == file }?.publisher.flatMap(Publisher.init(rawValue:)) ?? .major
            let fresh = 1 + publisher.freshBoost * max(0, 1 - days / Double(publisher.freshDays))
            // 실린 비평이 있으면 별점대로 더 팔리거나 덜 팔린다.
            let reviewed = state.reviews.last { $0.book == file && $0.published == true }.map { Critics.salesMultiplier(for: $0.stars) } ?? 1
            // 서점: 자리에 따라 다르다(재고를 쓸 때). 아니면 이달의 책은 더, 나머지는 덜. 광고 중이거나 독자 주문대로 쓴 책은 더.
            let placed: Double
            if Self.stockEnabled {
                guard let slot = state.shop.slot(of: file, window: state.featuredBook) else { continue }
                placed = slot.sales
            } else {
                placed = state.featuredBook == nil ? 1 : (state.featuredBook == file ? Balance.featuredBoost : Balance.featuredOthers)
            }
            let featured = placed
            let advertised = (state.ads[file].map { $0 > now } ?? false) ? Balance.adBoost : 1
            let ordered = (state.orderBonus[file].map { $0 > now } ?? false) ? Balance.orderBoost : 1
            let shop = state.shopBoosts.filter { $0.endsAt > now && ($0.book == nil || $0.book == file) }.reduce(1.0) { $0 * $1.value }
            // 그 책 작가의 매력.
            let charm = StatPerks(Library.books.first { $0.file == file }.flatMap { state.sheets[$0.authorShort] }).sales
            var copies = millions * Balance.copiesPerMillion * fresh * guestBoost * jitter * live.sales * reviewed * Weather.of(now).sales * shelf
                * featured * advertised * ordered * shop * charm
            if Self.stockEnabled {
                // 창고에 없는 책은 못 판다. 빈손으로 간 손님은 놓친 것으로 센다.
                let have = state.shop.stock[file, default: 0]
                if copies > have {
                    state.shop.weekMissed[file, default: 0] += copies - have
                    copies = have
                }
                state.shop.stock[file] = have - copies
                if copies > 0 { state.shop.noteSold(file, copies: copies, now: now) }
                if have - copies <= 0.5, have > 0 { soldOut(file, now: now) }
            }
            let before = state.sales[file, default: 0]
            let after = before + copies
            state.sales[file] = after
            sold += copies
            let tier = SalesTier.of(copies: after)
            if tier > SalesTier.of(copies: before), tier != .none,
               !state.salesNews.contains(where: { $0.book == file && $0.tier == tier }) {
                state.salesNews.append(SalesNews(book: file, tier: tier, copies: Int(after), date: now))
            }
        }
        if state.salesNews.count > 20 { state.salesNews.removeFirst(state.salesNews.count - 20) }
        state.salesByDay[DayKey.string(from: Calendar.current.startOfDay(for: now)), default: 0] += sold
    }

    var unnotifiedSales: [SalesNews] { state.salesNews.filter { $0.notified != true } }

    func markSalesNotified(_ id: String) {
        guard let i = state.salesNews.firstIndex(where: { $0.id == id }) else { return }
        state.salesNews[i].notified = true
        save()
    }

    /// 새로 탈고한 작품마다 기록을 남긴다. 걸린 날수는 쓰기 시작한 날(앞 작품을 탈고한 날)부터다.
    private func noteFinishes(since before: Int, now: Date) {
        let progress = WritingProgress(state: state, now: now)
        guard progress.finished.count > before else { return }
        let calendar = Calendar.current
        for (i, done) in progress.finished.enumerated().dropFirst(before) {
            let book = Library.books[done.bookIndex]
            let start = i > 0 ? progress.finished[i - 1].date
                : (state.days.keys.sorted().first.flatMap(DayKey.date(from:)) ?? done.date)
            let days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: done.date)).day ?? 0) + 1
            let logs = state.eventLog.filter { $0.book == book.file && $0.startedAt >= start && $0.startedAt <= done.date.addingTimeInterval(86_400) }
            var note = FinishNote(book: book.file, round: done.round, date: now, days: days,
                                  events: logs.filter { $0.lostCharacters == nil && !$0.event.hasPrefix("luck.") }.count,
                                  lost: logs.compactMap(\.lostCharacters).reduce(0, +))
            note.publisherDue = now.addingTimeInterval(TimeInterval(Balance.publisherHours) * 3600)
            if !state.finishNotes.contains(where: { $0.id == note.id }) {
                state.finishNotes.append(note)
                review(note, book: book, now: now)
                if Self.stockEnabled { receive(book.file, copies: Balance.sampleRun, now: now, reason: nil) }
            }
        }
        if state.finishNotes.count > 5 { state.finishNotes.removeFirst(state.finishNotes.count - 5) }
    }

    // MARK: 비평

    /// 탈고하면 비평가가 글을 쓴다. 몇 시간에서 이틀 뒤에 실린다(`publishReviews`).
    /// 탈고하면 비평가가 글을 쓰기 시작한다. 별점과 글은 실릴 때 정한다. 그때까지 출판사를 고를 수 있어서다.
    private func review(_ note: FinishNote, book: Book, now: Date) {
        let critic = Critics.all[min(Critics.all.count - 1, Int(random() * Double(Critics.all.count)))]
        let hours = Balance.reviewHours.lowerBound + random() * (Balance.reviewHours.upperBound - Balance.reviewHours.lowerBound)
        var review = Review(book: book.file, round: note.round, critic: critic.name, stars: 0, text: "",
                            date: now.addingTimeInterval(hours * 3600))
        review.days = note.days; review.events = note.events; review.lost = note.lost
        guard !state.reviews.contains(where: { $0.id == review.id }) else { return }
        state.reviews.append(review)
        if state.reviews.count > WritingState.maxReviews { state.reviews.removeFirst(state.reviews.count - WritingState.maxReviews) }
    }

    /// 실릴 때가 된 비평을 싣는다. 지금 쓰는 작가의 책이면 작가가 영향을 받는다(하루 동안의 보정과 한 줄).
    @discardableResult
    private func publishReviews(now: Date) -> Bool {
        var changed = false
        let current = WritingProgress(state: state, now: now).book?.authorShort
        for i in state.reviews.indices where state.reviews[i].published != true && state.reviews[i].date <= now {
            if state.reviews[i].text.isEmpty, let book = Library.books.first(where: { $0.file == state.reviews[i].book }) {
                // 실리는 순간 별점을 정한다. 문예 출판사면 조금 후하다.
                let r = state.reviews[i]
                let publisher = state.finishNotes.first { $0.id == r.id }?.publisher.flatMap(Publisher.init(rawValue:)) ?? .major
                let critic = Critics.all.first { $0.name == r.critic } ?? Critics.all[0]
                let stars = Critics.stars(days: r.days ?? 7, events: r.events ?? 0, lost: r.lost ?? 0, characters: book.characters,
                                          roll: random(), bonus: publisher.starsBonus + StatPerks(state.sheets[book.authorShort]).reviewBonus)
                state.reviews[i].stars = stars
                state.reviews[i].text = Critics.text(for: stars, days: r.days ?? 7, events: r.events ?? 0, lost: r.lost ?? 0, title: book.displayTitle,
                                                     author: book.displayAuthorShort, voice: critic.voice, rolls: (0..<12).map { _ in random() })
            }
            state.reviews[i].published = true
            changed = true
            guard let book = Library.books.first(where: { $0.file == state.reviews[i].book }), book.authorShort == current else { continue }
            let stars = state.reviews[i].stars
            state.reviews[i].affected = true
            state.boosts += Critics.boosts(for: stars, now: now)
            state.note = EventNote(text: Critics.authorLine(stars: stars, roll: random()), date: now, event: state.reviews[i].id, kind: .review, notified: true)
            if stars <= 2 { state.counters[Counter.panned.rawValue, default: 0] += 1 }
        }
        return changed
    }

    /// 확인용 실행에서 비평을 바로 싣는다.
    func publishReviewsForTesting(now: Date) {
        publishReviews(now: now)
        save(now: now)
    }

    var unnotifiedReviews: [Review] { state.reviews.filter { $0.published == true && $0.notified != true } }

    func markReviewNotified(_ id: String) {
        guard let i = state.reviews.firstIndex(where: { $0.id == id }) else { return }
        state.reviews[i].notified = true
        save()
    }

    // MARK: 출판사

    /// 탈고한 원고를 보낼 곳을 고른다. 대형이면 선금 아이템을 바로 준다.
    @discardableResult
    func choosePublisher(_ publisher: Publisher, for noteID: String, now: Date = Date()) -> WritingProgress {
        guard let i = state.finishNotes.firstIndex(where: { $0.id == noteID }), state.finishNotes[i].publisher == nil else {
            return WritingProgress(state: state, now: now)
        }
        state.finishNotes[i].publisher = publisher.rawValue
        for _ in 0..<publisher.advance { giveRandomItem() }
        state.counters[Counter.publishers.rawValue + "." + publisher.rawValue] = 1
        state.note = EventNote(text: publisher.line, date: now, event: noteID, kind: .publisher, notified: true)
        if Self.stockEnabled { receive(state.finishNotes[i].book, copies: publisher.firstRun, now: now, reason: nil) }
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    /// 하루 안에 안 고른 원고는 대형 출판사로 간다.
    private func settleUnchosenPublishers(now: Date) -> Bool {
        var changed = false
        for i in state.finishNotes.indices where state.finishNotes[i].publisher == nil {
            // 옛 기록(기한 없음)은 대형으로 조용히.
            guard let due = state.finishNotes[i].publisherDue else { state.finishNotes[i].publisher = Publisher.major.rawValue; changed = true; continue }
            guard now >= due else { continue }
            state.finishNotes[i].publisher = Publisher.major.rawValue
            for _ in 0..<Publisher.major.advance { giveRandomItem() }
            state.counters[Counter.publishers.rawValue + "." + Publisher.major.rawValue] = 1
            state.note = EventNote(text: "답이 없어 원고가 대형 출판사로 갔습니다. 선금이 왔습니다", date: now, event: state.finishNotes[i].id, kind: .publisher, notified: true)
            if Self.stockEnabled { receive(state.finishNotes[i].book, copies: Publisher.major.firstRun, now: now, reason: nil) }
            changed = true
        }
        return changed
    }

    // MARK: 작업실

    /// 가구를 산다. 아이템이 모자라거나 이미 있으면 그대로다.
    @discardableResult
    func buy(_ furniture: Furniture, now: Date = Date()) -> WritingProgress {
        guard !state.studio.contains(furniture.id), Studio.canAfford(furniture, items: state.items) else { return WritingProgress(state: state, now: now) }
        for (kind, n) in furniture.cost { state.items[kind.rawValue, default: 0] -= n }
        state.studio.append(furniture.id)
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    // MARK: 내기

    /// 손님 작가가 내기를 건다. 손님이 없거나, 이번 손님 때 이미 걸었거나, 손님이 곧 가면 걸지 않는다.
    @discardableResult
    func offerBet(now: Date = Date()) -> Bool {
        guard let luck = state.luck, luck.id == Lucks.guest.id, let guest = luck.guest, luck.endsAt > now.addingTimeInterval(30 * 60) else { return false }
        if let bet = state.bet, bet.offeredAt >= luck.startedAt { return false }
        let progress = WritingProgress(state: state, now: now)
        let hours = luck.endsAt.timeIntervalSince(now) / 3600
        let target = Bets.target(charactersPerDay: max(progress.recentCharactersPerDay, 5_000), hours: hours)
        state.bet = ActiveBet(guest: guest, target: target, offeredAt: now, endsAt: luck.endsAt)
        state.note = EventNote(text: Bets.text(Bets.offers, guest: guest, target: target, roll: random()), date: now, event: "bet", kind: .bet, notified: false)
        save(now: now)
        return true
    }

    /// 내기를 받거나 사양한다.
    @discardableResult
    func answerBet(accept: Bool, now: Date = Date()) -> WritingProgress {
        guard var bet = state.bet, bet.pending else { return WritingProgress(state: state, now: now) }
        if accept {
            bet.accepted = true
            bet.startCharacters = WritingProgress(state: state, now: now).totalCharacters
            state.bet = bet
        } else {
            bet.accepted = false
            bet.won = nil
            bet.resolvedAt = now
            state.bet = bet
            state.note = EventNote(text: Bets.text(Bets.declined, guest: bet.guest, target: bet.target, roll: random()), date: now, event: "bet", kind: .bet, notified: true)
        }
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    /// 받은 내기가 끝났으면 매긴다. 안 받은 채 손님이 갔으면 조용히 지운다.
    private func resolveBet(now: Date) -> Bool {
        guard var bet = state.bet else { return false }
        if bet.pending, now >= bet.endsAt {
            bet.accepted = false; bet.resolvedAt = now; state.bet = bet
            return true
        }
        guard bet.running, let start = bet.startCharacters else { return false }
        let written = WritingProgress(state: state, now: now).totalCharacters - start
        guard written >= Double(bet.target) || now >= bet.endsAt else { return false }
        let won = written >= Double(bet.target)
        bet.won = won
        bet.resolvedAt = now
        state.bet = bet
        if won {
            for _ in 0..<Balance.betWinItems { giveRandomItem() }
            state.boosts.append(ActiveBoost(kind: .sales, value: Balance.betSalesBoost, endsAt: now.addingTimeInterval(TimeInterval(Balance.betBoostHours) * 3600), source: "내기"))
            state.counters[Counter.betsWon.rawValue, default: 0] += 1
        } else {
            for _ in 0..<Balance.betLoseItems {
                let held = ItemKind.allCases.filter { state.items[$0.rawValue, default: 0] > 0 }
                guard !held.isEmpty else { break }
                state.items[held[min(held.count - 1, Int(random() * Double(held.count)))].rawValue, default: 0] -= 1
            }
            state.counters[Counter.betsLost.rawValue, default: 0] += 1
        }
        state.note = EventNote(text: Bets.text(won ? Bets.won : Bets.lost, guest: bet.guest, target: bet.target, roll: random()), date: now, event: "bet", kind: .bet, notified: false)
        return true
    }

    // MARK: 서점

    /// 이달의 책을 고른다. 하루에 한 번. 같은 책을 다시 고르면 내린다.
    @discardableResult
    func feature(_ file: String?, now: Date = Date()) -> WritingProgress {
        if Self.stockEnabled {
            if let file { return place(file, .window, now: now) }
            if let current = state.featuredBook { return place(current, .shelf, now: now) }
            return WritingProgress(state: state, now: now)
        }
        if let at = state.featuredAt, state.featuredBook != nil, now.timeIntervalSince(at) < TimeInterval(Balance.featuredHours) * 3600 {
            return WritingProgress(state: state, now: now)
        }
        state.featuredBook = file
        state.featuredAt = file == nil ? nil : now
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    // MARK: 서점 운영

    /// 책을 자리에 둔다. 진열창은 신뢰가 있어야 하고 하루에 한 번만 바꾼다. 매대가 차 있으면 주인이 고른 책 가운데 가장 덜 팔리는 것을 내린다.
    /// 서가로 보내면 이레 동안 주인이 다시 올리지 않는다. 직접 고른 자리는 이레 동안 그대로다.
    @discardableResult
    func place(_ file: String, _ slot: ShopSlot, now: Date = Date()) -> WritingProgress {
        guard state.shop.stock(of: file) > 0 || slot == .shelf else { return WritingProgress(state: state, now: now) }
        switch slot {
        case .window:
            guard state.shop.level.hasWindow, state.featuredBook != file,
                  state.featuredAt.map({ now.timeIntervalSince($0) >= TimeInterval(Balance.featuredHours) * 3600 }) ?? true
            else { return WritingProgress(state: state, now: now) }
            if let old = state.featuredBook { state.shop.pinned[old] = nil }
            state.featuredBook = file
            state.featuredAt = now
            state.shop.counter.removeAll { $0 == file }
            state.shop.pinned[file] = now
            state.shop.benched[file] = nil
            state.shop.placedAt[file] = now
        case .counter:
            if !state.shop.counter.contains(file) {
                if state.shop.counter.count >= state.shop.level.counterSlots {
                    let loose = state.shop.counter.filter { state.shop.pinned[$0] == nil }
                    guard let drop = loose.min(by: { Shopkeeper.score($0, state: state, now: now) < Shopkeeper.score($1, state: state, now: now) })
                    else { return WritingProgress(state: state, now: now) }
                    state.shop.counter.removeAll { $0 == drop }
                    state.shop.placedAt[drop] = nil
                }
                if state.featuredBook == file { state.featuredBook = nil; state.featuredAt = nil }
                state.shop.counter.append(file)
                state.shop.placedAt[file] = now
            }
            state.shop.pinned[file] = now
            state.shop.benched[file] = nil
        case .shelf:
            if state.featuredBook == file { state.featuredBook = nil; state.featuredAt = nil }
            state.shop.counter.removeAll { $0 == file }
            state.shop.pinned[file] = nil
            state.shop.placedAt[file] = nil
            state.shop.benched[file] = now
        case .storage: break
        }
        _ = arrange(now: now, morning: false)
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    /// 직접 정한 것을 거두고 주인에게 맡긴다.
    @discardableResult
    func leaveToKeeper(_ file: String, now: Date = Date()) -> WritingProgress {
        state.shop.pinned[file] = nil
        state.shop.benched[file] = nil
        _ = arrange(now: now, morning: false)
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    /// 확인용 실행에서 재고를 바로 정한다.
    func setStockForTesting(_ file: String, copies: Int) { state.shop.stock[file] = Double(copies) }

    func dismissStatement(_ id: String) {
        guard let i = state.shop.statements.firstIndex(where: { $0.id == id }) else { return }
        state.shop.statements[i].dismissed = true
        save()
    }

    var unnotifiedStatement: Statement? { state.shop.statements.last.flatMap { $0.notified != true ? $0 : nil } }

    func markStatementNotified(_ id: String) {
        guard let i = state.shop.statements.firstIndex(where: { $0.id == id }) else { return }
        state.shop.statements[i].notified = true
        save()
    }

    var unnotifiedStockNews: [StockNews] { state.shop.stockNews.filter { $0.notified != true } }

    func markStockNotified(_ id: String) {
        guard let i = state.shop.stockNews.firstIndex(where: { $0.id == id }) else { return }
        state.shop.stockNews[i].notified = true
        save()
    }

    /// 재고가 들어온다. 탈고 직후 견본, 출판사를 고른 뒤 초판, 재판. `reason` 이 있으면 한 줄 남긴다.
    private func receive(_ file: String, copies: Int, now: Date, reason: String?) {
        state.shop.stock[file, default: 0] += Double(copies)
        state.shop.reprints[file] = nil
        if let reason, let book = Library.books.first(where: { $0.file == file }) {
            state.shop.stockNews.append(StockNews(book: file, kind: .restocked, copies: copies, due: nil, date: now))
            state.note = EventNote(text: "\(book.displayTitle) \(reason) \(Format.integer(copies))부가 들어왔습니다", date: now, event: "restock", kind: .shop, notified: true)
            state.counters[Counter.reprints.rawValue, default: 0] += 1
        }
        if state.shop.stockNews.count > 20 { state.shop.stockNews.removeFirst(state.shop.stockNews.count - 20) }
        _ = arrange(now: now, morning: false)
    }

    /// 재고가 떨어졌다. 출판사에 재판을 청하고(지난 7일 판매의 1.5배, 초판의 0.5~4배 사이), 매대에 있던 책이면 신뢰가 깎인다.
    private func soldOut(_ file: String, now: Date) {
        guard state.shop.reprints[file] == nil, let book = Library.books.first(where: { $0.file == file }) else { return }
        let publisher = state.finishNotes.last { $0.book == file }?.publisher.flatMap(Publisher.init(rawValue:)) ?? .major
        let weekly = state.shop.sold(file, days: 7, now: now)
        let copies = Int(min(max(weekly * Balance.reprintWeeks, Double(publisher.firstRun) * Balance.reprintMinRatio), Double(publisher.firstRun) * Balance.reprintMaxRatio))
        let hours = publisher.reprintHours * state.shop.level.reprintSpeed
        let due = now.addingTimeInterval(hours * 3600)
        state.shop.reprints[file] = ShopState.Reprint(due: due, copies: copies, orderedAt: now)
        state.shop.stock[file] = 0
        if state.featuredBook == file || state.shop.counter.contains(file) {
            state.shop.adjustTrust(Balance.trustSoldOut, reason: "\(book.displayTitle) 품절로 손님을 돌려보냄", now: now)
        }
        state.shop.stockNews.append(StockNews(book: file, kind: .soldOut, copies: copies, due: due, date: now))
        if state.shop.stockNews.count > 20 { state.shop.stockNews.removeFirst(state.shop.stockNews.count - 20) }
        state.note = EventNote(text: "\(book.displayTitle)(이|가) 품절됐습니다. 재판 \(Format.integer(copies))부가 \(Int(hours.rounded()))시간 뒤에 들어옵니다".resolvedParticles,
                               date: now, event: "soldout", kind: .shop, notified: true)
        state.counters[Counter.soldOuts.rawValue, default: 0] += 1
        _ = arrange(now: now, morning: false)
    }

    /// 매번 반영할 때 서점을 돌본다. 옛 기록엔 재고를 채우고, 들어온 재판을 받고, 아침이면 주인이 자리를 정리한다.
    private func tendShop(now: Date) -> Bool {
        var changed = false
        let finished = Set(WritingProgress(state: state, now: now).finished.map { Library.books[$0.bookIndex].file })
        if !state.shop.migrated {
            for file in finished where state.shop.stock[file] == nil {
                let publisher = state.finishNotes.last { $0.book == file }?.publisher.flatMap(Publisher.init(rawValue:)) ?? .major
                state.shop.stock[file] = Double(publisher.firstRun)
            }
            state.shop.migrated = true
            changed = true
        }
        if state.shop.weekTrustStart == nil, !finished.isEmpty { state.shop.weekTrustStart = state.shop.trust; changed = true }
        if state.shop.trackedSince == nil, !finished.isEmpty { state.shop.trackedSince = now; changed = true }
        for (file, reprint) in state.shop.reprints where reprint.due <= now {
            receive(file, copies: reprint.copies, now: now, reason: "재판")
            changed = true
        }
        let calendar = Calendar.current
        let morning = state.shop.arrangedAt.map { !calendar.isDate($0, inSameDayAs: now) && calendar.component(.hour, from: now) >= Balance.arrangeHour } ?? true
        if !finished.isEmpty, arrange(now: now, morning: morning) { changed = true }
        return changed
    }

    /// 주인이 자리를 정한다. `morning` 이면 직접 고른 책만 두고 다시 고르고, 아니면 빈 자리만 채운다. 바뀐 게 있으면 true.
    @discardableResult
    private func arrange(now: Date, morning: Bool) -> Bool {
        guard Self.stockEnabled else { return false }
        var shop = state.shop
        let level = shop.level
        let pinLife = TimeInterval(Balance.pinDays) * 86_400
        shop.pinned = shop.pinned.filter { now.timeIntervalSince($0.value) < pinLife }
        shop.benched = shop.benched.filter { now.timeIntervalSince($0.value) < pinLife }
        let finished = Set(WritingProgress(state: state, now: now).finished.map { Library.books[$0.bookIndex].file })
        let inStock = finished.filter { shop.stock(of: $0) > 0 }
        var window = state.featuredBook
        if let w = window, !inStock.contains(w) || !level.hasWindow { window = nil; shop.pinned[w] = nil }
        shop.counter = shop.counter.filter { inStock.contains($0) && $0 != window }
        if morning, let w = window, shop.pinned[w] == nil { window = nil }
        if morning { shop.counter = shop.counter.filter { shop.pinned[$0] != nil } }
        var scores: [String: Double] = [:]
        for file in inStock { scores[file] = Shopkeeper.score(file, state: state, now: now) }
        func ranked(_ pool: Set<String>) -> [String] {
            pool.sorted { (scores[$0] ?? 0, $1) > (scores[$1] ?? 0, $0) }
        }
        var pool = ranked(inStock.filter { $0 != window && !shop.counter.contains($0) && shop.benched[$0] == nil })
        if window == nil, level.hasWindow, let best = pool.first {
            window = best
            pool.removeFirst()
            if state.featuredBook != best { state.featuredAt = nil }
        }
        while shop.counter.count > level.counterSlots,
              let drop = shop.counter.filter({ shop.pinned[$0] == nil }).min(by: { (scores[$0] ?? 0) < (scores[$1] ?? 0) }) {
            shop.counter.removeAll { $0 == drop }
        }
        while shop.counter.count < level.counterSlots, !pool.isEmpty {
            shop.counter.append(pool.removeFirst())
        }
        let placed = Set(shop.counter + [window].compactMap { $0 })
        for file in placed where shop.placedAt[file] == nil { shop.placedAt[file] = now }
        shop.placedAt = shop.placedAt.filter { placed.contains($0.key) }
        if morning { shop.arrangedAt = now }
        let changed = window != state.featuredBook || shop.counter != state.shop.counter
        state.featuredBook = window
        if window == nil { state.featuredAt = nil }
        let before = state.shop
        state.shop = shop
        if morning, changed, !shop.counter.isEmpty {
            let names = ([window].compactMap { $0 } + shop.counter).compactMap { f in Library.books.first { $0.file == f }?.displayTitle }
            state.note = EventNote(text: "주인이 아침에 매대를 다시 꾸렸습니다. " + names.joined(separator: " · "), date: now, event: "arrange", kind: .shop, notified: true)
        }
        return changed || before != shop
    }

    /// 월요일 정산서. 지난주 책별 판매·반품·놓친 손님·남은 재고와 신뢰 변화, 주인의 한마디. 주간 합은 비운다.
    private func settleWeek(now: Date) -> Bool {
        let thisWeek = Self.weekStart(of: now)
        guard let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: thisWeek),
              state.shop.statements.last.map({ $0.weekStart < lastWeek }) ?? true,
              let startTrust = state.shop.weekTrustStart,
              (state.shop.trackedSince ?? now) < thisWeek else { return false }
        let progress = WritingProgress(state: state, now: now)
        let finished = Array(Set(progress.finished.map { Library.books[$0.bookIndex].file }))
        guard !finished.isEmpty else { return false }
        let sold = Int(state.shop.weekSold.values.reduce(0, +))
        let missed = Int(state.shop.weekMissed.values.reduce(0, +))
        let returned = Int(state.shop.weekReturned.values.reduce(0, +))
        if sold + missed == 0 {
            state.shop.adjustTrust(Balance.trustWeekQuiet, reason: "한 주 내내 손님이 없음", now: now)
        } else if Double(missed) / Double(sold + missed) > 0.3 {
            state.shop.adjustTrust(Balance.trustWeekBad, reason: "품절로 돌려보낸 손님이 많음", now: now)
        } else if Double(missed) / Double(sold + missed) < 0.05, sold > 0 {
            state.shop.adjustTrust(Balance.trustWeekGood, reason: "한 주 내내 손님이 끊이지 않음", now: now)
        }
        let lines = finished.map { file in
            StatementLine(book: file, sold: Int(state.shop.weekSold[file] ?? 0), returned: Int(state.shop.weekReturned[file] ?? 0),
                          missed: Int(state.shop.weekMissed[file] ?? 0), stock: state.shop.stock(of: file),
                          slot: state.shop.slot(of: file, window: state.featuredBook) ?? .storage)
        }.sorted { ($0.sold, $0.book) > ($1.sold, $1.book) }
        let reasons = state.shop.trustLog.filter { $0.date >= lastWeek }.sorted { abs($0.delta) > abs($1.delta) }.prefix(3)
            .map { "\($0.reason) (\($0.delta > 0 ? "+" : "")\(Int($0.delta.rounded())))" }
        let delta = state.shop.trust - startTrust
        state.shop.statements.append(Statement(weekStart: lastWeek, lines: lines, sold: sold, returned: returned, missed: missed,
                                               trustBefore: startTrust, trustAfter: state.shop.trust, reasons: Array(reasons),
                                               keeperLine: Shopkeeper.line(sold: sold, missed: missed, returned: returned, trustDelta: delta)))
        if state.shop.statements.count > 8 { state.shop.statements.removeFirst(state.shop.statements.count - 8) }
        state.shop.weekSold = [:]
        state.shop.weekMissed = [:]
        state.shop.weekReturned = [:]
        state.shop.weekTrustStart = state.shop.trust
        state.counters[Counter.statements.rawValue, default: 0] += 1
        return true
    }

    /// 광고를 건다. 아이템이 모자라거나 이미 광고 중이면 그대로다.
    @discardableResult
    func advertise(_ file: String, now: Date = Date()) -> WritingProgress {
        guard Balance.adCost.allSatisfy({ state.items[$0.0.rawValue, default: 0] >= $0.1 }),
              (state.ads[file].map { $0 <= now } ?? true),
              !Self.stockEnabled || state.shop.stock(of: file) > 0 else { return WritingProgress(state: state, now: now) }
        for (kind, n) in Balance.adCost { state.items[kind.rawValue, default: 0] -= n }
        state.ads[file] = now.addingTimeInterval(TimeInterval(Balance.adHours) * 3600)
        state.counters[Counter.ads.rawValue, default: 0] += 1
        if Self.stockEnabled {
            state.shop.adjustTrust(Balance.trustAd, reason: "광고로 손님을 불러옴", now: now)
            _ = arrange(now: now, morning: false)
        }
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    /// 서점 사건을 하나 일으킨다. 탈고한 책이 없으면 아무 일도 없다. 확인용 실행에서 직접 부르기도 한다.
    @discardableResult
    func happenInShop(_ forced: ShopEvent? = nil, now: Date = Date()) -> ShopRecord? {
        let progress = WritingProgress(state: state, now: now)
        let done = Array(Set(progress.finished.map(\.bookIndex))).sorted()
        guard !done.isEmpty else { return nil }
        let praised = done.filter { (progress.review(of: Library.books[$0])?.stars ?? 0) >= 4 }
        let event = forced ?? ShopEvents.pick(roll: random(), context: .now(now, hasPraised: !praised.isEmpty, books: done.count))
        var candidates = event.praisedOnly ? praised : done
        // 재고를 쓸 때는 창고가 빈 책에 손님이 몰려도 소용없다. 재고 있는 책 가운데 고른다.
        if Self.stockEnabled {
            let stocked = candidates.filter { state.shop.stock(of: Library.books[$0].file) > 0 }
            if !stocked.isEmpty { candidates = stocked }
        }
        let book = event.scope == .book ? Library.books[candidates[min(candidates.count - 1, Int(random() * Double(candidates.count)))]] : nil
        var copies: Int?
        switch event.effect {
        case .sales(let value, let hours):
            state.shopBoosts.append(ShopBoost(book: book?.file, value: value, endsAt: now.addingTimeInterval(Double(hours) * 3600), source: event.title))
            // 인쇄소가 밀리면 재판도 늦는다.
            if Self.stockEnabled, event.id == "misprint", let book, let reprint = state.shop.reprints[book.file] {
                state.shop.reprints[book.file] = ShopState.Reprint(due: reprint.due.addingTimeInterval(Double(hours) * 3600), copies: reprint.copies, orderedAt: reprint.orderedAt)
            }
        case .copies(let low, let high):
            var n = low + Int(random() * Double(high - low))
            if let book {
                if Self.stockEnabled {
                    n = min(n, state.shop.stock(of: book.file))
                    state.shop.stock[book.file, default: 0] -= Double(n)
                    state.shop.noteSold(book.file, copies: Double(n), now: now)
                    if state.shop.stock(of: book.file) <= 0 { soldOut(book.file, now: now) }
                }
                state.sales[book.file, default: 0] += Double(n)
                state.salesByDay[DayKey.string(from: Calendar.current.startOfDay(for: now)), default: 0] += Double(n)
            }
            copies = n
        case .restock(let low, let high):
            let n = low + Int(random() * Double(high - low))
            copies = n
            if let book, Self.stockEnabled {
                state.shop.stock[book.file, default: 0] += Double(n)
                _ = arrange(now: now, morning: false)
            } else if let book {
                state.sales[book.file, default: 0] += Double(n)
            }
        case .returned(let low, let high):
            let n = low + Int(random() * Double(high - low))
            if let book {
                let lost = min(n, Int(state.sales[book.file, default: 0]))
                copies = -lost
                state.sales[book.file, default: 0] -= Double(lost)
                let key = DayKey.string(from: Calendar.current.startOfDay(for: now))
                state.salesByDay[key] = max(0, state.salesByDay[key, default: 0] - Double(lost))
                if Self.stockEnabled {
                    // 반품은 창고로 돌아온다. 젖은 책과 쥐가 갉은 책은 못 쓴다.
                    if event.id == "returns" { state.shop.stock[book.file, default: 0] += Double(lost) }
                    state.shop.weekReturned[book.file, default: 0] += Double(lost)
                    state.shop.adjustTrust(Balance.trustReturns, reason: "\(book.displayTitle) \(lost)부 반품", now: now)
                }
            }
        case .inspiration(let fraction):
            let before = state.inspiration
            state.inspiration = min(Balance.inspirationGaugeTokens, state.inspiration + Int(Double(Balance.inspirationGaugeTokens) * fraction))
            if before < Balance.inspirationGaugeTokens, state.inspiration >= Balance.inspirationGaugeTokens { state.inspirationNotified = false }
        case .feature:
            let busy = state.featuredAt.map { state.featuredBook != nil && now.timeIntervalSince($0) < TimeInterval(Balance.featuredHours) * 3600 } ?? false
            let pinned = Self.stockEnabled && state.featuredBook.map { state.shop.pinned[$0] != nil } == true
            let allowed = !Self.stockEnabled || (state.shop.level.hasWindow && !pinned)
            if let book, !busy, allowed {
                if Self.stockEnabled {
                    if let old = state.featuredBook { state.shop.pinned[old] = nil }
                    state.shop.counter.removeAll { $0 == book.file }
                    state.shop.placedAt[book.file] = now
                }
                state.featuredBook = book.file
                state.featuredAt = Self.stockEnabled ? nil : now
                if Self.stockEnabled { _ = arrange(now: now, morning: false) }
            } else {
                state.shopBoosts.append(ShopBoost(book: book?.file, value: 1.2, endsAt: now.addingTimeInterval(6 * 3600), source: event.title))
            }
        case .order:
            _ = offerOrder(now: now)
        case .items(let n) where n > 0:
            for _ in 0..<n { giveRandomItem() }
        case .items(let n):
            for _ in 0..<(-n) {
                let held = ItemKind.allCases.filter { state.items[$0.rawValue, default: 0] > 0 }
                guard !held.isEmpty else { break }
                state.items[held[min(held.count - 1, Int(random() * Double(held.count)))].rawValue, default: 0] -= 1
            }
        case .none: break
        }
        var text = event.texts[min(event.texts.count - 1, Int(random() * Double(event.texts.count)))]
        text = text.replacingOccurrences(of: "{T}", with: book?.displayTitle ?? "").replacingOccurrences(of: "{A}", with: book?.displayAuthorShort ?? "")
            .replacingOccurrences(of: "{N}", with: Format.integer(abs(copies ?? 0)))
        text = Format.resolve(text)
        if Self.stockEnabled, ["reading", "signing", "tea", "club", "portrait"].contains(event.id) {
            state.shop.adjustTrust(Balance.trustGathering, reason: "\(event.title)(이|가) 잘 끝남".resolvedParticles, now: now)
        }
        let record = ShopRecord(event: event.id, book: book?.file, text: text, date: now, copies: copies)
        state.shopLog.append(record)
        if state.shopLog.count > 20 { state.shopLog.removeFirst(state.shopLog.count - 20) }
        state.note = EventNote(text: text, date: now, event: event.id, kind: .shop, notified: true)
        state.counters[Counter.shopEvents.rawValue, default: 0] += 1
        save(now: now)
        return record
    }

    /// 독자가 아직 안 쓴 책 하나를 청한다. 지금 쓰는 책과 바로 다음 책은 빼고, 되도록 다른 작가의 책을.
    @discardableResult
    func offerOrder(now: Date = Date()) -> Bool {
        guard state.order == nil else { return false }
        let progress = WritingProgress(state: state, now: now)
        let pending = Array(progress.pendingInRound.dropFirst())
        guard !pending.isEmpty else { return false }
        let others = pending.filter { Library.books[$0].authorShort != progress.book?.authorShort }
        let pool = others.isEmpty ? pending : others
        let index = pool[min(pool.count - 1, Int(random() * Double(pool.count)))]
        let book = Library.books[index]
        let text = ReaderOrders.text(ReaderOrders.lines, book: book, roll: random())
        state.order = ReaderOrder(book: book.file, offeredAt: now, expiresAt: now.addingTimeInterval(TimeInterval(Balance.orderDays) * 86_400), text: text)
        state.note = EventNote(text: text, date: now, event: "order", kind: .order, notified: false)
        save(now: now)
        return true
    }

    /// 주문한 책을 쓰기 시작했으면 채운 것으로, 기한이 지났으면 지운다.
    private func checkOrder(now: Date) -> Bool {
        guard let order = state.order, order.fulfilled == nil else {
            if let order = state.order, order.fulfilled == true, now.timeIntervalSince(order.offeredAt) > 86_400 * 8 { state.order = nil; return true }
            return false
        }
        if now >= order.expiresAt {
            state.order = nil
            if Self.stockEnabled { state.shop.adjustTrust(Balance.trustOrderMissed, reason: "독자 주문을 기한 안에 못 씀", now: now) }
            return true
        }
        let progress = WritingProgress(state: state, now: now)
        guard progress.book?.file == order.book, let book = progress.book else { return false }
        state.order?.fulfilled = true
        if Self.stockEnabled { state.shop.adjustTrust(Balance.trustOrderKept, reason: "독자 주문대로 \(book.displayTitle)을 씀", now: now) }
        state.orderBonus[order.book] = now.addingTimeInterval(TimeInterval(Balance.freshDays) * 86_400)
        state.counters[Counter.ordersFilled.rawValue, default: 0] += 1
        state.note = EventNote(text: ReaderOrders.text(ReaderOrders.filled, book: book, roll: random()), date: now, event: "order", kind: .order, notified: true)
        return true
    }

    // MARK: 선택지가 있는 사건

    /// 사건을 낸다. 확인용 실행에서 직접 부르기도 한다.
    func offer(_ dilemma: Dilemma, now: Date = Date()) {
        guard state.dilemma == nil else { return }
        let text = dilemma.texts[min(dilemma.texts.count - 1, Int(random() * Double(dilemma.texts.count)))]
        state.dilemma = ActiveDilemma(id: dilemma.id, text: text, startedAt: now,
                                      expiresAt: now.addingTimeInterval(Double(dilemma.minutes) * 60))
        save(now: now)
    }

    /// 사건에 답한다. 효과(보정·아이템)를 붙이고 결과 한 줄을 남긴다. `auto` 는 시간이 지나 작가가 알아서 고른 것.
    @discardableResult
    func choose(_ index: Int, now: Date = Date(), auto: Bool = false) -> WritingProgress {
        guard let pending = state.dilemma, let dilemma = Dilemmas.byID(pending.id), dilemma.options.indices.contains(index) else {
            return WritingProgress(state: state)
        }
        let option = dilemma.options[index]
        state.dilemma = nil
        for (kind, value, seconds) in option.boosts {
            state.boosts.append(ActiveBoost(kind: kind, value: value, endsAt: now.addingTimeInterval(seconds), source: dilemma.title))
        }
        if option.items > 0 {
            for _ in 0..<option.items { giveRandomItem() }
        } else if option.items < 0 {
            for _ in 0..<(-option.items) {
                let held = ItemKind.allCases.filter { state.items[$0.rawValue, default: 0] > 0 }
                guard !held.isEmpty else { break }
                state.items[held[min(held.count - 1, Int(random() * Double(held.count)))].rawValue, default: 0] -= 1
            }
        }
        let outcome = option.outcomes[min(option.outcomes.count - 1, Int(random() * Double(option.outcomes.count)))]
        state.dilemmaLog.append(DilemmaRecord(dilemma: dilemma.id, option: option.label, outcome: outcome, date: now, auto: auto ? true : nil))
        if state.dilemmaLog.count > 30 { state.dilemmaLog.removeFirst(state.dilemmaLog.count - 30) }
        // 작가가 알아서 고른 것은 알린다. 직접 고른 것은 화면에서 봤으니 알리지 않는다.
        state.note = EventNote(text: outcome, date: now, event: dilemma.id, kind: .dilemma, notified: !auto)
        if !auto { state.counters[Counter.decisions.rawValue, default: 0] += 1 }
        save(now: now)
        return WritingProgress(state: state)
    }

    /// 알리지 않은 사건.
    var unnotifiedDilemma: ActiveDilemma? { state.dilemma.flatMap { $0.notified == true ? nil : $0 } }

    func markDilemmaNotified() {
        guard state.dilemma != nil else { return }
        state.dilemma?.notified = true
        save()
    }

    /// 월요일 기준 이번 주 시작.
    static func weekStart(of date: Date) -> Date {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)  // 일 1 … 토 7
        return calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: day) ?? day
    }

    /// 새 주가 되면 지난주를 정리한다. 지난주에 쓴 기록이 없으면 넘어간다.
    private func noteWeek(now: Date) {
        let thisWeek = Self.weekStart(of: now)
        guard state.weekly?.weekStart != thisWeek else { return }
        let calendar = Calendar.current
        guard let lastWeek = calendar.date(byAdding: .day, value: -7, to: thisWeek) else { return }
        let days = state.days.compactMap { key, record -> (Date, WritingRecord)? in
            guard let date = DayKey.date(from: key), date >= lastWeek, date < thisWeek else { return nil }
            return (date, record)
        }
        guard !days.isEmpty, days.contains(where: { $0.1.characters > 0 }) else { return }
        let progress = WritingProgress(state: state, now: now)
        let best = days.max { $0.1.characters < $1.1.characters }
        let soldLastWeek = state.salesByDay.reduce(0.0) { sum, pair in
            guard let date = DayKey.date(from: pair.key), date >= lastWeek, date < thisWeek else { return sum }
            return sum + pair.value
        }
        state.weekly = WeeklyReview(
            weekStart: thisWeek,
            characters: Int(days.reduce(0) { $0 + $1.1.net }),
            finished: progress.finished.filter { $0.date >= lastWeek && $0.date < thisWeek }.count,
            events: state.eventLog.filter { $0.lostCharacters == nil && !$0.event.hasPrefix("luck.") && $0.startedAt >= lastWeek && $0.startedAt < thisWeek }.count,
            disasters: state.eventLog.filter { $0.lostCharacters != nil && $0.startedAt >= lastWeek && $0.startedAt < thisWeek }.count,
            bestDay: best?.0, bestDayCharacters: Int(best?.1.characters ?? 0), sales: Int(soldLastWeek))
    }

    /// 이 작품을 지금 쓰는 책 바로 다음에 쓴다. 이미 쓴 것, 지금 쓰는 것은 못 옮긴다.
    func writeNext(_ bookIndex: Int) {
        let progress = WritingProgress(state: state)
        var order = progress.roundOrder
        guard let from = order.firstIndex(of: bookIndex), from > progress.orderPosition else { return }
        order.remove(at: from)
        order.insert(bookIndex, at: progress.orderPosition + 1)
        setOrder(order, round: progress.round)
    }

    /// 이 작가의 남은 작품을 지금 책 다음에 몰아 쓴다.
    func focus(author: String) {
        let progress = WritingProgress(state: state)
        var order = progress.roundOrder
        let picked = progress.pendingInRound.filter { Library.books[$0].authorShort == author }
        guard !picked.isEmpty else { return }
        order.removeAll { picked.contains($0) }
        order.insert(contentsOf: picked, at: progress.orderPosition + 1)
        state.counters[Counter.focuses.rawValue, default: 0] += 1
        setOrder(order, round: progress.round)
    }

    private func setOrder(_ order: [Int], round: Int) {
        while state.orders.count <= round { state.orders.append(Array(0..<Library.books.count)) }
        state.orders[round] = order
        save()
    }

    func dismissFinish(_ id: String) {
        guard let i = state.finishNotes.firstIndex(where: { $0.id == id }) else { return }
        state.finishNotes[i].dismissed = true
        save()
    }

    func dismissWeekly() {
        state.weekly?.dismissed = true
        save()
    }

    var unnotifiedFinishes: [FinishNote] { state.finishNotes.filter { $0.notified != true } }

    func markFinishNotified(_ id: String) {
        guard let i = state.finishNotes.firstIndex(where: { $0.id == id }) else { return }
        state.finishNotes[i].notified = true
        save()
    }

    func markWeeklyNotified() {
        state.weekly?.notified = true
        save()
    }

    /// 새 토큰 100만 개마다 한 번씩 추첨한다. 자연재해는 늘 추첨하고, 돌발 상황은 이미 있으면 추첨하지 않는다.
    private func rollEvent(newTokens: Int, now: Date, author: String?) {
        state.tokensTowardEventRoll += newTokens
        let live = Boosts(state.boosts, now: now)
        let weather = Weather.of(now)
        while state.tokensTowardEventRoll >= 1_000_000 {
            state.tokensTowardEventRoll -= 1_000_000
            let studio = StudioPerks(owned: state.studio)
            if random() < disasterChance * weather.disaster * (weather == .storm ? studio.stormDisaster : 1) { strike(Disasters.pick(roll: random()), now: now) }
            if state.luck == nil, random() < luckChance * sheetPerks(now: now).luckChance {
                var luck = Lucks.pick(roll: random())
                // 눈 오는 날은 손님이 못 온다. 대신 선금.
                if weather.blocksGuest, luck.id == Lucks.guest.id { luck = Lucks.advance }
                grant(luck, now: now, author: author)
            }
            if Self.shopEnabled, state.order == nil, random() < Balance.orderChancePerMillion { offerOrder(now: now) }
            if Self.shopEnabled, random() < Balance.shopEventChancePerMillion { happenInShop(now: now) }
            if state.dilemma == nil, now.timeIntervalSince(state.dilemmaLog.last?.date ?? .distantPast) >= Balance.dilemmaCooldown,
               random() < dilemmaChance {
                var dilemma = Dilemmas.pick(roll: random())
                // 고양이를 들였으면 창틀의 고양이는 오지 않는다.
                if studio.blocksCat, dilemma.id == "cat", let other = Dilemmas.all.first(where: { $0.id != "cat" }) { dilemma = other }
                offer(dilemma, now: now)
            }
            // 손님 작가가 있는 동안은 돌발 상황이 없다.
            let month = Calendar.current.component(.month, from: now)
            let winter = month == 12 || month <= 2
            guard state.event == nil, state.luck?.id != Lucks.guest.id,
                  random() < eventChance * perks.eventChance * live.eventChance * weather.event * studio.event * (winter ? studio.winterEvent : 1) else { continue }
            var event = AuthorEvents.pick(author: author ?? "", hour: Calendar.current.component(.hour, from: now), roll: random())
            // 카페인: 오늘 커피·홍차를 많이 권했으면 졸음 대신 글이 막히고, 어제 그랬으면 오늘은 졸음이 더 온다.
            let today = state.cups(on: now), yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now).map { state.cups(on: $0) } ?? 0
            if today >= Balance.caffeineCups, event.id == AuthorEvents.nap.id { event = AuthorEvents.block }
            else if yesterday >= Balance.caffeineCups, today < Balance.caffeineCups, event.id != AuthorEvents.nap.id, random() < Balance.hangoverNapChance { event = AuthorEvents.nap }
            start(event, now: now, author: author)
        }
    }

    /// 행운을 준다. 선금은 그 자리에서 아이템을, 나머지는 시간이 있는 상태로 남는다. 확인용 실행에서 직접 부르기도 한다.
    func grant(_ luck: LuckEvent, now: Date = Date(), author: String? = nil, invited: String? = nil) {
        var items: String?
        var guest: String?
        if luck.id == Lucks.advance.id {
            var counts: [ItemKind: Int] = [:]
            for _ in 0..<Balance.advanceItems {
                if let kind = giveRandomItem() { counts[kind, default: 0] += 1 }
            }
            items = counts.isEmpty ? "가방이 가득이라 사양했습니다"
                : ItemKind.allCases.compactMap { kind in counts[kind].map { "\(kind.shortTitle) \($0)" } }.joined(separator: ", ")
        } else {
            if luck.id == Lucks.guest.id {
                let others = Library.authors.filter { $0 != (author ?? "") }
                guest = invited ?? (others.isEmpty ? nil : others[min(others.count - 1, Int(random() * Double(others.count)))])
            }
            state.luck = ActiveLuck(id: luck.id, startedAt: now, endsAt: now.addingTimeInterval(Double(luck.minutes) * 60), guest: guest)
        }
        let text = Lucks.text(luck, guest: guest, items: items)
        state.note = EventNote(text: text, date: now, event: luck.id, kind: .luck, notified: false)
        var record = EventRecord(event: luck.id, book: WritingProgress(state: state).book?.file, startedAt: now)
        record.endedAt = now.addingTimeInterval(Double(luck.minutes) * 60)
        record.outcome = text
        state.eventLog.append(record)
        if state.eventLog.count > WritingState.maxEventLog {
            state.eventLog.removeFirst(state.eventLog.count - WritingState.maxEventLog)
        }
        save(now: now)
    }

    /// 상황을 시작한다. 확인용 실행에서 직접 부르기도 한다. `author` 는 지금 쓰는 작가(전집 효과용).
    func start(_ event: AuthorEvent, now: Date = Date(), author: String? = nil, minutes fixed: Double? = nil) {
        let range = Balance.eventMinutes
        let minutes = fixed ?? (Double(range.lowerBound) + random() * Double(range.upperBound - range.lowerBound))
            * perks.eventDuration(author: author)
        var active = ActiveEvent(id: event.id, startedAt: now, endsAt: now.addingTimeInterval(minutes * 60))
        if !event.causes.isEmpty { active.cause = min(event.causes.count - 1, Int(random() * Double(event.causes.count))) }
        state.event = active
        // 닫히지 않은 기록이 남아 있으면(예전 파일) 지금 시각으로 닫는다.
        state.closeRecord(at: now, by: nil)
        var record = EventRecord(event: event.id, book: WritingProgress(state: state).book?.file, startedAt: now)
        record.cause = active.cause.map { event.causes[$0] }
        state.eventLog.append(record)
        if state.eventLog.count > WritingState.maxEventLog {
            state.eventLog.removeFirst(state.eventLog.count - WritingState.maxEventLog)
        }
        save(now: now)
    }

    /// 자연재해. 지금 쓰는 책의 원고 일부를 오늘 기록에서 뺀다. 이 책에서 쓴 만큼보다 많이 빼지 않아
    /// 탈고한 책이 되돌아가지 않는다. 아직 이 책을 한 글자도 안 썼으면 아무 일도 없다.
    @discardableResult
    func strike(_ disaster: Disaster, now: Date = Date()) -> Int {
        let progress = WritingProgress(state: state, now: now)
        guard let book = progress.book, progress.charactersInBook > 0 else { return 0 }
        let range = Balance.disasterLoss
        let share = range.lowerBound + random() * (range.upperBound - range.lowerBound)
        var lost = min(progress.charactersInBook, max(1, Int(share * Double(book.characters) * perks.disasterLoss)))
        var line = EventRecord(event: disaster.id, book: book.file, startedAt: now)
        line.endedAt = now
        // 방재 아이템(금고·사본)이 있으면 하나가 저절로 쓰이고 잃는 것이 없다.
        if let shield = ItemRole.shield.kinds.first(where: { state.items[$0.rawValue, default: 0] > 0 }) {
            state.items[shield.rawValue, default: 0] -= 1
            lost = 0
            line.endedBy = shield.rawValue
            line.outcome = shield.curedLines.first
        } else {
            let key = DayKey.string(from: Calendar.current.startOfDay(for: now))
            var record = state.days[key] ?? WritingRecord(tokens: 0, characters: 0)
            record.lost = (record.lost ?? 0) + Double(lost)
            state.days[key] = record
        }
        line.lostCharacters = lost
        state.eventLog.append(line)
        if state.eventLog.count > WritingState.maxEventLog {
            state.eventLog.removeFirst(state.eventLog.count - WritingState.maxEventLog)
        }
        save(now: now)
        return lost
    }

    /// 알리지 않은 자연재해. 알리고 나면 `markDisasterNotified` 로 적는다.
    var unnotifiedDisasters: [EventRecord] {
        state.eventLog.filter { $0.lostCharacters != nil && $0.notified != true }
    }

    func markDisasterNotified(_ id: String) {
        guard let i = state.eventLog.firstIndex(where: { $0.id == id }) else { return }
        state.eventLog[i].notified = true
        save()
    }

    /// 아이템을 써서 지금 상황을 끝낸다. 맞는 아이템이 아니거나 없으면 그대로다.
    /// `Balance.refusalChance` 로 작가가 거절한다. 거절하면 아이템은 그대로 두고 몇 분 동안 다시 쓸 수 없다.
    @discardableResult
    func use(_ item: ItemKind, now: Date = Date()) -> WritingProgress {
        guard let active = state.event, let event = AuthorEvents.byID(active.id), event.cure.role == item.role,
              state.items[item.rawValue, default: 0] > 0 else { return WritingProgress(state: state) }
        // 이미 끝날 시각이 지났으면 아이템을 쓰지 않고 돌아온 것으로 처리한다(갱신 사이 틈).
        if now >= active.endsAt {
            state.event = nil
            let text = event.pick(event.returns, random()) ?? "다시 자리에 앉아 펜을 듭니다"
            state.note = EventNote(text: text, date: active.endsAt, event: active.id, kind: .returned)
            state.closeRecord(at: active.endsAt, by: nil, outcome: text)
            save(now: now)
            return WritingProgress(state: state)
        }
        if let until = active.refusedUntil, now < until { return WritingProgress(state: state) }
        // 거절당할수록 다음엔 덜 거절한다(25 → 15 → 5%).
        let refusals = active.refusals ?? 0
        let chance = max(0, min(0.9, refusalChance - perks.refusalDelta - Balance.refusalDecay * Double(refusals) + Boosts(state.boosts, now: now).refusal
                                   + StudioPerks(owned: state.studio).refusal))
        if !event.refusals.isEmpty, random() < chance {
            let range = Balance.refusalMinutes
            let minutes = (Double(range.lowerBound) + random() * Double(range.upperBound - range.lowerBound)) * perks.refusalWait
            state.event?.refusedUntil = now.addingTimeInterval(minutes * 60)
            state.event?.refusals = refusals + 1
            let lines = item.isPrimary ? event.refusals : item.refusalLines
            let text = event.pick(lines, random()) ?? "지금은 싫다고 합니다"
            state.note = EventNote(text: text, date: now, event: event.id, kind: .refused, notified: true)
            save(now: now)
            return WritingProgress(state: state)
        }
        state.items[item.rawValue, default: 0] -= 1
        state.event = nil
        if refusals > 0 { state.counters[Counter.persistence.rawValue, default: 0] += 1 }
        if item.role == .wake, Self.staminaEnabled, let author = WritingProgress(state: state, now: now).book?.authorShort {
            var sheet = state.sheets[author] ?? AuthorSheet()
            sheet.stamina = min(StatPerks(sheet).staminaMax, sheet.stamina + Balance.staminaCupRestore)
            state.sheets[author] = sheet
        }
        let text = event.pick(item.isPrimary ? event.cured : item.curedLines, random()) ?? "다시 씁니다"
        state.note = EventNote(text: text, date: now, event: event.id, kind: .cured, notified: true)
        state.closeRecord(at: now, by: item, outcome: text)
        save(now: now)
        return WritingProgress(state: state)
    }

    /// 다른 기록 파일로 바꾼다. 먼저 읽어 보고, 되면 지금 파일을 `writing.imported-backup-<시각>.json` 으로 남긴다.
    func replace(with url: URL) -> Bool {
        guard persist, let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any], raw["days"] != nil,
              let loaded = try? JSONDecoder().decode(WritingState.self, from: data), !loaded.days.isEmpty
        else { return false }
        let fm = FileManager.default
        if fm.fileExists(atPath: self.url.path) {
            let aside = self.url.deletingPathExtension().appendingPathExtension("imported-backup-\(Int(Date().timeIntervalSince1970)).json")
            try? fm.copyItem(at: self.url, to: aside)
        }
        state = loaded
        // 가져온 기록의 토큰 수는 다른 Mac 의 로그 합이다. 이 Mac 의 로그와 바로 비교하면 차이가 전부 글자가 되니,
        // 다음 갱신은 토큰만 맞춰 적는 기준선으로 돈다.
        needsBaseline = true
        save()
        return true
    }

    /// 같은 아이템 세 개를 다른 아이템 하나로 바꾼다.
    @discardableResult
    func exchange(_ from: ItemKind, for to: ItemKind) -> WritingProgress {
        guard from != to, state.items[from.rawValue, default: 0] >= Balance.exchangeCost,
              state.items[to.rawValue, default: 0] < Balance.itemCap else { return WritingProgress(state: state) }
        state.items[from.rawValue, default: 0] -= Balance.exchangeCost
        state.items[to.rawValue, default: 0] += 1
        state.counters[Counter.exchanges.rawValue, default: 0] += 1
        save()
        return WritingProgress(state: state)
    }

    /// 돌아옴 알림을 보냈다고 적는다.
    func markNoteNotified() {
        guard state.note != nil else { return }
        state.note?.notified = true
        save()
    }

    /// 확인용 실행에서 아이템을 하나 쥐여 준다.
    func giveForTesting(_ item: ItemKind) {
        state.items[item.rawValue, default: 0] += 1
    }

    /// 알림을 보냈다고 적는다.
    func markNotified() {
        guard state.event != nil else { return }
        state.event?.notified = true
        save()
    }

    /// 새로 이룬 성과를 적고 보상 아이템을 준다. 저장할 때마다 부른다.
    /// 처음 세는 때에 이미 이룬 것은 조용히 채우고 보상도 없다.
    private func updateBadges(now: Date = Date()) {
        let progress = WritingProgress(state: state, now: now)
        let quiet = !state.badgesInitialized
        let calendar = Calendar.current
        for achievement in Achievements.all where achievement.isMet(progress.facts) {
            let previous = state.badges[achievement.id]
            if let previous {
                // 매일 성과만 다시 이룰 수 있다. 오늘 이미 이뤘으면 그대로.
                guard achievement.daily, !calendar.isDate(previous.date, inSameDayAs: now) else { continue }
            }
            var record = BadgeRecord(date: now, notified: quiet)
            if achievement.daily {
                record.count = (previous?.count ?? 0) + 1
                let yesterday = previous.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.date),
                                                                        to: calendar.startOfDay(for: now)).day == 1 } ?? false
                record.streak = yesterday ? (previous?.streak ?? 1) + 1 : 1
            }
            if !quiet, badgeRewards {
                let items = (0..<achievement.rewardCount).compactMap { _ in giveRandomItem() }
                record.reward = items.map(\.rawValue)
            }
            state.badges[achievement.id] = record
        }
        state.badgesInitialized = true
    }

    /// 받은 금 뱃지의 효과. 매일 성과는 오늘 이룬 것만.
    private var perks: Perks { Perks(badges: state.badges) }

    /// 가득 차지 않은 종류 가운데 하나를 비중대로 준다. 모두 가득이면 아무것도 주지 않는다.
    @discardableResult
    func giveRandomItem() -> ItemKind? {
        let open = ItemKind.allCases.filter { state.items[$0.rawValue, default: 0] < Balance.itemCap }
        guard let kind = ItemKind.random(random(), among: open) else { return nil }
        state.items[kind.rawValue, default: 0] += 1
        return kind
    }

    /// 성과용 셈 값 이름.
    enum Counter: String {
        /// 아이템 교환 횟수
        case exchanges
        /// 거절당한 뒤 다시 권해 통한 횟수
        case persistence
        /// 밤(22~5시)에 쓴 글자
        case nightCharacters
        /// 원고 읽기 창을 연 횟수
        case reads
        /// 몰아 쓰기 횟수
        case focuses
        /// 농땡이 중에 들킨(돌아온) 횟수
        case caught
        /// 선택지가 있는 사건에 직접 답한 횟수
        case decisions
        /// 지금 쓰는 작가가 별 2개 이하 비평을 받은 횟수
        case panned
        /// 손님 작가와 말다툼한 횟수
        case quarrels
        /// 상시 창 초상화를 누른 횟수
        case taps
        /// 영감의 날을 직접 켠 횟수
        case ignitions
        /// 마감을 지킨·어긴 횟수
        case deadlinesMet
        case deadlinesMissed
        /// 내기를 이긴·진 횟수
        case betsWon
        case betsLost
        /// 써 본 출판사. 키 뒤에 ".major" 처럼 붙는다.
        case publishers
        /// 광고 횟수, 독자 주문대로 쓴 횟수, 서점 사건 수
        case ads
        case ordersFilled
        case shopEvents
        /// 오른 능력치 수
        case statUps
        /// 탈진 횟수
        case exhaustions
        /// 품절·재판·정산서 횟수
        case soldOuts, reprints, statements
        /// 마을에서 주운 물건, 권해서 판 횟수
        case pickups, recommendations
        /// 살롱에서 청한 횟수
        case invites
    }

    /// 셈 값을 올린다. 화면에서 부르는 것(원고 읽기)도 있다.
    func bump(_ counter: Counter, by amount: Int = 1) {
        state.counters[counter.rawValue, default: 0] += amount
        save()
    }

    /// 지금 상태의 진행.
    var progress: WritingProgress { WritingProgress(state: state) }

    /// 알리지 않은 성과.
    var unnotifiedBadges: [Achievement] {
        Achievements.all.filter { state.badges[$0.id]?.notified == false }
    }

    /// 성과 보상으로 받은 아이템 이름("커피 1, 종 2").
    func rewardText(for id: String) -> String? {
        guard let reward = state.badges[id]?.reward, !reward.isEmpty else { return nil }
        var counts: [ItemKind: Int] = [:]
        for raw in reward { if let kind = ItemKind(rawValue: raw) { counts[kind, default: 0] += 1 } }
        return ItemKind.allCases.compactMap { kind in counts[kind].map { n in "\(kind.shortTitle) \(n)" } }.joined(separator: ", ")
    }

    func markBadgeNotified(_ id: String) {
        guard state.badges[id] != nil else { return }
        state.badges[id]?.notified = true
        save()
    }

    /// `now` 는 확인용 실행이 시간을 흉내 낼 때 쓴다. 매일 성과가 "오늘"을 그 시각으로 본다.
    private func save(now: Date = Date()) {
        guard persist else { return }
        updateBadges(now: now)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        guard let data = try? encoder.encode(state) else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let backup = url.deletingPathExtension().appendingPathExtension("backup.json")
        if fm.fileExists(atPath: url.path), !skipBackupOnce {
            try? fm.removeItem(at: backup)
            try? fm.copyItem(at: url, to: backup)
        }
        skipBackupOnce = false
        try? data.write(to: url, options: .atomic)
    }
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
    /// 아직 닫지 않은 탈고 카드(하루 동안)와 지난주 돌아보기(그 주 동안).
    let finishCards: [FinishNote]
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
    let statPerks: StatPerks
    let tokensToNextStat: Int
    let tired: Bool
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
        // 회차마다 쓰는 순서. 저장된 것이 없거나 수가 안 맞으면 서재 순서 그대로.
        func order(_ round: Int) -> [Int] {
            if round < state.orders.count, state.orders[round].count == n, Set(state.orders[round]) == Set(0..<n) {
                return state.orders[round]
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
