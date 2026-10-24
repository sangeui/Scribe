import Foundation
import SwiftUI

// 서점 운영. 재고와 재판, 진열 자리(진열창·매대·서가·창고), 주인의 신뢰, 월요일 정산서.
// 진열은 주인이 아침마다 정리하고, 직접 고른 책은 이레 동안 그대로 둔다.

// MARK: - 자리

/// 책이 놓인 자리. 창고는 품절(재고 0).
enum ShopSlot: String, Codable, Sendable, CaseIterable {
    case window, counter, shelf, storage

    var title: String {
        switch self {
        case .window: "진열창"
        case .counter: "매대"
        case .shelf: "서가"
        case .storage: "창고"
        }
    }

    var symbol: String {
        switch self {
        case .window: "rectangle.portrait"
        case .counter: "tablecells"
        case .shelf: "books.vertical"
        case .storage: "shippingbox"
        }
    }

    /// 판매 배수.
    var sales: Double {
        switch self {
        case .window: Balance.windowSales
        case .counter: 1
        case .shelf: Balance.shelfSales
        case .storage: 0
        }
    }
}

// MARK: - 신뢰

/// 주인의 신뢰 단계. 0~100을 다섯으로 나눈다.
enum TrustLevel: Int, CaseIterable, Sendable, Comparable {
    case distant, acquainted, usual, friendly, regular

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    static func of(_ trust: Double) -> TrustLevel {
        switch trust {
        case ..<20: .distant
        case ..<40: .acquainted
        case ..<60: .usual
        case ..<80: .friendly
        default: .regular
        }
    }

    var title: String {
        switch self {
        case .distant: "서먹함"
        case .acquainted: "안면"
        case .usual: "보통"
        case .friendly: "친근함"
        case .regular: "단골 작가"
        }
    }

    /// 매대 칸 수.
    var counterSlots: Int {
        switch self {
        case .distant: 2
        case .acquainted: 3
        case .usual: 3
        case .friendly: 4
        case .regular: 5
        }
    }

    /// 진열창을 쓸 수 있는지.
    var hasWindow: Bool { self >= .acquainted }

    /// 재판 입고 시간 배수.
    var reprintSpeed: Double {
        switch self {
        case .distant: 1.25
        case .acquainted, .usual: 1
        case .friendly: 0.85
        case .regular: 0.7
        }
    }

    var detail: String {
        "매대 \(counterSlots)칸 · " + (hasWindow ? "진열창 있음" : "진열창 없음") + (reprintSpeed < 1 ? " · 재판 \(Int((1 - reprintSpeed) * 100))% 빠름" : reprintSpeed > 1 ? " · 재판 \(Int((reprintSpeed - 1) * 100))% 느림" : "")
    }
}

/// 신뢰가 오르내린 사유.
struct TrustRecord: Codable, Sendable, Equatable, Identifiable {
    let delta: Double
    let reason: String
    let date: Date
    var id: String { "\(reason)-\(date.timeIntervalSince1970)" }
}

// MARK: - 재고 소식

/// 품절·입고 소식. 알림과 상시 창에 쓴다.
struct StockNews: Codable, Sendable, Equatable, Identifiable {
    enum Kind: String, Codable, Sendable { case soldOut, restocked }
    let book: String
    let kind: Kind
    let copies: Int
    /// 품절이면 입고 예정 시각.
    let due: Date?
    let date: Date
    var notified: Bool?
    var id: String { "\(kind.rawValue)-\(book)-\(date.timeIntervalSince1970)" }
}

// MARK: - 정산서

/// 책 한 줄.
struct StatementLine: Codable, Sendable, Equatable, Identifiable {
    let book: String
    let sold: Int
    let returned: Int
    let missed: Int
    let stock: Int
    let slot: ShopSlot
    var id: String { book }
}

