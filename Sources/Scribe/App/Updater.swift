import AppKit
import Foundation
import Observation

/// GitHub Releases 기반 인앱 자동 업데이터(외부 의존성 없음).
/// 1) `sangeui/Scribe` 의 최신 릴리스를 확인하고 SemVer 로 비교한다.
/// 2) 새 버전이 있으면 `Scribe.zip` 을 내려받아 압축을 풀고 `codesign --verify` 로 무결성을 검증한다.
/// 3) `xattr -cr` 로 격리 속성을 지운 뒤 백그라운드 셸을 통해 현재 `.app` 번들을 원자적으로 교체하고 다시 연다.
@MainActor
@Observable
final class AppUpdater {
    nonisolated static let autoCheckKey = "autoCheckUpdates"
    nonisolated static let repo = "sangeui/Scribe"

    struct ReleaseInfo: Equatable, Sendable {
        let version: String
        let tagName: String
        let downloadURL: URL
        let pageURL: URL
        let notes: String
    }

    enum State: Equatable {
        case idle
        case checking
        case upToDate(Date)
        case available(ReleaseInfo)
        case installing(String)
        case failed(String)
    }

    private(set) var state: State = .idle
    @ObservationIgnored private var lastCheckedAt: Date = .distantPast
    /// 자동 확인 주기: 12시간.
    private static let checkInterval: TimeInterval = 12 * 3600

    static var isAutoCheckEnabled: Bool {
        if UserDefaults.standard.object(forKey: autoCheckKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: autoCheckKey)
    }

    var availableRelease: ReleaseInfo? {
        if case .available(let info) = state { return info }
        return nil
    }

    var isInstalling: Bool {
        if case .installing = state { return true }
        return false
    }

