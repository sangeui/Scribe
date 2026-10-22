import Foundation

// 작가가 하는 말. 초상화를 눌렀을 때(`Chatter`), 손님 작가와 말다툼할 때(`Quarrels`), 서점의 문단 소식(`Gossip`).

/// 초상화를 눌렀을 때 하는 말. 상황(돌발 상황·사건·비평·기분·시각·진행)에 맞는 말과 작가다운 말을 섞는다.
@MainActor
enum Chatter {
    static let generic = [
        "지금 쓰는 중입니다", "네?", "펜을 놓지 않았습니다", "한 줄만 더 쓰고요", "잉크가 아직 남았습니다",
        "오늘 분량은 채울 겁니다", "무슨 일이십니까", "종이가 모자라진 않습니다", "읽어 보시겠습니까. 아직은 아닙니다",
        "커피가 식었습니다", "창문 좀 열어 주시겠습니까", "이 문장이 잘 안 풀립니다", "조금만 조용히", "손이 안 보이시나요. 바쁩니다",
    ]
    static let byAuthor: [String: [String]] = [
        "Shakespeare": ["배우들이 대사를 또 틀렸습니다", "극장은 늘 돈이 모자랍니다", "운율이 안 맞으면 밤에 잠이 안 옵니다", "5막이 제일 어렵습니다", "여왕께서 보신답니다. 고쳐야겠군요", "펜은 칼보다 느립니다"],
        "Dickens": ["마감이 내일입니다. 늘 그렇듯", "런던은 안개가 걷히질 않습니다", "이번 장에서 또 누가 죽어야 합니다", "독자가 편지로 결말을 바꾸라 합니다", "신문사는 글자 수로 돈을 줍니다", "거리의 아이들이 이야기를 줍니다"],
        "Poe": ["까마귀가 또 왔습니다", "밤이 더 조용합니다", "심장 소리가 들리지 않습니까", "운율은 어둠에서 옵니다", "이 집은 어딘가 기울어 있습니다", "술은 아닙니다. 잉크입니다"],
        "Carroll": ["토끼가 시계를 보고 갔습니다", "수수께끼 하나 내 볼까요", "차 모임은 여섯 시입니다. 늘", "말은 뜻보다 소리가 먼저입니다", "거울 저쪽은 글씨가 뒤집혀 있습니다", "논리도 놀이입니다"],
        "Stevenson": ["바람이 바뀌었습니다", "지도부터 그려야 이야기가 됩니다", "기침이 좀 납니다. 괜찮습니다", "바다가 종이 위로 들어옵니다", "보물은 늘 마지막 장에", "짐을 쌀까 하다 말았습니다"],
        "Wilde": ["침묵도 재치가 있다면 좋겠군요", "카네이션이 시들기 전에 끝내겠습니다", "인용될 말을 쓰는 중입니다", "진지한 건 제 취향이 아닙니다", "살롱에 늦었습니다. 글이 먼저지만", "두 번 읽을 가치가 있는 문장만 남깁니다"],
        "Austen": ["차를 한 잔 더 우렸습니다", "이웃이 또 혼담을 가져왔습니다", "응접실 문을 닫고 씁니다", "비 오는 날이 글에는 낫습니다", "편지를 쓰듯 씁니다", "결혼은 소설 끝에서만"],
        "Goethe": ["잎 하나에도 법칙이 있습니다", "색은 빛과 어둠 사이에서 납니다", "광물 상자를 정리하다 왔습니다", "이탈리아가 그립습니다", "2부는 평생 걸릴지도 모릅니다", "시도 학문입니다"],
    ]
    static let poked = ["그만 찌르세요", "원고에 손자국이 납니다", "펜이 흔들립니다", "세 번째입니다", "눈치챘습니다. 그만", "간지럽습니다", "저도 할 일이 있습니다", "이러면 한 줄도 못 씁니다"]
    static let byEvent: [String: [String]] = [
        "nap": ["……", "(코 고는 소리)", "음냐…", "……오 분만……"],
        "ink": ["잉크가 없습니다. 보시다시피", "마른 펜으로는 못 씁니다", "잉크병이 비었다니까요"],
        "away": ["(빈 의자가 삐걱입니다)", "(아무도 없습니다)", "(창문이 열려 있습니다)"],
        "walk": ["(코트가 없습니다)", "(발자국만 남았습니다)"],
        "block": ["안 떠오릅니다", "한 글자도 안 나옵니다", "말 걸지 마세요. 아니, 걸어 주세요", "머리가 하얗습니다"],
        "letter": ["편지를 다 읽고요", "답장을 써야 합니다", "이 편지는 좀 깁니다"],
        "dark": ["초가 꺼졌습니다", "어둡습니다", "불 좀", "손이 안 보입니다"],
    ]
    static let waiting = ["쓸 걸 주셔야 쓰지요", "기다리는 중입니다", "토큰이 안 옵니다", "펜을 들고 있습니다. 보이시죠"]
    static let alone = ["계셨군요", "혼자 잘 쓰고 있었습니다", "돌아오셨군요. 몇 장 늘었습니다"]
    static let slacking = ["아, 네. 쓰고 있었습니다", "기지개만 켠 겁니다", "창밖에 뭐가 있어서요", "종이비행기는 제 것이 아닙니다"]
    static let dawn = ["새벽입니다. 주무시지요", "아직 안 주무셨습니까", "새벽 글은 아침에 읽으면 부끄럽습니다"]
    static let night = ["밤이 깊었습니다", "촛불이 하나 남았습니다", "밤에 쓴 글은 아침에 고칩니다"]
    static let nearlyDone = ["마지막 장입니다. 조용히", "거의 다 왔습니다", "끝이 보입니다", "탈고가 코앞입니다. 숨 쉬지 마세요"]
    static let justStarted = ["첫 장은 늘 어렵습니다", "이제 막 시작했습니다", "첫 문장을 세 번 고쳤습니다"]
    static let noItems = ["가방이 비었군요. 커피라도", "아이템이 없으면 제가 고생합니다", "커피 한 잔이면 더 쓸 텐데요"]
    static let fullBag = ["가방이 무겁습니다", "커피를 그렇게 쌓아 두면 식습니다", "아이템을 좀 쓰시지요"]
    static let pendingDilemma = ["답을 기다리고 있습니다. 편지가 왔잖습니까", "결정은 당신 몫입니다", "제 뜻은 묻지 마세요. 아니, 물어 주세요"]
    static let praised = ["신문 보셨습니까", "비평가도 가끔 옳습니다", "오늘은 기분이 좋습니다"]
    static let panned = ["신문 얘기는 꺼내지 마세요", "그 비평가는 책을 안 읽습니다", "오늘은 말을 걸지 마세요"]
    static let guest = ["손님이 와 있습니다. 조용히", "둘이 쓰니 두 배로 시끄럽습니다", "손님 커피까지 제가 타야 합니까"]

