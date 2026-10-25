import Foundation

// 작업실(아이템으로 사는 가구), 출판사 고르기(탈고한 원고를 어디에 보낼지), 내기(손님 작가와 글자 수 내기).

// MARK: - 작업실

/// 가구 하나. 아이템 몇 개로 사고, 한 번 사면 계속 효과가 붙으며 책상 장면에 그려진다.
struct Furniture: Identifiable, Sendable, Equatable {
    let id: String
    private let rawTitle: String
    var title: String { L10n.tr(rawTitle) }
    /// 효과를 짧게.
    private let rawEffect: String
    var effect: String { L10n.tr(rawEffect) }
    let cost: [(ItemKind, Int)]
    let symbol: String

    init(id: String, title: String, effect: String, cost: [(ItemKind, Int)], symbol: String) {
        self.id = id
        self.rawTitle = title
        self.rawEffect = effect
        self.cost = cost
        self.symbol = symbol
    }

    static func == (a: Furniture, b: Furniture) -> Bool { a.id == b.id }

    var costText: String { cost.map { "\($0.0.shortTitle) \($0.1)" }.joined(separator: " · ") }
}

enum Studio {
    static let all: [Furniture] = [
        Furniture(id: "lamp", title: "탁상등", effect: "밤(22~5시) 글자 +10%", cost: [(.candle, 3), (.lamp, 2)], symbol: "lamp.desk"),
        Furniture(id: "stove", title: "난로", effect: "겨울(12~2월) 돌발 상황 -20%", cost: [(.coffee, 3), (.ink, 2)], symbol: "flame"),
        Furniture(id: "shelf", title: "책장", effect: "판매 +5%", cost: [(.pencil, 3), (.copy, 2)], symbol: "books.vertical"),
        Furniture(id: "curtain", title: "두꺼운 커튼", effect: "폭풍 날 재해 확률 절반", cost: [(.safe, 2), (.bell, 2)], symbol: "curtains.closed"),
        Furniture(id: "chair", title: "안락의자", effect: "아이템 거절 -5%p", cost: [(.tea, 3), (.music, 1)], symbol: "chair.lounge"),
        Furniture(id: "cat", title: "고양이", effect: "돌발 상황 -5% · 고양이 사건 없음", cost: [(.messenger, 2), (.tea, 2)], symbol: "cat"),
    ]

    static func byID(_ id: String) -> Furniture? { all.first { $0.id == id } }

    /// 살 수 있는지(아이템이 충분한지).
    static func canAfford(_ furniture: Furniture, items: [String: Int]) -> Bool {
        furniture.cost.allSatisfy { items[$0.0.rawValue, default: 0] >= $0.1 }
    }
}

/// 가진 가구의 효과를 합친 것.
struct StudioPerks: Sendable, Equatable {
    var nightCharacters = 1.0
    var winterEvent = 1.0
    var sales = 1.0
    var stormDisaster = 1.0
    var refusal = 0.0
    var event = 1.0
    var blocksCat = false

    init() {}

    init(owned: [String]) {
        for id in owned {
            switch id {
            case "lamp": nightCharacters = 1.1
            case "stove": winterEvent = 0.8
            case "shelf": sales = 1.05
            case "curtain": stormDisaster = 0.5
            case "chair": refusal = -0.05
            case "cat": event = 0.95; blocksCat = true
            default: break
            }
        }
    }
}

// MARK: - 출판사

/// 탈고한 원고를 보낼 곳. 하루 안에 안 고르면 대형 출판사로 간다.
enum Publisher: String, Codable, CaseIterable, Sendable {
    case major, literary, indie

    var title: String {
        let raw: String = switch self {
        case .major: "대형 출판사"
        case .literary: "문예 출판사"
        case .indie: "독립 출판"
        }
        return L10n.tr(raw)
    }

    var detail: String {
        let raw: String = switch self {
        case .major: "선금 아이템 \(Balance.publisherAdvance)개 · 판매 보통"
        case .literary: "선금 없음 · 비평 별점 +0.5 · 신간 판매 느림"
        case .indie: "선금 없음 · 신간 기간 두 배 · 첫 달 판매 절반"
        }
        return L10n.tr(raw)
    }

    var symbol: String {
        switch self {
        case .major: "building.2"
        case .literary: "text.book.closed"
        case .indie: "printer"
        }
    }

    /// 탈고 직후 받는 아이템.
    var advance: Int { self == .major ? Balance.publisherAdvance : 0 }
    /// 비평 점수에 더하는 값.
    var starsBonus: Double { self == .literary ? 0.5 : 0 }
    /// 신간 보정: `1 + boost × (남은 신간 기간 비율)`. 대형은 최대 3배, 나머지는 최대 2배.
    var freshBoost: Double { self == .major ? 2 : 1 }
    /// 신간으로 치는 날수.
    var freshDays: Int { self == .indie ? Balance.freshDays * 2 : Balance.freshDays }

