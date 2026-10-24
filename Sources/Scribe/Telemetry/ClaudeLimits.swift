import Foundation
import Security

/// 5시간·주간 한도 조회. PokeTokenBar(MIT, chattymin)의 `OAuthLimitsProvider` 방식을 따른다.
///
/// `api.anthropic.com/api/oauth/usage` 는 공개 API 가 아니다. 언제든 바뀔 수 있으므로
/// 실패해도 토큰 표시에는 영향을 주지 않고 한도 칸에 이유만 보여 준다.
///
/// Claude Code 자격증명은 읽기만 한다. `refreshToken` 으로 직접 갱신하면 CLI 가 쥔 토큰이
/// 바뀌어 Claude Code 가 로그아웃될 수 있다. 토큰이 만료되면 Claude Code 가 갱신할 때까지 기다리고,
/// 자동 갱신 때 Keychain 을 다시 읽어 새 토큰을 가져온다.

enum LimitsError: Error {
    case tokenExpired
    case unauthorized
    case notLoggedIn
    case keychain(OSStatus)
    case http(Int)
    case rateLimited(retryAfter: TimeInterval?)

    /// Claude Code 에서 다시 로그인해야 풀리는 오류. 앱은 안내만 하고 로그인은 Claude Code 에서 한다.
    var needsLogin: Bool {
        switch self {
        case .tokenExpired, .unauthorized, .notLoggedIn: true
        default: false
        }
    }

    var message: String {
        switch self {
        case .tokenExpired: return "Claude Code 로그인이 만료됐습니다. Claude Code 를 한 번 쓰면 저절로 이어집니다."
        case .unauthorized: return "Claude Code 로그인이 거절됐습니다. 터미널에서 claude auth login 을 실행하세요."
        case .notLoggedIn: return "Claude Code 로그인 정보가 없습니다. 터미널에서 claude auth login 을 실행하세요."
        case .keychain(let status): return "Keychain 을 읽지 못했습니다 (\(status))."
        case .http(let code): return "한도 API 오류 (HTTP \(code))."
        case .rateLimited: return "요청이 많아 잠시 쉽니다."
        }
    }
}

struct Credential: Sendable {
    let accessToken: String
    let expiresAt: Date?
    let subscriptionType: String?
    let rateLimitTier: String?

    /// 만료 1분 전부터 만료로 본다.
    var isExpired: Bool { expiresAt.map { $0 <= Date().addingTimeInterval(60) } ?? false }

    /// `max` + `default_claude_max_20x` → "Max 20x"
    var planDisplay: String? {
        guard let s = subscriptionType, !s.isEmpty else { return nil }
        let base = s.prefix(1).uppercased() + s.dropFirst()
        let multiplier = rateLimitTier?.split(separator: "_").first {
            $0.count > 1 && $0.hasSuffix("x") && $0.dropLast().allSatisfy(\.isNumber)
        }
        if let multiplier { return "\(base) \(multiplier)" }
        return base
    }

    /// `{"claudeAiOauth": {"accessToken": ..., "expiresAt": <ms>, ...}}`
    static func parse(_ data: Data) -> Credential? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty else { return nil }
        var expires: Date?
        if let raw = (oauth["expiresAt"] as? NSNumber)?.doubleValue, raw > 0 {
            expires = Date(timeIntervalSince1970: raw > 10_000_000_000 ? raw / 1000 : raw)
        }
        return Credential(
            accessToken: token, expiresAt: expires,
            subscriptionType: oauth["subscriptionType"] as? String,
            rateLimitTier: oauth["rateLimitTier"] as? String)
    }
}

