import Foundation

// 선택지가 있는 사건과, 그 결과로 잠깐 붙는 보정(부스트). 비평도 같은 보정을 쓴다.

/// 잠깐 붙는 보정. 판매·글자·돌발 상황 확률·거절 확률 가운데 하나에 곱하거나 더한다.
struct ActiveBoost: Codable, Sendable, Equatable, Identifiable {
    enum Kind: String, Codable, Sendable { case sales, characters, eventChance, refusal }
    let kind: Kind
    /// sales·characters·eventChance 는 곱하는 값, refusal 은 더하는 값(0.1 = 10%p).
    let value: Double
    let endsAt: Date
    /// 어디서 왔는지(사건 이름이나 비평). 화면에 보여 준다.
    let rawSource: String
    var source: String { L10n.tr(rawSource) }
    var id: String { "\(rawSource)-\(endsAt.timeIntervalSince1970)" }

    init(kind: Kind, value: Double, endsAt: Date, source: String) {
        self.kind = kind
        self.value = value
        self.endsAt = endsAt
        self.rawSource = source
    }

    enum CodingKeys: String, CodingKey {
        case kind, value, endsAt, rawSource = "source"
    }

    var text: String {
        L10n.tr({ switch kind {
        case .sales: "판매 \(Self.percent(value))"
        case .characters: "글자 \(Self.percent(value))"
        case .eventChance: "돌발 상황 \(Self.percent(value))"
        case .refusal: "거절 \(value >= 0 ? "+" : "")\(Int((value * 100).rounded()))%p"
        } }())
    }

    private static func percent(_ multiplier: Double) -> String {
        let delta = Int(((multiplier - 1) * 100).rounded())
        return delta >= 0 ? "+\(delta)%" : "\(delta)%"
    }
}

/// 지금 살아 있는 보정을 모두 합친 것.
struct Boosts: Sendable, Equatable {
    var sales = 1.0
    var characters = 1.0
    var eventChance = 1.0
    var refusal = 0.0

    init() {}

    init(_ boosts: [ActiveBoost], now: Date) {
        for b in boosts where b.endsAt > now {
            switch b.kind {
            case .sales: sales *= b.value
            case .characters: characters *= b.value
            case .eventChance: eventChance *= b.value
            case .refusal: refusal += b.value
            }
        }
    }
}

/// 선택지 하나. 고르면 효과가 붙고 결과 문장 가운데 하나가 나온다.
struct DilemmaOption: Sendable, Equatable {
    let rawLabel: String
    /// 결과 문장. 여럿이면 무작위.
    let outcomes: [String]
    /// 붙는 보정(종류, 값, 시간).
    var boosts: [(ActiveBoost.Kind, Double, TimeInterval)] = []
    /// 바로 주거나 빼는 아이템 수.
    var items = 0
    /// 바로 더하거나 빼는 글자(비율, 지금 책 기준).
    var characterRatio = 0.0

    var label: String { L10n.tr(rawLabel) }

    init(
        label: String,
        outcomes: [String],
        boosts: [(ActiveBoost.Kind, Double, TimeInterval)] = [],
        items: Int = 0,
        characterRatio: Double = 0.0
    ) {
        self.rawLabel = label
        self.outcomes = outcomes
        self.boosts = boosts
        self.items = items
        self.characterRatio = characterRatio
    }

    static func == (a: DilemmaOption, b: DilemmaOption) -> Bool { a.rawLabel == b.rawLabel }
}

/// 선택지가 있는 사건.
struct Dilemma: Sendable, Equatable {
    let id: String
    let rawTitle: String
    /// 상황 설명. 여럿이면 무작위.
    let texts: [String]
    let options: [DilemmaOption]
    /// 답이 없으면 이 시간 뒤 작가가 알아서 고른다.
    var minutes = 120

    var title: String { L10n.tr(rawTitle) }

    init(id: String, title: String, texts: [String], options: [DilemmaOption], minutes: Int = 120) {
        self.id = id
        self.rawTitle = title
        self.texts = texts
        self.options = options
        self.minutes = minutes
    }

    static func == (a: Dilemma, b: Dilemma) -> Bool { a.id == b.id }
}

