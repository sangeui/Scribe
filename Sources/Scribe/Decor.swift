import Foundation
import SwiftUI

// 초상화 꾸미기. 성과를 이루면 장신구가 열리고, 작가마다 하나씩 골라 씌운다. 상시 창·팝오버·서재의 초상화에 모두 보인다.

struct Accessory: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    /// 여는 성과(`Achievement.id`). nil 이면 처음부터.
    let unlock: String?
    /// 그림 조각. `.` 은 비워 둔다.
    let art: [String]
    let x: Int
    /// 눈이 있는 줄(보통 4, 괴테 5)을 기준으로 한 세로 위치.
    let yFromEyes: Int

    static func == (a: Accessory, b: Accessory) -> Bool { a.id == b.id }
}

@MainActor
enum Decor {
    nonisolated static let key = "portraitDecor"

    static let all: [Accessory] = [
        Accessory(id: "monocle", title: "외알 안경", unlock: "first_book", art: ["yyy", "y.y", "yyy", "..y", "..y"], x: 13, yFromEyes: -1),
        Accessory(id: "glasses", title: "안경", unlock: "reader", art: ["HHHHHHHH", "H.HHHH.H", "HHH..HHH"], x: 8, yFromEyes: -1),
        Accessory(id: "quill", title: "귀 뒤 깃펜", unlock: "chars_100k", art: [".ww", "www", "ww.", "w..", "w.."], x: 17, yFromEyes: -5),
        Accessory(id: "tophat", title: "실크해트", unlock: "books_5", art: ["...kkkkkkkk...", "...kkkkkkkk...", "...kkkkkkkk...", "...kyyyyyyk...", "kkkkkkkkkkkkkk"], x: 5, yFromEyes: -10),
        Accessory(id: "laurel", title: "월계관", unlock: "round_1", art: ["...nnnnnnnn...", ".nn........nn.", "n............n"], x: 5, yFromEyes: -6),
        Accessory(id: "crown", title: "금관", unlock: "readers_100k", art: ["y...y...y", "yR..yR..y", "yyyyyyyyy"], x: 8, yFromEyes: -8),
        Accessory(id: "flower", title: "꽃", unlock: "sales_1k", art: ["RRR", "RRR", ".n."], x: 5, yFromEyes: 8),
        Accessory(id: "bowtie", title: "나비넥타이", unlock: "coffee_10", art: ["RR..RR", "RRRRRR", "RR..RR"], x: 9, yFromEyes: 7),
        Accessory(id: "scarf", title: "목도리", unlock: "streak_7", art: ["RRRRRRRRRR", ".RRRRRRRR.", ".RR......."], x: 7, yFromEyes: 6),
        Accessory(id: "pipe", title: "파이프", unlock: "patience_5", art: ["....G", ".....", "oo...", "..oo.", "...oo", "...oo"], x: 14, yFromEyes: 0),
    ]

    static func byID(_ id: String) -> Accessory? { all.first { $0.id == id } }

    /// 작가마다 고른 장신구. 키는 `authorShort`, 값은 `Accessory.id`.
    private(set) static var chosen: [String: String] = {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
    }()

    static func chosen(for author: String) -> Accessory? { chosen[author].flatMap(byID) }

    static func choose(_ accessory: Accessory?, for author: String) {
        chosen[author] = accessory?.id
        UserDefaults.standard.set(chosen, forKey: key)
    }

    /// 이 성과로 열렸는지. 기록을 읽기만 하는 실행은 조건을 채운 것도 열린 것으로 본다.
    static func isUnlocked(_ accessory: Accessory, progress: WritingProgress?) -> Bool {
        guard let id = accessory.unlock else { return true }
        guard let progress else { return false }
        return progress.badges[id] != nil || (Achievements.byID(id).map { $0.isMet(progress.facts) } ?? false)
    }

    /// 초상화에 장신구를 씌운다. 눈 줄은 `e` 가 있는 줄로 찾고, 없으면(눈을 감았으면) 4로 본다.
    static func apply(_ rows: [String], author: String) -> [String] {
        guard let accessory = chosen(for: author) else { return rows }
        return apply(rows, accessory: accessory)
    }

    static func apply(_ rows: [String], accessory: Accessory) -> [String] {
        let eyeRow = rows.firstIndex { $0.contains("e") } ?? Portraits.eyeRow
        return Portraits.overlay(rows, accessory.art, x: accessory.x, y: eyeRow + accessory.yFromEyes)
    }
}
