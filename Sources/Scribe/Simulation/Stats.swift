import Foundation
import SwiftUI

// MARK: - 능력치

/// 작가 능력치. 작가마다 따로 오른다.
enum Stat: String, CaseIterable, Codable, Sendable {
    case pen, grit, charm, sense, luck

    var title: String {
        switch self {
        case .pen: "필력"
        case .grit: "끈기"
        case .charm: "매력"
        case .sense: "감각"
        case .luck: "운"
        }
    }

    var symbol: String {
        switch self {
        case .pen: "pencil.tip"
        case .grit: "mountain.2"
        case .charm: "sparkle"
        case .sense: "eye"
        case .luck: "dice"
        }
    }

    /// 이 단계에서 주는 효과를 한 줄로.
    func effectText(level: Int) -> String {
        switch self {
        case .pen: "글자 +\(Int(Double(level) * Balance.penCharacters * 100))%"
        case .grit: "최대 체력 \(Int(Balance.staminaMax + Double(level) * Balance.gritStamina)) · 체력 소모 -\(Int(Double(level) * Balance.gritDrain * 100))%"
        case .charm: "판매 +\(Int(Double(level) * Balance.charmSales * 100))%"
        case .sense: "서평 별 +\(String(format: "%.1f", Double(level) * Balance.senseStars)) · 영감 +\(Int(Double(level) * Balance.senseInspiration * 100))%"
        case .luck: "아이템 \(Int(Double(level) * Balance.luckItems * 100))% 빨리 · 행운 +\(Int(Double(level) * Balance.luckLuck * 100))%"
        }
    }

    /// 오를 때 하는 말.
    var raisedLine: String {
        switch self {
        case .pen: "문장이 전보다 빨리 나옵니다"
        case .grit: "오래 앉아 있어도 덜 지칩니다"
        case .charm: "독자들이 이 작가 책을 먼저 집습니다"
        case .sense: "비평가가 좋아할 대목을 압니다"
        case .luck: "좋은 일이 조금 더 자주 생깁니다"
        }
    }
}

/// 작가 한 사람의 능력치와 체력.
struct AuthorSheet: Codable, Sendable, Equatable {
    var stats: [String: Int] = [:]
    var stamina = Balance.staminaMax
    /// 체력을 마지막으로 셈한 시각.
    var staminaAt: Date?
    var tokensTowardStat = 0

    init() {}

    func level(_ stat: Stat) -> Int { stats[stat.rawValue, default: 0] }
    var total: Int { Stat.allCases.reduce(0) { $0 + level($1) } }

    private enum CodingKeys: String, CodingKey { case stats, stamina, staminaAt, tokensTowardStat }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stats = (try? c.decodeIfPresent([String: Int].self, forKey: .stats)) ?? [:]
        stamina = (try? c.decodeIfPresent(Double.self, forKey: .stamina)) ?? Balance.staminaMax
        staminaAt = try? c.decodeIfPresent(Date.self, forKey: .staminaAt)
        tokensTowardStat = (try? c.decodeIfPresent(Int.self, forKey: .tokensTowardStat)) ?? 0
    }
}

/// 능력치가 주는 배수.
struct StatPerks: Sendable, Equatable {
    var characters = 1.0
    var staminaMax = Balance.staminaMax
    var staminaDrain = 1.0
    var sales = 1.0
    var reviewBonus = 0.0
    var inspiration = 1.0
    var itemTokens = 1.0
    var luckChance = 1.0

    init() {}

    init(_ sheet: AuthorSheet?) {
        guard let sheet else { return }
        characters = 1 + Double(sheet.level(.pen)) * Balance.penCharacters
        staminaMax = Balance.staminaMax + Double(sheet.level(.grit)) * Balance.gritStamina
        staminaDrain = max(0.4, 1 - Double(sheet.level(.grit)) * Balance.gritDrain)
        sales = 1 + Double(sheet.level(.charm)) * Balance.charmSales
        reviewBonus = Double(sheet.level(.sense)) * Balance.senseStars
        inspiration = 1 + Double(sheet.level(.sense)) * Balance.senseInspiration
        itemTokens = max(0.7, 1 - Double(sheet.level(.luck)) * Balance.luckItems)
        luckChance = 1 + Double(sheet.level(.luck)) * Balance.luckLuck
    }
}

extension Balance {
    /// 능력치: 새 토큰 이만큼마다 능력치 하나가 1 오른다. 한 능력치의 끝.
    static let statTokens = 20_000_000
    static let statMax = 20
    /// 능력치 한 단계가 주는 것. 필력은 글자 배수, 끈기는 최대 체력과 소모 줄임, 매력은 판매, 감각은 서평 별과 영감, 운은 아이템 간격과 행운 확률.
    static let penCharacters = 0.02
    static let gritStamina = 5.0
    static let gritDrain = 0.03
    static let charmSales = 0.02
    static let senseStars = 0.1
    static let senseInspiration = 0.03
    static let luckItems = 0.015
    static let luckLuck = 0.03
    /// 체력: 최대, 새 토큰 100만 개마다 줄어드는 양, 한 시간에 돌아오는 양(밤과 쉬는 동안은 두 배), 지친 기준(비율)과 그때 글자 배수, 탈진 쉬는 시간(분), 커피·홍차 한 잔에 돌아오는 양.
    static let staminaMax = 100.0
    static let staminaPerMillion = 1.2
    static let staminaRecoveryPerHour = 4.0
    static let staminaTiredBelow = 0.3
    static let staminaTiredMultiplier = 0.7
    static let exhaustedMinutes = 180
    static let staminaCupRestore = 15.0
}

