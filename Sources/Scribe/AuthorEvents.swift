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
    let title: String
    let icon: [String]
    /// 0이면 그 자리에서 끝나는 일(선금).
    let minutes: Int
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
        case inspiration.id: return "영감이 쏟아집니다. \(Balance.inspirationMinutes)분 동안 글자가 \(Int(Balance.inspirationMultiplier))배로 늘어납니다"
        case advance.id: return "출판사에서 선금이 왔습니다" + (items.map { $0.hasSuffix("습니다") ? ". \($0)" : ". \($0)을 받았습니다" } ?? "")
        default:
            let name = guest.flatMap { g in Library.books.first { $0.authorShort == g }?.displayAuthorShort } ?? "다른 작가"
            return "\(Format.particle(name, "이", "가")) 찾아와 함께 씁니다. \(Balance.guestMinutes / 60)시간 동안 돌발 상황이 없습니다"
        }
    }

    /// 끝날 때 보여 주는 말.
    static func endText(_ luck: LuckEvent) -> String {
        switch luck.id {
        case inspiration.id: "영감의 날이 저물었습니다. 평소 속도로 돌아갑니다"
        default: "손님 작가가 돌아갔습니다"
        }
    }
}

/// 자연재해. 집필은 멈추지 않고 지금 쓰는 책의 원고 일부를 잃는다. 탈고한 책은 건드리지 않는다.
struct Disaster: Equatable, Sendable {
    let id: String
    /// 화재, 홍수처럼 짧은 이름. 좁은 자리에서 쓴다.
    let name: String
    /// "원고 n자를" 앞에 오는 말과 뒤에 오는 말.
    let cause: String
    let effect: String
    let icon: [String]

