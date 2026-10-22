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
        switch self {
        case .paused: "멈춤"
        case .focused: "집중"
        case .waiting: "눈치"
        case .alone: "혼자"
        case .slacking: "농땡이"
        }
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
    ]
    static let waitingByAuthor: [String: [String]] = [
        "Shakespeare": ["극장에나 다녀올까요", "배우들은 지금쯤 대사를 외우고 있을 텐데", "무대는 기다려 주지 않습니다"],
        "Dickens": ["런던 거리를 걷고 싶어집니다", "마감이 있어야 글이 됩니다", "신문사가 전화를 안 하네요"],
        "Poe": ["까마귀도 기다리다 졸았습니다", "어둠은 글이 없어도 깊어집니다", "시계 소리만 들립니다"],
        "Carroll": ["토끼는 벌써 늦었다고 합니다", "수수께끼 하나 낼까요", "차 모임 시간이 지났습니다"],
        "Stevenson": ["배는 떴는데 바람이 없습니다", "지도만 들여다봅니다", "바다가 부릅니다"],
        "Wilde": ["침묵도 재치가 있다면 좋겠는데요", "살롱에 늦겠습니다", "카네이션이 시들어 갑니다"],
        "Austen": ["차를 한 잔 더 우립니다", "이웃이 올 때가 됐는데요", "응접실이 조용합니다"],
        "Goethe": ["잎의 변형이나 그릴까요", "자연은 기다림을 모릅니다", "광물이나 정리해야겠습니다"],
    ]
    static let alone = ["주인이 없어도 쓰고 있습니다", "조용하니 오히려 잘 써집니다", "다녀오세요. 여기는 제가 봅니다",
                        "혼자 쓰는 것도 나쁘지 않습니다", "돌아오면 몇 장 더 늘어 있을 겁니다", "커피는 식었지만 글은 따뜻합니다"]
    static let slackIn = ["잠깐 기지개만", "창밖이 궁금해졌습니다", "종이비행기 접기에는 좋은 종이입니다",
                          "의자가 이렇게 편했던가요", "아무도 안 보니 조금만", "펜을 내려놓고 눈을 감습니다"]
    static let slackOut = ["오셨군요. 바로 이어 씁니다", "자리 뜬 적 없습니다", "기지개만 켠 겁니다",
                           "종이비행기는 못 본 걸로 하죠", "어서 오세요. 어디까지 썼더라", "헛기침을 하고 펜을 집습니다"]

    /// 기분에 맞는 말 하나. 하루 두 번 넘게 쓴 말은 피한다.
    func line(for mood: Mood, author: String, caught: Bool = false, roll: Double = .random(in: 0..<1)) -> String? {
        let pool: [String]
        switch mood {
        case .waiting: pool = Self.waiting + (Self.waitingByAuthor[author] ?? [])
        case .alone: pool = Self.alone
        case .slacking: pool = Self.slackIn
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
        return picked
    }
}
