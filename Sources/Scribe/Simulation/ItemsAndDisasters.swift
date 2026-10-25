import Foundation
import SwiftUI

// MARK: - 균형

/// 돌발 상황과 아이템의 수치. 한곳에 모아 둔다.
enum Balance {
    /// 새 토큰 100만 개마다 돌발 상황이 생길 확률.
    static let eventChancePerMillion = 0.035
    /// 돌발 상황이 저절로 끝나기까지 걸리는 시간(분).
    static let eventMinutes = 15...60
    /// 이만큼 토큰을 쓰면 아이템 하나를 얻는다. 멈춘 동안 쓴 토큰도 센다.
    /// 하루 4억 토큰이면 16개쯤. 돌발 상황(100만 개마다 3.5%)이 하루 14번쯤이니 상황 하나에 아이템 하나 남짓이다.
    static let tokensPerItem = 25_000_000
    /// 한 종류를 이보다 많이 가질 수 없다. 가득 찬 종류는 추첨에서 빠지고, 모두 가득이면 그 아이템은 없던 일이 된다.
    static let itemCap = 5
    /// 아이템을 썼을 때 작가가 거절할 확률. 거절하면 아이템은 그대로고 몇 분 뒤에 다시 쓸 수 있다.
    static let refusalChance = 0.25
    /// 거절당한 뒤 다시 쓸 수 있을 때까지(분).
    static let refusalMinutes = 3...5
    /// 같은 상황에서 거절당할 때마다 거절 확률에서 빼는 값.
    static let refusalDecay = 0.10
    /// 아이템 교환: 같은 것 몇 개로 다른 것 하나.
    static let exchangeCost = 3
    /// 새 토큰 100만 개마다 행운이 생길 확률.
    static let luckChancePerMillion = 0.015
    /// 영감의 날 동안 글자 배수와 길이(분), 손님 작가가 머무는 시간(분), 선금 아이템 수.
    static let inspirationMultiplier = 2.0
    static let inspirationMinutes = 60
    static let guestMinutes = 180
    static let advanceItems = 3
    /// 판매: 새 토큰 100만 개마다 탈고한 책 한 권에 팔리는 부수, 신간으로 치는 날수, 손님 작가 입소문 배수.
    static let copiesPerMillion = 10.0
    static let freshDays = 30
    static let guestSalesMultiplier = 2.0
    /// 새 토큰 100만 개마다 자연재해가 생길 확률. 집필은 멈추지 않고 원고 일부를 잃는다.
    static let disasterChancePerMillion = 0.004
    /// 자연재해로 잃는 양. 지금 쓰는 책 전체 분량에 대한 비율이고, 이 책에서 쓴 만큼보다 많이 잃지는 않는다.
    static let disasterLoss = 0.01...0.04
    /// 새 토큰 100만 개마다 선택지가 있는 사건이 생길 확률, 다음 사건까지 비우는 시간(초).
    static let dilemmaChancePerMillion = 0.008
    static let dilemmaCooldown: TimeInterval = 3 * 3600
    /// 비평: 탈고 뒤 실리기까지(시간), 지금 쓰는 작가의 책이면 작가에게 붙는 보정이 가는 시간(시간).
    static let reviewHours = 2.0...36.0
    static let reviewBoostHours = 24
    /// 손님 작가와 말다툼하는 간격(분).
    static let quarrelMinutes = 25
    /// 카페인: 하루에 커피·홍차를 이만큼 권하면 손이 떨린다. 그날은 졸음이 안 오고, 다음 날은 졸음 확률이 이만큼 더해진다. 타자 빠르기 배수.
    static let caffeineCups = 5
    static let hangoverNapChance = 0.25
    static let caffeineTempo = 2.2
    /// 출판사: 대형 출판사 선금 아이템 수, 고르지 않으면 대형으로 가기까지(시간).
    static let publisherAdvance = 3
    static let publisherHours = 24
    /// 내기: 손님이 있을 때 말다툼 차례에 내기를 걸 확률, 이기면 받는 아이템과 판매 보정(배수, 시간), 지면 잃는 아이템.
    static let betChance = 0.3
    static let betWinItems = 3
    static let betSalesBoost = 1.5
    static let betBoostHours = 24
    static let betLoseItems = 2
    /// 서점: 이달의 책 판매 배수와 나머지 책 배수, 바꾸기까지(시간). 광고 값과 배수·시간. 독자 주문 확률과 기한(일)과 판매 배수.
    static let featuredBoost = 1.3
    static let featuredOthers = 0.9
    static let featuredHours = 24
    static let adCost: [(ItemKind, Int)] = [(.pencil, 1), (.copy, 1), (.messenger, 1)]
    static let adBoost = 2.0
    static let adHours = 24
    static let orderChancePerMillion = 0.006
    static let orderDays = 7
    static let orderBoost = 1.5
    /// 서점 사건: 새 토큰 100만 개마다 생길 확률(탈고한 책이 있을 때).
    static let shopEventChancePerMillion = 0.012
    /// 영감 게이지: 이만큼 읽기(입력·캐시) 토큰이 쌓이면 영감의 날을 직접 켤 수 있다.
    static let inspirationGaugeTokens = 150_000_000
    /// 마감: 지키면 받는 아이템 수와 판매 보정(배수, 시간), 어기면 오르는 거절 확률(p, 시간).
    static let deadlineItems = 2
    static let deadlineSalesBoost = 1.2
    static let deadlineBoostHours = 24
    static let deadlinePenalty = 0.1
    static let deadlinePenaltyHours = 48
}