    /// 상황에 맞는 말 하나. `pokes` 는 몇 초 안에 연달아 누른 횟수. `rolls` 는 0..<1 두 개.
    static func line(author: String, progress: WritingProgress, mood: Mood, now: Date, pokes: Int, rolls: (Double, Double)) -> String {
        func pick(_ pool: [String], _ roll: Double) -> String { pool[min(pool.count - 1, Int(roll * Double(pool.count)))] }
        if pokes >= 3 { return pick(poked, rolls.0) }
        var situational: [String] = []
        if let event = progress.event {
            situational += byEvent[event.id] ?? byEvent["away"]!
            // 돌발 상황 중에는 그 말만 한다.
            return pick(situational, rolls.0)
        }
        if progress.dilemma != nil { situational += pendingDilemma }
        if let review = progress.reviews.first, now.timeIntervalSince(review.date) < 86_400, review.affected == true {
            situational += review.stars >= 4 ? praised : review.stars <= 2 ? panned : []
        }
        switch mood {
        case .waiting: situational += waiting
        case .alone: situational += alone
        case .slacking: situational += slacking
        default: break
        }
        if progress.guestAuthor != nil { situational += guest }
        switch DayPart.current(now) {
        case .dawn: situational += dawn
        case .night: situational += night
        default: break
        }
        if progress.fraction >= 0.9 { situational += nearlyDone } else if progress.fraction < 0.03 { situational += justStarted }
        let items = ItemKind.allCases.reduce(0) { $0 + progress.count($1) }
        if items == 0 { situational += noItems } else if items >= 20 { situational += fullBag }
        let flavor = (byAuthor[author] ?? []) + generic
        // 상황에 맞는 말이 있으면 열에 일곱은 그것을, 나머지는 작가다운 말을.
        if !situational.isEmpty, rolls.1 < 0.7 { return pick(situational, rolls.0) }
        return pick(flavor, rolls.0)
    }
}