/// 토큰을 메모리에만 들고 있는다. 디스크나 앱 자체 Keychain 에는 쓰지 않는다.
actor CredentialStore {
    private var cached: Credential?
    private static let keychainService = "Claude Code-credentials"

    /// `fresh` 면 메모리 캐시를 건너뛰고 다시 읽는다(새로고침 버튼, 401 뒤 재시도).
    func credential(fresh: Bool) throws -> Credential {
        // 1. 파일 자격증명. Keychain 을 안 쓰는 설치에서만 있다.
        let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/.credentials.json")
        if let data = try? Data(contentsOf: file), let c = Credential.parse(data), !c.isExpired {
            cached = c
            return c
        }
        // 2. 메모리 캐시. 만료됐으면 Claude Code 가 Keychain 에 새 토큰을 넣었을 수 있어 다시 읽는다.
        if !fresh, let cached, !cached.isExpired { return cached }
        // 3. Keychain.
        let c = try Self.readKeychain()
        cached = c
        guard !c.isExpired else { throw LimitsError.tokenExpired }
        return c
    }

    func forget() { cached = nil }

    /// 비밀번호는 `/usr/bin/security` 로 읽는다. Claude Code 가 이 도구로 항목을 만들기 때문에
    /// 항목의 접근 목록에 이미 들어 있어 암호 창이 뜨지 않고, 앱을 다시 빌드해 서명이 바뀌어도 그대로다.
    /// 앱이 `SecItemCopyMatching` 으로 데이터를 직접 읽으면 빌드마다 "항상 허용"을 다시 눌러야 했다.
    /// 같은 서비스 이름에 여러 항목이 있을 수 있어(예: `acct="unknown"` 은 MCP OAuth 만 담는다)
    /// 계정 이름은 속성만 읽어 고른다. 속성만 읽을 때는 암호 창이 뜨지 않는다.
    private static func readKeychain() throws -> Credential {
        var listResult: CFTypeRef?
        let listQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        let listStatus = SecItemCopyMatching(listQuery as CFDictionary, &listResult)
        if listStatus == errSecItemNotFound { throw LimitsError.notLoggedIn }

        let rows = (listResult as? [[String: Any]]) ?? []
        let accounts = prioritized(rows.compactMap { $0[kSecAttrAccount as String] as? String })
        let candidates: [String?] = accounts.isEmpty ? [nil] : accounts

        var lastStatus: Int32 = 0
        for account in candidates {
            let (status, data) = runSecurity(account: account)
            lastStatus = status
            if status == 0, let c = Credential.parse(data) { return c }
        }
        // 44: 항목 없음
        throw lastStatus == 0 || lastStatus == 44 ? LimitsError.notLoggedIn : LimitsError.keychain(OSStatus(lastStatus))
    }

    /// `security find-generic-password -s … [-a …] -w`. 키체인이 잠겨 있으면 응답이 없을 수 있어 5초 뒤 끊는다.
    private static func runSecurity(account: String?) -> (Int32, Data) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        var args = ["find-generic-password", "-s", keychainService]
        if let account { args += ["-a", account] }
        process.arguments = args + ["-w"]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return (-1, Data()) }
        // 바쁜 대기 대신 종료를 기다리되, 5초가 지나면 끊는다(잠긴 Keychain 이면 응답이 없을 수 있다).
        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }
        if done.wait(timeout: .now() + 5) == .timedOut {
            process.terminate()
            return (-2, Data())
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, data)
    }

    /// Mac 로그인 사용자 이름과 같은 계정을 먼저, `unknown`·`none` 은 마지막에 읽는다.
    private static func prioritized(_ names: [String]) -> [String] {
        let user = NSUserName().lowercased()
        func rank(_ name: String) -> Int {
            let lower = name.lowercased()
            if lower == "unknown" || lower == "none" { return 2 }
            return lower == user ? 0 : 1
        }
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
            .enumerated()
            .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map(\.element)
    }
}

struct LimitRow: Sendable, Identifiable {
    var id: String { name }
    let name: String
    /// 0...100
    let percent: Double
    let resetsAt: Date?
}

/// `/api/oauth/usage` 응답. 예전 필드(`five_hour`, `seven_day`)와 새 `limits[]` 가 함께 온다.
/// 모델별 주간 한도는 `limits[]` 의 `weekly_scoped` 로만 온다.
private struct UsageResponse: Decodable {
    struct Window: Decodable {
        let utilization: Double?
        let resets_at: String?
    }

    struct Limit: Decodable {
        struct Scope: Decodable {
            struct Model: Decodable { let display_name: String? }
            let model: Model?
        }
        let kind: String?
        let percent: Double?
        let resets_at: String?
        let scope: Scope?
    }

    let five_hour: Window?
    let seven_day: Window?
    let limits: [Limit]?

    var rows: [LimitRow] {
        var rows: [LimitRow] = []
        if let w = five_hour, let u = w.utilization {
            rows.append(LimitRow(name: "5시간", percent: u, resetsAt: parseISO(w.resets_at)))
        }
        if let w = seven_day, let u = w.utilization {
            rows.append(LimitRow(name: "주간", percent: u, resetsAt: parseISO(w.resets_at)))
        }
        let legacyMissing = five_hour == nil && seven_day == nil
        for l in limits ?? [] {
            guard let p = l.percent else { continue }
            if !legacyMissing && (l.kind == "session" || l.kind == "weekly_all") { continue }
            let name: String
            switch l.kind {
            case "session": name = "5시간"
            case "weekly_all": name = "주간"
            default: name = "주간 · " + (l.scope?.model?.display_name ?? l.kind ?? "기타")
            }
            rows.append(LimitRow(name: name, percent: p, resetsAt: parseISO(l.resets_at)))
        }
        return rows
    }

    private func parseISO(_ text: String?) -> Date? {
        guard let text else { return nil }
        return (try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
            ?? (try? Date(text, strategy: Date.ISO8601FormatStyle()))
    }
}

struct LimitsResult: Sendable {
    let rows: [LimitRow]
    let plan: String?
}

struct ClaudeLimitsClient: Sendable {
    private static let url = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    let credentials = CredentialStore()

    /// `userInitiated` 면 메모리의 토큰을 버리고 Keychain 을 다시 읽는다.
    func fetch(userInitiated: Bool) async throws -> LimitsResult {
        do {
            return try await fetch(credential: credentials.credential(fresh: userInitiated))
        } catch LimitsError.unauthorized where !userInitiated {
            // Claude Code 가 토큰을 바꿨을 수 있다. Keychain 을 한 번 다시 읽어 본다.
            return try await fetch(credential: credentials.credential(fresh: true))
        }
    }

    private func fetch(credential: Credential) async throws -> LimitsResult {
        var request = URLRequest(url: Self.url, timeoutInterval: 15)
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200:
            let decoded = try JSONDecoder().decode(UsageResponse.self, from: data)
            return LimitsResult(rows: decoded.rows, plan: credential.planDisplay)
        case 401, 403:
            // 토큰이 바뀌었을 수 있다. 다음 갱신이 옛 토큰을 다시 쓰지 않게 비운다.
            await credentials.forget()
            throw LimitsError.unauthorized
        case 429:
            let header = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After")
            throw LimitsError.rateLimited(retryAfter: header.flatMap { TimeInterval($0) }.map { min($0, 3600) })
        default:
            throw LimitsError.http(status)
        }
    }
}