/// 월요일에 주인이 보내는 지난주 정산서.
struct Statement: Codable, Sendable, Equatable, Identifiable {
    let weekStart: Date
    let lines: [StatementLine]
    let sold: Int
    let returned: Int
    let missed: Int
    let trustBefore: Double
    let trustAfter: Double
    let reasons: [String]
    let keeperLine: String
    var notified: Bool?
    var dismissed: Bool?
    var id: String { "statement-\(weekStart.timeIntervalSince1970)" }
}

// MARK: - 상태

/// 서점 운영 상태. `WritingState.shop`.
struct ShopState: Codable, Sendable, Equatable {
    /// 책별 재고. 없는 키는 아직 인쇄 전.
    var stock: [String: Double] = [:]
    /// 재판 중인 책 → 입고 시각과 부수.
    var reprints: [String: Reprint] = [:]
    /// 매대에 있는 책(차례대로). 진열창은 `WritingState.featuredBook`.
    var counter: [String] = []
    /// 직접 고른 자리(책 → 고른 시각). 이레 동안 주인이 안 건드린다.
    var pinned: [String: Date] = [:]
    /// 직접 내린 책(책 → 내린 시각). 이레 동안 주인이 다시 올리지 않는다.
    var benched: [String: Date] = [:]
    /// 자리에 놓인 시각(돌려 놓기용).
    var placedAt: [String: Date] = [:]
    /// 주인이 마지막으로 정리한 시각.
    var arrangedAt: Date?
    /// 신뢰 0~100.
    var trust = Balance.trustStart
    var trustLog: [TrustRecord] = []
    /// 이번 주 책별 판매·반품·놓친 손님. 월요일에 정산서로 넘어간다.
    var weekSold: [String: Double] = [:]
    var weekReturned: [String: Double] = [:]
    var weekMissed: [String: Double] = [:]
    var weekTrustStart: Double?
    /// 셈을 시작한 시각. 이보다 앞선 주는 정산하지 않는다.
    var trackedSince: Date?
    /// 날짜별 책별 판매(최근 14일). 주인이 자리를 정할 때 본다.
    var soldByDay: [String: [String: Double]] = [:]
    var statements: [Statement] = []
    var stockNews: [StockNews] = []
    /// 옛 기록에 재고를 채웠는지.
    var migrated = false

    struct Reprint: Codable, Sendable, Equatable {
        let due: Date
        let copies: Int
        let orderedAt: Date
    }

    init() {}

    private enum CodingKeys: String, CodingKey {
        case stock, reprints, counter, pinned, benched, placedAt, arrangedAt, trust, trustLog
        case weekSold, weekReturned, weekMissed, weekTrustStart, trackedSince, soldByDay, statements, stockNews, migrated
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stock = (try? c.decodeIfPresent([String: Double].self, forKey: .stock)) ?? [:]
        reprints = (try? c.decodeIfPresent([String: Reprint].self, forKey: .reprints)) ?? [:]
        counter = (try? c.decodeIfPresent([String].self, forKey: .counter)) ?? []
        pinned = (try? c.decodeIfPresent([String: Date].self, forKey: .pinned)) ?? [:]
        benched = (try? c.decodeIfPresent([String: Date].self, forKey: .benched)) ?? [:]
        placedAt = (try? c.decodeIfPresent([String: Date].self, forKey: .placedAt)) ?? [:]
        arrangedAt = try? c.decodeIfPresent(Date.self, forKey: .arrangedAt)
        trust = (try? c.decodeIfPresent(Double.self, forKey: .trust)) ?? Balance.trustStart
        trustLog = ((try? c.decodeIfPresent([Lossy<TrustRecord>].self, forKey: .trustLog)) ?? []).compactMap(\.value)
        weekSold = (try? c.decodeIfPresent([String: Double].self, forKey: .weekSold)) ?? [:]
        weekReturned = (try? c.decodeIfPresent([String: Double].self, forKey: .weekReturned)) ?? [:]
        weekMissed = (try? c.decodeIfPresent([String: Double].self, forKey: .weekMissed)) ?? [:]
        weekTrustStart = try? c.decodeIfPresent(Double.self, forKey: .weekTrustStart)
        trackedSince = try? c.decodeIfPresent(Date.self, forKey: .trackedSince)
        soldByDay = (try? c.decodeIfPresent([String: [String: Double]].self, forKey: .soldByDay)) ?? [:]
        statements = ((try? c.decodeIfPresent([Lossy<Statement>].self, forKey: .statements)) ?? []).compactMap(\.value)
        stockNews = ((try? c.decodeIfPresent([Lossy<StockNews>].self, forKey: .stockNews)) ?? []).compactMap(\.value)
        migrated = (try? c.decodeIfPresent(Bool.self, forKey: .migrated)) ?? false
    }