    /// 고른 뒤 한 줄.
    var line: String {
        let raw: String = switch self {
        case .major: "원고를 대형 출판사에 보냈습니다. 선금이 바로 왔습니다"
        case .literary: "원고를 문예 출판사에 보냈습니다. 비평가들이 먼저 읽을 겁니다"
        case .indie: "원고를 독립 출판으로 냈습니다. 천천히, 오래 팔릴 겁니다"
        }
        return L10n.tr(raw)
    }
}

// MARK: - 내기

/// 손님 작가가 거는 내기. 받으면 정해진 시간 안에 글자를 채워야 한다.
struct ActiveBet: Codable, Sendable, Equatable {
    /// 손님 작가(`authorShort`)
    let guest: String
    let target: Int
    let offeredAt: Date
    let endsAt: Date
    var accepted: Bool?
    /// 받은 순간의 모두 쓴 글자.
    var startCharacters: Double?
    var won: Bool?
    var resolvedAt: Date?
    var notified: Bool?

    var pending: Bool { accepted == nil && won == nil }
    var running: Bool { accepted == true && won == nil }
}

enum Bets {
    static let offers = ["{B}(이|가) 내기를 겁니다. \"{T}자, 해 지기 전에. 못 쓰면 커피는 내 거요\"", "{B}(이|가) 펜을 내려놓고 말합니다. \"{T}자 내기 어떻소\"",
                         "{B}(이|가) 시계를 보며 웃습니다. \"{T}자. 질 자신 있소?\"", "{B}(이|가) 책상을 두드립니다. \"{T}자에 커피 두 잔\""]
    static let declined = ["작가가 내기를 사양했습니다. {B}(은|는) 콧방귀를 뀌었습니다", "\"내기는 안 하오.\" {B}(이|가) 어깨를 으쓱합니다"]
    static let won = ["내기에서 이겼습니다. {B}(이|가) 커피를 사 왔습니다", "{T}자를 채웠습니다. {B}(이|가) 말없이 원고를 넘겨봅니다", "이겼습니다. {B}(은|는) \"운이 좋았군\"이라고 합니다"]
    static let lost = ["내기에서 졌습니다. {B}(이|가) 아이템을 챙겨 갔습니다", "{T}자에 못 미쳤습니다. {B}(이|가) 휘파람을 붑니다", "졌습니다. {B}(은|는) 당분간 그 얘기만 할 겁니다"]

    @MainActor
    static func text(_ pool: [String], guest: String, target: Int, roll: Double) -> String {
        let name = Library.books.first { $0.authorShort == guest }?.displayAuthorShort ?? guest
        let line = L10n.tr(pool[min(pool.count - 1, Int(roll * Double(pool.count)))])
        return Format.resolve(line.replacingOccurrences(of: "{B}", with: name).replacingOccurrences(of: "{T}", with: Format.integer(target)))
    }

    /// 목표 글자. 남은 시간 동안 평소 속도로 쓸 양의 1.2배, 500자 단위, 최소 2,000자.
    static func target(charactersPerDay: Double, hours: Double) -> Int {
        let base = charactersPerDay * hours / 24 * 1.2
        return max(2_000, Int((base / 500).rounded(.up)) * 500)
    }
}

// MARK: - 서점

/// 독자 주문. 특정 작품을 청하고, 기한 안에 그 책을 쓰기 시작하면 그 책이 신간 기간 동안 더 팔린다.
struct ReaderOrder: Codable, Sendable, Equatable {
    /// `Book.file`
    let book: String
    let offeredAt: Date
    let expiresAt: Date
    /// 독자가 한 말.
    let rawText: String
    var fulfilled: Bool?
    var notified: Bool?

    var text: String { L10n.tr(rawText) }

    init(book: String, offeredAt: Date, expiresAt: Date, text: String, fulfilled: Bool? = nil, notified: Bool? = nil) {
        self.book = book
        self.offeredAt = offeredAt
        self.expiresAt = expiresAt
        self.rawText = text
        self.fulfilled = fulfilled
        self.notified = notified
    }

    enum CodingKeys: String, CodingKey {
        case book, offeredAt, expiresAt, rawText = "text", fulfilled, notified
    }
}

enum ReaderOrders {
    static let lines = ["어느 독자가 편지를 보냈습니다. \"다음은 {T}를 읽고 싶습니다\"", "서점에 손님이 와서 물었답니다. \"{T}는 언제 나오나요\"",
                        "독자 모임에서 {T}를 기다린다는 말이 왔습니다", "먼 도시의 독자가 {T}를 미리 주문했습니다", "학교 선생님이 {T}를 수업에 쓰고 싶답니다"]
    static let filled = ["주문하신 책을 쓰기 시작했습니다. 독자가 기뻐합니다", "{T}를 시작했습니다. 미리 주문한 독자에게 편지가 갔습니다"]

