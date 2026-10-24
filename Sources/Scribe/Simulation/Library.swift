import Foundation
import SwiftUI

/// 날짜별 기록의 키. 로컬 날짜 "yyyy-MM-dd".
enum DayKey {
    nonisolated static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(from date: Date) -> String { formatter.string(from: date) }
    static func date(from key: String) -> Date? { formatter.date(from: key) }
}

// MARK: - 서재

/// `Books/manifest.json` 한 줄. 원문은 Project Gutenberg 의 퍼블릭 도메인 텍스트에서 안내문을 뗀 것이다.
struct Book: Codable, Sendable, Identifiable {
    let file: String
    /// 원서의 작가와 제목. 초상화·색을 고르는 열쇠로 쓰고 화면에는 한국어 이름을 쓴다.
    let author: String
    let title: String
    let titleKo: String?
    let authorKo: String?
    /// 희곡처럼 줄바꿈을 살려 보여 줄 작품.
    let preserveLines: Bool
    let characters: Int
    /// 번들 단일 압축 컨테이너(`books.pak`) 안의 바이트 위치와 길이.
    var offset: Int? = nil
    var length: Int? = nil
    /// 서재에서 원문 압축을 풀지 않고 바로 보여 줄 첫머리 발췌문.
    var opening: String? = nil

    var id: String { file }
    var displayTitle: String { titleKo ?? title }
    var displayAuthor: String { authorKo ?? author }
    /// "에드거 앨런 포" → "포"
    var displayAuthorShort: String { displayAuthor.split(separator: " ").last.map(String.init) ?? displayAuthor }

    /// 작가 성. 좁은 자리에서 쓴다.
    var authorShort: String { author.split(separator: " ").last.map(String.init) ?? author }

    /// 책등 색. 작가마다 하나.
    var spineColor: Color {
        switch authorShort {
        case "Shakespeare": Color(red: 0.55, green: 0.15, blue: 0.2)
        case "Dickens": Color(red: 0.2, green: 0.35, blue: 0.25)
        case "Poe": Color(red: 0.18, green: 0.18, blue: 0.24)
        case "Carroll": Color(red: 0.3, green: 0.5, blue: 0.75)
        case "Stevenson": Color(red: 0.6, green: 0.42, blue: 0.2)
        case "Wilde": Color(red: 0.45, green: 0.3, blue: 0.55)
        case "Austen": Color(red: 0.75, green: 0.55, blue: 0.6)
        case "Goethe": Color(red: 0.2, green: 0.45, blue: 0.5)
        default: Color.gray
        }
    }
}