/// 손님 작가와의 말다툼. 둘이 한 마디씩 주고받는다. 둘의 조합에 맞는 말이 있으면 그것을, 없으면 이름을 넣는 말을.
@MainActor
enum Quarrels {
    struct Exchange: Sendable {
        let a: String
        let b: String
        let aLine: String
        let bLine: String
    }

    /// 특정한 둘 사이의 말. 순서는 상관없다(바뀌면 줄도 바꾼다).
    static let pairs: [Exchange] = [
        Exchange(a: "Shakespeare", b: "Wilde", aLine: "그 경구는 내 대사에서 가져간 것 아니오", bLine: "빌린 게 아니라 고쳐 쓴 겁니다. 훨씬 낫게"),
        Exchange(a: "Shakespeare", b: "Wilde", aLine: "희극은 웃기면 되는 게 아니오", bLine: "그래서 당신 희극은 안 웃긴 겁니까"),
        Exchange(a: "Poe", b: "Carroll", aLine: "까마귀는 '다시는'이라고 했소", bLine: "제 까마귀는 책상과 닮은 점을 묻던데요"),
        Exchange(a: "Poe", b: "Carroll", aLine: "운율이 너무 가볍소", bLine: "무거운 운율은 가라앉습니다"),
        Exchange(a: "Dickens", b: "Austen", aLine: "응접실에서 무슨 소설이 나오겠소", bLine: "거리에서 쓴 소설은 늘 길더군요"),
        Exchange(a: "Dickens", b: "Austen", aLine: "연재는 독자를 기다리게 하는 기술이오", bLine: "기다리게 하는 건 신랑감으로 충분합니다"),
        Exchange(a: "Goethe", b: "Shakespeare", aLine: "당신 작품은 번역하면서 많이 고쳤소", bLine: "독일어로도 운율이 남았기를"),
        Exchange(a: "Goethe", b: "Poe", aLine: "어둠도 빛이 있어야 보이는 법이오", bLine: "빛은 어둠을 모릅니다"),
        Exchange(a: "Stevenson", b: "Poe", aLine: "보물은 땅에 묻는 거요", bLine: "저는 심장을 마루 밑에 묻습니다"),
        Exchange(a: "Stevenson", b: "Dickens", aLine: "배 타 본 적은 있소", bLine: "템스강이면 충분하오"),
        Exchange(a: "Wilde", b: "Austen", aLine: "결혼은 상상력의 패배입니다", bLine: "결혼 안 한 사람이 늘 그렇게 말하더군요"),
        Exchange(a: "Wilde", b: "Dickens", aLine: "가난을 그렇게 길게 쓸 일입니까", bLine: "가난은 원래 길게 가오"),
        Exchange(a: "Carroll", b: "Austen", aLine: "차 모임에 초대해도 될까요", bLine: "여섯 시에 멈춘 시계라면 사양합니다"),
        Exchange(a: "Goethe", b: "Wilde", aLine: "젊은이, 색채론은 읽었소", bLine: "빛은 안 읽어도 압니다. 전 늘 빛 쪽에 섭니다"),
        Exchange(a: "Stevenson", b: "Carroll", aLine: "지도 없이 이야기를 쓴다고", bLine: "지도는 땅 크기로 그리면 됩니다. 땅 위에 펼치고"),
        Exchange(a: "Goethe", b: "Dickens", aLine: "장편에도 형식이 있어야 하오", bLine: "마감이 형식이오"),
    ]