    @MainActor
    static func text(_ pool: [String], book: Book, roll: Double) -> String {
        let line = L10n.tr(pool[min(pool.count - 1, Int(roll * Double(pool.count)))])
        let quotedTitle = L10n.isEnglish ? "\"\(book.displayTitle)\"" : "「\(book.displayTitle)」"
        return Format.resolve(line.replacingOccurrences(of: "{T}", with: quotedTitle))
    }
}

// MARK: - 서점 사건

/// 서점에서 가끔 일어나는 일. 책 하나나 책 전부의 판매에 몇 시간 보정이 붙거나, 부수가 한 번에 늘거나 줄거나, 아이템이 오가거나, 영감이 차거나, 주인이 책을 밀어주거나, 손님이 다음 책을 예약한다.
struct ShopEvent: Identifiable, Sendable {
    enum Scope: Sendable { case book, all, none }
    enum Effect: Sendable {
        /// 판매 배수, 시간.
        case sales(Double, Int)
        /// 부수가 한 번에(최소, 최대).
        case copies(Int, Int)
        /// 부수가 돌아온다(최소, 최대). 반품·파본.
        case returned(Int, Int)
        /// 재고가 들어온다(최소, 최대). 재고를 안 쓸 때는 부수로.
        case restock(Int, Int)
        case items(Int)
        /// 영감 게이지가 이만큼(0~1) 찬다.
        case inspiration(Double)
        /// 주인이 그 책을 이달의 책으로 건다. 이미 걸린 책이 있으면 대신 판매 1.2배가 6시간.
        case feature
        /// 손님이 다음 책을 예약한다. 독자 주문이 생긴다. 이미 있으면 아무 일도 없다.
        case order
        case none
    }

    let id: String
    let rawTitle: String
    /// 상황 글. {T} 책 제목, {A} 작가, {N} 부수. 여럿이면 무작위.
    let texts: [String]
    let scope: Scope
    let effect: Effect
    var weight = 3
    /// 주말에만.
    var weekendOnly = false
    /// 서평 별 4개 이상인 책에만.
    var praisedOnly = false
    /// 이 날씨일 때만.
    var weather: [Weather]? = nil
    /// 이 달에만(1~12).
    var months: [Int]? = nil
    /// 밤(21시~6시)에만.
    var nightOnly = false
    /// 탈고한 책이 이만큼은 있어야.
    var minBooks = 1
    var symbol = "storefront"

    var title: String { L10n.tr(rawTitle) }

    init(
        id: String,
        title: String,
        texts: [String],
        scope: Scope,
        effect: Effect,
        weight: Int = 3,
        weekendOnly: Bool = false,
        praisedOnly: Bool = false,
        weather: [Weather]? = nil,
        months: [Int]? = nil,
        nightOnly: Bool = false,
        minBooks: Int = 1,
        symbol: String = "storefront"
    ) {
        self.id = id
        self.rawTitle = title
        self.texts = texts
        self.scope = scope
        self.effect = effect
        self.weight = weight
        self.weekendOnly = weekendOnly
        self.praisedOnly = praisedOnly
        self.weather = weather
        self.months = months
        self.nightOnly = nightOnly
        self.minBooks = minBooks
        self.symbol = symbol
    }

    var good: Bool {
        switch effect {
        case .sales(let m, _): m >= 1
        case .returned: false
        case .items(let n): n >= 0
        case .copies, .restock, .inspiration, .feature, .order, .none: true
        }
    }

    /// 지금 상황에 맞는 사건인지.
    func fits(_ c: ShopEvents.Context) -> Bool {
        (!weekendOnly || c.weekend) && (!praisedOnly || c.hasPraised) && (weather.map { $0.contains(c.weather) } ?? true)
            && (months.map { $0.contains(c.month) } ?? true) && (!nightOnly || c.night) && c.books >= minBooks
    }
}

