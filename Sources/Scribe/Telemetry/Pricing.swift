import Foundation

/// API 단가로 환산한 추정 비용. 구독 요금이 아니다.
///
/// 단가는 PokeTokenBar(MIT, chattymin)의 `ModelPricing.swift` 에서 Claude 행만 가져왔다.
/// 원본은 캐시 쓰기를 모두 5분 단가로 계산하지만, 여기서는 로그의 `cache_creation` 을 보고
/// 1시간 캐시 쓰기를 입력의 2배로 따로 계산한다.
enum Pricing {
    struct Rate {
        /// USD / 1M tokens
        let input: Double
        let output: Double
        let cacheRead: Double
    }

    static let table: [String: Rate] = [
        "claude-fable-5-1":           Rate(input: 10, output: 50, cacheRead: 0.25),
        "claude-fable-5":             Rate(input: 10, output: 50, cacheRead: 1.0),
        "claude-opus-5-5":            Rate(input: 4, output: 20, cacheRead: 0.2),
        "claude-opus-5":              Rate(input: 5, output: 25, cacheRead: 0.5),
        "claude-sonnet-5-5":          Rate(input: 2, output: 10, cacheRead: 0.1),
        "claude-sonnet-5":            Rate(input: 2, output: 10, cacheRead: 0.2),
        "claude-opus-4-8":            Rate(input: 5, output: 25, cacheRead: 0.5),
        "claude-opus-4-7":            Rate(input: 5, output: 25, cacheRead: 0.5),
        "claude-sonnet-4-6":          Rate(input: 3, output: 15, cacheRead: 0.3),
        "claude-sonnet-4-5-20250929": Rate(input: 3, output: 15, cacheRead: 0.3),
        "claude-sonnet-4-20250514":   Rate(input: 3, output: 15, cacheRead: 0.3),
        "claude-opus-4-20250514":     Rate(input: 15, output: 75, cacheRead: 1.5),
        "claude-haiku-4-5-20251001":  Rate(input: 1, output: 5, cacheRead: 0.1),
        // Antigravity · Gemini API 단가 환산 (USD / 1M tokens)
        "gemini-pro":                 Rate(input: 1.25, output: 10.0, cacheRead: 0.125),
        "gemini-flash":               Rate(input: 0.30, output: 2.50, cacheRead: 0.03),
        "gemini-flash-lite":          Rate(input: 0.10, output: 0.40, cacheRead: 0.01),
    ]

    private static let aliases: [String: String] = [
        "claude-sonnet-4": "claude-sonnet-4-20250514",
        "claude-opus-4": "claude-opus-4-20250514",
        "claude-sonnet-4-5": "claude-sonnet-4-5-20250929",
        "claude-haiku-4-5": "claude-haiku-4-5-20251001",
    ]

    /// `claude-opus-5[1m]` 같은 컨텍스트 표기와 `anthropic/`·`google/` 접두어를 떼고 별칭을 푼다.
    /// Antigravity 의 Gemini 모델 표기(`Gemini 4 Argon (High)`, `gemini-2.5-pro` 등)도 해당 계열 단가로 매핑한다.
    static func key(for model: String) -> String {
        var key = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key.hasPrefix("anthropic/") { key.removeFirst("anthropic/".count) }
        if key.hasPrefix("google/") { key.removeFirst("google/".count) }
        if let bracket = key.firstIndex(of: "[") { key = String(key[..<bracket]) }
        if key.contains("gemini") {
            if key.contains("flash-lite") || key.contains("flash lite") { return "gemini-flash-lite" }
            if key.contains("flash") { return "gemini-flash" }
            return "gemini-pro"
        }
        return aliases[key] ?? key
    }

    static func rate(for model: String) -> Rate? { table[key(for: model)] }

    /// 단가표에 없는 모델이면 nil. 0달러와 구분하려고 일부러 nil 을 돌려준다.
    static func cost(of e: UsageEntry) -> Double? {
        guard let r = rate(for: e.model) else { return nil }
        let perMillion = Double(e.input) * r.input
            + Double(e.output) * r.output
            + Double(e.cacheWrite5m) * r.input * 1.25
            + Double(e.cacheWrite1h) * r.input * 2
            + Double(e.cacheRead) * r.cacheRead
        return perMillion / 1_000_000
    }
}