extension AuthorEvents {
    /// 체력이 0이 되면. 커피로 깨울 수는 있지만 자주 거절한다.
    static let exhausted = AuthorEvent(
        id: "exhausted", text: "탈진해서 긴 의자에 누워 있습니다", icon: PixelIcon.zzz, leavesDesk: false, cure: .coffee,
        causes: [
            "며칠을 쉬지 않고 썼습니다", "밤낮없이 원고에 매달렸습니다", "펜을 놓는 법을 잊은 듯했습니다",
            "마지막 장을 끝내겠다며 밤을 꼬박 새웠습니다", "손목이 굳어 더는 펜대를 쥘 힘이 남지 않았습니다",
            "원고지 더미 옆에서 끝내 눈꺼풀이 내려앉았습니다"
        ],
        returns: [
            "한참 자고 일어나 기지개를 켭니다. 다시 씁니다", "눈을 뜨고 물을 한 잔 마신 뒤 책상으로 갑니다",
            "누워 있던 자리에서 천천히 일어납니다. 아직 어깨가 무겁습니다",
            "창문으로 들어온 바람에 정신을 차리고 담요를 접어 둡니다",
            "굳었던 손가락을 하나씩 펴 보더니 조심스럽게 펜을 다시 쥡니다"
        ],
        cured: [
            "커피 냄새에 겨우 눈을 뜹니다", "잔을 받아 들고 일어나 앉습니다. 손이 조금 떨립니다",
            "따뜻한 커피 한 모금에 창백하던 얼굴로 혈색이 조금 돌아옵니다",
            "김이 모락모락 나는 잔을 비우고 호흡을 가다듬으며 책상으로 복귀합니다"
        ],
        refusals: [
            "커피로 될 일이 아니라며 돌아눕습니다", "잔을 받지 않습니다. 눈도 안 뜹니다",
            "손만 저을 뿐 일어나지 않습니다", "지금은 아무것도 못 마시겠답니다",
            "담요를 머리끝까지 끌어 올리며 깊은 숨만 내쉽니다"
        ])
}

// MARK: - 화면

/// 체력 줄. 심장 기호와 짧은 막대, 숫자. 지쳤으면 주황, 거의 없으면 빨강.
struct StaminaRow: View {
    let stamina: Double
    let max: Double
    let tired: Bool

    var body: some View {
        let fraction = Swift.max(0, Swift.min(1, stamina / Swift.max(1, max)))
        let color: Color = fraction <= 0.1 ? ChartPalette.critical : tired ? ChartPalette.warning : ChartPalette.rose
        HStack(spacing: 5) {
            Symbol(name: tired ? "heart.slash" : "heart.fill", size: 11, color: color.opacity(0.9))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.12))
                GeometryReader { geo in Capsule().fill(color).frame(width: Swift.max(2, geo.size.width * fraction)) }
            }
            .frame(width: 36, height: 3)
            Text("\(Int(stamina.rounded()))").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08), in: Capsule())
        .hint("체력 \(Int(stamina.rounded())) / \(Int(max))",
              ["새 토큰 100만 개마다 \(String(format: "%.1f", Balance.staminaPerMillion))씩 줄고, 한 시간에 \(Int(Balance.staminaRecoveryPerHour))씩 돌아옵니다. 밤과 쉬는 동안은 두 배.",
               "\(Int(Balance.staminaTiredBelow * 100))% 아래면 글자가 \(Int((1 - Balance.staminaTiredMultiplier) * 100))% 덜 늘고, 0이 되면 탈진해 \(Balance.exhaustedMinutes / 60)시간 쉽니다.",
               "커피·홍차로 상황을 끝내면 \(Int(Balance.staminaCupRestore)) 돌아옵니다. 끈기가 오르면 최대 체력이 늘고 덜 줄어듭니다."],
              symbol: "heart")
    }
}

/// 능력치 칩 다섯과 다음 상승까지 남은 토큰.
struct StatsRow: View {
    let sheet: AuthorSheet
    let tokensToNext: Int
    let authorName: String

    var body: some View {
        FlowLayout(spacing: 4) {
            Group {
                ForEach(Stat.allCases, id: \.self) { stat in
                    let level = sheet.level(stat)
                    HStack(spacing: 3) {
                        Symbol(name: stat.symbol, size: 10, color: level > 0 ? .primary : .secondary)
                        Text("\(stat.title) \(level)").font(.caption2.monospacedDigit()).foregroundStyle(level > 0 ? .primary : .secondary)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.08), in: Capsule())
                    .hint("\(stat.title) \(level)", [level > 0 ? "지금: \(stat.effectText(level: level))" : "아직 0입니다.",
                                                    level < Balance.statMax ? "다음: \(stat.effectText(level: level + 1))" : "끝까지 올랐습니다.",
                                                    stat.raisedLine], symbol: stat.symbol)
                }
                HStack(spacing: 3) {
                    Symbol(name: "arrow.up", size: 9)
                    Text(Format.short(tokensToNext)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(Color.secondary.opacity(0.05), in: Capsule())
                .hint("다음 능력치까지", ["\(authorName)의 능력치는 새 토큰 \(Format.short(Balance.statTokens)) 개마다 하나가 무작위로 1 오릅니다. \(Format.integer(tokensToNext)) 개 남았습니다.",
                                      "능력치는 작가마다 따로입니다. 교대하면 그 작가 것으로 바뀝니다."], symbol: "arrow.up")
            }
        }
    }
}

/// 작은 고리. 머리 카드에서 체력·영감을 한눈에.
struct MiniRing: View {
    let fraction: Double
    let color: Color
    let symbol: String

    var body: some View {
        ZStack {
            Circle().inset(by: 1.2)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 2.2)
            Circle().inset(by: 1.2)
                .trim(from: 0, to: max(0.02, min(1, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: fraction)
            Symbol(name: symbol, size: 7, color: color)
        }
        .frame(width: 18, height: 18)
    }
}