/// 행운. 돌발 상황의 반대편으로, 가끔 좋은 일이 생긴다.
struct LuckEvent: Equatable, Sendable {
    let id: String
    let rawTitle: String
    let icon: [String]
    /// 0이면 그 자리에서 끝나는 일(선금).
    let minutes: Int

    var title: String { L10n.tr(rawTitle) }

    init(id: String, title: String, icon: [String], minutes: Int) {
        self.id = id
        self.rawTitle = title
        self.icon = icon
        self.minutes = minutes
    }
}

enum Lucks {
    static let inspiration = LuckEvent(id: "luck.inspiration", title: "영감의 날", icon: PixelIcon.star, minutes: Balance.inspirationMinutes)
    static let advance = LuckEvent(id: "luck.advance", title: "출판사 선금", icon: PixelIcon.coin, minutes: 0)
    static let guest = LuckEvent(id: "luck.guest", title: "손님 작가", icon: PixelIcon.door, minutes: Balance.guestMinutes)

    static let all = [inspiration, advance, guest]
    static func byID(_ id: String) -> LuckEvent? { all.first { $0.id == id } }
    static func pick(roll: Double) -> LuckEvent { all[min(all.count - 1, Int(roll * Double(all.count)))] }

    /// 시작할 때 보여 주는 말.
    @MainActor
    static func text(_ luck: LuckEvent, guest: String?, items: String?) -> String {
        switch luck.id {
        case inspiration.id:
            return L10n.tr("영감이 쏟아집니다. \(Balance.inspirationMinutes)분 동안 글자가 \(Int(Balance.inspirationMultiplier))배로 늘어납니다")
        case advance.id:
            if L10n.isEnglish {
                return "An advance arrived from the publisher" + (items.map { ". Received \($0)" } ?? "")
            }
            return "출판사에서 선금이 왔습니다" + (items.map { $0.hasSuffix("습니다") ? ". \($0)" : ". \($0)을 받았습니다" } ?? "")
        default:
            let name = guest.flatMap { g in Library.books.first { $0.authorShort == g }?.displayAuthorShort } ?? L10n.tr("다른 작가")
            return L10n.tr("\(Format.particle(name, "이", "가")) 찾아와 함께 씁니다. \(Balance.guestMinutes / 60)시간 동안 돌발 상황이 없습니다")
        }
    }

    /// 끝날 때 보여 주는 말.
    static func endText(_ luck: LuckEvent) -> String {
        L10n.tr({ switch luck.id {
        case inspiration.id: "영감의 날이 저물었습니다. 평소 속도로 돌아갑니다"
        default: "손님 작가가 돌아갔습니다"
        } }())
    }
}