    /// 누구와도 쓸 수 있는 말. {A} 가 말하고 {B} 가 받는다.
    static let generic: [(String, String)] = [
        ("그 의자는 내 것이오", "앉은 사람이 임자입니다"),
        ("펜 소리가 너무 큽니다", "당신 한숨 소리보다는 작소"),
        ("창문을 열면 안 되오", "닫으면 잉크가 안 마릅니다"),
        ("커피를 다 마셨군요", "홍차는 남았소"),
        ("{B}, 그 문장은 내 것 같은데", "비슷한 생각은 누구나 합니다"),
        ("이 책상은 둘이 쓰기엔 좁소", "그럼 당신이 서서 쓰시오"),
        ("그 대목은 결말이 너무 쉽소", "쉬운 결말을 쓰기가 제일 어렵소"),
        ("초를 하나 더 켜도 되겠소", "책상이 타면 당신 탓이오"),
        ("{B}의 독자는 참을성이 많더군", "{A}의 독자는 숫자가 적더군"),
        ("오늘 몇 장 썼소", "묻는 사람보다는 많이"),
        ("비평가가 당신 책을 칭찬했다지요", "그 사람은 내 책도 칭찬했소. 작년에"),
        ("내 원고를 보지 마시오", "볼 게 있어야 보지"),
        ("손님은 손님답게 조용히", "주인이 먼저 조용하면"),
        ("종이를 그렇게 쓰면 모자라오", "글이 길면 종이가 드는 법"),
    ]

    /// 한 번의 말다툼. `rolls` 는 0..<1 두 개.
    static func exchange(host: String, guest: String, rolls: (Double, Double)) -> (host: String, guest: String) {
        let hostName = Library.books.first { $0.authorShort == host }?.displayAuthorShort ?? host
        let guestName = Library.books.first { $0.authorShort == guest }?.displayAuthorShort ?? guest
        let matched = pairs.filter { ($0.a == host && $0.b == guest) || ($0.a == guest && $0.b == host) }
        // 둘의 말이 있어도 가끔은 일반적인 말다툼을 한다.
        if !matched.isEmpty, rolls.1 < 0.6 {
            let e = matched[min(matched.count - 1, Int(rolls.0 * Double(matched.count)))]
            return e.a == host ? (e.aLine, e.bLine) : (e.bLine, e.aLine)
        }
        let g = generic[min(generic.count - 1, Int(rolls.0 * Double(generic.count)))]
        func fill(_ s: String) -> String {
            Format.resolve(s.replacingOccurrences(of: "{A}", with: hostName).replacingOccurrences(of: "{B}", with: guestName))
        }
        return (fill(g.0), fill(g.1))
    }
}

/// 작가 교대. 책이 다음 작가 차례로 넘어갈 때 떠나는 작가와 오는 작가가 한 마디씩 한다.
@MainActor
enum Handoffs {
    /// 특정한 둘 사이의 말. (떠나는 작가, 오는 작가, 떠나는 말, 오는 말)
    static let pairs: [(from: String, to: String, leaving: String, arriving: String)] = [
        ("Shakespeare", "Dickens", "무대는 치웠소. 거리는 당신 몫이오", "런던 안개가 벌써 들어오는군요"),
        ("Dickens", "Poe", "난로는 켜 두었소", "끄겠소. 어둠이 편하오"),
        ("Poe", "Carroll", "까마귀가 책상 위에 있소. 건드리지 마시오", "토끼가 무서워하겠는데요"),
        ("Carroll", "Stevenson", "차는 여섯 시에 식었습니다", "항해엔 럼이 낫소"),
        ("Stevenson", "Wilde", "지도는 서랍에 넣어 두었소", "지도보다 거울이 필요한데요"),
        ("Wilde", "Austen", "카네이션은 꽃병에 두고 갑니다", "응접실에는 어울리겠군요"),
        ("Austen", "Goethe", "차 한 잔 남겨 두었어요", "고맙소. 광물 상자는 어디 두면 되오"),
        ("Goethe", "Shakespeare", "잎의 변형에 대해 적어 두었소. 읽어 보시오", "운율이 없으면 안 읽소"),
        ("Dickens", "Shakespeare", "마감이 닷새 남았소. 참고하시오", "마감은 극장 주인이나 지키는 것이오"),
        ("Poe", "Dickens", "초는 반쯤 남았소", "충분하오. 나는 가스등이 있소"),
    ]
    /// 누구와도 쓰는 말. {A} 떠나는 작가, {B} 오는 작가.
    static let generic: [(String, String)] = [
        ("책상은 치우고 가오", "잉크는 남겨 두셨군요. 고맙소"),
        ("의자가 좀 삐걱거리오", "제 의자는 더 심했소"),
        ("펜촉은 새것이오. 아껴 쓰시오", "펜촉은 제 걸 쓰겠소"),
        ("창문은 열어 두었소", "닫겠소. 종이가 날리오"),
        ("{B}, 늦었군요", "{A}, 아직 안 갔군요"),
        ("원고는 가져가오. 보지 마시오", "볼 게 있어야 보지"),
        ("독자들에게 안부 전해 주시오", "제 독자들이오. 이제"),
        ("등잔 기름이 얼마 없소", "밤엔 안 쓰오"),
        ("행운을 비오", "운은 필요 없소. 시간이면 되오"),
        ("커피는 찬장 두 번째 칸이오", "홍차는요"),
        ("다음은 당신 차례요. 잘 써 보시오", "지켜보시오"),
        ("편집자가 성미가 급하오. 조심하시오", "편집자는 다 그렇소"),
    ]

