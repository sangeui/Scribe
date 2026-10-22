import Foundation

// 비평. 탈고하면 가상의 비평가가 별점과 서너 문장 평을 쓰고, 몇 시간에서 이틀 뒤 신문에 실린다.
// 별점은 걸린 날수, 돌발 상황, 재해로 잃은 양, 분량으로 정한다. 글은 문장 틀에 낱말(살펴본 대목, 평가, 독자, 비교)을
// 끼워 짓고 조사는 받침에 맞춘다. 실릴 때 지금 쓰는 작가의 책이면 작가가 영향을 받는다(하루 동안의 보정과 한 줄).

struct Review: Codable, Sendable, Equatable, Identifiable {
    /// `Book.file`
    let book: String
    let round: Int
    let critic: String
    /// 1~5. 실릴 때 정한다(출판사에 따라 달라서). 그 전엔 0.
    var stars: Int
    var text: String
    /// 실리는 시각. 그 전에는 화면에 나오지 않는다.
    let date: Date
    /// 별점을 정할 때 쓰는 집필 사정. 탈고 기록에서 옮겨 둔다.
    var days: Int?
    var events: Int?
    var lost: Int?
    var published: Bool?
    /// 실릴 때 지금 쓰는 작가의 책이라 작가가 영향을 받았는지.
    var affected: Bool?
    var notified: Bool?
    var id: String { "\(round)-\(book)" }

    var starText: String { String(repeating: "★", count: stars) + String(repeating: "☆", count: 5 - stars) }
}

/// 난수 목록에서 차례로 고른다. 목록이 모자라면 앞 값을 조금씩 비틀어 쓴다(확인용 실행도 결과가 정해진다).
struct Dice {
    private let rolls: [Double]
    private var index = 0

    init(_ rolls: [Double]) { self.rolls = rolls.isEmpty ? [0.5] : rolls }

    mutating func next() -> Double {
        let base = rolls[index % rolls.count]
        let turn = Double(index / rolls.count)
        index += 1
        return (base + turn * 0.3819).truncatingRemainder(dividingBy: 1)
    }

    mutating func pick<T>(_ pool: [T]) -> T { pool[min(pool.count - 1, Int(next() * Double(pool.count)))] }
    mutating func chance(_ p: Double) -> Bool { next() < p }
}

enum Critics {
    struct Critic: Sendable {
        let name: String
        /// 문체. 마무리와 말투를 고를 때 쓴다.
        let voice: Voice
    }

    enum Voice: Sendable { case dry, lofty, kind, snippy }

    static let all = [
        Critic(name: "H. 애스턴", voice: .dry),
        Critic(name: "마거릿 로우", voice: .kind),
        Critic(name: "P. 드 라 투르", voice: .lofty),
        Critic(name: "익명의 독자", voice: .snippy),
        Critic(name: "T. 웰스비", voice: .dry),
        Critic(name: "클라라 반 데어 몰", voice: .lofty),
        Critic(name: "주간 문예 편집부", voice: .snippy),
        Critic(name: "E. 그린우드", voice: .kind),
    ]

    /// 별점. 하루 글자가 많고, 돌발 상황이 적고, 재해로 잃은 게 없으면 높다. 무작위가 ±0.75 섞인다.
    static func stars(days: Int, events: Int, lost: Int, characters: Int, roll: Double, bonus: Double = 0) -> Int {
        var score = 3.0 + bonus
        let pace = Double(characters) / Double(max(1, days))
        if pace >= 60_000 { score += 1 } else if pace >= 20_000 { score += 0.5 } else if pace < 5_000 { score -= 0.5 }
        if events == 0 { score += 0.5 } else if events >= 6 { score -= 1 } else if events >= 3 { score -= 0.5 }
        if lost > 0 { score -= lost >= 10_000 ? 1 : 0.5 }
        score += (roll - 0.5) * 1.5
        return max(1, min(5, Int(score.rounded())))
    }

    // MARK: 낱말

