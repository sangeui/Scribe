import Foundation

enum Format {
    /// 1234 → "1.2K", 200_700_000 → "200.7M"
    static func tokens(_ n: Int) -> String {
        let v = Double(n)
        switch v {
        case 1_000_000_000...: return trim(v / 1_000_000_000) + "B"
        case 1_000_000...: return trim(v / 1_000_000) + "M"
        case 1_000...: return trim(v / 1_000) + "K"
        default: return "\(n)"
        }
    }

    /// 받침에 맞는 조사. ("커피", "을", "를") → "커피를", ("잉크병", "을", "를") → "잉크병을"
    static func particle(_ word: String, _ withFinal: String, _ withoutFinal: String) -> String {
        guard let last = word.unicodeScalars.last, (0xAC00...0xD7A3).contains(last.value) else {
            return word + withoutFinal
        }
        return word + ((last.value - 0xAC00) % 28 != 0 ? withFinal : withoutFinal)
    }

    /// 문장 속 "(이|가)", "(은|는)", "(을|를)", "(과|와)", "(으로|로)", "(이|)" 꼴을 앞 글자의 받침에 맞게 고른다.
    /// "햄릿(은|는) 좋다" → "햄릿은 좋다", "포(과|와)" → "포와", "캐럴(으로|로)" → "캐럴로". 이름을 끼워 넣은 문장에 쓴다.
    static func resolve(_ text: String) -> String {
        var out = ""
        var chars = Array(text)
        var i = 0
        while i < chars.count {
            if chars[i] == "(", let close = chars[i...].firstIndex(of: ")"), let bar = chars[i..<close].firstIndex(of: "|"),
               let previous = out.last, !chars[(i + 1)..<close].contains(" ") {
                let withFinal = String(chars[(i + 1)..<bar])
                let withoutFinal = String(chars[(bar + 1)..<close])
                out += pick(after: previous, withFinal, withoutFinal)
                i = close + 1
                continue
            }
            out.append(chars[i])
            i += 1
        }
        chars = []
        return out
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

    /// 짧은 우리말 수. 12_345 → "1.2만", 123_456_789 → "1.2억", 999 → "999"
    static func short(_ n: Int) -> String {
        let v = Double(n)
        switch v {
        case 100_000_000...: return trim(v / 100_000_000) + "억"
        case 10_000...: return trim(v / 10_000) + "만"
        default: return integer(n)
        }
    }

    static func cost(_ usd: Double) -> String {
        usd >= 100 ? String(format: "$%.0f", usd) : String(format: "$%.2f", usd)
    }

    static func percent(_ value: Double) -> String {
        let s = String(format: "%.1f", value)
        return (s.hasSuffix(".0") ? String(s.dropLast(2)) : s) + "%"
    }

    /// 초기화까지 남은 시간. "2시간 13분 후", "3일 4시간 후"
    static func until(_ date: Date, now: Date = Date()) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        guard seconds > 0 else { return "곧 초기화" }
        let days = seconds / 86_400
        let hours = seconds % 86_400 / 3600
        let minutes = seconds % 3600 / 60
        if days > 0 { return "\(days)일 \(hours)시간 후 초기화" }
        if hours > 0 { return "\(hours)시간 \(minutes)분 후 초기화" }
        return "\(max(minutes, 1))분 후 초기화"
    }

    private static func trim(_ v: Double) -> String {
        let s = String(format: v >= 100 ? "%.0f" : "%.1f", v)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }
}

extension String {
    /// "(이|가)" 같은 조사 표시를 앞말에 맞춰 푼다.
    var resolvedParticles: String { Format.resolve(self) }
}
