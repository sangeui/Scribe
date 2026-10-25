import AppKit
import Foundation

// 작가의 기분. 사용자가 손을 뗀 지 얼마나 됐는지(macOS 의 마지막 입력 뒤 지난 시간, 권한 없음, 무엇을 쳤는지는 모름)와
// 토큰이 마지막으로 들어온 때를 보고 정한다. 글자·아이템·판매에는 영향이 없고 표정과 한 줄만 바뀐다.

enum Mood: String, Sendable, Equatable {
    /// 돌발 상황 중. 눈치도 농땡이도 없다.
    case paused
    /// 토큰이 들어오고 있다.
    case focused
    /// 사용자는 쓰는데 토큰이 한참 없다. 곁눈질.
    case waiting
    /// 사용자가 자리를 비웠는데 토큰은 들어온다.
    case alone
    /// 둘 다 한참 조용하다. 의자에 기대 창밖을 본다.
    case slacking

    var title: String {
        L10n.tr({ switch self {
        case .paused: "멈춤"
        case .focused: "집중"
        case .waiting: "눈치"
        case .alone: "혼자"
        case .slacking: "농땡이"
        } }())
    }
}

/// 판정에 넣는 값.
struct MoodInput: Sendable {
    /// 마지막 입력 뒤 지난 초.
    var userIdle: TimeInterval
    /// 마지막으로 토큰이 늘어난 뒤 지난 초.
    var tokenIdle: TimeInterval
    var eventActive = false
    var guestActive = false
}

/// 기분을 정한다. 조건이 2번 연속(30초) 맞아야 바뀌고, 농땡이에서 입력이 오면 바로 깨어난다.
struct MoodJudge: Sendable {
    nonisolated static let enabledKey = "moodEnabled"
    nonisolated static let slackMinutesKey = "moodSlackMinutes"

    static var enabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
    static var slackMinutes: Int { UserDefaults.standard.object(forKey: slackMinutesKey) as? Int ?? 30 }

    /// 농땡이까지 걸리는 시간(초).
    var slackAfter: TimeInterval = 30 * 60
    private(set) var current: Mood = .focused
    private var candidate: Mood = .focused
    private var streak = 0

    /// 지금 값으로 후보를 고른다.
    static func candidate(for input: MoodInput, slackAfter: TimeInterval) -> Mood {
        if input.eventActive { return .paused }
        if input.userIdle >= slackAfter, input.tokenIdle >= 30 * 60, !input.guestActive { return .slacking }
        if input.userIdle >= 15 * 60, input.tokenIdle < 5 * 60 { return .alone }
        if input.userIdle < 5 * 60, input.tokenIdle >= 10 * 60 { return .waiting }
        return .focused
    }

    /// 새 값을 넣는다. 기분이 바뀌면 그 값을 돌려주고, 농땡이에서 깨어난 것이면 `caught` 가 true.
    mutating func update(_ input: MoodInput) -> (changed: Mood?, caught: Bool) {
        let next = Self.candidate(for: input, slackAfter: slackAfter)
        // 농땡이 중에 손이 닿으면 바로 깨어난다.
        if current == .slacking, input.userIdle < 15 {
            current = next == .slacking ? .focused : next
            candidate = current
            streak = 0
            return (current, true)
        }
        if next == candidate {
            streak += 1
        } else {
            candidate = next
            streak = 1
        }
        guard next != current, streak >= 2 else { return (nil, false) }
        current = next
        streak = 0
        return (next, false)
    }
}

/// 마지막 입력 뒤 지난 시간. macOS 가 세션 단위로 알려 주며 권한이 필요 없다.
enum UserActivity {
    static func secondsSinceLastInput() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0) ?? .null)
    }
}

/// 기분마다 하는 말. 상태가 바뀔 때 하나, 같은 상태가 이어지면 10분마다 하나. 같은 말은 하루 두 번까지.
@MainActor
final class MoodLines {
    private var uses: [String: (day: String, count: Int)] = [:]

