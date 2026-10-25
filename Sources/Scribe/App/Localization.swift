import Foundation

/// 앱 표시 언어 설정. 시스템 기본값(macOS 선호 언어), 한국어, 영어 가운데 고른다.
enum AppLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case system
    case ko
    case en

    var id: String { rawValue }
    nonisolated static let key = "appLanguage"

    var title: String {
        switch self {
        case .system: L10n.isEnglish ? "System Default" : "시스템 기본값"
        case .ko: "한국어"
        case .en: "English"
        }
    }
}

/// 런타임 국제화(한국어·영어) 엔진.
/// `Resources/Localizable.xcstrings`(컴파일 시 `en.lproj/Localizable.strings`, `ko.lproj/Localizable.strings`)를 읽어
/// SwiftUI `Locale` 환경 주입과 동적 문자열 변환(`L10n.tr`)을 함께 처리한다.
enum L10n {
    /// 테스트나 미리보기에서 언어를 강제로 고정할 때 쓴다.
    nonisolated(unsafe) static var overrideLanguage: AppLanguage? = nil
    nonisolated(unsafe) private static var cachedPreference: AppLanguage? = nil

    /// `--selftest`, `--snapshot` 등 자동화 실행에서는 시스템 로케일(예: GitHub Actions 의 `en_US`)에 흔들리지 않도록 기본값을 한국어로 둔다.
    nonisolated static let isAutomatedCLI: Bool = {
        let flags: Set<String> = [
            "--selftest", "--tour", "--snapshot", "--export-icons",
            "--export-record", "--import-record", "--reset-record", "--preview"
        ]
        return CommandLine.arguments.contains { flags.contains($0) }
    }()

    static var preference: AppLanguage {
        if let overrideLanguage { return overrideLanguage }
        if isAutomatedCLI { return .ko }
        if let cachedPreference { return cachedPreference }
        let raw = UserDefaults.standard.string(forKey: AppLanguage.key) ?? ""
        let lang = AppLanguage(rawValue: raw) ?? .system
        cachedPreference = lang
        return lang
    }

