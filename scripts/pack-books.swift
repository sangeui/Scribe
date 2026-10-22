// 원서를 zlib 로 압축해 번들에 넣는다. 사용: swift scripts/pack-books.swift <Books 폴더> <출력 폴더>
// manifest.json 은 그대로 복사하고, *.txt 는 *.txt.z 로 만든다. 앱은 .txt 가 없으면 .txt.z 를 풀어 읽는다.
import Foundation

let args = CommandLine.arguments
guard args.count == 3 else { print("usage: pack-books.swift <Books> <out>"); exit(1) }
let source = URL(fileURLWithPath: args[1]), out = URL(fileURLWithPath: args[2])
let fm = FileManager.default
try? fm.removeItem(at: out)
try fm.createDirectory(at: out, withIntermediateDirectories: true)
try fm.copyItem(at: source.appendingPathComponent("manifest.json"), to: out.appendingPathComponent("manifest.json"))
var before = 0, after = 0
for name in try fm.contentsOfDirectory(atPath: source.path).sorted() where name.hasSuffix(".txt") {
    let data = try Data(contentsOf: source.appendingPathComponent(name))
    let packed = try (data as NSData).compressed(using: .zlib) as Data
    // 풀어서 같은지 바로 확인한다.
    let back = try (packed as NSData).decompressed(using: .zlib) as Data
    guard back == data else { print("round trip failed: \(name)"); exit(1) }
    try packed.write(to: out.appendingPathComponent(name + ".z"))
    before += data.count; after += packed.count
}
print("packed \(before / 1024)KB -> \(after / 1024)KB")