    /// "난로 불똥이 튀어 원고 2,300자가 탔습니다"
    func text(lost: Int) -> String { "\(cause) 원고 \(Format.integer(lost))자\(effect)" }
    /// "화재로 원고 2,300자를 잃었습니다"
    func shortText(lost: Int) -> String { "\(Format.particle(name, "으로", "로")) 원고 \(Format.integer(lost))자를 잃었습니다" }
    /// 방재 아이템이 막았을 때. "난로 불똥이 튀었지만 금고 덕에 원고는 무사했습니다"
    func shieldedText(_ item: ItemKind) -> String { "\(name)가 났지만 \(item.title) 덕에 원고는 무사했습니다" }
    /// 상시 창용. "화재 · 금고 덕에 원고 무사"
    func shortShieldedText(_ item: ItemKind) -> String { "\(name) · \(item.shortTitle) 덕에 원고 무사" }
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
        switch self {
        case .wake: "깨우기"
        case .ink: "잉크"
        case .call: "불러오기"
        case .muse: "영감"
        case .light: "불빛"
        case .shield: "방재"
        }
    }

    /// 어떤 상황을 끝내는지.
    var cures: String {
        switch self {
        case .wake: "졸고 있을 때 깨웁니다"
        case .ink: "잉크가 떨어졌을 때 다시 쓰게 합니다"
        case .call: "자리를 비우거나 산책·편지·외출 중일 때 불러옵니다"
        case .muse: "글이 막히거나 멍하니 바라볼 때 영감을 줍니다"
        case .light: "촛불이 꺼졌을 때 불을 밝힙니다"
        case .shield: "자연재해가 나면 저절로 쓰여 원고를 지킵니다"
        }
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
        switch self {
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
        }
    }

    /// 어떤 상황을 끝내는지.
    var cures: String { role.cures }

    /// 버튼처럼 좁은 자리에 쓰는 이름.
    var shortTitle: String {
        switch self {
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
        }
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
        case .tea: ["홍차를 한 모금 넘기고 펜을 듭니다", "찻잔의 김에 눈이 뜨였습니다"]
        case .pencil: ["연필을 깎아 이어 씁니다", "잉크는 나중에 채우기로 하고 연필로 씁니다"]
        case .messenger: ["심부름꾼이 쪽지를 들고 뛰어가 작가를 불러옵니다", "심부름꾼의 숨 가쁜 소리에 돌아옵니다"]
        case .music: ["오르골 소리에 다음 문장이 떠올랐습니다", "태엽이 풀리기 전에 한 장을 썼습니다"]
        case .lamp: ["등잔을 켜자 글자가 보입니다", "등잔불 아래 다시 씁니다"]
        case .safe: ["금고에 넣어 둔 원고는 무사했습니다"]
        case .copy: ["사본이 있어 잃은 것이 없습니다"]
        default: ["다시 씁니다"]
        }
    }

    /// 기본이 아닌 아이템을 거절할 때.
    var refusalLines: [String] {
        switch self {
        case .tea: ["홍차는 밤에 마시겠다고 합니다", "식었다며 찻잔을 밀어 둡니다"]
        case .pencil: ["연필로는 진지한 글을 못 쓴다고 합니다", "연필심이 부러졌습니다"]
        case .messenger: ["심부름꾼이 길을 잃었습니다", "쪽지를 받고도 모른 척한답니다"]
        case .music: ["오르골 소리가 거슬린다고 뚜껑을 닫습니다", "태엽이 다 풀릴 때까지 듣기만 합니다"]
        case .lamp: ["등잔 기름 냄새가 싫다고 합니다", "등잔이 너무 어둡다고 합니다"]
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

// MARK: - 돌발 상황

/// 작가에게 생긴 일. 이 동안은 토큰이 글자로 바뀌지 않는다. `cure` 아이템을 쓰면 바로 끝난다.
struct AuthorEvent: Equatable, Sendable {
    /// 저장용 이름. 바꾸면 저장된 상황을 못 읽는다.
    let id: String
    let text: String
    let icon: [String]
    /// 책상을 떠난 일이면 초상화를 흐리게.
    let leavesDesk: Bool
    let cure: ItemKind
    /// 왜 그렇게 됐는지. 시작할 때 하나 고른다.
    var causes: [String] = []
    /// 저절로 끝나 돌아올 때 하는 말.
    var returns: [String] = []
    /// 아이템이 통했을 때.
    var cured: [String] = []
    /// 아이템을 거절할 때. 비어 있으면 거절하지 않는다.
    var refusals: [String] = []

    func pick(_ lines: [String], _ roll: Double) -> String? {
        guard !lines.isEmpty else { return nil }
        return lines[min(lines.count - 1, Int(roll * Double(lines.count)))]
    }
}

enum AuthorEvents {
    static let nap = AuthorEvent(
        id: "nap", text: "책상에 엎드려 졸고 있습니다", icon: PixelIcon.zzz, leavesDesk: false, cure: .coffee,
        causes: ["밤새 교정을 보느라 한숨도 못 잤습니다", "점심을 든든히 먹은 탓입니다", "난로 옆이 너무 따뜻합니다",
                 "창밖 빗소리가 자장가 같습니다", "어젯밤 늦게까지 친구와 술잔을 기울였습니다", "오후 햇살이 책상에 길게 누웠습니다",
                 "같은 문장을 열 번째 읽고 있었습니다", "이불을 두르고 쓰다가 그만 눈이 감겼습니다"],
        returns: ["기지개를 켜고 다시 펜을 듭니다", "하품을 하며 원고 앞에 앉았습니다", "볼에 찍힌 종이 자국을 문지르며 일어납니다",
                  "꿈에서 본 장면을 서둘러 적습니다", "찬물로 세수하고 돌아왔습니다", "잠깐 눈 붙였을 뿐이라고 우깁니다"],
        cured: ["커피 향에 눈을 번쩍 뜹니다. 다시 씁니다", "한 모금에 정신이 돌아왔습니다", "뜨거운 잔을 두 손으로 감싸더니 펜을 듭니다",
                "커피를 들이켜고 어깨를 폅니다", "잔을 비우자마자 밀린 문장을 쏟아냅니다"],
        refusals: ["한 잔 더는 심장이 뛴다며 손을 젓습니다", "컵을 밀어 두고 다시 엎드립니다", "오 분만 더 자겠다고 중얼거립니다",
                   "커피가 식도록 코를 골고 있습니다", "지금 마시면 밤에 못 잔다고 합니다", "눈을 뜨는가 싶더니 다시 감습니다"])
    static let ink = AuthorEvent(
        id: "ink", text: "잉크가 떨어졌습니다", icon: PixelIcon.drop, leavesDesk: false, cure: .ink,
        causes: ["어젯밤 편지를 너무 많이 썼습니다", "잉크병이 넘어져 책상이 엉망입니다", "문방구가 오늘 문을 닫았습니다",
                 "고양이가 잉크병을 바닥에 떨어뜨렸습니다", "지난주에 사 둔다는 걸 깜빡했습니다", "마지막 한 방울로 서명만 겨우 했습니다",
                 "펜촉이 굳어 잉크가 나오지 않습니다"],
        returns: ["서랍 깊숙이 남은 잉크를 찾아냈습니다", "이웃에게 잉크를 빌려 왔습니다", "묽게 탄 잉크로나마 다시 씁니다",
                  "문방구에 다녀와 새 병을 땄습니다", "연필로 쓰다가 잉크를 구해 왔습니다"],
        cured: ["새 잉크를 찍어 첫 줄을 긋습니다", "병뚜껑을 따자 익숙한 냄새가 납니다", "펜촉을 담그고 만족스럽게 고개를 끄덕입니다",
                "새 잉크로 쓴 글씨가 유난히 검습니다"],
        refusals: ["이 잉크는 색이 마음에 안 든다며 돌려보냅니다", "병을 열어 보더니 묽다며 고개를 젓습니다", "늘 쓰던 상표가 아니라고 투덜거립니다",
                   "펜촉부터 닦아야 한다며 미룹니다", "잉크는 됐고 종이가 문제라고 합니다"])
    static let away = AuthorEvent(
        id: "away", text: "잠시 자리를 비웠습니다", icon: PixelIcon.door, leavesDesk: true, cure: .bell,
        causes: ["문밖에 손님이 찾아왔습니다", "우체부가 서명을 받으러 왔습니다", "집주인이 월세 얘기를 하자고 합니다",
                 "아래층에서 뭔가 깨지는 소리가 났습니다", "출판사 사환이 원고를 받으러 왔습니다", "식모가 저녁 찬거리를 물어봅니다",
                 "굴뚝 청소부가 왔습니다", "옆집 개가 마당에 들어왔습니다", "오랜 친구가 예고 없이 들렀습니다"],
        returns: ["손님을 배웅하고 책상으로 돌아왔습니다", "한숨을 쉬며 다시 자리에 앉았습니다", "문을 닫고 귀마개를 찾습니다",
                  "별일 아니었다며 펜을 집어 듭니다", "손님이 두고 간 과자를 먹으며 씁니다", "문고리를 걸어 잠그고 돌아왔습니다"],
        cured: ["종소리를 듣고 서둘러 돌아옵니다", "종소리에 손님께 양해를 구하고 올라옵니다", "종이 울리자 급한 일이 생겼다고 둘러댑니다",
                "종소리 핑계로 자리를 뜹니다"],
        refusals: ["종소리는 들었지만 조금만 더 있겠다고 합니다", "아직 이야기가 안 끝났다며 손짓합니다", "종소리를 바람 소리로 알아들은 모양입니다",
                   "손님 앞에서 일어설 수 없다고 합니다", "차 한 잔만 더 하고 가겠다고 합니다", "종을 흔들어도 대답이 없습니다"])
    static let walk = AuthorEvent(
        id: "walk", text: "산책하러 나갔습니다", icon: PixelIcon.boot, leavesDesk: true, cure: .bell,
        causes: ["머리가 무거워 바람을 쐬러 나갔습니다", "비가 그쳐 거리가 반짝입니다", "강가의 안개가 보고 싶어졌습니다",
                 "의사가 하루 한 시간은 걸으라고 했습니다", "공원 밤나무가 꽃을 피웠다고 합니다", "다리가 저려 더는 못 앉아 있겠답니다",
                 "해 질 녘 하늘이 너무 좋습니다", "개가 문 앞에서 끈을 물고 기다립니다"],
        returns: ["볼이 발그레해져서 돌아왔습니다", "산책길에 떠오른 문장을 서둘러 적습니다", "신발의 흙을 털고 자리에 앉습니다",
                  "젖은 외투를 걸어 두고 펜을 듭니다", "들꽃 한 송이를 잉크병 옆에 꽂았습니다", "걷다 보니 결말이 보였다고 합니다"],
        cured: ["종소리에 발길을 돌립니다", "멀리서 종소리를 듣고 서둘러 돌아옵니다", "종소리를 듣고 걸음을 재촉합니다",
                "종이 울리자 산책을 내일로 미룹니다"],
        refusals: ["모퉁이까지만 더 걷겠다고 합니다", "종소리를 못 들은 척 걸음을 재촉합니다", "강 건너까지는 가야겠다고 합니다",
                   "바람이 좋아 못 돌아가겠다고 합니다", "이미 너무 멀리 왔다고 합니다"])
    static let block = AuthorEvent(
        id: "block", text: "다음 문장이 떠오르지 않습니다", icon: PixelIcon.page, leavesDesk: false, cure: .muse,
        causes: ["다음 장면이 두 갈래로 갈려 결정을 못 합니다", "어제 쓴 대목이 마음에 들지 않습니다", "주인공이 말을 듣지 않습니다",
                 "비평가의 혹평이 자꾸 떠오릅니다", "쓰려던 단어가 혀끝에서 맴돕니다", "이 장을 통째로 지울까 고민 중입니다",
                 "옆방 피아노 소리에 집중이 안 됩니다", "같은 문장을 쓰고 지우기를 열 번째입니다"],
        returns: ["창밖을 보다 문득 실마리를 잡았습니다", "앞 장을 다시 읽더니 펜을 듭니다", "구겨 버린 종이를 펴서 다시 봅니다",
                  "차를 끓이다 다음 문장이 떠올랐습니다", "일단 쓰고 나중에 고치기로 했습니다", "주인공을 다른 방으로 보내기로 했습니다"],
        cured: ["깃펜을 쥐자 문장이 줄줄 나옵니다", "깃펜을 쥔 손이 저절로 움직입니다", "깃펜 끝에서 다음 장면이 나왔습니다",
                "깃펜을 돌리더니 무릎을 칩니다"],
        refusals: ["깃펜을 만지작거리다 내려놓습니다", "지금은 영감으로 될 일이 아니라고 중얼거립니다", "깃펜을 귀에 꽂고 또 창밖을 봅니다",
                   "영감보다 잠이 필요하다고 합니다", "이 깃펜은 어제 다 썼다고 합니다"])
    static let letter = AuthorEvent(
        id: "letter", text: "밀린 편지에 답장하는 중입니다", icon: PixelIcon.letter, leavesDesk: false, cure: .bell,
        causes: ["출판사에서 독촉 편지가 왔습니다", "고향의 누이에게 답장할 때가 지났습니다", "독자 편지가 한 묶음 왔습니다",
                 "빚쟁이에게 보낼 변명을 써야 합니다", "옛 스승의 편지에 답하지 않은 지 한 달입니다", "청혼 편지에 답을 해야 합니다",
                 "신문사에서 기고 요청이 왔습니다"],
        returns: ["편지를 봉하고 원고로 돌아왔습니다", "봉투 세 개를 쌓아 두고 펜을 듭니다", "우표를 붙이고 자리에 앉았습니다",
                  "답장은 반만 쓰고 나머지는 내일로 미뤘습니다", "편지를 부치고 홀가분하게 돌아왔습니다"],
        cured: ["종소리에 편지를 서랍에 넣습니다", "종이 울리자 편지는 뒷전이 됩니다", "종소리를 듣고 편지지를 덮습니다"],
        refusals: ["이 한 장만 마저 쓰겠다고 합니다", "서명만 하면 된다며 손을 흔듭니다", "답장이 늦으면 큰일 난다고 합니다",
                   "종소리를 듣고도 봉투를 핥고 있습니다"])
    static let dark = AuthorEvent(
        id: "dark", text: "촛불이 꺼졌습니다", icon: PixelIcon.candle, leavesDesk: false, cure: .candle,
        causes: ["바람이 창틈으로 들어왔습니다", "초가 다 타 버렸습니다", "나방이 불에 뛰어들었습니다", "하품하다 입김에 꺼뜨렸습니다",
                 "고양이가 꼬리로 쳤습니다", "심지가 짧아 오래 못 버텼습니다", "문을 세게 닫은 바람에 꺼졌습니다"],
        returns: ["동이 트자 다시 펜을 듭니다", "더듬더듬 새 초를 찾아 불을 붙였습니다", "달빛에 눈이 익어 다시 씁니다",
                  "난로 불씨로 초에 불을 옮겼습니다", "부엌에서 초 토막을 가져왔습니다"],
        cured: ["새 초에 불을 붙이자 방이 환해집니다", "새 초의 불빛에 눈을 가늘게 뜹니다", "초를 세우고 심지를 다듬은 뒤 씁니다",
                "불을 붙이자 그림자가 춤춥니다"],
        refusals: ["어둠 속에서 생각할 게 있다며 초를 물립니다", "이 초는 냄새가 싫다고 합니다", "불을 붙이면 나방이 또 온다고 합니다",
                   "어둠이 오히려 집중이 잘 된다고 합니다"])

    static let byAuthor: [String: AuthorEvent] = [
        "Shakespeare": AuthorEvent(
            id: "author.Shakespeare", text: "극장에 리허설을 보러 갔습니다", icon: PixelIcon.door, leavesDesk: true, cure: .bell,
            causes: ["배우들이 대사를 자꾸 틀립니다", "극장 주인이 급히 불렀습니다", "주연 배우가 목이 쉬었다고 합니다",
                     "무대 장치가 무너졌다는 전갈입니다", "내일 초연인데 3막이 엉망이랍니다", "광대 역이 대사를 멋대로 바꿨습니다"],
            returns: ["리허설을 마치고 돌아왔습니다", "배우들에게 고함을 치고 돌아왔습니다", "무대에서 본 실수를 대본에 고치고 있습니다",
                      "목이 쉬어서 돌아왔습니다"],
            cured: ["종소리에 배우들을 남겨 두고 돌아옵니다", "종소리를 듣고 무대 뒤로 사라집니다", "종이 울리자 연출을 조수에게 맡깁니다"],
            refusals: ["3막이 끝날 때까지는 못 간다고 합니다", "지금 나가면 극이 망한다고 합니다", "종소리를 무대 효과음으로 알아들었습니다",
                       "배우 하나만 더 혼내고 오겠다고 합니다"]),
        "Dickens": AuthorEvent(
            id: "author.Dickens", text: "런던 밤거리를 걸으러 나갔습니다", icon: PixelIcon.boot, leavesDesk: true, cure: .bell,
            causes: ["잠이 오지 않아 런던을 걷습니다", "가로등 아래 사람들 얼굴이 보고 싶어졌습니다", "안개 낀 강변이 그립답니다",
                     "구두 수선공 골목에 쓸 거리가 있답니다", "밤 열두 시에 꼭 걸어야 글이 된답니다", "빈민가 아이들을 보고 와야겠답니다"],
            returns: ["새벽 거리에서 돌아왔습니다", "구두에 안개를 묻히고 돌아왔습니다", "거리에서 들은 말투를 그대로 옮겨 적습니다",
                      "이십 마일을 걸었다며 자리에 앉습니다"],
            cured: ["종소리를 듣고 발길을 돌립니다", "종소리에 마차를 잡아타고 돌아옵니다", "종이 울리자 골목에서 나옵니다"],
            refusals: ["템스 강까지만 가겠다고 합니다", "아직 열 마일밖에 안 걸었다고 합니다", "저 모퉁이 가게 간판만 보고 오겠답니다",
                       "안개 속에서 종소리가 안 들린답니다"]),
        "Poe": AuthorEvent(
            id: "author.Poe", text: "창밖의 까마귀만 바라보고 있습니다", icon: PixelIcon.bird, leavesDesk: false, cure: .muse,
            causes: ["창가에 까마귀 한 마리가 앉았습니다", "까마귀가 자꾸 같은 말을 하는 것 같습니다", "검은 새가 흉상 위에 앉았습니다",
                     "까마귀 눈이 등불처럼 빛납니다", "자정에 문 두드리는 소리를 들었답니다"],
            returns: ["까마귀가 날아가자 펜을 듭니다", "까마귀는 가고 깃털 하나만 남았습니다", "창을 닫고 커튼을 쳤습니다",
                      "까마귀가 한 말을 시로 옮기기 시작합니다"],
            cured: ["깃펜을 쥐자 까마귀가 시가 됩니다", "깃펜 끝에서 검은 날개가 펼쳐집니다", "깃펜을 들자 까마귀가 고개를 끄덕입니다"],
            refusals: ["까마귀가 뭐라고 하는지 더 들어야 한다고 합니다", "깃펜을 들자 까마귀가 울어 손을 멈춥니다", "지금은 아무것도 쓸 수 없다고 합니다",
                       "까마귀가 날아가기 전까지는 안 된답니다"]),
        "Carroll": AuthorEvent(
            id: "author.Carroll", text: "아이들에게 이야기를 들려주러 갔습니다", icon: PixelIcon.page, leavesDesk: true, cure: .bell,
            causes: ["리델 가의 아이들이 이야기를 졸랐습니다", "뱃놀이에서 이야기를 약속했답니다", "앨리스가 토끼 이야기의 뒷부분을 묻습니다",
                     "아이들이 수수께끼를 내 달라고 합니다", "차 모임에 초대받았습니다"],
            returns: ["아이들을 재우고 돌아왔습니다", "이야기를 하다 새 장면이 떠올랐습니다", "아이들이 웃던 대목을 적어 둡니다",
                      "차가 식은 줄도 몰랐다며 돌아왔습니다"],
            cured: ["종소리에 이야기를 다음으로 미룹니다", "종이 울리자 아이들에게 '다음에'라고 합니다", "종소리를 듣고 모자를 집어 듭니다"],
            refusals: ["이야기가 제일 재미있는 데라고 합니다", "아이들이 놓아주지 않는답니다", "수수께끼 하나만 더 내겠답니다",
                       "종소리는 하얀 토끼의 시계 소리랍니다"]),
        "Stevenson": AuthorEvent(
            id: "author.Stevenson", text: "바다 너머만 바라보고 있습니다", icon: PixelIcon.wave, leavesDesk: false, cure: .muse,
            causes: ["남쪽 바다 생각에 잠겼습니다", "항구에 큰 배가 들어왔습니다", "기침이 심해 창가에 앉았습니다",
                     "지도를 펴 놓고 섬 이름을 짓고 있습니다", "갈매기 소리에 고개를 들었습니다"],
            returns: ["바다에서 눈을 떼고 돌아왔습니다", "지도에 보물 표시를 하고 펜을 듭니다", "파도 소리를 문장에 담기 시작합니다",
                      "담요를 두르고 다시 씁니다"],
            cured: ["깃펜을 쥐자 바다가 종이 위로 옵니다", "깃펜 끝에서 돛이 올라갑니다", "깃펜을 들자 섬이 보였답니다"],
            refusals: ["파도 소리를 조금 더 듣겠다고 합니다", "배가 수평선을 넘을 때까지만 보겠답니다", "지금은 글보다 바다랍니다",
                       "기침이 가라앉으면 쓰겠답니다"]),
        "Wilde": AuthorEvent(
            id: "author.Wilde", text: "살롱에 재담을 늘어놓으러 갔습니다", icon: PixelIcon.cup, leavesDesk: true, cure: .bell,
            causes: ["살롱에서 초대장이 왔습니다", "새 경구를 시험해 볼 청중이 필요하답니다", "공작 부인이 만찬에 불렀습니다",
                     "카네이션을 새로 꽂았으니 보여 줘야 한답니다", "어젯밤 농담이 신문에 났답니다"],
            returns: ["재담을 다 풀고 돌아왔습니다", "박수를 받고 기분 좋게 돌아왔습니다", "살롱에서 한 말을 대사로 옮깁니다",
                      "샴페인 기운으로 쓰고 있습니다"],
            cured: ["종소리에 마지막 농담을 남기고 돌아옵니다", "종이 울리자 우아하게 퇴장합니다", "종소리마저 재치 있게 받아치고 돌아옵니다"],
            refusals: ["이 농담만 마저 하겠다고 합니다", "청중을 두고 갈 수는 없답니다", "종소리가 자기 등장 음악이랍니다",
                       "한 잔만 더 하고 오겠답니다"]),
        "Austen": AuthorEvent(
            id: "author.Austen", text: "응접실에서 손님을 맞고 있습니다", icon: PixelIcon.cup, leavesDesk: true, cure: .bell,
            causes: ["이웃 부인이 소식을 들고 왔습니다", "목사님 부부가 차를 마시러 왔습니다", "언니가 편지를 들고 내려왔습니다",
                     "무도회 초대장을 가진 손님이 왔습니다", "새로 이사 온 신사 이야기를 들어야 한답니다"],
            returns: ["손님을 배웅하고 자리에 앉았습니다", "들은 험담을 등장인물에게 나눠 줍니다", "원고를 압지 아래 숨겼다가 꺼냅니다",
                      "손님의 말투를 흉내 내며 씁니다"],
            cured: ["종소리에 손님께 양해를 구합니다", "종이 울리자 공손히 일어납니다", "종소리를 듣고 원고 생각이 났답니다"],
            refusals: ["차가 아직 남았다고 합니다", "이야기가 막 재미있어졌답니다", "손님보다 먼저 일어설 수 없답니다",
                       "종소리를 못 들은 척 찻잔을 듭니다"]),
        "Goethe": AuthorEvent(
            id: "author.Goethe", text: "정원에 식물을 관찰하러 나갔습니다", icon: PixelIcon.leaf, leavesDesk: true, cure: .bell,
            causes: ["정원의 새싹이 궁금해졌습니다", "잎의 변형에 대해 생각할 게 있답니다", "광물 표본이 도착했습니다",
                     "색채론에 쓸 실험을 해야 한답니다", "은행나무 잎을 따러 갔습니다"],
            returns: ["식물 관찰을 마치고 돌아왔습니다", "잎 한 장을 책갈피에 끼우고 돌아왔습니다", "스케치를 덮고 펜을 듭니다",
                      "돌 몇 개를 주머니에 넣고 돌아왔습니다"],
            cured: ["종소리에 노트를 덮고 돌아옵니다", "종이 울리자 흙을 털고 일어섭니다", "종소리를 듣고 온실 문을 닫습니다"],
            refusals: ["잎이 피는 순간을 놓칠 수 없다고 합니다", "실험이 한창이라 못 온답니다", "자연이 부르는데 종이 대수냐고 합니다",
                       "이 표본만 정리하고 오겠답니다"]),
    ]

    static let common = [nap, ink, away, walk, block, letter]

    /// 저장된 이름으로 찾는다. 모르는 이름이면 nil.
    static func byID(_ id: String) -> AuthorEvent? {
        (common + [dark, exhausted] + Array(byAuthor.values)).first { $0.id == id }
    }

    /// 새 상황 하나를 고른다. 작가 고유의 일은 두 배, 밤(20~6시)에는 촛불 꺼짐과 졸음이 더 잦다.
    static func pick(author: String, hour: Int, roll: Double) -> AuthorEvent {
        var pool = common
        if let own = byAuthor[author] { pool += [own, own] }
        if hour >= 20 || hour < 6 { pool += [dark, dark, nap] }
        return pool[min(pool.count - 1, Int(roll * Double(pool.count)))]
    }
}

extension PixelIcon {
    static let coin = [
        "..#####..",
        ".#.....#.",
        "#..###..#",
        "#.#...#.#",
        "#.#...#.#",
        "#.#...#.#",
        "#..###..#",
        ".#.....#.",
        "..#####..",
    ]
    static let bag = [
        "...###...",
        "..#...#..",
        ".#######.",
        ".#.....#.",
        ".#.....#.",
        ".#.....#.",
        ".#.....#.",
        ".#.....#.",
        ".#######.",
    ]
    static let teapot = [
        "...##....",
        "...#.....",
        ".#####...",
        "#.....##.",
        "#.....#.#",
        "#.....##.",
        ".#...#...",
        "..###....",
        ".#####...",
    ]
    static let pencil = [
        "......##.",
        ".....####",
        "....###..",
        "...###...",
        "..###....",
        ".###.....",
        "##.......",
        "#........",
        ".........",
    ]
    static let horn = [
        ".........",
        "........#",
        "......###",
        "...######",
        "#########",
        "#..######",
        ".#...###.",
        "..####...",
        ".........",
    ]
    static let note = [
        "....####.",
        "....#...#",
        "....#....",
        "....#....",
        "....#....",
        "....#....",
        ".####....",
        "#####....",
        ".###.....",
    ]
    static let lamp = [
        "....#....",
        "...###...",
        "..#####..",
        "...###...",
        "....#....",
        ".#######.",
        "#.......#",
        "#.......#",
        ".#######.",
    ]
    static let safe = [
        "#########",
        "#.......#",
        "#..###..#",
        "#..#.#..#",
        "#..###..#",
        "#...#...#",
        "#.......#",
        "#########",
        ".#.....#.",
    ]
    static let pages = [
        "######...",
        "#....#...",
        "#....###.",
        "#....#.#.",
        "######.#.",
        "..#....#.",
        "..#....#.",
        "..#....#.",
        "..######.",
    ]
    static let flame = [
        "....#....",
        "...##....",
        "...###...",
        "..####.#.",
        "..#####..",
        ".###.###.",
        ".##...##.",
        ".##...##.",
        "..#####..",
    ]
    static let wind = [
        "....###..",
        ".......#.",
        "#######..",
        ".........",
        "########.",
        "........#",
        "#######..",
        ".........",
        "..####...",
    ]
    /// 지진계 바늘처럼 튀는 선과 땅.
    static let crack = [
        "....#....",
        "....#....",
        "...#.#...",
        "...#.#...",
        "##.#.#.##",
        "..#...#..",
        "..#...#..",
        ".........",
        "#########",
    ]
    static let leaf = [
        ".....####",
        "...######",
        "..####.##",
        ".####.###",
        ".###.####",
        ".##.####.",
        ".#.####..",
        "#.##.....",
        "#........",
    ]
    static let cup = [
        "..#.#....",
        ".#.#.....",
        ".........",
        "#######..",
        "#.....###",
        "#.....#.#",
        "#.....###",
        ".#####...",
        "#######..",
    ]
    static let door = [
        ".#######.",
        ".#.....#.",
        ".#.....#.",
        ".#.....#.",
        ".#...#.#.",
        ".#.....#.",
        ".#.....#.",
        ".#.....#.",
        "#########",
    ]
    static let boot = [
        "..###....",
        "..###....",
        "..###....",
        "..###....",
        "..####...",
        "..######.",
        "..#######",
        "..#######",
        ".........",
    ]
    static let zzz = [
        "....#####",
        ".......#.",
        "......#..",
        ".....####",
        "####.....",
        "...#.....",
        "..#......",
        ".#.......",
        "####.....",
    ]
    static let page = [
        "#####....",
        "#...##...",
        "#.....#..",
        "#.###.#..",
        "#.....#..",
        "#.###.#..",
        "#.....#..",
        "#.###.#..",
        "#######..",
    ]
    static let drop = [
        "....#....",
        "....#....",
        "...###...",
        "..#####..",
        ".#######.",
        ".#######.",
        ".#######.",
        "..#####..",
        "...###...",
    ]
    static let letter = [
        ".........",
        "#########",
        "##.....##",
        "#.#...#.#",
        "#..#.#..#",
        "#...#...#",
        "#.......#",
        "#########",
        ".........",
    ]
    static let bird = [
        ".........",
        "...##....",
        "..####...",
        "##.####..",
        "..######.",
        "...######",
        "....###..",
        "....#.#..",
        ".........",
    ]
    static let wave = [
        ".........",
        ".........",
        ".##...##.",
        "#..#.#..#",
        "....#....",
        ".##...##.",
        "#..#.#..#",
        "....#....",
        ".........",
    ]
    static let quill = [
        "........#",
        ".......##",
        "......###",
        ".....###.",
        "....###..",
        "...###...",
        "..##.....",
        ".#.......",
        "#........",
    ]
    static let bell = [
        "....#....",
        "...###...",
        "..#####..",
        "..#####..",
        "..#####..",
        ".#######.",
        "#########",
        ".........",
        "....#....",
    ]
    static let candle = [
        "....#....",
        "...###...",
        "....#....",
        "...###...",
        "...###...",
        "...###...",
        "...###...",
        "..#####..",
        ".#######.",
    ]
}

/// 작가가 지금 무엇을 하는지 한 줄. 상황이 없으면 "쓰는 중".
struct AuthorStatusLine: View {
    let event: AuthorEvent?
    var color: Color = .secondary
    var fontSize: CGFloat = 11

    var body: some View {
        HStack(spacing: 4) {
            PixelIconView(rows: event?.icon ?? PixelIcon.quill, color: color, scale: fontSize / 9)
            Text(event?.text ?? "쓰는 중").font(.system(size: fontSize)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}