    static func exchange(from: String, to: String, rolls: (Double, Double)) -> (leaving: String, arriving: String) {
        let fromName = Library.books.first { $0.authorShort == from }?.displayAuthorShort ?? from
        let toName = Library.books.first { $0.authorShort == to }?.displayAuthorShort ?? to
        let matched = pairs.filter { $0.from == from && $0.to == to }
        if let m = matched.first, rolls.1 < 0.7 { return (m.leaving, m.arriving) }
        let g = generic[min(generic.count - 1, Int(rolls.0 * Double(generic.count)))]
        func fill(_ s: String) -> String { Format.resolve(s.replacingOccurrences(of: "{A}", with: fromName).replacingOccurrences(of: "{B}", with: toName)) }
        return (fill(g.0), fill(g.1))
    }
}

/// 서점의 문단 소식. 한 주 동안 같은 소식이 보이도록 주 시작 시각으로 난수를 고정한다. 이름을 끼운 자리의 조사는 받침에 맞춘다.
@MainActor
enum Gossip {
    /// 두 작가 사이의 소문. {A}, {B}. 말끝을 섞어 같은 투가 이어지지 않게 한다.
    static let rumors = [
        "{A}(이|가) {B}의 신작을 몰래 샀다는 소문", "{A}(과|와) {B}(이|가) 같은 카페에서 등을 돌리고 앉았다고 합니다",
        "{B}(이|가) {A}의 서평을 쓰겠다고 했다가 말았다는 이야기", "{A}(이|가) {B}에게 빌려준 펜을 아직 못 받았답니다",
        "{A}(과|와) {B}(이|가) 같은 비평가를 저녁에 초대했고, 비평가는 둘 다 거절했습니다", "{B}(은|는) {A}의 제목을 자기가 먼저 떠올렸다고 합니다",
        "{A}(이|가) {B}의 낭독회에 갔다가 중간에 나왔다고들 합니다", "{A}(과|와) {B}(이|가) 쉼표 자리를 두고 편지로 다툽니다",
        "{B}(은|는) {A}의 책을 읽고 '길다'고만 했습니다", "{A}(이|가) {B}의 집 앞을 두 번 지나갔습니다. 들어가지는 않았습니다",
        "{A}(과|와) {B}(이|가) 같은 날 같은 출판사에 원고를 냈습니다", "{B}(이|가) {A}의 문장을 외워 다닙니다. 비꼬려고",
        "{A}(이|가) {B}(을|를) 저녁에 초대했는데 둘 다 글 얘기는 안 했답니다", "{B}의 새 모자를 {A}(이|가) 먼저 썼다는 말이 돕니다",
    ]
    static let quiet = ["문단은 이번 주 조용합니다", "서점 주인이 선반을 닦았습니다. 소식은 그게 다입니다", "비평가들이 휴가를 갔다고 합니다",
                        "우체부가 편지를 잘못 배달했는데 아무도 눈치채지 못했습니다", "이번 주는 비 소식뿐입니다"]

