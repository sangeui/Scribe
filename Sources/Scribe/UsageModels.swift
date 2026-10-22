import Foundation

/// 토큰 로그를 남긴 개별 에이전트.
enum AgentProvider: String, Codable, Sendable, CaseIterable, Identifiable {
    case claude
    case antigravity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claude: "Claude Code"
        case .antigravity: "Antigravity"
        }
    }

    var shortTitle: String {
        switch self {
        case .claude: "Claude"
        case .antigravity: "Antigravity"
        }
    }
}

/// 사용자가 고르는 토큰 공급 데이터 소스.
enum AgentSource: String, Codable, Sendable, CaseIterable, Identifiable {
    case antigravity
    case claude
    case all

    var id: String { rawValue }
    nonisolated static let key = "agentSource"

    var title: String {
        switch self {
        case .antigravity: "Antigravity"
        case .claude: "Claude Code"
        case .all: "통합"
        }
    }

    var summaryTitle: String {
        switch self {
        case .antigravity: "Antigravity 사용량"
        case .claude: "Claude Code 사용량"
        case .all: "통합 토큰 사용량"
        }
    }

    var badgeTitle: String {
        switch self {
        case .antigravity: "Antigravity · Gemini"
        case .claude: "Claude Code"
        case .all: "Antigravity + Claude"
        }
    }

    var logPathDisplay: String {
        switch self {
        case .antigravity: "~/.gemini/antigravity/brain"
        case .claude: "~/.claude/projects"
        case .all: "~/.gemini/antigravity/brain · ~/.claude/projects"
        }
    }

    var detail: String {
        switch self {
        case .antigravity: "Antigravity · Gemini CLI 로컬 대화 기록으로 집필하고 사용량 화면을 보여 줍니다."
        case .claude: "Claude Code 로컬 대화 기록과 플랜 한도로 집필하고 사용량 화면을 보여 줍니다."
        case .all: "Antigravity 와 Claude Code 의 토큰을 함께 합쳐 집필하고 에이전트별 비중을 보여 줍니다."
        }
    }

    func includes(_ provider: AgentProvider) -> Bool {
        switch self {
        case .all: true
        case .antigravity: provider == .antigravity
        case .claude: provider == .claude
        }
    }
}

/// 어시스턴트 응답 한 건의 토큰 사용량.
struct UsageEntry: Sendable {
    let id: String
    var provider: AgentProvider = .claude
    var date: Date
    let model: String
    let input: Int
    let output: Int
    /// 5분 캐시 쓰기. 단가는 입력의 1.25배.
    let cacheWrite5m: Int
    /// 1시간 캐시 쓰기. 단가는 입력의 2배.
    let cacheWrite1h: Int
    let cacheRead: Int

    var cacheWrite: Int { cacheWrite5m + cacheWrite1h }
    var total: Int { input + output + cacheWrite + cacheRead }
}

struct DayUsage: Sendable, Identifiable {
    var id: Date { day }
    /// 로컬 시간 기준 그날 0시.
    let day: Date
    var tokens: Int = 0
    /// 입력·캐시 토큰. 작가가 "읽은" 양으로 쳐서 영감 게이지에 쌓인다.
    var read: Int = 0
    var cost: Double = 0
    /// 단가표에 없는 모델이 섞여 있어 `cost` 가 실제보다 작다.
    var hasUnpriced = false
}

struct ModelUsage: Sendable, Identifiable {
    var id: String { model }
    let model: String
    var tokens: Int = 0
    var input: Int = 0
    var output: Int = 0
    var cacheWrite: Int = 0
    var cacheRead: Int = 0
    /// 단가표에 없는 모델이면 nil.
    var cost: Double? = 0
}