/// 자연재해. 집필은 멈추지 않고 지금 쓰는 책의 원고 일부를 잃는다. 탈고한 책은 건드리지 않는다.
struct Disaster: Equatable, Sendable {
    let id: String
    /// 화재, 홍수처럼 짧은 이름. 좁은 자리에서 쓴다.
    let rawName: String
    /// "원고 n자를" 앞에 오는 말과 뒤에 오는 말.
    let rawCause: String
    let rawEffect: String
    let icon: [String]

    var name: String { L10n.tr(rawName) }
    var cause: String { L10n.tr(rawCause) }
    var effect: String { L10n.tr(rawEffect) }

    init(id: String, name: String, cause: String, effect: String, icon: [String]) {
        self.id = id
        self.rawName = name
        self.rawCause = cause
        self.rawEffect = effect
        self.icon = icon
    }

    /// "난로 불똥이 튀어 원고 2,300자가 탔습니다"
    func text(lost: Int) -> String {
        if L10n.isEnglish {
            return "\(cause) — \(Format.integer(lost)) chars of manuscript \(effect)"
        }
        return L10n.tr("\(rawCause) 원고 \(Format.integer(lost))자\(rawEffect)")
    }
    /// "화재로 원고 2,300자를 잃었습니다"
    func shortText(lost: Int) -> String {
        if L10n.isEnglish {
            return "Lost \(Format.integer(lost)) chars to \(name.lowercased())"
        }
        return L10n.tr("\(Format.particle(rawName, "으로", "로")) 원고 \(Format.integer(lost))자를 잃었습니다")
    }
    /// 방재 아이템이 막았을 때. "난로 불똥이 튀었지만 금고 덕에 원고는 무사했습니다"
    func shieldedText(_ item: ItemKind) -> String {
        L10n.tr("\(name)가 났지만 \(item.title) 덕에 원고는 무사했습니다")
    }
    /// 상시 창용. "화재 · 금고 덕에 원고 무사"
    func shortShieldedText(_ item: ItemKind) -> String {
        L10n.tr("\(name) · \(item.shortTitle) 덕에 원고 무사")
    }
}

enum Disasters {
    static let fire = Disaster(id: "disaster.fire", name: "화재", cause: "난로 불똥이 튀어", effect: "가 탔습니다", icon: PixelIcon.flame)
    static let flood = Disaster(id: "disaster.flood", name: "홍수", cause: "지붕에서 비가 새어", effect: "가 젖어 번졌습니다", icon: PixelIcon.drop)
    static let storm = Disaster(id: "disaster.storm", name: "폭풍", cause: "폭풍에 창문이 열려", effect: "가 날아갔습니다", icon: PixelIcon.wind)
    static let quake = Disaster(id: "disaster.quake", name: "지진", cause: "땅이 흔들려", effect: "가 흩어져 사라졌습니다", icon: PixelIcon.crack)

    static let all = [fire, flood, storm, quake]

    static func byID(_ id: String) -> Disaster? { all.first { $0.id == id } }

    static func pick(roll: Double) -> Disaster { all[min(all.count - 1, Int(roll * Double(all.count)))] }
}

// MARK: - 아이템

/// 토큰을 쓰면 얻고, 돌발 상황을 바로 끝내는 데 쓴다.
/// 아이템이 하는 일. 같은 역할이면 어느 아이템이든 그 상황을 끝낸다.
enum ItemRole: String, CaseIterable, Codable, Sendable {
    case wake, ink, call, muse, light, shield

    var title: String {
        L10n.tr({ switch self {
        case .wake: "깨우기"
        case .ink: "잉크"
        case .call: "불러오기"
        case .muse: "영감"
        case .light: "불빛"
        case .shield: "방재"
        } }())
    }

    /// 어떤 상황을 끝내는지.
    var cures: String {
        L10n.tr({ switch self {
        case .wake: "졸고 있을 때 깨웁니다"
        case .ink: "잉크가 떨어졌을 때 다시 쓰게 합니다"
        case .call: "자리를 비우거나 산책·편지·외출 중일 때 불러옵니다"
        case .muse: "글이 막히거나 멍하니 바라볼 때 영감을 줍니다"
        case .light: "촛불이 꺼졌을 때 불을 밝힙니다"
        case .shield: "자연재해가 나면 저절로 쓰여 원고를 지킵니다"
        } }())
    }