    nonisolated static var currentVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.1.0"
    }

    /// 자동 확인이 켜져 있고 마지막 확인 뒤 12시간이 지났으면 백그라운드에서 조용히 확인한다.
    func checkIfNeeded() async {
        guard Self.isAutoCheckEnabled else { return }
        guard Date().timeIntervalSince(lastCheckedAt) >= Self.checkInterval else { return }
        if case .installing = state { return }
        await check(userInitiated: false)
    }

    /// 최신 릴리스를 조회한다. `userInitiated` 가 false 면 네트워크 오류 시 조용히 넘긴다.
    func check(userInitiated: Bool = true) async {
        if case .installing = state { return }
        if userInitiated { state = .checking }
        lastCheckedAt = Date()

        guard let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else {
            if userInitiated { state = .failed("릴리스 주소를 만들지 못했습니다.") }
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Scribe/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                if userInitiated { state = .failed("GitHub 릴리스 정보를 읽지 못했습니다.") }
                return
            }
            let current = Self.currentVersion
            if let release = Self.parseRelease(data: data, currentVersion: current) {
                state = .available(release)
            } else {
                state = .upToDate(Date())
            }
        } catch {
            if userInitiated {
                state = .failed("네트워크 연결을 확인해 주세요.")
            }
        }
    }

    /// 새 버전을 내려받아 검증한 뒤 현재 앱 번들을 교체하고 다시 실행한다.
    func install(_ release: ReleaseInfo) async {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else {
            // `swift run` 등 번들이 아닌 실행이면 릴리스 페이지를 연다.
            NSWorkspace.shared.open(release.pageURL)
            return
        }
        let parentDir = bundleURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parentDir.path) else {
            state = .failed("\(parentDir.path) 폴더에 쓰기 권한이 없습니다. 릴리스 페이지에서 받아 주세요.")
            NSWorkspace.shared.open(release.pageURL)
            return
        }

        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent("scribe-update-\(UUID().uuidString)")
        let zipURL = workDir.appendingPathComponent("Scribe.zip")
        let extractDir = workDir.appendingPathComponent("extracted")

        do {
            try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
            state = .installing("v\(release.version) 내려받는 중…")

            var request = URLRequest(url: release.downloadURL)
            request.timeoutInterval = 120
            request.setValue("Scribe/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
            let (tempFile, response) = try await URLSession.shared.download(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw UpdateError("압축 파일을 내려받지 못했습니다.")
            }
            try FileManager.default.moveItem(at: tempFile, to: zipURL)

            state = .installing("압축 해제 및 서명 검증 중…")
            try Self.runProcess("/usr/bin/ditto", args: ["-x", "-k", zipURL.path, extractDir.path])

            let stagedApp = extractDir.appendingPathComponent("Scribe.app")
            guard FileManager.default.fileExists(atPath: stagedApp.path) else {
                throw UpdateError("압축 파일 안에 Scribe.app 이 없습니다.")
            }

            // 격리 속성 제거 후 코드서명 무결성 검증
            _ = try? Self.runProcess("/usr/bin/xattr", args: ["-cr", stagedApp.path])
            try Self.runProcess("/usr/bin/codesign", args: ["--verify", "--deep", "--strict", stagedApp.path])

            state = .installing("다시 여는 중…")
            let pid = ProcessInfo.processInfo.processIdentifier
            let script = """
            PID="$1"; SRC="$2"; DST="$3"; WORK="$4"
            for _ in $(seq 1 60); do
              kill -0 "$PID" 2>/dev/null || break
              sleep 0.1
            done
            rm -rf "$DST" && mv "$SRC" "$DST" && /usr/bin/xattr -cr "$DST" && /usr/bin/open "$DST"
            rm -rf "$WORK"
            """
            let launcher = Process()
            launcher.executableURL = URL(fileURLWithPath: "/bin/sh")
            launcher.arguments = ["-c", script, "--", "\(pid)", stagedApp.path, bundleURL.path, workDir.path]
            launcher.standardOutput = FileHandle.nullDevice
            launcher.standardError = FileHandle.nullDevice
            try launcher.run()

            NSApplication.shared.terminate(nil)
        } catch {
            try? FileManager.default.removeItem(at: workDir)
            let msg = (error as? UpdateError)?.message ?? "업데이트 설치 중 오류가 났습니다."
            state = .failed(msg)
        }
    }

    private struct UpdateError: Error {
        let message: String
        init(_ message: String) { self.message = message }
    }

    @discardableResult
    nonisolated private static func runProcess(_ launchPath: String, args: [String]) throws -> Int32 {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = args
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw UpdateError("\(URL(fileURLWithPath: launchPath).lastPathComponent) 검증 실패 (코드 \(proc.terminationStatus))")
        }
        return proc.terminationStatus
    }

    // MARK: - 순수 파싱 및 버전 비교 (테스트 가능)

    /// `"v0.2.0"` → `"0.2.0"`.
    nonisolated static func normalizeVersion(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        if let dash = s.firstIndex(of: "-") { s = String(s[..<dash]) }
        return s
    }

    /// `lhs > rhs` 이면 `1`, 같으면 `0`, `lhs < rhs` 이면 `-1`.
    nonisolated static func compareVersions(_ lhs: String, _ rhs: String) -> Int {
        let a = normalizeVersion(lhs).split(separator: ".").map { Int($0) ?? 0 }
        let b = normalizeVersion(rhs).split(separator: ".").map { Int($0) ?? 0 }
        let count = max(a.count, b.count)
        for i in 0..<count {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av != bv { return av > bv ? 1 : -1 }
        }
        return 0
    }

    /// GitHub Releases `/releases/latest` JSON 응답을 파싱해 `currentVersion` 보다 높으면 `ReleaseInfo` 를 돌려준다.
    nonisolated static func parseRelease(data: Data, currentVersion: String) -> ReleaseInfo? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else { return nil }
        let normalized = normalizeVersion(tag)
        guard !normalized.isEmpty, compareVersions(normalized, currentVersion) > 0 else { return nil }

        let pageString = (json["html_url"] as? String) ?? "https://github.com/\(repo)/releases/tag/\(tag)"
        guard let pageURL = URL(string: pageString) else { return nil }

        let assets = (json["assets"] as? [[String: Any]]) ?? []
        let zipAsset = assets.first { ($0["name"] as? String) == "Scribe.zip" }
            ?? assets.first { ($0["name"] as? String)?.hasSuffix(".zip") == true }
        guard let downloadString = zipAsset?["browser_download_url"] as? String,
              let downloadURL = URL(string: downloadString) else { return nil }

        let notes = ((json["body"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return ReleaseInfo(version: normalized, tagName: tag, downloadURL: downloadURL, pageURL: pageURL, notes: notes)
    }
}