    /// 이번 주 소식 몇 줄. 판매·비평·사건·돌발 상황·손님 기록에서 뽑고, 소문 한둘을 섞는다.
    static func lines(progress: WritingProgress, now: Date = Date()) -> [String] {
        let weekStart = WritingStore.weekStart(of: now)
        var dice = Dice([Double(UInt64(weekStart.timeIntervalSince1970) % 9973) / 9973])
        func name(_ author: String) -> String { Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author }

        var lines: [String] = []
        if let top = progress.finished.map(\.bookIndex).max(by: { progress.sales(of: Library.books[$0]) < progress.sales(of: Library.books[$1]) }),
           progress.sales(of: Library.books[top]) > 0 {
            let book = Library.books[top]
            let author = name(book.authorShort)
            lines.append(dice.pick(["이번 주 매대 맨 앞은 \(book.displayTitle). \(author)(이|가) 지나가다 두 번 봤다고 합니다",
                                    "\(book.displayTitle)(이|가) 매대에서 제일 빨리 빠집니다. \(Format.integer(progress.sales(of: book)))부째",
                                    "서점 주인이 \(book.displayTitle)(을|를) 창가로 옮겼습니다. \(author)(은|는) 모른 척합니다"]))
        }
        if let review = progress.reviews.first, let book = Library.books.first(where: { $0.file == review.book }) {
            let author = name(book.authorShort)
            let title = book.displayTitle
            lines.append(review.stars >= 4
                ? dice.pick(["\(review.critic)의 \(title) 서평이 화제입니다. \(author)(은|는) '안 읽었다'고 합니다",
                             "\(title)에 별 \(review.stars)개. \(author)(이|가) 신문을 오려 두었다고 합니다"])
                : review.stars <= 2
                ? dice.pick(["\(review.critic)(이|가) \(title)에 별 \(review.stars)개를 줬습니다. \(author)(은|는) 그 이름을 적어 두었습니다",
                             "\(title) 서평 때문에 \(author)(이|가) 신문을 끊었다는 소문"])
                : dice.pick(["\(review.critic)(은|는) \(title)(이|가) '읽을 만하다'고 했습니다. \(author)(은|는) 그 말이 더 싫답니다",
                             "\(title)에 별 3개. 기뻐한 사람도 화낸 사람도 없습니다"]))
        }
        if let decision = progress.decisions.first, let dilemma = Dilemmas.byID(decision.dilemma) {
            lines.append(decision.auto == true
                ? "\(dilemma.title) 건은 작가가 묻지도 않고 '\(decision.option)'(으로|로) 정했습니다"
                : dice.pick(["\(dilemma.title) 건은 '\(decision.option)'(으로|로) 결론이 났습니다", "문단에서는 \(dilemma.title) 이야기가 아직 돕니다. 결론은 '\(decision.option)'"]))
        }
        let events = progress.recentEvents.filter { $0.lostCharacters == nil && !$0.event.hasPrefix("luck.") && $0.startedAt >= weekStart }.count
        if events >= 3, let book = progress.book {
            let author = name(book.authorShort)
            lines.append(dice.pick(["이번 주 돌발 상황 \(events)번. '\(author)(이|가) 요즘 산만하다'는 말이 돕니다",
                                    "\(author)의 집에 이번 주만 \(events)번 일이 있었습니다. 이웃이 세고 있습니다"]))
        }
        if let file = progress.featuredBook, let book = Library.books.first(where: { $0.file == file }) {
            lines.append(dice.pick(["서점 진열창에 \(book.displayTitle)(이|가) 걸렸습니다. 지나던 사람들이 걸음을 멈춥니다",
                                    "진열창의 \(book.displayTitle)(을|를) 보려고 \(name(book.authorShort))(이|가) 서점 앞을 세 번 지나갔습니다"]))
        }
        if progress.facts.guests > 0 {
            lines.append(dice.pick(["손님 작가가 지금까지 \(progress.facts.guests)번 다녀갔습니다. 커피값이 만만치 않다고 합니다",
                                    "손님이 \(progress.facts.guests)번째 다녀간 뒤로 의자가 하나 더 생겼습니다"]))
        }
        if progress.facts.longestStreak >= 7, let book = progress.book {
            lines.append("\(name(book.authorShort))(은|는) \(progress.facts.longestStreak)일째 하루도 안 빠졌습니다. 비서가 더 지쳤다는 후문")
        }
        let authors = Library.authors
        if authors.count >= 2 {
            for _ in 0..<(lines.count < 3 ? 2 : 1) {
                let a = dice.pick(authors)
                let b = dice.pick(authors.filter { $0 != a })
                lines.append(dice.pick(rumors).replacingOccurrences(of: "{A}", with: name(a)).replacingOccurrences(of: "{B}", with: name(b)))
            }
        }
        if lines.isEmpty { lines.append(dice.pick(quiet)) }
        return lines.prefix(6).map(Format.resolve)
    }
}