    /// 이 역할의 아이템. 앞엣것이 기본(돌발 상황 문구가 가리키는 것).
    var kinds: [ItemKind] { ItemKind.allCases.filter { $0.role == self } }
}

enum ItemKind: String, CaseIterable, Codable, Sendable {
    case coffee, tea, ink, pencil, bell, messenger, muse, music, candle, lamp, safe, copy

    var role: ItemRole {
        switch self {
        case .coffee, .tea: .wake
        case .ink, .pencil: .ink
        case .bell, .messenger: .call
        case .muse, .music: .muse
        case .candle, .lamp: .light
        case .safe, .copy: .shield
        }
    }

    /// 역할의 기본 아이템인지. 돌발 상황의 문구(종소리, 커피 향)는 이것을 가리킨다.
    var isPrimary: Bool { role.kinds.first == self }

    var title: String {
        L10n.tr({ switch self {
        case .coffee: "커피"
        case .tea: "홍차"
        case .ink: "잉크병"
        case .pencil: "연필"
        case .bell: "호출 종"
        case .messenger: "심부름꾼"
        case .muse: "영감의 깃펜"
        case .music: "오르골"
        case .candle: "새 초"
        case .lamp: "등잔"
        case .safe: "금고"
        case .copy: "사본"
        } }())
    }

    /// 어떤 상황을 끝내는지.
    var cures: String { role.cures }

    /// 버튼처럼 좁은 자리에 쓰는 이름.
    var shortTitle: String {
        L10n.tr({ switch self {
        case .coffee: "커피"
        case .tea: "홍차"
        case .ink: "잉크"
        case .pencil: "연필"
        case .bell: "종"
        case .messenger: "심부름꾼"
        case .muse: "깃펜"
        case .music: "오르골"
        case .candle: "초"
        case .lamp: "등잔"
        case .safe: "금고"
        case .copy: "사본"
        } }())
    }

    var icon: [String] {
        switch self {
        case .coffee: PixelIcon.cup
        case .tea: PixelIcon.teapot
        case .ink: PixelIcon.drop
        case .pencil: PixelIcon.pencil
        case .bell: PixelIcon.bell
        case .messenger: PixelIcon.horn
        case .muse: PixelIcon.quill
        case .music: PixelIcon.note
        case .candle: PixelIcon.candle
        case .lamp: PixelIcon.lamp
        case .safe: PixelIcon.safe
        case .copy: PixelIcon.pages
        }
    }

    /// 얻을 때 고르는 비중.
    var weight: Int {
        switch self {
        case .coffee: 18
        case .tea: 12
        case .ink: 12
        case .pencil: 8
        case .bell: 15
        case .messenger: 10
        case .muse: 9
        case .music: 6
        case .candle: 6
        case .lamp: 4
        case .safe: 3
        case .copy: 2
        }
    }