    /// 살펴보는 대목.
    static let aspects = ["문장", "인물", "결말", "첫 장", "대화", "호흡", "구성", "풍경 묘사", "유머", "마지막 장", "서두", "문체", "속도", "비유", "제목"]
    /// 대목에 대한 평. 세기별로 넷.
    static let strongPraise = ["살아 있다", "손에 잡힐 듯하다", "오래 남는다", "흠잡을 데가 없다", "읽는 이를 놓아주지 않는다", "이 작가의 최고다", "한 글자도 버릴 게 없다", "책을 덮은 뒤에도 따라온다"]
    static let mildPraise = ["제 몫을 한다", "무난하다", "나쁘지 않다", "기대보다 낫다", "읽을수록 낫다", "조용히 좋다", "믿을 만하다"]
    static let mildFault = ["조금 느슨하다", "힘이 빠진다", "급하게 닫힌다", "군데군데 늘어진다", "낯익다", "두 번 읽어야 잡힌다", "어딘가 서두른다"]
    static let strongFault = ["자주 길을 잃는다", "뜻을 알기 어렵다", "읽는 이를 시험한다", "있으나 마나다", "작가도 잊은 듯하다", "종이가 아깝다", "끝까지 가지 못한다"]
    /// 권하는 독자.
    static let readers = ["밤 기차의 독자", "긴 겨울을 앞둔 사람", "이 작가를 처음 읽는 이", "참을성 있는 독자", "결말부터 읽는 사람", "소리 내어 읽는 사람", "두 번 읽을 각오가 된 독자"]

