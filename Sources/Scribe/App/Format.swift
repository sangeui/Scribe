import Foundation

enum Format {
    /// 한국어 모드에서는 "1,234"·"1.2만"·"2,500만"·"2억", 영어 모드에서는 "1.2K"·"25M"·"200.7M"·"1.5B".
    static func tokens(_ n: Int) -> String {
        L10n.isEnglish ? usTokens(n) : koreanShort(n)
    }

    private static func usTokens(_ n: Int) -> String {
        let v = Double(n)
        switch v {
        case 1_000_000_000...: return trim(v / 1_000_000_000) + "B"
        case 1_000_000...: return trim(v / 1_000_000) + "M"
        case 1_000...: return trim(v / 1_000) + "K"
        default: return "\(n)"
        }
    }

    private static func koreanShort(_ n: Int) -> String {
        let v = Double(n)
        switch v {
        case 1_000_000_000_000...: return trim(v / 1_000_000_000_000) + "조"
        case 100_000_000...: return trim(v / 100_000_000) + "억"
        case 10_000...: return trim(v / 10_000) + "만"
        default: return integer(n)
        }
    }

    /// 받침에 맞는 조사. ("커피", "을", "를") → "커피를", ("잉크병", "을", "를") → "잉크병을"
    static func particle(_ word: String, _ withFinal: String, _ withoutFinal: String) -> String {
        if L10n.isEnglish { return L10n.tr(word) }
        guard let last = word.unicodeScalars.last, (0xAC00...0xD7A3).contains(last.value) else {
            return word + withoutFinal
        }
        return word + ((last.value - 0xAC00) % 28 != 0 ? withFinal : withoutFinal)
    }

    /// 문장 속 "(이|가)", "(은|는)", "(을|를)", "(과|와)", "(으로|로)", "(이|)" 꼴을 앞 글자의 받침에 맞게 고른다.
    /// "햄릿(은|는) 좋다" → "햄릿은 좋다", "포(과|와)" → "포와", "캐럴(으로|로)" → "캐럴로". 이름을 끼워 넣은 문장에 쓴다.
    static func resolve(_ text: String) -> String {
        if L10n.isEnglish {
            let direct = L10n.tr(text)
            if direct != text { return direct }
        }
        var out = ""
        var chars = Array(text)
        var i = 0
        while i < chars.count {
            if chars[i] == "(", let close = chars[i...].firstIndex(of: ")"), let bar = chars[i..<close].firstIndex(of: "|"),
               let previous = out.last, !chars[(i + 1)..<close].contains(" ") {
                let withFinal = String(chars[(i + 1)..<bar])
                let withoutFinal = String(chars[(bar + 1)..<close])
                out += L10n.isEnglish ? "" : pick(after: previous, withFinal, withoutFinal)
                i = close + 1
                continue
            }
            out.append(chars[i])
            i += 1
        }
        chars = []
        return L10n.isEnglish ? L10n.tr(out) : out
    }

    /// 앞 글자에 받침이 있으면 `withFinal`. "(으로|로)" 는 ㄹ 받침이면 "로". 숫자는 읽는 소리로, 로마자는 받침 없는 것으로 본다.
    private static func pick(after previous: Character, _ withFinal: String, _ withoutFinal: String) -> String {
        guard let scalar = previous.unicodeScalars.first else { return withoutFinal }
        if (0xAC00...0xD7A3).contains(scalar.value) {
            let jong = (scalar.value - 0xAC00) % 28
            if jong == 0 { return withoutFinal }
            if jong == 8, withFinal == "으로" { return withoutFinal }
            return withFinal
        }
        if let digit = previous.wholeNumberValue {
            // 영·일·삼·육·칠·팔은 받침이 있다. 일·칠·팔은 ㄹ.
            let final = [0, 1, 3, 6, 7, 8].contains(digit)
            if final, withFinal == "으로", [1, 7, 8].contains(digit) { return withoutFinal }
            return final ? withFinal : withoutFinal
        }
        return withoutFinal
    }

    /// 1234567 → "1,234,567"
    static func integer(_ n: Int) -> String {
        n.formatted(.number.grouping(.automatic))
    }

    /// 짧은 우리말 수. 12_345 → "1.2만", 123_456_789 → "1.2억", 999 → "999" (영어 모드에서는 K/M/B)
    static func short(_ n: Int) -> String {
        tokens(n)
    }

    /// 달러 원본 표기 ("$0.45", "$12.34", "$120"). 영어 모드 및 툴팁 병기용.
    static func usd(_ usd: Double) -> String {
        usd >= 100 ? String(format: "$%.0f", usd) : String(format: "$%.2f", usd)
    }

    /// 현재 언어에 맞춘 화폐 표기.
    /// - 한국어: 한글 단위형 ("0원", "450원", "14,200원", 10만 원 이상 "14.2만 원", 1억 원 이상 "1.4억 원")
    /// - 영어: "$0.45", "$12.34", "$120"
    static func cost(_ usd: Double) -> String {
        if L10n.isEnglish { return Self.usd(usd) }
        guard usd > 0 else { return "0원" }
        let krw = usd * ExchangeRate.currentRate
        if krw < 1 { return "1원" }
        switch krw {
        case 100_000_000...: return trim(krw / 100_000_000) + "억 원"
        case 100_000...: return trim(krw / 10_000) + "만 원"
        default: return integer(Int(krw.rounded())) + "원"
        }
    }

    static func percent(_ value: Double) -> String {
        let s = String(format: "%.1f", value)
        return (s.hasSuffix(".0") ? String(s.dropLast(2)) : s) + "%"
    }