/// 진행 중인 사건. 답하거나 시간이 지나면 사라진다.
struct ActiveDilemma: Codable, Sendable, Equatable {
    let id: String
    let rawText: String
    let startedAt: Date
    let expiresAt: Date
    var notified: Bool?

    var text: String { L10n.tr(rawText) }

    init(id: String, text: String, startedAt: Date, expiresAt: Date, notified: Bool? = nil) {
        self.id = id
        self.rawText = text
        self.startedAt = startedAt
        self.expiresAt = expiresAt
        self.notified = notified
    }

    enum CodingKeys: String, CodingKey {
        case id, rawText = "text", startedAt, expiresAt, notified
    }
}

/// 답한 기록.
struct DilemmaRecord: Codable, Sendable, Equatable, Identifiable {
    let dilemma: String
    let rawOption: String
    let rawOutcome: String
    let date: Date
    /// 시간이 지나 작가가 알아서 고른 것.
    var auto: Bool?
    var id: String { "\(dilemma)-\(date.timeIntervalSince1970)" }

    var option: String { L10n.tr(rawOption) }
    var outcome: String { L10n.tr(rawOutcome) }

    init(dilemma: String, option: String, outcome: String, date: Date, auto: Bool? = nil) {
        self.dilemma = dilemma
        self.rawOption = option
        self.rawOutcome = outcome
        self.date = date
        self.auto = auto
    }

    enum CodingKeys: String, CodingKey {
        case dilemma, rawOption = "option", rawOutcome = "outcome", date, auto
    }
}

enum Dilemmas {
    private static let hour: TimeInterval = 3600