    /// 서너 문장 평. 첫인상, 대목 평(한둘), 집필 사정이나 비교·권유, 비평가 문체의 마무리. 틀과 낱말을 난수로 골라 같은 조건에서도 매번 다르다.
    static func text(for stars: Int, days: Int, events: Int, lost: Int, title: String, author: String, voice: Voice, rolls: [Double]) -> String {
        var dice = Dice(rolls)
        var sentences: [String] = []

        // 1. 첫인상
        let hooks: [String]
        switch stars {
        case 5: hooks = ["올해 읽은 것 가운데 가장 빛난다", "덮고 나서 한동안 말을 잃었다", "이런 책은 십 년에 하나 나온다", "{title}(은|는) {author}의 정점이다",
                         "첫 장부터 마지막까지 한 호흡이다", "읽는 동안 난로가 꺼진 줄도 몰랐다", "서점 주인이 두 권을 샀다는데 이해가 간다", "{author}(이|가) 이런 책을 쓸 줄은 몰랐다"]
        case 4: hooks = ["군더더기가 거의 없다", "오랜만에 끝까지 읽게 만드는 책이다", "{author}의 솜씨가 여전함을 보여 준다", "두어 군데 늘어지지만 흠이 되지 않는다",
                         "독자가 손해 볼 일은 없다", "밤 기차에서 읽기 좋은 책이다", "{title}(은|는) 조용히 좋은 책이다", "{author}(을|를) 아는 독자라면 반길 것이다"]
        case 3: hooks = ["나쁘지 않다. 그 이상은 아니다", "기대만큼은 아니지만 실망할 정도도 아니다", "중간쯤에서 잠시 길을 잃는다", "{author}답긴 한데 새롭진 않다",
                         "읽을 만하다. 다시 읽을진 모르겠다", "장점과 단점이 같은 수다", "빌려 읽어도 되고 사도 된다", "{title}(은|는) {author}의 평균이다"]
        case 2: hooks = ["무엇을 하려 했는지는 알겠다", "장면은 좋은데 책이 되지 못했다", "{title}(은|는) 초고처럼 읽힌다", "독자보다 작가가 더 지친 것 같다",
                         "절반쯤에서 덮을 뻔했다", "제목이 가장 좋은 대목이다", "편집자는 어디 있었나", "{author}(이|가) 급했던 모양이다"]
        default: hooks = ["이 책을 추천할 방법을 찾지 못했다", "종이가 아깝다는 말은 하지 않겠다. 거의", "{author}의 이름이 없었다면 끝까지 읽지 않았다", "무슨 일이 있었던 게 분명하다",
                          "다음 작품을 기다리겠다. 이 책 때문은 아니다", "난로에 넣지 않은 건 겨울이 아니라서다", "읽는 데 걸린 시간을 돌려받고 싶다", "{title}(은|는) 제목부터 틀렸다"]
        }
        sentences.append(dice.pick(hooks))

        // 2. 대목 평. 별점에 따라 칭찬과 흠을 섞는다.
        let first = dice.pick(aspects)
        let second = dice.pick(aspects.filter { $0 != first })
        let adverb = dice.pick(["", "", "특히 ", "뜻밖에 ", "끝까지 ", "무엇보다 "])
        switch stars {
        case 5:
            sentences.append("\(adverb)\(first)(은|는) \(dice.pick(strongPraise))")
            if dice.chance(0.6) { sentences.append(dice.pick(["\(second)도 그렇다", "\(second)(은|는) 말할 것도 없다", "\(second)까지 \(dice.pick(strongPraise))"])) }
        case 4:
            sentences.append("\(adverb)\(first)(은|는) \(dice.pick(strongPraise + mildPraise))")
            if dice.chance(0.7) { sentences.append("다만 \(second)(은|는) \(dice.pick(mildFault))") }
        case 3:
            sentences.append("\(first)(은|는) \(dice.pick(mildPraise)). \(second)(은|는) \(dice.pick(mildFault))")
        case 2:
            sentences.append("\(adverb)\(first)(은|는) \(dice.pick(mildFault + strongFault))")
            if dice.chance(0.6) { sentences.append(dice.pick(["그래도 \(second)(은|는) \(dice.pick(mildPraise))", "\(second)만은 \(dice.pick(mildPraise))", "\(second)도 \(dice.pick(mildFault))"])) }
        default:
            sentences.append("\(first)(은|는) \(dice.pick(strongFault)). \(second)(은|는) 더하다")
        }

        // 3. 집필 사정. 두드러진 것이 있으면 그 말을, 없으면 가끔 비교나 권유를.
        var context: [String] = []
        if events >= 6 { context += ["집필 중 일이 많았다는 소문이 글에 배어 있다", "쉼이 잦았는지 호흡이 끊긴다", "작가가 책상보다 문밖에 더 있었던 모양이다"] }
        else if events >= 3 { context += ["중간중간 멈춘 흔적이 보인다", "몇 장은 분명 다른 날에 쓴 것이다", "커피가 떨어진 날이 어느 장인지 알 것 같다"] }
        else if events == 0 { context += ["한자리에서 쓴 듯 고르다", "한 번도 펜을 놓지 않은 글이다"] }
        if lost >= 10_000 { context += ["불이든 물이든, 잃은 대목이 아쉽다", "사라진 장이 있다고 들었다. 그래서인지 틈이 있다"] }
        else if lost > 0 { context += ["몇 장을 잃었다는데 티가 거의 안 난다", "다시 쓴 대목이 오히려 낫다는 말도 있다"] }
        if days <= 2 { context += ["이틀 만에 썼다는 게 믿기지 않는다", "급히 쓴 글의 열기가 있다"] }
        else if days >= 30 { context += ["한 달을 넘긴 공이 보인다", "느리게 쓴 글은 느리게 읽힌다. 좋은 뜻이다"] }
        let good = stars >= 4, bad = stars <= 2
        let extras = [
            "\(author)의 전작을 기억하는 독자라면 " + (good ? dice.pick(["안심해도 된다", "한 번 더 놀랄 것이다"]) : bad ? dice.pick(["고개를 갸웃할 것이다", "실망할 것이다"]) : "고개를 끄덕일 것이다"),
            good ? "\(dice.pick(readers))에게 권한다" : bad ? dice.pick(["아무에게도 권하지 않는다", "\(author)의 열렬한 독자에게만 권한다"]) : "\(dice.pick(readers))에게는 권할 만하다",
            good ? "\(title)(은|는) 올겨울 서점 창가에 오래 있을 것이다" : bad ? "\(title)(은|는) 서점 안쪽 선반으로 곧 밀려날 것이다" : "\(title)(은|는) 서점 가운데 선반쯤에 있을 것이다",
        ]
        if !context.isEmpty { sentences.append(dice.pick(context)) }
        if context.isEmpty || dice.chance(0.4) { sentences.append(dice.pick(extras)) }

        // 4. 마무리. 비평가 문체.
        let closer: [String]
        switch voice {
        case .dry: closer = ["별 \(stars)개. 더도 덜도 아니다", "별 \(stars)개를 준다", "\(stars)점. 계산은 끝났다", "별 \(stars)개. 이의는 편지로"]
        case .lofty: closer = ["문학은 이렇게 또 한 걸음을 뗀다. 별 \(stars)개", "별 \(stars)개를 바친다", "후세가 판단하겠지만 우선 별 \(stars)개", "별 \(stars)개. 시대가 기억할지는 두고 보자"]
        case .kind: closer = ["별 \(stars)개, 그리고 응원을", "별 \(stars)개입니다. 다음 책도 기다릴게요", "별 \(stars)개. 작가에게 차 한 잔을", "별 \(stars)개. 독자 한 사람의 마음으로"]
        case .snippy: closer = ["별 \(stars)개. 이유는 위에 썼다", "\(stars)개면 후하다", "별 \(stars)개. 돈은 독자 몫이다", "별 \(stars)개. 더 묻지 마라"]
        }
        sentences.append(dice.pick(closer))

        let joined = sentences.joined(separator: ". ") + "."
        return Format.resolve(joined.replacingOccurrences(of: "{title}", with: title).replacingOccurrences(of: "{author}", with: author))
    }

