import Foundation

/// Claude Code 대화 로그(`<root>/**/*.jsonl`)와 Antigravity·Gemini 로그(`~/.gemini/antigravity/brain`, `~/.gemini/tmp`)에서 토큰 사용량을 읽는다.
///
/// - Claude Code: PokeTokenBar(MIT, chattymin)의 `LocalUsageReader` 방식을 따른다.
///   `type:"assistant"` 줄의 `message.usage` 를 읽고 `message.id|requestId` 로 중복을 묶는다.
/// - Antigravity: `brain/<conversation-id>/.system_generated/logs/transcript.jsonl` 에서
///   `type:"PLANNER_RESPONSE"` 줄의 `input_tokens`, `cache_read_tokens`, `output_tokens` 를 읽는다.
/// - Gemini CLI: `~/.gemini/tmp/<hash>/chats/session-*.json` 의 `messages[].tokens` 를 읽는다.
enum ClaudeLogParser {
    /// Claude Code 사용 로그가 있을 수 있는 projects 루트.
    ///
    /// 메뉴바 앱은 셸 환경을 물려받지 않아 `.zshrc` 에만 있는 `CLAUDE_CONFIG_DIR` 은 안 보인다.
    /// 프로세스 환경에 있으면 쓰고, 기본 위치 두 곳과 Claude 데스크톱 앱 세션 폴더를 함께 본다.
    static func projectRoots(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        var roots: [URL] = []
        if let raw = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"] {
            for part in raw.split(separator: ",") {
                let path = part.trimmingCharacters(in: .whitespaces)
                guard !path.isEmpty else { continue }
                roots.append(URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
                    .appendingPathComponent("projects"))
            }
        }
        roots.append(home.appendingPathComponent(".config/claude/projects"))
        roots.append(home.appendingPathComponent(".claude/projects"))
        let desktop = home.appendingPathComponent("Library/Application Support/Claude")
        for store in ["claude-code-sessions", "local-agent-mode-sessions"] {
            roots.append(contentsOf: embeddedProjectRoots(under: desktop.appendingPathComponent(store)))
        }
        return uniqueExistingDirectories(roots)
    }

    /// Antigravity 대화 트랜스크립트가 있는 `brain` 루트.
    static func antigravityRoots(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        var roots: [URL] = []
        if let raw = ProcessInfo.processInfo.environment["ANTIGRAVITY_BRAIN_DIR"] {
            for part in raw.split(separator: ",") {
                let path = part.trimmingCharacters(in: .whitespaces)
                guard !path.isEmpty else { continue }
                roots.append(URL(fileURLWithPath: NSString(string: path).expandingTildeInPath))
            }
        }
        if let raw = ProcessInfo.processInfo.environment["GEMINI_CONFIG_DIR"] {
            for part in raw.split(separator: ",") {
                let path = part.trimmingCharacters(in: .whitespaces)
                guard !path.isEmpty else { continue }
                roots.append(URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
                    .appendingPathComponent("antigravity/brain"))
            }
        }
        roots.append(home.appendingPathComponent(".gemini/antigravity/brain"))
        return uniqueExistingDirectories(roots)
    }

    /// Gemini CLI 세션 로그가 있는 `tmp` 루트.
    static func geminiCLIRoots(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        var roots: [URL] = []
        if let raw = ProcessInfo.processInfo.environment["GEMINI_CONFIG_DIR"] {
            for part in raw.split(separator: ",") {
                let path = part.trimmingCharacters(in: .whitespaces)
                guard !path.isEmpty else { continue }
                roots.append(URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
                    .appendingPathComponent("tmp"))
            }
        }
        roots.append(home.appendingPathComponent(".gemini/tmp"))
        return uniqueExistingDirectories(roots)
    }

    private static func uniqueExistingDirectories(_ urls: [URL]) -> [URL] {
        // 심볼릭 링크를 풀어 같은 폴더를 두 번 훑지 않게 한다.
        var seen = Set<String>()
        return urls.filter { url in
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                return false
            }
            return seen.insert(url.resolvingSymlinksInPath().standardizedFileURL.path).inserted
        }
    }

    /// 데스크톱 앱 세션 폴더 아래 `.claude/projects` 를 찾는다. 세션 경로에 UUID 단계가 여러 겹이라
    /// 고정 경로로는 못 잡는다. `.claude` 가 숨김 폴더라 `skipsHiddenFiles` 를 쓰면 안 된다.
    static func embeddedProjectRoots(under base: URL, maxDepth: Int = 7) -> [URL] {
        guard let en = FileManager.default.enumerator(
            at: base, includingPropertiesForKeys: [.isDirectoryKey], options: []) else { return [] }
        var out: [URL] = []
        for case let url as URL in en {
            if en.level > maxDepth { en.skipDescendants(); continue }
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            if url.lastPathComponent == "projects", url.deletingLastPathComponent().lastPathComponent == ".claude" {
                out.append(url)
                en.skipDescendants()
            } else if url.lastPathComponent == "node_modules" || url.lastPathComponent == ".git" {
                en.skipDescendants()
            }
        }
        return out
    }

    enum FileKind {
        case claude
        case antigravityTranscript
        case geminiSession

        var provider: AgentProvider {
            switch self {
            case .claude: .claude
            case .antigravityTranscript, .geminiSession: .antigravity
            }
        }
    }

    struct FileInfo {
        let url: URL
        let size: Int
        let modified: Date
        var kind: FileKind = .claude
    }

    static func jsonlFiles(in root: URL, modifiedSince: Date) -> [FileInfo] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        guard let en = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [] }
        var out: [FileInfo] = []
        for case let url as URL in en where url.pathExtension == "jsonl" {
            guard let v = try? url.resourceValues(forKeys: Set(keys)), v.isRegularFile == true,
                  let modified = v.contentModificationDate, modified >= modifiedSince else { continue }
            out.append(FileInfo(url: url, size: v.fileSize ?? 0, modified: modified, kind: .claude))
        }
        return out
    }

    /// Antigravity `brain` 폴더 아래 각 대화의 `.system_generated/logs/transcript.jsonl` 을 찾는다.
    /// `.system_generated` 가 숨김 폴더라 직접 경로를 짚어 들어가고, `transcript_full.jsonl` 과 겹쳐 두 번 세지 않게 한다.
    static func antigravityFiles(in root: URL, modifiedSince: Date) -> [FileInfo] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey, .isDirectoryKey]
        let fm = FileManager.default
        var out: [FileInfo] = []
        func checkFile(_ fileURL: URL) -> Bool {
            guard let v = try? fileURL.resourceValues(forKeys: Set(keys)), v.isRegularFile == true,
                  let modified = v.contentModificationDate else { return false }
            if modified >= modifiedSince {
                out.append(FileInfo(url: fileURL, size: v.fileSize ?? 0, modified: modified, kind: .antigravityTranscript))
            }
            return true
        }
        // 루트 바로 아래 또는 대화 폴더 직접 지정 시(.system_generated/logs/transcript.jsonl)
        _ = checkFile(root.appendingPathComponent("transcript.jsonl"))
        let directLogs = root.appendingPathComponent(".system_generated/logs")
        if !checkFile(directLogs.appendingPathComponent("transcript.jsonl")) {
            _ = checkFile(directLogs.appendingPathComponent("transcript_full.jsonl"))
        }
        guard let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return out
        }
        for child in children {
            guard (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            let logsDir = child.appendingPathComponent(".system_generated/logs")
            if !checkFile(logsDir.appendingPathComponent("transcript.jsonl")) {
                _ = checkFile(logsDir.appendingPathComponent("transcript_full.jsonl"))
            }
            _ = checkFile(child.appendingPathComponent("transcript.jsonl"))
        }
        return out
    }

    /// Gemini CLI 의 `~/.gemini/tmp/<hash>/chats/session-*.json` 파일을 찾는다.
    static func geminiCLIFiles(in root: URL, modifiedSince: Date) -> [FileInfo] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey, .isDirectoryKey]
        let fm = FileManager.default
        guard let hashes = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        var out: [FileInfo] = []
        for dir in hashes {
            let chatsDir = dir.appendingPathComponent("chats")
            guard let files = try? fm.contentsOfDirectory(at: chatsDir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { continue }
            for file in files where file.pathExtension == "json" {
                guard let v = try? file.resourceValues(forKeys: Set(keys)), v.isRegularFile == true,
                      let modified = v.contentModificationDate, modified >= modifiedSince else { continue }
                out.append(FileInfo(url: file, size: v.fileSize ?? 0, modified: modified, kind: .geminiSession))
            }
        }
        return out
    }

    static func parse(_ file: FileInfo) -> [UsageEntry] {
        switch file.kind {
        case .claude: parseFile(file.url)
        case .antigravityTranscript: parseAntigravityFile(file.url)
        case .geminiSession: parseGeminiSessionFile(file.url)
        }
    }

    /// 파일 하나를 읽어 파일 안에서 한 번 묶은 결과를 돌려준다.
    ///
    /// 줄 나누기와 거르기는 바이트 단위로 한다. `String.split` 은 문자 경계를 계산하느라
    /// 1.7GB 로그에서 50초가 걸렸다(바이트 단위로는 몇 초).
    static func parseFile(_ url: URL) -> [UsageEntry] {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return [] }
        var out: [UsageEntry] = []
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let base = buffer.baseAddress else { return }
            var start = 0
            while start < buffer.count {
                let end = memchr(base + start, 0x0A, buffer.count - start)
                    .map { base.distance(to: UnsafeRawPointer($0)) } ?? buffer.count
                let line = base + start
                let length = end - start
                start = end + 1
                // JSON 을 풀기 전에 먼저 거른다. 대부분의 줄이 여기서 빠진다.
                guard length > 0,
                      contains(line, length, usageNeedle),
                      contains(line, length, assistantNeedle) else { continue }
                autoreleasepool {
                    if let e = parseLine(Data(bytes: line, count: length)) { out.append(e) }
                }
            }
        }
        return dedupKeepMax(out)
    }

    /// Antigravity `transcript.jsonl` 하나를 읽는다.
    /// `USER_INPUT` 의 `<USER_SETTINGS_CHANGE>` 에서 고른 모델 이름을 따라가며 `PLANNER_RESPONSE` 의 토큰을 읽는다.
    static func parseAntigravityFile(_ url: URL) -> [UsageEntry] {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return [] }
        let convID = conversationID(for: url)
        var currentModel = "Gemini (Antigravity)"
        var out: [UsageEntry] = []
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let base = buffer.baseAddress else { return }
            var start = 0
            while start < buffer.count {
                let end = memchr(base + start, 0x0A, buffer.count - start)
                    .map { base.distance(to: UnsafeRawPointer($0)) } ?? buffer.count
                let line = base + start
                let length = end - start
                start = end + 1
                guard length > 0 else { continue }
                if contains(line, length, modelSelectionNeedle) {
                    autoreleasepool {
                        if let model = extractAntigravityModel(Data(bytes: line, count: length)) {
                            currentModel = model
                        }
                    }
                }
                guard contains(line, length, plannerNeedle),
                      contains(line, length, inputTokensNeedle) else { continue }
                autoreleasepool {
                    if let e = parseAntigravityLine(Data(bytes: line, count: length), conversationID: convID, defaultModel: currentModel) {
                        out.append(e)
                    }
                }
            }
        }
        return dedupKeepMax(out)
    }

    private static func conversationID(for url: URL) -> String {
        let parent = url.deletingLastPathComponent()
        if parent.lastPathComponent == "logs" {
            let sys = parent.deletingLastPathComponent()
            if sys.lastPathComponent == ".system_generated" {
                return sys.deletingLastPathComponent().lastPathComponent
            }
        }
        return parent.lastPathComponent
    }

    /// `<USER_SETTINGS_CHANGE>` 안의 `Model Selection` 변경 문장에서 모델 이름을 뽑는다.
    private static func extractAntigravityModel(_ line: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let content = obj["content"] as? String,
              let marker = content.range(of: "Model Selection` from ") else { return nil }
        let after = content[marker.upperBound...]
        guard let toRange = after.range(of: " to ") else { return nil }
        let tail = after[toRange.upperBound...]
        let end = tail.firstIndex { $0 == "." || $0 == "\n" || $0 == "<" } ?? tail.endIndex
        let candidate = tail[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, candidate.lowercased() != "none" else { return nil }
        return candidate
    }

    static func parseAntigravityLine(_ line: Data, conversationID: String = "agy", defaultModel: String = "Gemini (Antigravity)") -> UsageEntry? {
        guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              obj["type"] as? String == "PLANNER_RESPONSE",
              let ts = (obj["created_at"] as? String) ?? (obj["timestamp"] as? String),
              let date = parseDate(ts) else { return nil }
        let input = int(obj["input_tokens"])
        let output = int(obj["output_tokens"])
        let cacheRead = int(obj["cache_read_tokens"])
        let cacheWrite = int(obj["cache_write_tokens"])
        guard input + output + cacheRead + cacheWrite > 0 else { return nil }
        let step = obj["step_index"].map { "\(int($0))" } ?? UUID().uuidString
        let rawModel = (obj["model"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = (rawModel?.isEmpty == false ? rawModel! : defaultModel)
        return UsageEntry(
            id: "agy|\(conversationID)|\(step)",
            provider: .antigravity,
            date: date,
            model: model,
            input: input,
            output: output,
            cacheWrite5m: cacheWrite,
            cacheWrite1h: 0,
            cacheRead: cacheRead)
    }

    /// Gemini CLI 의 `session-*.json` 파일을 읽는다.
    static func parseGeminiSessionFile(_ url: URL) -> [UsageEntry] {
        return autoreleasepool {
            guard let data = try? Data(contentsOf: url),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let messages = obj["messages"] as? [[String: Any]] else { return [] }
            let sessionID = (obj["sessionId"] as? String) ?? url.deletingPathExtension().lastPathComponent
            var out: [UsageEntry] = []
            for (idx, msg) in messages.enumerated() {
                guard msg["type"] as? String == "gemini",
                      let tokens = msg["tokens"] as? [String: Any],
                      let ts = msg["timestamp"] as? String,
                      let date = parseDate(ts) else { continue }
                let cached = int(tokens["cached"])
                let rawInput = int(tokens["input"])
                let input = max(0, rawInput - cached)
                let output = int(tokens["output"]) + int(tokens["thoughts"]) + int(tokens["tool"])
                guard input + output + cached > 0 else { continue }
                let msgID = (msg["id"] as? String) ?? "\(idx)"
                let model = (msg["model"] as? String) ?? "Gemini CLI"
                out.append(UsageEntry(
                    id: "gcli|\(sessionID)|\(msgID)",
                    provider: .antigravity,
                    date: date,
                    model: model,
                    input: input,
                    output: output,
                    cacheWrite5m: 0,
                    cacheWrite1h: 0,
                    cacheRead: cached))
            }
            return dedupKeepMax(out)
        }
    }

    private static let usageNeedle = Array("\"usage\"".utf8)
    private static let assistantNeedle = Array("\"assistant\"".utf8)
    private static let plannerNeedle = Array("\"PLANNER_RESPONSE\"".utf8)
    private static let inputTokensNeedle = Array("\"input_tokens\"".utf8)
    private static let modelSelectionNeedle = Array("Model Selection".utf8)

    private static func contains(_ haystack: UnsafeRawPointer, _ length: Int, _ needle: [UInt8]) -> Bool {
        needle.withUnsafeBytes { memmem(haystack, length, $0.baseAddress, needle.count) != nil }
    }

    static func parseLine(_ line: Data) -> UsageEntry? {
        guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              obj["type"] as? String == "assistant",
              let msg = obj["message"] as? [String: Any],
              let usage = msg["usage"] as? [String: Any],
              let ts = obj["timestamp"] as? String,
              let date = parseDate(ts) else { return nil }

        var id = (msg["id"] as? String ?? "") + "|" + (obj["requestId"] as? String ?? "")
        // 둘 다 없으면 모든 줄이 하나로 묶이므로 줄마다 다른 uuid 를 쓴다.
        if id == "|" { id = obj["uuid"] as? String ?? UUID().uuidString }

        let writeTotal = int(usage["cache_creation_input_tokens"])
        var write1h = 0
        var write5m = writeTotal
        if let detail = usage["cache_creation"] as? [String: Any] {
            write1h = int(detail["ephemeral_1h_input_tokens"])
            write5m = int(detail["ephemeral_5m_input_tokens"])
            // 세부 합이 전체보다 작으면 나머지는 5분 쓰기로 본다.
            write5m += max(0, writeTotal - write1h - write5m)
        }

        return UsageEntry(
            id: id, provider: .claude, date: date, model: msg["model"] as? String ?? "unknown",
            input: int(usage["input_tokens"]),
            output: int(usage["output_tokens"]),
            cacheWrite5m: write5m,
            cacheWrite1h: write1h,
            cacheRead: int(usage["cache_read_input_tokens"]))
    }

    static func dedupKeepMax(_ entries: [UsageEntry]) -> [UsageEntry] {
        var byID: [String: UsageEntry] = [:]
        byID.reserveCapacity(entries.count)
        for e in entries {
            guard let existing = byID[e.id] else {
                byID[e.id] = e
                continue
            }
            var kept = e.total > existing.total ? e : existing
            kept.date = min(e.date, existing.date)
            byID[e.id] = kept
        }
        return Array(byID.values)
    }

    private static func int(_ value: Any?) -> Int {
        switch value {
        case let n as NSNumber:
            let d = n.doubleValue
            return d.isFinite && d >= 0 && d < Double(Int.max) ? n.intValue : 0
        case let s as String: return Int(s) ?? 0
        default: return 0
        }
    }

    private static func parseDate(_ text: String) -> Date? {
        if let d = try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
            return d
        }
        return try? Date(text, strategy: Date.ISO8601FormatStyle())
    }

    static func allFiles(claudeRoots: [URL], antigravityRoots: [URL], geminiRoots: [URL], modifiedSince since: Date) -> [FileInfo] {
        var out: [FileInfo] = []
        for root in claudeRoots {
            out.append(contentsOf: jsonlFiles(in: root, modifiedSince: since))
        }
        for root in antigravityRoots {
            out.append(contentsOf: antigravityFiles(in: root, modifiedSince: since))
        }
        for root in geminiRoots {
            out.append(contentsOf: geminiCLIFiles(in: root, modifiedSince: since))
        }
        return out
    }

    /// 캐시 없이 한 번에 훑는다. `--dump` 에서 쓴다.
    static func scanAll(since: Date) -> (entries: [UsageEntry], files: Int) {
        let result = scanAllWithProviders(since: since)
        return (result.entries, result.files)
    }

    static func scanAllWithProviders(since: Date) -> (entries: [UsageEntry], files: Int, filesByProvider: [AgentProvider: Int]) {
        var all: [UsageEntry] = []
        var filesByProvider: [AgentProvider: Int] = [:]
        let files = allFiles(
            claudeRoots: projectRoots(),
            antigravityRoots: antigravityRoots(),
            geminiRoots: geminiCLIRoots(),
            modifiedSince: since)
        for file in files {
            filesByProvider[file.kind.provider, default: 0] += 1
            all.append(contentsOf: parse(file))
        }
        return (dedupKeepMax(all), files.count, filesByProvider)
    }
}

/// 파일별 결과를 크기·수정 시각과 함께 기억해 두고, 바뀐 파일만 다시 읽는다.
actor ClaudeLogScanner {
    private struct Cached {
        let size: Int
        let modified: Date
        let entries: [UsageEntry]
    }

    private var cache: [String: Cached] = [:]
    private var claudeRoots: [URL] = []
    private var antigravityRoots: [URL] = []
    private var geminiRoots: [URL] = []
    private var rootsCheckedAt: Date = .distantPast

    func scan(since: Date) -> (entries: [UsageEntry], files: Int, filesByProvider: [AgentProvider: Int]) {
        // 데스크톱 세션 폴더 탐색은 무거워서 5분에 한 번만 다시 찾는다.
        if Date().timeIntervalSince(rootsCheckedAt) > 300 {
            claudeRoots = ClaudeLogParser.projectRoots()
            antigravityRoots = ClaudeLogParser.antigravityRoots()
            geminiRoots = ClaudeLogParser.geminiCLIRoots()
            rootsCheckedAt = Date()
        }

        var all: [UsageEntry] = []
        var alive = Set<String>()
        var filesByProvider: [AgentProvider: Int] = [:]
        let files = ClaudeLogParser.allFiles(
            claudeRoots: claudeRoots,
            antigravityRoots: antigravityRoots,
            geminiRoots: geminiRoots,
            modifiedSince: since)
        for file in files {
            let path = file.url.path
            guard alive.insert(path).inserted else { continue }
            filesByProvider[file.kind.provider, default: 0] += 1
            if let hit = cache[path], hit.size == file.size, hit.modified == file.modified {
                all.append(contentsOf: hit.entries)
                continue
            }
            let entries = ClaudeLogParser.parse(file)
            cache[path] = Cached(size: file.size, modified: file.modified, entries: entries)
            all.append(contentsOf: entries)
        }
        cache = cache.filter { alive.contains($0.key) }
        return (ClaudeLogParser.dedupKeepMax(all), alive.count, filesByProvider)
    }
}