/// 앱에 넣은 원문. 작가가 번갈아 나오도록 순서가 정해져 있고, 끝나면 처음부터 다시 쓴다.
@MainActor
enum Library {
    /// 앱 번들의 `Resources/Books`, 없으면(`swift run`) 저장소의 `Books`.
    static let directory: URL? = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Books"),
           FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path) {
            return url
        }
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while dir.path != "/", !FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
            dir = dir.deletingLastPathComponent()
        }
        let repo = dir.appendingPathComponent("Books")
        return FileManager.default.fileExists(atPath: repo.appendingPathComponent("manifest.json").path) ? repo : nil
    }()

    static let books: [Book] = {
        guard let directory,
              let data = try? Data(contentsOf: directory.appendingPathComponent("manifest.json")),
              let books = try? JSONDecoder().decode([Book].self, from: data) else { return [] }
        // 분량 0인 책은 글자 없이 탈고돼 버리니 뺀다.
        return books.filter { $0.characters > 0 }
    }()

    /// 작가 순서(처음 나오는 순).
    static let authors: [String] = {
        var seen = Set<String>()
        return books.map(\.authorShort).filter { seen.insert($0).inserted }
    }()

    /// 한 바퀴(모든 책) 글자 수.
    static let roundCharacters: Int = books.reduce(0) { $0 + $1.characters }

    /// `starts[i]` 는 한 바퀴 안에서 `books[i]` 가 시작하는 글자 위치. 마지막 원소는 한 바퀴 길이.
    static let starts: [Int] = books.reduce(into: [0]) { $0.append($0.last! + $1.characters) }

    /// 읽어 둔 원문. 글자 배열 대신 문자열을 그대로 두고(글자당 1바이트쯤), 64글자마다 자리를 적어 둬 n번째 글자를 빨리 찾는다.
    struct BookText {
        let string: String
        /// `checkpoints[k]` 는 64k번째 글자의 자리.
        let checkpoints: [String.Index]
        let count: Int
        static let stride = 64

        init(_ string: String) {
            self.string = string
            var marks: [String.Index] = []
            marks.reserveCapacity(string.utf8.count / Self.stride + 1)
            var i = string.startIndex, n = 0
            while i != string.endIndex {
                if n % Self.stride == 0 { marks.append(i) }
                i = string.index(after: i)
                n += 1
            }
            checkpoints = marks
            count = n
        }

        /// n번째 글자의 자리. 가까운 표시에서 64글자 안으로 걷는다.
        func index(at n: Int) -> String.Index {
            let n = min(max(0, n), count)
            if n == count { return string.endIndex }
            let k = n / Self.stride
            return string.index(checkpoints[k], offsetBy: n - k * Self.stride)
        }
    }

    /// 읽어 둔 책. 쓰는 책과 읽기 창에 연 책 정도만 남기고(`cacheLimit`) 오래된 것은 비운다.
    private static var texts: [String: BookText] = [:]
    private static var recent: [String] = []
    static let cacheLimit = 2

    /// 원문. 번들에서는 `books.pak`(lzma 단일 컨테이너)의 해당 구간만 풀어 읽고, 저장소에서는 `.txt`를 그대로 읽는다. 한 번 읽으면 기억한다.
    static func text(of book: Book) -> BookText? {
        if let cached = texts[book.file] {
            recent.removeAll { $0 == book.file }
            recent.append(book.file)
            return cached
        }
        guard let directory, let string = load(book, in: directory) else { return nil }
        let text = BookText(string)
        texts[book.file] = text
        recent.append(book.file)
        while recent.count > cacheLimit, let old = recent.first {
            recent.removeFirst()
            texts[old] = nil
        }
        return text
    }

    /// 지금 읽어 둔 책 수(확인용).
    static var cachedCount: Int { texts.count }

    static func load(_ book: Book, in directory: URL) -> String? {
        autoreleasepool {
            if let offset = book.offset, let length = book.length, length > 0 {
                let pak = directory.appendingPathComponent("books.pak")
                if let handle = try? FileHandle(forReadingFrom: pak) {
                    defer { try? handle.close() }
                    if (try? handle.seek(toOffset: UInt64(offset))) != nil,
                       let chunk = try? handle.read(upToCount: length),
                       chunk.count == length,
                       let raw = try? (chunk as NSData).decompressed(using: .lzma) {
                        return String(data: raw as Data, encoding: .utf8)
                    }
                }
            }
            let plain = directory.appendingPathComponent(book.file)
            if let string = try? String(contentsOf: plain, encoding: .utf8) { return string }
            let packed = directory.appendingPathComponent(book.file + ".z")
            guard let data = try? Data(contentsOf: packed), let raw = try? (data as NSData).decompressed(using: .zlib) else { return nil }
            return String(data: raw as Data, encoding: .utf8)
        }
    }

    /// 압축(lzma). 빌드 스크립트와 확인용 실행이 쓴다.
    static func pack(_ string: String) -> Data? {
        (try? (Data(string.utf8) as NSData).compressed(using: .lzma)) as Data?
    }

    /// `book` 의 앞 `count` 글자.
    static func prefix(of book: Book, count: Int) -> String {
        guard let text = text(of: book) else { return "" }
        return String(text.string[..<text.index(at: count)])
    }

    /// `book` 의 앞 `count` 글자 중 끝 `tail` 글자.
    static func tail(of book: Book, upTo count: Int, length tail: Int) -> String {
        guard let text = text(of: book) else { return "" }
        let end = min(max(0, count), text.count)
        let startAt = max(0, end - tail)
        let endIndex = text.index(at: end)
        var start = text.index(at: startAt)
        // 잘린 낱말로 시작하지 않게 다음 공백까지 건너뛴다.
        if startAt > 0, let space = text.string[start..<endIndex].firstIndex(where: { $0 == " " || $0 == "\n" }) {
            start = text.string.index(after: space)
        }
        return String(text.string[start..<endIndex])
    }
}