    static func setPreference(_ language: AppLanguage) {
        cachedPreference = language
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.key)
    }

    static var resolvedLanguage: AppLanguage {
        switch preference {
        case .ko: return .ko
        case .en: return .en
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "ko"
            return preferred.hasPrefix("en") ? .en : .ko
        }
    }

    static var isEnglish: Bool { resolvedLanguage == .en }
    static var locale: Locale { Locale(identifier: isEnglish ? "en" : "ko") }

    /// 한국어 원문 또는 동적 조립 문자열을 현재 언어에 맞춰 번역한다. 한국어 모드에서는 즉시 원문을 돌려준다.
    static func tr(_ text: String) -> String {
        guard isEnglish, !text.isEmpty else { return text }
        if text.contains("\n") {
            return text.components(separatedBy: "\n").map { translateSingleLine($0) }.joined(separator: "\n")
        }
        return translateSingleLine(text)
    }

    private static func translateSingleLine(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return text }
        let cat = Catalog.shared
        if let hit = cat.exact[text] { return hit }
        if let hit = cat.exact[trimmed] { return hit }
        if let matched = cat.matchPattern(text) { return matched }
        if text.contains(" → ") {
            let parts = text.components(separatedBy: " → ")
            let translated = parts.map { translateSingleLine($0) }
            if translated != parts { return translated.joined(separator: " → ") }
        }
        if text.contains(" · ") {
            let parts = text.components(separatedBy: " · ")
            let translated = parts.map { translateSingleLine($0) }
            if translated != parts { return translated.joined(separator: " · ") }
        }
        // 서평처럼 문장 여러 개가 공백으로 이어진 경우 문장 단위로 번역한다.
        if text.contains(". ") {
            let clauses = text.components(separatedBy: ". ")
            if clauses.count >= 2 {
                var allTranslated = true
                var out: [String] = []
                for (idx, clause) in clauses.enumerated() {
                    let withDot = idx < clauses.count - 1 ? (clause.hasSuffix(".") ? clause : clause + ".") : clause
                    let trClause = cat.exact[withDot] ?? cat.exact[clause] ?? cat.matchPattern(withDot) ?? cat.matchPattern(clause)
                    if let trClause {
                        out.append(trClause.hasSuffix(".") ? String(trClause.dropLast()) : trClause)
                    } else {
                        allTranslated = false
                        break
                    }
                }
                if allTranslated {
                    let joined = out.joined(separator: ". ")
                    return joined.hasSuffix(".") || joined.hasSuffix("!") || joined.hasSuffix("?") ? joined : joined + "."
                }
            }
        }
        return text
    }

    // MARK: - 번역 카탈로그 로더 및 정규식 매처

    private final class Catalog: @unchecked Sendable {
        static let shared = Catalog()

        struct PatternRule {
            let regex: NSRegularExpression
            let segments: [Segment]
            let literalLength: Int

            enum Segment {
                case text(String)
                case capture(Int)
            }
        }

        let exact: [String: String]
        let patterns: [PatternRule]

        private init() {
            let raw = Self.loadRawTable()
            var exactMap: [String: String] = [:]
            var rules: [PatternRule] = []

            for (ko, en) in raw {
                exactMap[ko] = en
                for variant in Self.particleVariants(of: ko) {
                    if exactMap[variant] == nil {
                        exactMap[variant] = en
                    }
                }
                if let rule = Self.buildPatternRule(ko: ko, en: en) {
                    rules.append(rule)
                }
            }

            // 수동 보강 규칙 (숫자·날짜·단위 등 동적 조각)
            for (ko, en) in Self.builtinPatterns {
                if let rule = Self.buildPatternRule(ko: ko, en: en) {
                    rules.append(rule)
                }
            }

            rules.sort { $0.literalLength > $1.literalLength }
            self.exact = exactMap
            self.patterns = rules
        }

        func matchPattern(_ input: String) -> String? {
            let ns = input as NSString
            let range = NSRange(location: 0, length: ns.length)
            for rule in patterns {
                guard let m = rule.regex.firstMatch(in: input, options: [], range: range) else { continue }
                var result = ""
                for segment in rule.segments {
                    switch segment {
                    case .text(let s):
                        result += s
                    case .capture(let idx):
                        let groupIndex = idx + 1
                        guard groupIndex < m.numberOfRanges else { continue }
                        let r = m.range(at: groupIndex)
                        guard r.location != NSNotFound else { continue }
                        let captured = ns.substring(with: r)
                        result += translateCapture(captured)
                    }
                }
                return result
            }
            return nil
        }

        private func translateCapture(_ value: String) -> String {
            if let hit = exact[value] { return hit }
            // 쉼표나 조사 등이 붙은 작은 값 변환
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            if let hit = exact[trimmed] { return hit }
            return value
        }

        private static func loadRawTable() -> [String: String] {
            var merged: [String: String] = [:]
            let fm = FileManager.default
            let cwd = fm.currentDirectoryPath

            // 1. Resources/Localizable.xcstrings 직접 파싱 (개발·테스트 시 최신 번역 보장)
            let xcstringsPaths = [
                cwd + "/Resources/Localizable.xcstrings",
                Bundle.main.bundleURL.deletingLastPathComponent().path + "/Resources/Localizable.xcstrings"
            ]
            for path in xcstringsPaths where fm.fileExists(atPath: path) {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let strings = json["strings"] as? [String: Any] {
                    for (key, entryAny) in strings {
                        guard let entry = entryAny as? [String: Any],
                              let locs = entry["localizations"] as? [String: Any],
                              let en = locs["en"] as? [String: Any],
                              let unit = en["stringUnit"] as? [String: Any],
                              let val = unit["value"] as? String, !val.isEmpty else { continue }
                        merged[key] = val
                    }
                    break
                }
            }

            // 2. 번들 내 컴파일된 en.lproj/Localizable.strings 로드
            var stringsPaths: [String] = []
            if let bundleEn = Bundle.main.path(forResource: "en", ofType: "lproj") {
                stringsPaths.append(bundleEn + "/Localizable.strings")
            }
            if let direct = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "en") {
                stringsPaths.append(direct)
            }
            stringsPaths.append(cwd + "/build/Scribe.app/Contents/Resources/en.lproj/Localizable.strings")

            for path in stringsPaths where fm.fileExists(atPath: path) {
                if let dict = NSDictionary(contentsOfFile: path) as? [String: String] {
                    for (k, v) in dict where !v.isEmpty {
                        merged[k] = v
                    }
                }
            }

            // 작가 한글 이름·약칭 기본 매핑
            let authors: [String: String] = [
                "셰익스피어": "Shakespeare",
                "윌리엄 셰익스피어": "William Shakespeare",
                "디킨스": "Dickens",
                "찰스 디킨스": "Charles Dickens",
                "포": "Poe",
                "에드거 앨런 포": "Edgar Allan Poe",
                "캐럴": "Carroll",
                "루이스 캐럴": "Lewis Carroll",
                "도일": "Doyle",
                "아서 코난 도일": "Arthur Conan Doyle",
                "스티븐슨": "Stevenson",
                "로버트 루이스 스티븐슨": "Robert Louis Stevenson",
                "오스틴": "Austen",
                "제인 오스틴": "Jane Austen",
                "괴테": "Goethe",
                "요한 볼프강 폰 괴테": "Johann Wolfgang von Goethe",
                "와일드": "Wilde",
                "오스카 와일드": "Oscar Wilde"
            ]
            for (k, v) in authors { merged[k] = v }
            for book in Library.books {
                if let ko = book.titleKo { merged[ko] = book.title }
                if let aKo = book.authorKo { merged[aKo] = book.author }
            }
            return merged
        }

        private static let particlePairs: [(marker: String, first: String, second: String)] = [
            ("(이|가)", "이", "가"),
            ("(가|이)", "가", "이"),
            ("(을|를)", "을", "를"),
            ("(를|을)", "를", "을"),
            ("(은|는)", "은", "는"),
            ("(는|은)", "는", "은"),
            ("(과|와)", "과", "와"),
            ("(와|과)", "와", "과"),
            ("(으로|로)", "으로", "로"),
            ("(로|으로)", "로", "으로"),
        ]

        private static func particleVariants(of text: String) -> [String] {
            guard text.contains("(") && text.contains("|") else { return [] }
            var firstVariant = text
            var secondVariant = text
            for p in particlePairs {
                firstVariant = firstVariant.replacingOccurrences(of: p.marker, with: p.first)
                secondVariant = secondVariant.replacingOccurrences(of: p.marker, with: p.second)
            }
            return [firstVariant, secondVariant]
        }

        /// 플레이스홀더(`\(...)`, `%@`, `%lld`, `{0}`, `{1}`, `{A}`, `{B}`, `{T}`, `{title}` 등)를 감지하는 정규식.
        private static let placeholderRegex: NSRegularExpression = {
            let pattern = #"\\\((?:[^()]|\((?:[^()]|\([^()]*\))*\))+\)|%(?:\d+\$)?(?:\.\d+)?(?:lld|ld|d|f|lf|@)|\{[A-Za-z0-9]+\}"#
            return try! NSRegularExpression(pattern: pattern)
        }()

        private static func buildPatternRule(ko: String, en: String) -> PatternRule? {
            let nsKo = ko as NSString
            let koMatches = placeholderRegex.matches(in: ko, range: NSRange(location: 0, length: nsKo.length))
            guard !koMatches.isEmpty else { return nil }

            var regexPattern = "^"
            var cursor = 0
            var koTokens: [String] = []
            var literalLen = 0
            var literalOnly = ""

            for (idx, m) in koMatches.enumerated() {
                if m.range.location > cursor {
                    let lit = nsKo.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
                    let stripped = stripParticleMarkers(lit)
                    literalLen += stripped.count
                    literalOnly += stripped
                    regexPattern += escapeLiteralWithParticles(lit)
                }
                let token = nsKo.substring(with: m.range)
                koTokens.append(token)
                let isAtEnd = (idx == koMatches.count - 1) && (m.range.location + m.range.length == nsKo.length)
                regexPattern += isAtEnd ? "(.+)" : "(.+?)"
                cursor = m.range.location + m.range.length
            }
            if cursor < nsKo.length {
                let tail = nsKo.substring(from: cursor)
                let stripped = stripParticleMarkers(tail)
                literalLen += stripped.count
                literalOnly += stripped
                regexPattern += escapeLiteralWithParticles(tail)
            }
            regexPattern += "$"

            // 조사 마커를 뺀 순수 고정 리터럴에 한글이 없거나 너무 짧으면 무차별 매칭되므로 제외
            let meaningfulLiteral = literalOnly.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) }
            guard meaningfulLiteral, let compiled = try? NSRegularExpression(pattern: regexPattern) else { return nil }

            // 영어 문자열을 세그먼트로 분해하고 각 플레이스홀더가 어느 캡처 그룹을 가리키는지 연결
            let nsEn = en as NSString
            let enMatches = placeholderRegex.matches(in: en, range: NSRange(location: 0, length: nsEn.length))
            var segments: [PatternRule.Segment] = []
            var enCursor = 0
            var usedSequential = 0

            for m in enMatches {
                if m.range.location > enCursor {
                    let textSeg = nsEn.substring(with: NSRange(location: enCursor, length: m.range.location - enCursor))
                    segments.append(.text(textSeg))
                }
                let enToken = nsEn.substring(with: m.range)
                let captureIdx: Int
                if let pos = positionalIndex(of: enToken), pos >= 1, pos <= koTokens.count {
                    captureIdx = pos - 1
                } else if (enToken.hasPrefix("\\(") || enToken.hasPrefix("{")),
                          let exactIdx = koTokens.firstIndex(of: enToken) {
                    captureIdx = exactIdx
                } else {
                    captureIdx = min(usedSequential, koTokens.count - 1)
                }
                usedSequential += 1
                segments.append(.capture(captureIdx))
                enCursor = m.range.location + m.range.length
            }
            if enCursor < nsEn.length {
                segments.append(.text(nsEn.substring(from: enCursor)))
            }

            return PatternRule(regex: compiled, segments: segments, literalLength: literalLen)
        }

        private static func positionalIndex(of token: String) -> Int? {
            // "%1$@", "%2$lld" 등에서 번호 추출
            guard token.hasPrefix("%"), let dollar = token.firstIndex(of: "$") else { return nil }
            let digits = token[token.index(after: token.startIndex)..<dollar]
            return Int(digits)
        }

        private static func stripParticleMarkers(_ lit: String) -> String {
            var working = lit
            for p in particlePairs {
                working = working.replacingOccurrences(of: p.marker, with: "")
            }
            return working
        }

        private static func escapeLiteralWithParticles(_ lit: String) -> String {
            var placeholders: [String: String] = [:]
            var working = lit
            for (i, p) in particlePairs.enumerated() {
                let token = "__PARTICLE_\(i)__"
                if working.contains(p.marker) {
                    working = working.replacingOccurrences(of: p.marker, with: token)
                    let escapedMarker = NSRegularExpression.escapedPattern(for: p.marker)
                    placeholders[token] = "(?:\(p.first)|\(p.second)|\(escapedMarker))"
                }
            }
            var escaped = NSRegularExpression.escapedPattern(for: working)
            for (token, regexFrag) in placeholders {
                escaped = escaped.replacingOccurrences(of: token, with: regexFrag)
            }
            return escaped
        }

        private static let builtinPatterns: [(String, String)] = [
            ("%@ · 초상 %@", "%1$@ · Portrait %2$@"),
            ("%@ 탈고", "Completed %@"),
            ("%lld편 뒤", "%lld ahead"),
            ("%lld일 소요", "%lldd taken"),
            ("%@부 판매", "%@ sold"),
            ("오늘 +%@자", "+%@ chars today"),
            ("탈고까지 약 %lld일", "~%lldd to finish"),
            ("분량 %@자", "%@ chars"),
            ("%@자", "%@ chars"),
            ("오늘 %@", "Today %@"),
            ("어제 %@", "Yesterday %@"),
            ("%lld분", "%lldm"),
            ("%lld시간", "%lldh"),
            ("%lld일째", "Day %lld"),
            ("%lld번", "%lldx"),
            ("%@으로 끝냄", "Cured with %@"),
            ("%@로 끝냄", "Cured with %@"),
            ("주간 · %@", "Weekly · %@"),
        ]
    }
}
