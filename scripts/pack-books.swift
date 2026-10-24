// 원서를 lzma 로 압축해 단일 컨테이너(books.pak)와 manifest.json 으로 묶는다.
// 사용: swift scripts/pack-books.swift <Books 폴더> <출력 폴더>
import Foundation

struct ManifestEntry: Codable {
    var file: String
    var author: String
    var title: String
    var titleKo: String?
    var authorKo: String?
    var preserveLines: Bool
    var characters: Int
    var offset: Int?
    var length: Int?
    var opening: String?
}

func makeOpening(from string: String, fallback: String) -> String {
    let raw = String(string.prefix(320))
    let lines = raw
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    let bodyLines = lines.count > 1 && lines[0].count < 45 ? Array(lines.dropFirst()) : lines
    let joined = bodyLines.joined(separator: " ")
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
    return joined.isEmpty ? fallback : String(joined.prefix(240))
}

let args = CommandLine.arguments
guard args.count == 3 else { print("usage: pack-books.swift <Books> <out>"); exit(1) }
let source = URL(fileURLWithPath: args[1]), out = URL(fileURLWithPath: args[2])
let fm = FileManager.default
try? fm.removeItem(at: out)
try fm.createDirectory(at: out, withIntermediateDirectories: true)

let manifestURL = source.appendingPathComponent("manifest.json")
let manifestData = try Data(contentsOf: manifestURL)
var sourceEntries = try JSONDecoder().decode([ManifestEntry].self, from: manifestData)
var packedEntries: [ManifestEntry] = []
var pakData = Data()
var before = 0, after = 0
var sourceChanged = false

for i in sourceEntries.indices {
    var entry = sourceEntries[i]
    let fileURL = source.appendingPathComponent(entry.file)
    let data = try Data(contentsOf: fileURL)
    guard let string = String(data: data, encoding: .utf8) else {
        print("invalid utf8: \(entry.file)")
        exit(1)
    }
    let charCount = string.count
    let opening = makeOpening(from: string, fallback: entry.title)
    if entry.characters != charCount || entry.opening != opening {
        sourceEntries[i].characters = charCount
        sourceEntries[i].opening = opening
        sourceChanged = true
    }
    entry.characters = charCount
    entry.opening = opening

    let packed = try (data as NSData).compressed(using: .lzma) as Data
    let back = try (packed as NSData).decompressed(using: .lzma) as Data
    guard back == data else { print("round trip failed: \(entry.file)"); exit(1) }

    entry.offset = pakData.count
    entry.length = packed.count
    pakData.append(packed)
    packedEntries.append(entry)
    before += data.count
    after += packed.count
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

if sourceChanged {
    var srcJSON = try encoder.encode(sourceEntries)
    srcJSON.append(0x0A)
    try srcJSON.write(to: manifestURL)
}

try pakData.write(to: out.appendingPathComponent("books.pak"))
var outJSON = try encoder.encode(packedEntries)
outJSON.append(0x0A)
try outJSON.write(to: out.appendingPathComponent("manifest.json"))

print("packed \(packedEntries.count) books: \(before / 1024)KB -> \(after / 1024)KB (books.pak, lzma)")