enum ShopEvents {
    static let all: [ShopEvent] = [
        ShopEvent(id: "press", title: "신문 소개", texts: ["아침 신문 문화면에 {T}(이|가) 소개됐습니다", "{A}의 {T}(이|가) 주간지 추천 목록에 올랐습니다", "기자가 서점에 와서 {T}(을|를) 사 갔습니다. 기사가 날 겁니다"],
                  scope: .book, effect: .sales(1.5, 12), weight: 4, symbol: "newspaper"),
        ShopEvent(id: "reading", title: "낭독회", texts: ["서점에서 {T} 낭독회가 열렸습니다. 의자가 모자랐습니다", "{A}(이|가) 서점에서 {T} 한 대목을 읽었습니다. 박수가 길었습니다"],
                  scope: .book, effect: .sales(1.4, 6), weight: 3, symbol: "mic"),
        ShopEvent(id: "signing", title: "사인본", texts: ["단골이 {T} 사인본을 부탁했습니다. 서점이 열 권을 더 주문했습니다", "{A}(이|가) 서점에서 {T}에 서명했습니다. 줄이 문밖까지"],
                  scope: .book, effect: .copies(40, 160), weight: 3, symbol: "signature"),
        ShopEvent(id: "school", title: "학교 주문", texts: ["학교에서 {T}(을|를) 교재로 쓰겠다며 {N}부를 주문했습니다", "독서 모임이 {T} {N}부를 한꺼번에 사 갔습니다"],
                  scope: .book, effect: .copies(60, 300), weight: 3, symbol: "graduationcap"),
        ShopEvent(id: "library", title: "도서관 납품", texts: ["시립 도서관이 {T} {N}부를 들였습니다", "순회 도서관 마차가 {T} {N}부를 싣고 갔습니다"],
                  scope: .book, effect: .copies(30, 120), weight: 3, symbol: "building.columns"),
        ShopEvent(id: "celebrity", title: "유명인의 구매", texts: ["무대 배우가 {T}(을|를) 사 갔습니다. 소문이 퍼졌습니다", "시장 부인이 {T}(을|를) 세 권 샀습니다. 다들 따라 삽니다"],
                  scope: .book, effect: .sales(2.0, 3), weight: 2, symbol: "sparkles"),
        ShopEvent(id: "translation", title: "번역판 소식", texts: ["{T}의 번역판 계약 소식이 났습니다. 원서가 덩달아 팔립니다", "바다 건너 서점에도 {T}(이|가) 걸렸습니다"],
                  scope: .book, effect: .sales(1.3, 24), weight: 2, symbol: "globe"),
        ShopEvent(id: "revisit", title: "서평 재조명", texts: ["어느 독자가 {T} 서평을 신문에 다시 올렸습니다", "{T}(이|가) '놓치기 쉬운 책' 목록에 올랐습니다"],
                  scope: .book, effect: .sales(1.4, 12), weight: 2, praisedOnly: true, symbol: "star"),
        ShopEvent(id: "debate", title: "비평가 논쟁", texts: ["비평가 둘이 {T}(을|를) 두고 지면에서 다툽니다. 다들 궁금해합니다", "{T}의 결말을 두고 편지가 신문에 쏟아집니다"],
                  scope: .book, effect: .sales(1.3, 6), weight: 2, symbol: "bubble.left.and.bubble.right"),
        ShopEvent(id: "illustrated", title: "삽화판 제안", texts: ["출판사가 {T} 삽화판을 내자고 합니다. 소문만으로 팔립니다"],
                  scope: .book, effect: .sales(1.2, 24), weight: 1, symbol: "paintbrush"),
        ShopEvent(id: "sale", title: "서점 세일", texts: ["서점이 세일을 시작했습니다. 책이 빨리 빠집니다", "장날입니다. 서점 앞에 손님이 줄을 섭니다"],
                  scope: .all, effect: .sales(1.3, 6), weight: 3, symbol: "tag"),
        ShopEvent(id: "holiday", title: "휴일 특수", texts: ["휴일이라 서점이 붐빕니다", "장이 서는 날이라 서점에도 사람이 몰립니다"],
                  scope: .all, effect: .sales(1.5, 24), weight: 3, weekendOnly: true, symbol: "sun.max"),
        ShopEvent(id: "cat", title: "서점 고양이", texts: ["서점 고양이가 {T} 위에서 잡니다. 손님들이 사진을 찍고 책도 삽니다", "고양이가 {T}(을|를) 깔고 앉아 아무도 못 삽니다"],
                  scope: .book, effect: .sales(1.1, 3), weight: 2, symbol: "cat"),
        ShopEvent(id: "misprint", title: "인쇄소 지연", texts: ["인쇄소가 밀려 {T} 재고가 떨어졌습니다", "{T} 새 판이 늦어집니다. 서점 선반이 비었습니다"],
                  scope: .book, effect: .sales(0.5, 6), weight: 3, symbol: "printer"),
        ShopEvent(id: "leak", title: "비 새는 서점", texts: ["서점 지붕에서 비가 새어 책을 안쪽으로 옮겼습니다", "서점이 수리 중이라 반만 엽니다"],
                  scope: .all, effect: .sales(0.8, 6), weight: 2, symbol: "drop"),
        ShopEvent(id: "rival", title: "경쟁작 출간", texts: ["다른 작가의 신작이 매대 앞자리를 차지했습니다", "옆 서점이 큰 세일을 시작했습니다. 손님이 그리로 갑니다"],
                  scope: .all, effect: .sales(0.85, 12), weight: 3, symbol: "books.vertical"),
        ShopEvent(id: "post", title: "우편 파업", texts: ["우편이 멈춰 주문한 책이 못 갑니다", "눈 때문에 우편 마차가 안 다닙니다"],
                  scope: .all, effect: .sales(0.6, 12), weight: 2, symbol: "envelope"),
        ShopEvent(id: "secondhand", title: "헌책방", texts: ["헌책방에 {T}(이|가) 잔뜩 나왔습니다. 새 책이 덜 팔립니다"],
                  scope: .book, effect: .sales(0.7, 12), weight: 2, symbol: "arrow.uturn.backward"),
        ShopEvent(id: "thief", title: "좀도둑", texts: ["서점에 좀도둑이 들었습니다. 작가 물건도 하나 없어졌습니다"],
                  scope: .none, effect: .items(-1), weight: 1, symbol: "figure.walk"),
        ShopEvent(id: "gift", title: "독자의 선물", texts: ["어느 독자가 서점에 작가 앞으로 꾸러미를 맡겼습니다", "{T}(을|를) 열 번 읽었다는 독자가 선물을 두고 갔습니다"],
                  scope: .book, effect: .items(1), weight: 2, symbol: "gift"),
        ShopEvent(id: "window", title: "진열창", texts: ["서점 주인이 진열창을 {T}(으|로) 꾸몄습니다", "{T} 표지가 진열창 한가운데 걸렸습니다"],
                  scope: .book, effect: .sales(1.25, 12), weight: 3, symbol: "rectangle.portrait"),
        ShopEvent(id: "quiet", title: "조용한 날", texts: ["서점이 하루 종일 조용했습니다. 주인이 선반을 닦았습니다", "손님보다 고양이가 많은 평일이었습니다"],
                  scope: .none, effect: .none, weight: 2, symbol: "moon.zzz"),

        // 날씨
        ShopEvent(id: "shelter", title: "비 피하는 손님", texts: ["비를 피해 들어온 손님들이 나가기 전에 책을 한 권씩 집었습니다", "소나기 덕에 서점이 꽉 찼습니다. 우산보다 책이 더 팔렸습니다"],
                  scope: .all, effect: .sales(1.2, 6), weight: 3, weather: [.rain], symbol: "cloud.rain"),
        ShopEvent(id: "snowbound", title: "눈에 갇힌 손님", texts: ["눈에 갇힌 손님이 {T}(을|를) 난로 옆에서 끝까지 읽고 사 갔습니다", "눈길에 발이 묶인 나그네가 {T}(을|를) 두 권 샀습니다. 하나는 선물이랍니다"],
                  scope: .book, effect: .copies(10, 40), weight: 3, weather: [.snow], symbol: "snowflake"),
        ShopEvent(id: "fogtale", title: "안개 낀 밤", texts: ["안개가 짙은 밤이면 {T} 얘기가 돕니다. 다들 그 책을 찾습니다", "안개 속에서 {T} 한 대목을 떠올렸다는 손님이 책을 사 갔습니다"],
                  scope: .book, effect: .sales(1.3, 6), weight: 2, weather: [.fog], symbol: "cloud.fog"),
        ShopEvent(id: "heatwave", title: "더위 피난처", texts: ["너무 더워 서점 안으로 피한 사람들이 미안해서 책을 삽니다", "서점이 동네에서 제일 시원한 곳이 됐습니다. 손님이 안 나갑니다"],
                  scope: .all, effect: .sales(1.15, 6), weight: 3, weather: [.heat], symbol: "thermometer.sun"),
        ShopEvent(id: "stormclosed", title: "폭풍 휴업", texts: ["폭풍에 서점이 덧문을 닫았습니다", "바람에 간판이 떨어져 서점이 반나절 문을 닫았습니다"],
                  scope: .all, effect: .sales(0.4, 6), weight: 3, weather: [.storm], symbol: "wind"),
        ShopEvent(id: "snowroad", title: "눈길", texts: ["눈에 길이 막혀 손님이 없습니다", "눈이 무릎까지 쌓여 배달 마차가 안 옵니다"],
                  scope: .all, effect: .sales(0.6, 12), weight: 2, weather: [.snow], symbol: "snowflake"),
        ShopEvent(id: "damp", title: "젖은 책", texts: ["{T} 한 묶음이 빗물에 젖어 {N}부를 못 팔게 됐습니다", "창고에 물이 들어 {T} {N}부가 못 쓰게 됐습니다"],
                  scope: .book, effect: .returned(10, 40), weight: 2, weather: [.rain, .storm], symbol: "drop.triangle"),

        // 계절
        ShopEvent(id: "yearend", title: "연말 선물", texts: ["연말 선물로 {T}(이|가) 많이 나갑니다. 리본을 묶느라 주인이 바쁩니다", "성탄 전야, 다들 책 한 권씩 안고 갑니다"],
                  scope: .all, effect: .sales(1.4, 24), weight: 4, months: [12], symbol: "gift"),
        ShopEvent(id: "springfair", title: "봄 축제", texts: ["봄 축제 노점에 {T}(이|가) 깔렸습니다. {N}부가 나갔습니다", "축제 행렬이 서점 앞을 지나갔습니다. {T} {N}부가 그 자리에서 팔렸습니다"],
                  scope: .book, effect: .copies(30, 100), weight: 3, months: [3, 4, 5], symbol: "leaf"),
        ShopEvent(id: "summer", title: "피서객", texts: ["피서객이 기차에서 읽을 {T}(을|를) 사 갑니다", "바닷가로 가는 사람들이 가벼운 책을 찾습니다. {T}(이|가) 그 축에 끼었습니다"],
                  scope: .book, effect: .sales(1.2, 12), weight: 3, months: [6, 7, 8], symbol: "sun.haze"),
        ShopEvent(id: "autumn", title: "긴 밤", texts: ["밤이 길어져 다들 두꺼운 책을 찾습니다", "낙엽 치우던 사람들이 서점에 들러 겨울 읽을거리를 쌓아 갑니다"],
                  scope: .all, effect: .sales(1.2, 12), weight: 3, months: [9, 10, 11], symbol: "leaf"),
        ShopEvent(id: "newyear", title: "새해 결심", texts: ["새해에 책을 읽겠다는 사람들이 {T}(을|를) 삽니다. 다 읽을지는 모릅니다"],
                  scope: .book, effect: .sales(1.3, 24), weight: 3, months: [1], symbol: "calendar"),

        // 밤
        ShopEvent(id: "nightowl", title: "밤늦은 손님", texts: ["문 닫을 때 들어온 손님이 {T}(을|를) 사며 작가 얘기를 오래 했습니다. 작가가 들었으면 기뻐했을 겁니다", "밤늦게 온 손님이 {A}의 다음 책을 꼭 읽겠다고 했습니다"],
                  scope: .book, effect: .inspiration(0.1), weight: 3, nightOnly: true, symbol: "moon.stars"),
        ShopEvent(id: "lamplight", title: "등불 아래", texts: ["주인이 등불 아래서 {T}(을|를) 다시 읽었습니다. 내일은 앞자리에 둘 겁니다"],
                  scope: .book, effect: .feature, weight: 2, nightOnly: true, symbol: "lamp.desk"),

        // 여러 권일 때
        ShopEvent(id: "collector", title: "전집 수집가", texts: ["전집을 모으는 손님이 {T}부터 시작하겠다며 {N}부를 샀습니다. 친구들 몫까지", "수집가가 {A} 책을 전부 달라고 했습니다. {T}(이|가) {N}부 나갔습니다"],
                  scope: .book, effect: .copies(20, 80), weight: 2, minBooks: 3, symbol: "books.vertical"),
        ShopEvent(id: "frontrow", title: "매대 앞자리", texts: ["주인이 {T}(을|를) 매대 앞자리로 옮겼습니다", "주인이 {T}에 '주인 추천' 쪽지를 붙였습니다"],
                  scope: .book, effect: .feature, weight: 3, minBooks: 2, symbol: "star.square"),
        ShopEvent(id: "dusty", title: "뒷선반", texts: ["{T}(이|가) 뒷선반으로 밀려 먼지가 앉았습니다", "새 책에 밀려 {T}(을|를) 찾는 손님이 줄었습니다"],
                  scope: .book, effect: .sales(0.7, 24), weight: 2, minBooks: 3, symbol: "archivebox"),
        ShopEvent(id: "set", title: "전집 할인", texts: ["주인이 {A} 책을 묶어 전집으로 내놓았습니다. 묶음이 잘 나갑니다"],
                  scope: .all, effect: .sales(1.2, 12), weight: 2, minBooks: 4, symbol: "square.stack"),

        // 좋은 일
        ShopEvent(id: "prize", title: "문학상 후보", texts: ["{T}(이|가) 문학상 후보에 올랐습니다. 서점에 전보가 왔습니다", "{A}(이|가) 올해의 작가 후보가 됐습니다. {T}(을|를) 찾는 사람이 늘었습니다"],
                  scope: .book, effect: .sales(1.6, 24), weight: 1, praisedOnly: true, symbol: "rosette"),
        ShopEvent(id: "serial", title: "신문 연재", texts: ["{T} 한 대목이 신문에 연재됐습니다. 결말이 궁금한 사람들이 책을 삽니다", "주간지가 {T} 첫 장을 실었습니다. 다음 호를 못 기다린 사람들이 서점으로"],
                  scope: .book, effect: .sales(1.3, 12), weight: 3, symbol: "doc.text"),
        ShopEvent(id: "sermon", title: "설교 인용", texts: ["목사가 설교에서 {T}(을|를) 인용했습니다. 월요일에 교인들이 왔습니다"],
                  scope: .book, effect: .sales(1.25, 12), weight: 2, symbol: "book.closed"),
        ShopEvent(id: "station", title: "기차역 매점", texts: ["기차역 매점이 {T} {N}부를 들였습니다. 여행자들이 삽니다", "역 앞 가판대에 {T}(이|가) 걸렸습니다. {N}부가 하루에 나갔습니다"],
                  scope: .book, effect: .copies(40, 150), weight: 2, symbol: "tram"),
        ShopEvent(id: "club", title: "독서 모임", texts: ["독서 모임이 다음 달 책으로 {T}(을|를) 골랐습니다. {N}부가 한꺼번에", "부인회가 {T}(을|를) 같이 읽기로 했습니다. {N}부"],
                  scope: .book, effect: .copies(20, 60), weight: 3, symbol: "person.3"),
        ShopEvent(id: "tea", title: "서점 다과회", texts: ["서점 다과회에서 주인이 {T} 얘기만 했습니다", "다과회 손님들이 돌아가며 {T} 한 줄씩 읽었습니다"],
                  scope: .book, effect: .sales(1.15, 3), weight: 2, symbol: "cup.and.saucer"),
        ShopEvent(id: "leather", title: "가죽 장정판", texts: ["제본소가 {T} 가죽 장정판을 {N}부 만들었습니다. 금방 팔렸습니다"],
                  scope: .book, effect: .copies(10, 30), weight: 2, symbol: "book"),
        ShopEvent(id: "letters", title: "독자 편지", texts: ["서점에 {A} 앞으로 독자 편지가 쌓였습니다. 작가가 힘을 냅니다", "{T}(을|를) 읽고 울었다는 편지가 왔습니다. 작가가 오래 들고 있었습니다"],
                  scope: .book, effect: .inspiration(0.15), weight: 3, symbol: "envelope.badge"),
        ShopEvent(id: "crate", title: "창고 상자", texts: ["주인이 창고에서 {T} {N}부가 든 상자를 찾아냈습니다. 바로 내놓았습니다", "{T} {N}부가 든 상자가 뒤늦게 도착했습니다"],
                  scope: .book, effect: .restock(15, 50), weight: 2, symbol: "shippingbox"),
        ShopEvent(id: "reserve", title: "예약 손님", texts: ["손님이 작가의 다음 책을 미리 주문하고 갔습니다", "단골이 \"다음 책은 나한테 먼저\"라며 선금을 두고 갔습니다"],
                  scope: .none, effect: .order, weight: 2, symbol: "bookmark"),
        ShopEvent(id: "poet", title: "떠돌이 시인", texts: ["떠돌이 시인이 서점 앞에서 {T} 구절을 읊었습니다. 지나던 사람 몇이 들어왔습니다"],
                  scope: .book, effect: .copies(3, 12), weight: 2, symbol: "music.mic"),
        ShopEvent(id: "child", title: "어린 손님", texts: ["어린 손님이 용돈을 모아 {T}(을|를) 샀습니다. 주인이 값을 조금 깎아 줬습니다", "아이가 {T}(을|를) 사 들고 계단에 앉아 바로 읽기 시작했습니다"],
                  scope: .book, effect: .copies(1, 3), weight: 3, symbol: "figure.and.child.holdinghands"),
        ShopEvent(id: "quarrel", title: "손님 다툼", texts: ["두 손님이 마지막 남은 {T}(을|를) 두고 다퉜습니다. 주인이 한 권 더 주문했습니다"],
                  scope: .book, effect: .copies(2, 6), weight: 2, symbol: "exclamationmark.bubble"),
        ShopEvent(id: "portrait", title: "작가 초상", texts: ["화가가 {A} 초상을 그려 서점에 걸었습니다. 손님들이 그 밑에서 {T}(을|를) 삽니다"],
                  scope: .book, effect: .sales(1.2, 24), weight: 1, symbol: "person.crop.rectangle"),

        // 나쁜 일
        ShopEvent(id: "returns", title: "반품", texts: ["학교가 {T} 주문을 취소해 {N}부가 돌아왔습니다", "도매상이 {T} {N}부를 돌려보냈습니다. 안 팔린답니다"],
                  scope: .book, effect: .returned(20, 80), weight: 2, symbol: "arrow.uturn.left"),
        ShopEvent(id: "mice", title: "창고의 쥐", texts: ["창고에 쥐가 들어 {T} {N}부를 갉았습니다", "쥐가 {T} 상자 속에 둥지를 틀었습니다. {N}부를 버렸습니다"],
                  scope: .book, effect: .returned(5, 20), weight: 2, symbol: "pawprint"),
        ShopEvent(id: "keeperill", title: "주인의 감기", texts: ["서점 주인이 감기로 누웠습니다. 조카가 대신 보는데 책을 못 찾습니다", "주인이 앓아 서점이 오후에만 엽니다"],
                  scope: .all, effect: .sales(0.75, 12), weight: 2, symbol: "bandage"),
        ShopEvent(id: "paper", title: "종이값 인상", texts: ["종이값이 올라 {T} 값이 올랐습니다. 망설이는 손님이 늘었습니다"],
                  scope: .book, effect: .sales(0.8, 24), weight: 2, symbol: "banknote"),
        ShopEvent(id: "scandal", title: "투서", texts: ["{T}(이|가) 점잖지 못하다는 투서가 신문에 났습니다. 몰래 사 가는 사람도 있긴 합니다"],
                  scope: .book, effect: .sales(0.8, 12), weight: 1, symbol: "eye.slash"),
        ShopEvent(id: "nextdoorfire", title: "옆집 불", texts: ["옆 가게에 불이 나 서점이 하루 문을 닫았습니다. 책은 무사합니다"],
                  scope: .all, effect: .sales(0.5, 12), weight: 1, symbol: "flame"),
        ShopEvent(id: "misdelivery", title: "배달 착오", texts: ["{T} 상자가 다른 마을로 갔습니다. 며칠 뒤에나 옵니다", "마부가 {T} 상자를 엉뚱한 서점에 내려놓았습니다"],
                  scope: .book, effect: .sales(0.6, 24), weight: 2, symbol: "shippingbox.circle"),
        ShopEvent(id: "taxman", title: "세금 징수원", texts: ["세금 징수원이 다녀갔습니다. 주인이 작가 물건을 하나 팔아 메웠습니다"],
                  scope: .none, effect: .items(-1), weight: 1, symbol: "doc.text.magnifyingglass"),
        ShopEvent(id: "counterfeit", title: "해적판", texts: ["{T} 해적판이 장터에 돌고 있습니다. 반값입니다"],
                  scope: .book, effect: .sales(0.65, 24), weight: 1, symbol: "doc.on.doc"),

        // 그냥 있었던 일
        ShopEvent(id: "forgotten", title: "두고 간 책", texts: ["손님이 {T}(을|를) 두고 갔습니다. 주인이 서랍에 넣어 두었습니다"],
                  scope: .book, effect: .none, weight: 1, symbol: "tray"),
        ShopEvent(id: "dog", title: "옆집 개", texts: ["옆집 개가 서점에 들어와 {T} 밑에서 잤습니다. 손님들이 웃었습니다"],
                  scope: .book, effect: .none, weight: 1, symbol: "dog"),
        ShopEvent(id: "clock", title: "멈춘 시계", texts: ["서점 시계가 멈춰 주인이 한 시간 늦게 문을 열었습니다. 아무도 몰랐습니다"],
                  scope: .none, effect: .none, weight: 1, symbol: "clock"),
    ]