    /// 초기화까지 남은 시간. "2시간 13분 후", "3일 4시간 후"
    static func until(_ date: Date, now: Date = Date()) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        if L10n.isEnglish {
            guard seconds > 0 else { return "Resets soon" }
            let days = seconds / 86_400
            let hours = seconds % 86_400 / 3600
            let minutes = seconds % 3600 / 60
            if days > 0 { return "Resets in \(days)d \(hours)h" }
            if hours > 0 { return "Resets in \(hours)h \(minutes)m" }
            return "Resets in \(max(minutes, 1))m"
        }
        guard seconds > 0 else { return "곧 초기화" }
        let days = seconds / 86_400
        let hours = seconds % 86_400 / 3600
        let minutes = seconds % 3600 / 60
        if days > 0 { return "\(days)일 \(hours)시간 후 초기화" }
        if hours > 0 { return "\(hours)시간 \(minutes)분 후 초기화" }
        return "\(max(minutes, 1))분 후 초기화"
    }

    private static func trim(_ v: Double) -> String {
        if v >= 1_000 { return integer(Int(v.rounded())) }
        let s = String(format: v >= 100 ? "%.0f" : "%.1f", v)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }
}

extension String {
    /// "(이|가)" 같은 조사 표시를 앞말에 맞춰 푼다.
    var resolvedParticles: String { Format.resolve(self) }
}

/// USD → KRW 일별 기준 환율 조회 및 로컬 캐시(오프라인 시 이전날·직전 조회 환율을 그대로 유지).
enum ExchangeRate {
    nonisolated static let rateKey = "exchangeRateUSDToKRW"
    nonisolated static let dateKey = "exchangeRateDateString"
    nonisolated static let fetchedAtKey = "exchangeRateFetchedAt"
    /// 한 번도 네트워크 조회에 성공한 적이 없을 때 쓰는 직전 영업일 기준 초기 환율(원/USD).
    nonisolated static let seedRate: Double = 1_385.0
    nonisolated static let seedDate: String = "직전 고시 환율"

    /// 테스트에서 환율을 고정할 때 쓴다.
    nonisolated(unsafe) static var overrideRate: Double? = nil
    nonisolated(unsafe) private static var cachedRate: Double? = nil
    nonisolated(unsafe) private static var cachedDate: String? = nil

    /// 현재 적용되는 1 USD 당 원화(KRW) 환율. 오프라인이면 저장된 이전날 환율을 그대로 돌려준다.
    static var currentRate: Double {
        if let overrideRate { return overrideRate }
        if L10n.isAutomatedCLI { return 1_400.0 }
        if let cachedRate { return cachedRate }
        let stored = UserDefaults.standard.double(forKey: rateKey)
        let valid = (stored >= 500 && stored <= 5_000) ? stored : seedRate
        cachedRate = valid
        return valid
    }

    /// 현재 환율의 기준일 문자열(예: "2026-10-24" 또는 "직전 고시 환율").
    static var currentDateString: String {
        if let cachedDate { return cachedDate }
        let stored = UserDefaults.standard.string(forKey: dateKey) ?? seedDate
        cachedDate = stored
        return stored
    }

    static var lastFetchedAt: Date? {
        let ts = UserDefaults.standard.double(forKey: fetchedAtKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    static func needsDailyRefresh(now: Date = Date()) -> Bool {
        guard let last = lastFetchedAt else { return true }
        return !Calendar.current.isDate(last, inSameDayAs: now)
    }

    static func save(rate: Double, dateString: String, now: Date = Date()) {
        guard rate >= 500 && rate <= 5_000 else { return }
        cachedRate = rate
        cachedDate = dateString
        let defaults = UserDefaults.standard
        defaults.set(rate, forKey: rateKey)
        defaults.set(dateString, forKey: dateKey)
        defaults.set(now.timeIntervalSince1970, forKey: fetchedAtKey)
    }

    /// Frankfurter(ECB) 또는 ExchangeRate-API JSON 응답에서 USD → KRW 환율과 기준일을 파싱한다.
    static func parseResponse(data: Data, now: Date = Date()) -> (rate: Double, date: String)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rates = json["rates"] as? [String: Any] else { return nil }
        let rawRate: Double? = (rates["KRW"] as? Double)
            ?? (rates["KRW"] as? NSNumber)?.doubleValue
        guard let rate = rawRate, rate >= 500, rate <= 5_000 else { return nil }
        if let dateStr = json["date"] as? String, !dateStr.isEmpty {
            return (rate, dateStr)
        }
        return (rate, DayKey.string(from: now))
    }

    /// 외부 무인증 공개 환율 API(1순위 Frankfurter ECB, 2순위 open.er-api)에서 최신 환율을 가져온다.
    /// 오프라인이거나 실패하면 저장된 이전날 환율을 덮어쓰지 않고 그대로 유지한다.
    static func fetchLatest() async -> (rate: Double, date: String)? {
        let endpoints = [
            "https://api.frankfurter.dev/v1/latest?base=USD&symbols=KRW",
            "https://open.er-api.com/v6/latest/USD"
        ]
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 8
        let session = URLSession(configuration: config)
        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
            var req = URLRequest(url: url)
            req.setValue("Scribe/\(AppUpdater.currentVersion)", forHTTPHeaderField: "User-Agent")
            if let (data, resp) = try? await session.data(for: req),
               let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               let parsed = parseResponse(data: data) {
                save(rate: parsed.rate, dateString: parsed.date)
                return parsed
            }
        }
        return nil
    }
}