    var level: TrustLevel { TrustLevel.of(trust) }

    func stock(of file: String) -> Int { Int(stock[file] ?? 0) }

    /// 자리. 재고가 없으면 창고, 인쇄 전이면 nil.
    func slot(of file: String, window: String?) -> ShopSlot? {
        guard stock[file] != nil else { return nil }
        if stock(of: file) <= 0 { return .storage }
        if window == file { return .window }
        if counter.contains(file) { return .counter }
        return .shelf
    }

    /// 지난 며칠 동안 팔린 부수.
    func sold(_ file: String, days: Int, now: Date, calendar: Calendar = .current) -> Double {
        let start = calendar.startOfDay(for: now)
        return (0..<days).reduce(0.0) { sum, back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: start) else { return sum }
            return sum + (soldByDay[DayKey.string(from: day)]?[file] ?? 0)
        }
    }

    mutating func noteSold(_ file: String, copies: Double, now: Date, calendar: Calendar = .current) {
        let key = DayKey.string(from: calendar.startOfDay(for: now))
        soldByDay[key, default: [:]][file, default: 0] += copies
        weekSold[file, default: 0] += copies
        if soldByDay.count > 16 {
            for old in soldByDay.keys.sorted().prefix(soldByDay.count - 16) { soldByDay[old] = nil }
        }
    }

    /// 신뢰를 올리거나 내린다. 0~100에 묶고 최근 사유 열둘만 남긴다.
    mutating func adjustTrust(_ delta: Double, reason: String, now: Date) {
        let before = trust
        trust = max(0, min(100, trust + delta))
        guard abs(trust - before) > 0.001 else { return }
        trustLog.append(TrustRecord(delta: trust - before, reason: reason, date: now))
        if trustLog.count > 12 { trustLog.removeFirst(trustLog.count - 12) }
    }
}

// MARK: - 주인의 셈

@MainActor
enum Shopkeeper {
    /// 책 하나가 매대에 설 자격. 최근 판매 속도에 신간·서평·광고·주문을 곱하고, 오래 자리를 차지한 책은 조금 깎는다.
    static func score(_ file: String, state: WritingState, now: Date) -> Double {
        let shop = state.shop
        let recent = shop.sold(file, days: 7, now: now)
        let publisher = state.finishNotes.last { $0.book == file }?.publisher.flatMap(Publisher.init(rawValue:)) ?? .major
        let finishedAt = state.finishNotes.last { $0.book == file }?.date
        let days = finishedAt.map { max(0, now.timeIntervalSince($0) / 86_400) } ?? 30
        // 신간은 아직 팔린 기록이 없어도 앞에 둔다. 첫 이레는 지금 제일 잘 나가는 책만큼은 팔릴 것으로 본다.
        let fresh = 1 + publisher.freshBoost * max(0, 1 - days / Double(publisher.freshDays))
        let best = state.finishNotes.map(\.book).reduce(0.0) { max($0, shop.sold($1, days: 7, now: now)) }
        let expected = max(Balance.copiesPerMillion * 20, best * 1.2) * (1 - days / 7)
        let velocity = days < 7 ? max(recent, expected) : recent + 1
        let reviewed = state.reviews.last { $0.book == file && $0.published == true }.map { Critics.salesMultiplier(for: $0.stars) } ?? 1
        let advertised = (state.ads[file].map { $0 > now } ?? false) ? 2.0 : 1
        let ordered = (state.orderBonus[file].map { $0 > now } ?? false) ? 1.5 : 1
        let onSlot = shop.placedAt[file].map { now.timeIntervalSince($0) / 86_400 } ?? 0
        let rotation = max(0.6, 1 - 0.05 * max(0, onSlot - 7))
        // 주마다 조금 다른 눈. 같은 점수면 매주 다른 책이 앞에 선다.
        let seed = abs((file + DayKey.string(from: WritingStore.weekStart(of: now))).hashValue) % 21
        let whim = 0.9 + Double(seed) / 100
        return velocity * fresh * reviewed * advertised * ordered * rotation * whim
    }