    static func byID(_ id: String) -> ShopEvent? { all.first { $0.id == id } }

    /// 사건을 고를 때 보는 지금 상황.
    struct Context: Sendable {
        var weekend = false
        var hasPraised = false
        var weather: Weather = .clear
        var month = 6
        var night = false
        var books = 1

        static func now(_ date: Date, hasPraised: Bool, books: Int, calendar: Calendar = .current) -> Context {
            let weekday = calendar.component(.weekday, from: date)
            let hour = calendar.component(.hour, from: date)
            return Context(weekend: weekday == 1 || weekday == 7, hasPraised: hasPraised, weather: Weather.of(date, calendar: calendar),
                           month: calendar.component(.month, from: date), night: hour >= 21 || hour < 6, books: books)
        }
    }

    /// 비중대로 고른다. 주말·날씨·달·밤·책 수 조건이 안 맞는 사건은 빠진다.
    static func pick(roll: Double, context: Context) -> ShopEvent {
        let pool = all.filter { $0.fits(context) }
        let total = pool.reduce(0) { $0 + $1.weight }
        var r = Int(roll * Double(total))
        for e in pool {
            if r < e.weight { return e }
            r -= e.weight
        }
        return pool.last ?? all[0]
    }

    static func pick(roll: Double, weekend: Bool, hasPraised: Bool) -> ShopEvent {
        pick(roll: roll, context: Context(weekend: weekend, hasPraised: hasPraised))
    }
}