    /// 별점이 작가에게 주는 보정(지금 쓰는 작가의 책일 때). 하루 동안.
    static func boosts(for stars: Int, now: Date) -> [ActiveBoost] {
        let day = now.addingTimeInterval(TimeInterval(Balance.reviewBoostHours) * 3600)
        switch stars {
        case 5: return [ActiveBoost(kind: .characters, value: 1.15, endsAt: day, source: "비평 ★5"),
                        ActiveBoost(kind: .eventChance, value: 0.7, endsAt: day, source: "비평 ★5")]
        case 4: return [ActiveBoost(kind: .characters, value: 1.08, endsAt: day, source: "비평 ★4")]
        case 2: return [ActiveBoost(kind: .refusal, value: 0.1, endsAt: day, source: "비평 ★2"),
                        ActiveBoost(kind: .eventChance, value: 1.2, endsAt: day, source: "비평 ★2")]
        case 1: return [ActiveBoost(kind: .refusal, value: 0.2, endsAt: day, source: "비평 ★1"),
                        ActiveBoost(kind: .eventChance, value: 1.4, endsAt: day, source: "비평 ★1"),
                        ActiveBoost(kind: .characters, value: 0.9, endsAt: day, source: "비평 ★1")]
        default: return []
        }
    }

    /// 별점이 그 책 판매에 주는 배수.
    static func salesMultiplier(for stars: Int) -> Double {
        [1: 0.7, 2: 0.85, 3: 1.0, 4: 1.15, 5: 1.3][stars] ?? 1
    }

    /// 작가가 자기 책의 비평을 읽고 하는 말.
    static func authorLine(stars: Int, roll: Double) -> String {
        let pool: [String]
        switch stars {
        case 5: pool = ["작가가 신문을 액자에 넣겠답니다", "작가가 비평가에게 꽃을 보냈습니다", "작가가 하루 종일 콧노래입니다", "작가가 신문을 세 부 더 사 왔습니다"]
        case 4: pool = ["작가가 신문을 두 번 읽었습니다", "작가가 '그 정도면 됐다'고 합니다", "작가가 신문을 접어 주머니에 넣었습니다"]
        case 3: pool = ["작가가 신문을 접어 서랍에 넣었습니다", "작가가 '읽을 만하다니, 그렇군' 합니다", "작가가 신문으로 창을 닦았습니다"]
        case 2: pool = ["작가가 신문을 난로에 넣으려다 말았습니다", "작가가 비평가 이름을 적어 두었습니다", "작가가 '편집자 탓'이라고 중얼거립니다"]
        default: pool = ["작가가 신문을 찢었습니다", "작가가 '그 사람은 책을 안 읽는다'고 합니다", "작가가 창밖을 오래 봅니다", "작가가 오늘은 아무와도 말을 안 합니다"]
        }
        return pool[min(pool.count - 1, Int(roll * Double(pool.count)))]
    }
}