    /// 기본이 아닌 아이템이 통했을 때. 기본 아이템은 상황마다 있는 문구를 쓴다.
    var curedLines: [String] {
        switch self {
        case .tea: [
            "홍차를 한 모금 넘기고 펜을 듭니다", "찻잔의 김에 눈이 뜨였습니다",
            "베르가모트 향이 감돌자 무겁던 눈꺼풀이 가벼워집니다", "따뜻한 찻물이 목을 타고 내려가자 손끝에 온기가 돕니다",
            "설탕 한 조각을 넣은 홍차를 마시고 원고지를 끌어당깁니다", "찻잔 받침을 내려놓는 소리와 함께 다시 문장을 잇습니다"
        ]
        case .pencil: [
            "연필을 깎아 이어 씁니다", "잉크는 나중에 채우기로 하고 연필로 씁니다",
            "사각거리는 흑연 소리가 오히려 경쾌합니다", "여백에 연필로 급히 떠오른 문장부터 눌러 적습니다",
            "작은 주머니칼로 연필심을 뾰족하게 다듬고 다시 달립니다", "잉크가 마를 걱정이 없다며 연필을 쥐고 속도를 냅니다"
        ]
        case .messenger: [
            "심부름꾼이 쪽지를 들고 뛰어가 작가를 불러옵니다", "심부름꾼의 숨 가쁜 소리에 돌아옵니다",
            "소년이 골목 끝까지 달려가 외투 자락을 붙잡아 왔습니다", "급한 전갈이라는 말에 모자를 챙겨 서둘러 들어옵니다",
            "심부름꾼에게 동전 한 닢을 쥐여 주고 책상으로 복귀합니다"
        ]
        case .music: [
            "오르골 소리에 다음 문장이 떠올랐습니다", "태엽이 풀리기 전에 한 장을 썼습니다",
            "맑은 금속 음계가 엉켜 있던 생각을 가지런히 풀어 줍니다", "오르골의 박자에 맞춰 펜촉이 종이 위를 춤추듯 지나갑니다",
            "익숙한 선율이 흐르자 막혔던 대화 장면이 단숨에 풀립니다"
        ]
        case .lamp: [
            "등잔을 켜자 글자가 보입니다", "등잔불 아래 다시 씁니다",
            "유리 등피 안으로 따뜻한 불빛이 번지며 원고지가 환해집니다", "심지를 조금 올리자 방 안의 어둠이 물러납니다",
            "흔들림 없는 등잔불 덕분에 잔글씨까지 또렷이 보입니다"
        ]
        case .safe: ["금고에 넣어 둔 원고는 무사했습니다", "무거운 철문 덕에 원고 한 장도 상하지 않았습니다"]
        case .copy: ["사본이 있어 잃은 것이 없습니다", "미리 필사해 둔 사본을 꺼내 이어 씁니다"]
        default: ["다시 씁니다"]
        }
    }

    /// 기본이 아닌 아이템을 거절할 때.
    var refusalLines: [String] {
        switch self {
        case .tea: [
            "홍차는 밤에 마시겠다고 합니다", "식었다며 찻잔을 밀어 둡니다",
            "지금은 찻잎이 너무 진하게 우러났다며 고개를 젓습니다", "우유를 타지 않은 홍차는 마시지 않겠다고 합니다",
            "찻잔만 물끄러미 보더니 다시 팔을 베고 눕습니다"
        ]
        case .pencil: [
            "연필로는 진지한 글을 못 쓴다고 합니다", "연필심이 부러졌습니다",
            "흑연 가루가 손날에 묻는 건 질색이라며 내려놓습니다", "나중에 잉크로 다시 베껴 적기 귀찮다고 손사래를 칩니다",
            "연필 글씨는 금방 흐려진다며 잉크를 가져오라고 합니다"
        ]
        case .messenger: [
            "심부름꾼이 길을 잃었습니다", "쪽지를 받고도 모른 척한답니다",
            "심부름꾼에게 되레 간식을 사 주며 돌려보냈답니다", "전갈을 읽더니 주머니에 넣고 발걸음을 옮기지 않습니다",
            "지금 있는 자리가 어딘지 심부름꾼도 찾지 못했습니다"
        ]
        case .music: [
            "오르골 소리가 거슬린다고 뚜껑을 닫습니다", "태엽이 다 풀릴 때까지 듣기만 합니다",
            "선율이 너무 구슬퍼서 오히려 눈물이 난다고 합니다", "음악에 취해 눈을 감고 박자만 맞추고 있습니다",
            "이 곡은 지금 쓰는 장의 분위기와 안 맞는다고 합니다"
        ]
        case .lamp: [
            "등잔 기름 냄새가 싫다고 합니다", "등잔이 너무 어둡다고 합니다",
            "유리 등피에 그을음이 꼈다며 닦기 전엔 안 켠답니다", "등잔불보다 촛불의 흔들리는 그림자가 필요하다고 고집합니다"
        ]
        default: ["지금은 싫다고 합니다"]
        }
    }

    static func random(_ roll: Double) -> ItemKind {
        random(roll, among: allCases) ?? .coffee
    }

    /// 비중대로 하나 고른다. `among` 이 비면 nil.
    static func random(_ roll: Double, among kinds: [ItemKind]) -> ItemKind? {
        let total = kinds.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }
        var point = roll * Double(total)
        for kind in kinds {
            point -= Double(kind.weight)
            if point < 0 { return kind }
        }
        return kinds.last
    }
}