    static let waiting = [
        "쓸 거리가 없어 펜을 돌립니다", "오늘은 글이 안 오나요", "잉크가 마르겠습니다", "종이가 하얗게 쳐다봅니다",
        "헛기침을 합니다", "책상을 손가락으로 두드립니다", "창밖만 봐도 되는 걸까요", "기다리는 것도 일입니다",
        "펜촉 끝에 맺힌 잉크 방울만 물끄러미 바라봅니다", "백지 위에서 펜 그림자만 길어집니다",
        "서랍을 열었다 닫으며 쓸 거리를 기다립니다", "안경을 벗어 닦고 다시 써 보지만 아직 조용하군요",
        "첫 줄을 쓸 준비는 이미 끝났습니다", "문진을 이리저리 옮겨 놓으며 손가락을 풉니다",
    ]
    static let waitingByAuthor: [String: [String]] = [
        "Shakespeare": [
            "극장에나 다녀올까요", "배우들은 지금쯤 대사를 외우고 있을 텐데", "무대는 기다려 주지 않습니다",
            "막이 오르기 전의 정적 같군요", "독백 한 줄이라도 읊어 볼까요", "관객들이 객석에서 기다리고 있습니다"
        ],
        "Dickens": [
            "런던 거리를 걷고 싶어집니다", "마감이 있어야 글이 됩니다", "신문사가 전화를 안 하네요",
            "연재 날이 다가오는데 원고지가 비어 있습니다", "인쇄소 소년이 문밖에서 기다릴 시간인데 말입니다", "제라늄 화분 잎사귀만 세고 있습니다"
        ],
        "Poe": [
            "까마귀도 기다리다 졸았습니다", "어둠은 글이 없어도 깊어집니다", "시계 소리만 들립니다",
            "침묵이 길어질수록 불길한 상상이 자라납니다", "촛불 심지가 타 들어가는 소리만 선명합니다", "백지가 무덤처럼 고요하군요"
        ],
        "Carroll": [
            "토끼는 벌써 늦었다고 합니다", "수수께끼 하나 낼까요", "차 모임 시간이 지났습니다",
            "회중시계 바늘이 거꾸로 가는 건 아닐까요", "아무 일도 일어나지 않는 장은 재미가 없는데요", "여백에 고양이 미소만 그려 두었습니다"
        ],
        "Stevenson": [
            "배는 떴는데 바람이 없습니다", "지도만 들여다봅니다", "바다가 부릅니다",
            "무풍지대에 갇힌 범선 같은 기분이군요", "나침반 바늘만 톡톡 두드려 봅니다", "항해 일지가 한 줄도 나아가지 못했습니다"
        ],
        "Wilde": [
            "침묵도 재치가 있다면 좋겠는데요", "살롱에 늦겠습니다", "카네이션이 시들어 갑니다",
            "아무 일도 안 하는 것은 세상에서 가장 어려운 일입니다", "지루함이야말로 유일한 죄악이지요", "거울을 보는 편이 더 생산적이겠군요"
        ],
        "Austen": [
            "차를 한 잔 더 우립니다", "이웃이 올 때가 됐는데요", "응접실이 조용합니다",
            "편지 배달부가 오늘따라 늦는군요", "찻잔이 다 식도록 소식이 없습니다", "자수라도 놓으면서 기다려야 할까 봐요"
        ],
        "Goethe": [
            "잎의 변형이나 그릴까요", "자연은 기다림을 모릅니다", "광물이나 정리해야겠습니다",
            "구름의 모양이 바뀌는 것을 관찰하고 있습니다", "사색의 시간도 창작의 일부이긴 합니다만", "서재의 해시계가 벌써 한 칸 옮겨 갔습니다"
        ],
    ]
    static let alone = [
        "주인이 없어도 쓰고 있습니다", "조용하니 오히려 잘 써집니다", "다녀오세요. 여기는 제가 봅니다",
        "혼자 쓰는 것도 나쁘지 않습니다", "돌아오면 몇 장 더 늘어 있을 겁니다", "커피는 식었지만 글은 따뜻합니다",
        "아무도 안 볼 때가 가장 솔직한 문장이 나옵니다", "서재에 펜촉 달리는 소리만 가득합니다",
        "비워 두신 자리 몫까지 부지런히 채워 두겠습니다", "혼자만의 고요 속에서 한 장을 훌쩍 넘겼습니다"
    ]
    static let aloneByAuthor: [String: [String]] = [
        "Shakespeare": ["관객 없는 무대에서 혼자 독백을 다듬는 기분이군요", "조용한 틈에 5막의 비극적 결말을 단숨에 밀어붙입니다"],
        "Dickens": ["밤거리를 혼자 걸을 때처럼 문장이 거침없이 쏟아집니다", "누구도 방해하지 않으니 등장인물들이 제 목소리로 떠들기 시작합니다"],
        "Poe": ["완벽한 고독 속에서만 들리는 운율이 있습니다", "방 안의 어둠과 단둘이 남으니 비로소 문장이 완성됩니다"],
        "Carroll": ["혼자 체스를 두듯 문장과 문장을 맞물려 놓고 있습니다", "아무도 없을 때 거울 너머의 이야기를 몰래 적어 둡니다"],
        "Stevenson": ["홀로 당직을 서는 조타수처럼 묵묵히 항해를 이어 갑니다", "조용한 서재가 어느새 폭풍우 치는 갑판으로 바뀝니다"],
        "Wilde": ["청중이 없어도 제 문장은 스스로 빛나는군요", "혼자 읽고 혼자 감탄하기에 아까운 경구가 나왔습니다"],
        "Austen": ["응접실에 아무도 없으니 원고를 숨기지 않고 마음껏 씁니다", "문 여는 소리에 놀랄 일 없이 한 장을 온전히 채웠습니다"],
        "Goethe": ["고요한 질서 속에서 생각의 줄기가 뻗어 나갑니다", "방해받지 않는 사색 끝에 마침내 알맞은 시어를 찾았습니다"],
    ]
    static let slackIn = [
        "잠깐 기지개만", "창밖이 궁금해졌습니다", "종이비행기 접기에는 좋은 종이입니다",
        "의자가 이렇게 편했던가요", "아무도 안 보니 조금만", "펜을 내려놓고 눈을 감습니다",
        "원고지 여백에 작은 캐리커처를 그리고 있습니다", "펜대를 손가락 위에 올려 중심 잡기 놀이를 합니다",
        "책상 서랍 구석에서 옛날 편지 뭉치를 꺼내 읽습니다", "잠시 허리를 편다는 것이 그대로 등받이에 파묻혔습니다"
    ]
    static let slackInByAuthor: [String: [String]] = [
        "Shakespeare": ["소품용 단검을 공중에 던졌다 받으며 딴청을 피웁니다", "다음 희극에 쓸 익살스러운 표정을 거울 앞에서 연습합니다"],
        "Dickens": ["거울을 보며 등장인물의 우스꽝스러운 말투를 혼자 연기해 봅니다", "모자를 비스듬히 고쳐 쓰고 서재 안을 무대처럼 걸어 다닙니다"],
        "Poe": ["촛불 위로 손을 이리저리 움직이며 벽에 박쥐 그림자를 만듭니다", "오래된 암호표를 뒤적이며 원고와는 상관없는 수수께끼를 풉니다"],
        "Carroll": ["원고지 귀퉁이에 토끼 귀를 그려 넣고 빙그레 웃습니다", "종이를 접어 작은 개구리를 만든 뒤 책상 위에서 튕겨 봅니다"],
        "Stevenson": ["종이배를 접어 책상 위를 항해시키고 있습니다", "주머니칼로 연필 끝을 조각하며 뱃노래를 흥얼거립니다"],
        "Wilde": ["손거울을 꺼내 앞머리와 옷깃의 카네이션 각도를 다듬습니다", "소파에 비스듬히 기대어 천장의 무늬를 감상하고 있습니다"],
        "Austen": ["창가 커튼 틈으로 지나가는 이웃들의 모자를 구경합니다", "남은 찻잎으로 오늘의 운세를 점쳐 보고 있습니다"],
        "Goethe": ["서랍에서 광물 표본을 꺼내 돋보기로 결을 들여다봅니다", "창가 화분의 잎사귀 수를 세며 한가로운 오후를 즐깁니다"],
    ]
    static let slackOut = [
        "오셨군요. 바로 이어 씁니다", "자리 뜬 적 없습니다", "기지개만 켠 겁니다",
        "종이비행기는 못 본 걸로 하죠", "어서 오세요. 어디까지 썼더라", "헛기침을 하고 펜을 집습니다",
        "방금까지 아주 중요한 구상을 하던 참이었습니다", "여백의 낙서는 압지로 급히 가렸습니다",
        "시치미를 뚝 떼고 가장 진지한 표정으로 원고지를 내려다봅니다", "손에 쥐고 있던 딴짓거리를 재빨리 서랍 속에 밀어 넣습니다"
    ]

    /// 기분에 맞는 말 하나. 하루 두 번 넘게 쓴 말은 피한다.
    func line(for mood: Mood, author: String, caught: Bool = false, roll: Double = .random(in: 0..<1)) -> String? {
        let pool: [String]
        switch mood {
        case .waiting: pool = Self.waiting + (Self.waitingByAuthor[author] ?? [])
        case .alone: pool = Self.alone + (Self.aloneByAuthor[author] ?? [])
        case .slacking: pool = Self.slackIn + (Self.slackInByAuthor[author] ?? [])
        case .focused: pool = caught ? Self.slackOut : []
        case .paused: pool = []
        }
        let today = DayKey.string(from: Date())
        let fresh = pool.filter { line in
            guard let use = uses[line], use.day == today else { return true }
            return use.count < 2
        }
        guard !fresh.isEmpty else { return nil }
        let picked = fresh[min(fresh.count - 1, Int(roll * Double(fresh.count)))]
        let previous = uses[picked].flatMap { $0.day == today ? $0.count : nil } ?? 0
        uses[picked] = (today, previous + 1)
        return L10n.tr(picked)
    }
}