    /// 지난주 정산서에 붙는 주인의 한마디.
    static func line(sold: Int, missed: Int, returned: Int, trustDelta: Double) -> String {
        if sold == 0 && missed == 0 { return "지난주엔 발길이 뜸했습니다. 신간 소식이 있으면 알려 주십시오" }
        if missed > sold / 3 { return "품절로 돌려보낸 손님이 많았습니다. 재판을 미리 청했으면 더 팔았을 겁니다" }
        if returned > sold / 4 { return "반품이 많았습니다. 큰 주문은 받기 전에 저와 한 번 상의합시다" }
        if trustDelta >= 4 { return "이번 주는 손님이 끊이지 않았습니다. 앞자리를 더 내드리지요" }
        if trustDelta <= -4 { return "손님이 줄었습니다. 매대는 잘 팔리는 책 차지입니다" }
        if missed > 0 { return "몇 분은 빈손으로 갔습니다. 재고를 조금 넉넉히 두는 게 어떻겠습니까" }
        return "별일 없이 한 주가 갔습니다. 다음 주도 부탁드립니다"
    }
}

extension Publisher {
    /// 초판 부수.
    var firstRun: Int {
        switch self {
        case .major: 3_000
        case .literary: 1_000
        case .indie: 300
        }
    }

    /// 재판이 들어오기까지(시간).
    var reprintHours: Double {
        switch self {
        case .major: 6
        case .literary: 12
        case .indie: 24
        }
    }
}

extension Balance {
    /// 서점 운영: 자리 배수(진열창, 서가), 탈고 직후 견본 부수, 직접 고른 자리를 주인이 안 건드리는 날수, 아침 정리 시각.
    static let windowSales = 1.3
    static let shelfSales = 0.5
    static let sampleRun = 100
    static let pinDays = 7
    static let arrangeHour = 8
    /// 재판 부수: 지난 7일 판매의 몇 배, 초판의 몇 배 사이.
    static let reprintWeeks = 1.5
    static let reprintMinRatio = 0.5
    static let reprintMaxRatio = 4.0
    /// 신뢰: 처음 값, 독자 주문을 지키면·놓치면, 매대 책이 품절되면, 반품이 오면, 사람 모이는 사건이 잘 끝나면, 광고를 걸면, 정산 때 놓친 손님 비율로.
    static let trustStart = 40.0
    static let trustOrderKept = 5.0
    static let trustOrderMissed = -5.0
    static let trustSoldOut = -2.0
    static let trustReturns = -3.0
    static let trustGathering = 2.0
    static let trustAd = 1.0
    static let trustWeekGood = 4.0
    static let trustWeekBad = -4.0
    static let trustWeekQuiet = -1.0
    /// 마을: 손님에게 책을 권하면 팔리는 부수와 하루 횟수, 그때 오르는 신뢰.
    static let recommendCopies = 3...12
    static let recommendPerDay = 3
    static let trustRecommend = 0.5
    /// 살롱: 같이 쓰자고 청했을 때 응할 확률(기본, 매력 한 단계마다 더함, 최대).
    static let inviteBaseChance = 0.5
    static let inviteCharmBonus = 0.05
    static let inviteMaxChance = 0.9
}