/// 서점 사건의 판매 보정. 책 하나(`book`)나 전부(nil).
struct ShopBoost: Codable, Sendable, Equatable, Identifiable {
    let book: String?
    let value: Double
    let endsAt: Date
    let rawSource: String
    var source: String { L10n.tr(rawSource) }
    var id: String { "\(rawSource)-\(book ?? "all")-\(endsAt.timeIntervalSince1970)" }

    init(book: String?, value: Double, endsAt: Date, source: String) {
        self.book = book
        self.value = value
        self.endsAt = endsAt
        self.rawSource = source
    }

    enum CodingKeys: String, CodingKey {
        case book, value, endsAt, rawSource = "source"
    }
}

/// 서점 사건 기록.
struct ShopRecord: Codable, Sendable, Equatable, Identifiable {
    let event: String
    let book: String?
    let rawText: String
    let date: Date
    /// 한 번에 늘어난 부수.
    var copies: Int?
    var text: String { L10n.tr(rawText) }
    var id: String { "\(event)-\(date.timeIntervalSince1970)" }

    init(event: String, book: String?, text: String, date: Date, copies: Int? = nil) {
        self.event = event
        self.book = book
        self.rawText = text
        self.date = date
        self.copies = copies
    }

    enum CodingKeys: String, CodingKey {
        case event, book, rawText = "text", date, copies
    }
}