    static let all: [Dilemma] = [
        Dilemma(id: "title", title: "제목을 바꾸자는 편집자",
                texts: ["편집자가 제목이 밋밋하다며 바꾸자고 합니다", "편집자가 요즘 유행하는 제목으로 바꾸자고 편지를 보냈습니다",
                        "편집자가 '이 제목으로는 안 팔린다'고 못을 박습니다"],
                options: [
                    DilemmaOption(label: "바꾼다", outcomes: ["새 제목이 서점에 걸렸습니다. 작가는 못마땅한 눈치입니다", "제목은 바뀌었고 작가는 하루 종일 말이 없습니다",
                                                       "편집자는 신이 났고 작가는 원고에 옛 제목을 몰래 적어 둡니다"],
                                  boosts: [(.sales, 1.5, 6 * hour), (.refusal, 0.15, 3 * hour)]),
                    DilemmaOption(label: "지킨다", outcomes: ["작가가 고맙다며 커피를 따릅니다", "편집자는 한숨을 쉬었지만 작가는 신이 났습니다",
                                                       "제목은 그대로입니다. 작가가 평소보다 오래 앉아 있습니다"],
                                  boosts: [(.eventChance, 0.7, 3 * hour), (.sales, 0.85, 6 * hour)]),
                    DilemmaOption(label: "작가에게 맡긴다", outcomes: ["작가는 사흘을 고민하더니 쉼표 하나를 바꿨습니다", "작가가 제목 끝에 느낌표를 붙였다 뗐다 합니다",
                                                            "작가는 '둘 다 싫다'며 세 번째 제목을 냈습니다"],
                                  boosts: [(.sales, 1.15, 6 * hour)]),
                ]),
        Dilemma(id: "serial", title: "연재로 쪼개자는 출판사",
                texts: ["출판사가 선금을 더 줄 테니 작품을 연재로 쪼개자고 합니다", "출판사에서 '매주 한 장씩 신문에 내면 어떻겠냐'고 묻습니다"],
                options: [
                    DilemmaOption(label: "쪼갠다", outcomes: ["선금이 들어왔습니다. 작가는 장마다 끝을 궁리하느라 느려졌습니다", "신문 연재가 시작됐습니다. 마감이 매주 돌아옵니다"],
                                  boosts: [(.characters, 0.9, 3 * hour)], items: 2),
                    DilemmaOption(label: "한 권으로 낸다", outcomes: ["출판사는 아쉬워했지만 책은 한 호흡으로 나옵니다", "작가가 '쪼개면 숨이 끊긴다'며 고개를 저었습니다"],
                                  boosts: [(.sales, 1.2, 6 * hour)]),
                ]),
        Dilemma(id: "critic", title: "비평가의 초대",
                texts: ["이름난 비평가가 저녁 모임에 초대했습니다", "비평가가 '작품 얘기를 나누고 싶다'며 초대장을 보냈습니다"],
                options: [
                    DilemmaOption(label: "간다", outcomes: ["비평가와 밤늦도록 이야기했습니다. 서점에 입소문이 돌 겁니다", "모임에서 작품 한 대목을 낭독했습니다. 박수가 길었습니다"],
                                  boosts: [(.sales, 1.3, 12 * hour), (.characters, 0.85, 2 * hour)]),
                    DilemmaOption(label: "원고를 핑계로 거절한다", outcomes: ["작가는 밤새 원고 앞에 있었습니다", "거절 편지를 쓰고 나니 영감이 돌아왔다고 합니다"],
                                  items: 1),
                    DilemmaOption(label: "편지만 보낸다", outcomes: ["정중한 편지를 보냈습니다. 비평가는 답이 없습니다", "편지에 작품 첫 장을 끼워 보냈습니다"],
                                  boosts: [(.sales, 1.1, 12 * hour)]),
                ]),
        Dilemma(id: "letters", title: "쌓인 팬레터",
                texts: ["독자 편지가 한 묶음 왔습니다. 답장을 바라는 눈치입니다", "우체부가 편지 뭉치를 두고 갔습니다. 절반은 독자입니다"],
                options: [
                    DilemmaOption(label: "직접 답장한다", outcomes: ["작가가 하루를 편지에 썼습니다. 독자들이 기뻐합니다", "답장 쉰 통을 썼습니다. 손목이 아프답니다"],
                                  boosts: [(.sales, 1.2, 12 * hour), (.characters, 0.9, 3 * hour)]),
                    DilemmaOption(label: "비서에게 맡긴다", outcomes: ["비서가 답장을 썼습니다. 작가 서명은 진짜입니다", "비서가 편지를 분류하고 답장은 인쇄했습니다"],
                                  items: -1),
                    DilemmaOption(label: "서랍에 넣는다", outcomes: ["편지는 서랍에 들어갔습니다. 작가가 가끔 서랍을 봅니다", "답장은 다음에. 작가는 조금 찔리는 눈치입니다"],
                                  boosts: [(.refusal, 0.05, 6 * hour)]),
                ]),
        Dilemma(id: "illustrator", title: "삽화가의 제안",
                texts: ["젊은 삽화가가 작품에 그림을 넣고 싶다고 찾아왔습니다", "출판사가 삽화판을 내자고 합니다. 그림값은 작가 몫입니다"],
                options: [
                    DilemmaOption(label: "그림을 넣는다", outcomes: ["삽화 열두 장이 들어갔습니다. 책이 두꺼워졌습니다", "삽화가는 밤새 그렸고 작가는 그림을 보며 몇 줄을 고쳤습니다"],
                                  boosts: [(.sales, 1.4, 6 * hour), (.characters, 0.95, 6 * hour)]),
                    DilemmaOption(label: "글로만 간다", outcomes: ["작가는 '독자가 그릴 것'이라고 했습니다", "삽화가는 다른 작가를 찾아갔습니다"],
                                  boosts: [(.characters, 1.05, 6 * hour)]),
                ]),
        Dilemma(id: "translation", title: "해외 출판 제안",
                texts: ["바다 건너 출판사가 번역 출판을 제안했습니다", "프랑스 출판사가 번역권을 사겠다고 합니다"],
                options: [
                    DilemmaOption(label: "계약한다", outcomes: ["번역이 시작됐습니다. 작가는 번역자의 질문에 답하느라 바쁩니다", "계약서에 서명했습니다. 바다 건너 서점에도 책이 걸립니다"],
                                  boosts: [(.sales, 2.0, 24 * hour), (.characters, 0.9, 24 * hour)]),
                    DilemmaOption(label: "거절한다", outcomes: ["작가는 '내 말은 내 말로'라고 했습니다", "거절했지만 출판사는 다음에 또 오겠답니다"],
                                  items: 1),
                ]),
        Dilemma(id: "holiday", title: "휴가를 바라는 작가",
                texts: ["작가가 사흘만 바닷가에 다녀오고 싶다고 합니다", "작가가 '머리를 식혀야 글이 나온다'며 휴가를 청합니다"],
                options: [
                    DilemmaOption(label: "보내 준다", outcomes: ["작가가 짐을 쌌습니다. 돌아오면 한동안 잘 써질 겁니다", "바닷가에서 엽서가 왔습니다. 글씨가 밝습니다"],
                                  boosts: [(.characters, 0.8, 3 * hour), (.eventChance, 0.5, 24 * hour)]),
                    DilemmaOption(label: "원고부터", outcomes: ["작가는 말없이 펜을 들었습니다. 한동안 삐딱합니다", "'원고부터'라는 말에 작가가 창밖을 오래 봤습니다"],
                                  boosts: [(.refusal, 0.2, 6 * hour), (.characters, 1.05, 3 * hour)]),
                    DilemmaOption(label: "하루만", outcomes: ["하루 다녀왔습니다. 모자가 새것입니다", "하루짜리 휴가였지만 작가는 만족한 눈치입니다"],
                                  boosts: [(.characters, 0.9, 1 * hour), (.eventChance, 0.75, 12 * hour)]),
                ]),
        Dilemma(id: "pen", title: "낡은 펜",
                texts: ["작가의 펜이 갈라졌습니다. 새 펜이 눈에 들어옵니다", "문방구 주인이 '이 펜이면 글이 저절로 나온다'고 합니다"],
                options: [
                    DilemmaOption(label: "새 펜을 산다", outcomes: ["새 펜을 쥔 손이 가볍습니다", "펜촉이 종이 위를 미끄러집니다"],
                                  boosts: [(.characters, 1.1, 24 * hour)], items: -1),
                    DilemmaOption(label: "낡은 펜으로 버틴다", outcomes: ["작가는 낡은 펜이 손에 익었다고 합니다", "갈라진 펜촉을 칼로 다듬어 씁니다"],
                                  boosts: [(.eventChance, 1.2, 12 * hour)]),
                ]),
        Dilemma(id: "rival", title: "라이벌의 신작",
                texts: ["라이벌 작가의 신작이 서점에 깔렸습니다. 작가가 신경을 씁니다", "신문에 라이벌의 신작 광고가 크게 났습니다"],
                options: [
                    DilemmaOption(label: "사다 준다", outcomes: ["작가가 밤새 읽더니 '나쁘지 않다'고 했습니다", "책을 받은 작가가 밑줄을 긋기 시작했습니다"],
                                  boosts: [(.characters, 1.08, 12 * hour)], items: -1),
                    DilemmaOption(label: "모른 척한다", outcomes: ["작가는 신문을 뒤집어 놓았습니다", "'신경 안 쓴다'고 세 번 말했습니다"],
                                  boosts: [(.eventChance, 1.3, 6 * hour)]),
                    DilemmaOption(label: "서평을 쓰게 한다", outcomes: ["작가가 서평을 썼습니다. 날카롭습니다", "서평이 신문에 실렸습니다. 작가 이름이 함께 났습니다"],
                                  boosts: [(.sales, 1.25, 12 * hour), (.characters, 0.9, 2 * hour)]),
                ]),
        Dilemma(id: "student", title: "제자가 되고 싶다는 청년",
                texts: ["원고 뭉치를 든 청년이 제자로 받아 달라고 찾아왔습니다", "편지 열두 통을 보낸 끝에 청년이 직접 문을 두드렸습니다",
                        "출판사가 '재능 있는 청년'을 보냈습니다. 청년은 겁에 질려 있습니다"],
                options: [
                    DilemmaOption(label: "받아 준다", outcomes: ["청년이 잉크를 갈고 종이를 자릅니다. 작가는 가르치느라 느립니다", "제자가 생겼습니다. 질문이 많습니다",
                                                       "청년이 첫날부터 원고를 베껴 씁니다. 글씨가 좋습니다"],
                                  boosts: [(.characters, 0.9, 6 * hour), (.eventChance, 0.8, 24 * hour)], items: 1),
                    DilemmaOption(label: "원고만 읽어 준다", outcomes: ["작가가 원고에 빨간 줄을 잔뜩 그어 돌려줬습니다", "청년은 울면서 갔고 작가는 '다 그렇게 큰다'고 합니다"],
                                  boosts: [(.characters, 0.95, 2 * hour)]),
                    DilemmaOption(label: "돌려보낸다", outcomes: ["청년은 다른 작가를 찾아갔습니다", "작가는 '제자는 책으로 두는 것'이라고 했습니다"],
                                  boosts: [(.refusal, 0.05, 6 * hour)]),
                    DilemmaOption(label: "심부름꾼으로 쓴다", outcomes: ["청년이 우체국과 문방구를 뛰어다닙니다", "제자 대신 심부름꾼이 생겼습니다. 청년은 그래도 좋답니다"],
                                  boosts: [(.characters, 0.97, 3 * hour)], items: 2),
                ]),
        Dilemma(id: "painter", title: "초상화를 그리겠다는 화가",
                texts: ["화가가 작가의 초상화를 그리고 싶다며 이젤을 들고 왔습니다", "출판사가 책 앞장에 넣을 초상화를 주문했습니다. 화가가 두 시간을 달라고 합니다"],
                options: [
                    DilemmaOption(label: "앉아 준다", outcomes: ["작가가 두 시간 동안 꼼짝 않고 앉았습니다. 목이 뻐근하답니다", "초상화가 나왔습니다. 작가는 코가 크게 나왔다고 합니다"],
                                  boosts: [(.characters, 0.85, 2 * hour), (.sales, 1.2, 12 * hour)]),
                    DilemmaOption(label: "쓰는 모습을 그리게 한다", outcomes: ["화가가 책상 옆에 앉아 그립니다. 작가는 신경 쓰이는 눈치입니다", "쓰는 모습이 그려졌습니다. 펜이 조금 흔들렸답니다"],
                                  boosts: [(.characters, 0.95, 2 * hour), (.sales, 1.1, 12 * hour), (.eventChance, 1.2, 2 * hour)]),
                    DilemmaOption(label: "거절한다", outcomes: ["작가는 '글이 초상화'라고 했습니다", "화가는 창밖에서 몰래 그리고 갔습니다"],
                                  boosts: [(.characters, 1.03, 3 * hour)]),
                ]),
        Dilemma(id: "lecture", title: "강연 요청",
                texts: ["대학에서 강연을 요청했습니다. 사례는 두둑합니다", "문학회가 저녁 강연을 부탁했습니다. 청중이 백 명이랍니다"],
                options: [
                    DilemmaOption(label: "수락한다", outcomes: ["강연은 길었고 박수는 짧았습니다. 그래도 책은 팔렸습니다", "작가가 원고를 들고 연단에 섰습니다. 두 장을 빼먹었답니다"],
                                  boosts: [(.sales, 1.35, 12 * hour), (.characters, 0.8, 3 * hour)], items: 1),
                    DilemmaOption(label: "원고를 대신 보낸다", outcomes: ["대독으로 대신했습니다. 청중은 아쉬워했습니다", "원고만 보냈습니다. 누군가 읽었다는데 누군지 모릅니다"],
                                  boosts: [(.sales, 1.1, 12 * hour)]),
                    DilemmaOption(label: "거절한다", outcomes: ["작가는 '말은 종이에만'이라고 했습니다", "거절 편지에 사과를 세 번 썼습니다"],
                                  boosts: [(.characters, 1.05, 3 * hour)]),
                ]),
        Dilemma(id: "cat", title: "창틀의 고양이",
                texts: ["길고양이가 창틀에 앉아 안을 들여다봅니다", "고양이가 원고 위에 올라앉았습니다. 비킬 생각이 없습니다"],
                options: [
                    DilemmaOption(label: "들인다", outcomes: ["고양이가 책상 한구석을 차지했습니다. 작가가 가끔 말을 겁니다", "고양이 이름은 '잉크'가 됐습니다"],
                                  boosts: [(.eventChance, 0.85, 24 * hour), (.characters, 0.97, 6 * hour)]),
                    DilemmaOption(label: "우유만 준다", outcomes: ["고양이가 우유를 먹고 갔습니다. 내일 또 올 겁니다", "우유 접시가 창틀에 놓였습니다"],
                                  boosts: [(.eventChance, 0.95, 12 * hour)]),
                    DilemmaOption(label: "내보낸다", outcomes: ["고양이가 원고 한 장을 물고 갔습니다", "고양이는 나갔고 작가는 조금 섭섭한 눈치입니다"],
                                  boosts: [(.refusal, 0.05, 3 * hour)]),
                    DilemmaOption(label: "작가에게 맡긴다", outcomes: ["작가가 고양이와 한참 눈싸움을 했습니다. 고양이가 이겼습니다", "작가가 고양이에게 원고를 읽어 줬습니다. 고양이는 잤습니다"],
                                  boosts: [(.characters, 0.95, 1 * hour), (.eventChance, 0.9, 12 * hour)]),
                ]),
        Dilemma(id: "landlord", title: "집세를 올리겠다는 집주인",
                texts: ["집주인이 집세를 올리겠다고 합니다. 안 되면 나가랍니다", "집주인이 '작가는 집세를 늦게 낸다'며 올려 받겠답니다"],
                options: [
                    DilemmaOption(label: "올려 준다", outcomes: ["집세를 올려 줬습니다. 작가는 커피를 줄이기로 했습니다", "집주인은 만족했고 작가는 가방을 열어 봤습니다"],
                                  items: -2),
                    DilemmaOption(label: "책으로 갚는다", outcomes: ["집주인에게 서명본을 건넸습니다. 집주인은 읽지 않을 겁니다", "집주인이 책을 받고 '다음 달도'라고 했습니다"],
                                  boosts: [(.sales, 0.95, 6 * hour)], items: -1),
                    DilemmaOption(label: "이사한다", outcomes: ["짐을 쌌습니다. 새 집은 창이 큽니다", "이사는 하루가 걸렸고 원고는 두 번 셌습니다"],
                                  boosts: [(.characters, 0.7, 4 * hour), (.eventChance, 0.8, 24 * hour)]),
                    DilemmaOption(label: "버틴다", outcomes: ["작가가 문을 잠갔습니다. 집주인이 매일 두드립니다", "버티는 중입니다. 작가는 신경이 곤두섰습니다"],
                                  boosts: [(.eventChance, 1.3, 12 * hour), (.refusal, 0.1, 6 * hour)]),
                ]),
        Dilemma(id: "plagiarism", title: "표절 시비",
                texts: ["한 신문이 작가의 한 대목이 남의 것과 닮았다고 썼습니다", "익명의 편지가 '그 장면은 어디서 본 것'이라고 합니다"],
                options: [
                    DilemmaOption(label: "반박문을 낸다", outcomes: ["반박문이 실렸습니다. 날카로워서 더 화제가 됐습니다", "작가가 반박문에 원고 날짜를 적었습니다. 신문은 조용해졌습니다"],
                                  boosts: [(.sales, 1.25, 12 * hour), (.characters, 0.9, 3 * hour)]),
                    DilemmaOption(label: "무시한다", outcomes: ["작가는 신문을 접었습니다. 소문은 한 주 갔습니다", "아무 말도 안 했습니다. 작가는 속이 끓습니다"],
                                  boosts: [(.sales, 0.9, 12 * hour), (.refusal, 0.1, 6 * hour)]),
                    DilemmaOption(label: "그 대목을 고친다", outcomes: ["그 장면을 다시 썼습니다. 작가는 '원래 것이 나았다'고 합니다", "고쳐 썼습니다. 어쩐지 더 길어졌습니다"],
                                  boosts: [(.characters, 0.85, 2 * hour), (.sales, 1.05, 12 * hour)]),
                ]),
        Dilemma(id: "neighbor", title: "시끄러운 이웃",
                texts: ["옆집이 피아노를 들였습니다. 아침부터 연습합니다", "위층에서 망치 소리가 납니다. 며칠 간답니다"],
                options: [
                    DilemmaOption(label: "항의한다", outcomes: ["이웃이 미안하다며 저녁에만 치기로 했습니다", "항의하러 갔다가 차를 얻어 마시고 왔습니다"],
                                  boosts: [(.eventChance, 0.9, 12 * hour)]),
                    DilemmaOption(label: "귀마개를 산다", outcomes: ["귀마개를 꼈습니다. 작가는 자기 펜 소리도 안 들린답니다", "귀마개 덕에 조용합니다. 초인종도 못 듣습니다"],
                                  boosts: [(.characters, 1.05, 12 * hour)], items: -1),
                    DilemmaOption(label: "참는다", outcomes: ["작가는 피아노에 맞춰 쓰기 시작했습니다. 문장이 빨라졌습니다", "참았습니다. 작가 눈 밑이 어둡습니다"],
                                  boosts: [(.eventChance, 1.2, 12 * hour), (.characters, 1.03, 6 * hour)]),
                    DilemmaOption(label: "카페로 간다", outcomes: ["작가가 카페 구석에 자리를 잡았습니다. 커피값이 듭니다", "카페는 더 시끄러웠습니다. 그래도 썼습니다"],
                                  boosts: [(.eventChance, 0.8, 6 * hour)], items: -1),
                ]),
        Dilemma(id: "dedication", title: "헌사를 부탁하는 후원자",
                texts: ["오랜 후원자가 이번 책을 자기에게 바쳐 달라고 합니다", "출판사가 '후원자 이름을 앞장에 넣으면 선금을 더 준다'고 합니다"],
                options: [
                    DilemmaOption(label: "헌사를 쓴다", outcomes: ["앞장에 후원자 이름이 들어갔습니다. 후원자는 열 권을 샀습니다", "헌사는 한 줄입니다. 후원자는 액자에 넣었습니다"],
                                  boosts: [(.sales, 1.2, 12 * hour)], items: 1),
                    DilemmaOption(label: "어머니에게 바친다", outcomes: ["작가는 어머니에게 바쳤습니다. 후원자는 이해했다고 합니다", "헌사는 '어머니께'. 후원자는 다음 책을 기다리기로 했습니다"],
                                  boosts: [(.characters, 1.05, 6 * hour)]),
                    DilemmaOption(label: "헌사 없이 낸다", outcomes: ["앞장이 비었습니다. 작가는 '책이 헌사'라고 합니다", "헌사 없이 냈습니다. 후원자가 편지를 보냈습니다. 짧았습니다"],
                                  boosts: [(.sales, 0.9, 6 * hour), (.eventChance, 0.9, 12 * hour)]),
                ]),
        Dilemma(id: "festival", title: "문학제 초청",
                texts: ["이웃 도시 문학제에서 초청장이 왔습니다. 사흘 일정입니다", "문학제가 작가를 올해의 손님으로 모시겠답니다"],
                options: [
                    DilemmaOption(label: "간다", outcomes: ["사흘 동안 서명만 했습니다. 손목에 붕대를 감았습니다", "문학제에서 낭독했습니다. 책이 동났답니다"],
                                  boosts: [(.sales, 1.6, 24 * hour), (.characters, 0.75, 6 * hour)]),
                    DilemmaOption(label: "하루만 간다", outcomes: ["하루 다녀왔습니다. 기차에서 두 장을 썼습니다", "첫날만 얼굴을 비쳤습니다. 그래도 책은 팔렸습니다"],
                                  boosts: [(.sales, 1.3, 12 * hour), (.characters, 0.9, 3 * hour)]),
                    DilemmaOption(label: "거절한다", outcomes: ["작가는 '원고가 손님'이라고 했습니다", "거절했습니다. 문학제는 라이벌을 불렀답니다"],
                                  boosts: [(.characters, 1.05, 6 * hour), (.sales, 0.95, 12 * hour)]),
                    DilemmaOption(label: "원고만 보낸다", outcomes: ["원고 일부를 보냈습니다. 누군가 대신 읽었답니다", "원고는 갔고 작가는 남았습니다"],
                                  boosts: [(.sales, 1.1, 12 * hour)]),
                ]),
    ]

    static func byID(_ id: String) -> Dilemma? { all.first { $0.id == id } }
    static func pick(roll: Double) -> Dilemma { all[min(all.count - 1, Int(roll * Double(all.count)))] }
}