struct UsageSnapshot: Sendable {
    /// 적용된 데이터 소스.
    var source: AgentSource = .all
    /// 첫 기록이 있는 날(늦어도 13일 전)부터 오늘까지 하루도 빠짐없이, 오래된 날이 앞이다.
    let days: [DayUsage]
    let todayByModel: [ModelUsage]
    /// 오늘 시간대별 토큰. 0시부터 23시까지 24칸.
    var todayByHour: [Int] = Array(repeating: 0, count: 24)
    /// 최근 5시간 동안 쓴 토큰.
    var recentFiveHourTokens: Int = 0
    /// 오늘 에이전트별 토큰(소스 선택 카드에서 비교용으로 늘 전체를 담아 둔다).
    var todayByProvider: [AgentProvider: Int] = [:]
    /// 오늘 에이전트별 비용.
    var todayCostByProvider: [AgentProvider: Double] = [:]
    /// 에이전트별 스캔된 로그 파일 수.
    var filesByProvider: [AgentProvider: Int] = [:]
    let scannedFiles: Int
    let generatedAt: Date

    var today: DayUsage { days.last ?? DayUsage(day: Calendar.current.startOfDay(for: generatedAt)) }

    /// 오늘 캐시 적중률(0...100). 입력+캐시 중 캐시 읽기가 차지하는 비율.
    var todayCacheHitPercent: Double {
        let input = todayByModel.reduce(0) { $0 + $1.input + $1.cacheWrite }
        let read = todayByModel.reduce(0) { $0 + $1.cacheRead }
        guard input + read > 0 else { return 0 }
        return Double(read) / Double(input + read) * 100
    }
}

enum UsageAggregator {
    static func snapshot(entries: [UsageEntry], scannedFiles: Int,
                         filesByProvider: [AgentProvider: Int] = [:],
                         source: AgentSource = .all,
                         now: Date = Date(), calendar: Calendar = .current) -> UsageSnapshot {
        let today = calendar.startOfDay(for: now)
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)

        var todayByProvider: [AgentProvider: Int] = [:]
        var todayCostByProvider: [AgentProvider: Double] = [:]
        for e in entries where e.total > 0 && calendar.startOfDay(for: e.date) == today {
            todayByProvider[e.provider, default: 0] += e.total
            if let cost = Pricing.cost(of: e) {
                todayCostByProvider[e.provider, default: 0] += cost
            }
        }

        let filtered = entries.filter { source.includes($0.provider) }
        // 14일 막대그래프는 기록이 없어도 자리가 있어야 한다.
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -13, to: today) ?? today
        let firstEntry = filtered.map(\.date).min().map { calendar.startOfDay(for: $0) } ?? today
        var days: [DayUsage] = []
        var indexByDay: [Date: Int] = [:]
        var day = min(firstEntry, twoWeeksAgo)
        while day <= today {
            indexByDay[day] = days.count
            days.append(DayUsage(day: day))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        var models: [String: ModelUsage] = [:]
        var hours = Array(repeating: 0, count: 24)
        var recentFiveHour = 0
        for e in filtered where e.total > 0 {
            if e.date >= fiveHoursAgo && e.date <= now.addingTimeInterval(60) {
                recentFiveHour += e.total
            }
            let entryDay = calendar.startOfDay(for: e.date)
            guard let i = indexByDay[entryDay] else { continue }
            let cost = Pricing.cost(of: e)
            days[i].tokens += e.total
            days[i].read += e.input + e.cacheWrite + e.cacheRead
            if let cost { days[i].cost += cost } else { days[i].hasUnpriced = true }

            guard entryDay == today else { continue }
            hours[calendar.component(.hour, from: e.date)] += e.total
            var m = models[e.model] ?? ModelUsage(model: e.model)
            m.tokens += e.total
            m.input += e.input
            m.output += e.output
            m.cacheWrite += e.cacheWrite
            m.cacheRead += e.cacheRead
            m.cost = cost.flatMap { c in m.cost.map { $0 + c } }
            models[e.model] = m
        }

        let effectiveFiles: Int
        if filesByProvider.isEmpty {
            effectiveFiles = scannedFiles
        } else {
            effectiveFiles = AgentProvider.allCases.filter { source.includes($0) }.reduce(0) { $0 + (filesByProvider[$1] ?? 0) }
        }

        return UsageSnapshot(
            source: source,
            days: days,
            todayByModel: models.values.sorted { $0.tokens > $1.tokens },
            todayByHour: hours,
            recentFiveHourTokens: recentFiveHour,
            todayByProvider: todayByProvider,
            todayCostByProvider: todayCostByProvider,
            filesByProvider: filesByProvider,
            scannedFiles: effectiveFiles,
            generatedAt: now)
    }
}
