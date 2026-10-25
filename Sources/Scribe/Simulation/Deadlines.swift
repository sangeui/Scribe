import Foundation

// 마감. 월요일마다 출판사가 이번 주 과제를 준다. 지난주 기록으로 난이도를 잡는다.
// 지키면 아이템과 판매 보정, 어기면 거절 확률이 오르고 편집자가 편지를 보낸다.

struct Deadline: Codable, Sendable, Equatable {
    enum Kind: String, Codable, Sendable {
        /// 이번 주 글자 수.
        case characters
        /// 이번 주 안에 탈고.
        case finish
        /// 이번 주 판매 부수.
        case sales
    }

    let weekStart: Date
    let kind: Kind
    let target: Int
    /// 시작할 때의 탈고 수. 탈고 과제에만 쓴다.
    var base = 0
    /// 탈고 과제가 가리키는 책(`Book.file`). 과제를 낼 때 쓰던 책이다.
    var book: String?
    var met: Bool?
    /// 지킨 시각. 하루 지나면 줄을 거둔다.
    var metAt: Date?
    var failed: Bool?
    var notified: Bool?
    var resultNotified: Bool?

    @MainActor
    var title: String {
        let raw: String = switch kind {
        case .characters: "이번 주 \(Format.short(target))자"
        case .finish: bookTitle.map { "\($0) 탈고" } ?? "이번 주 안에 탈고"
        case .sales: "이번 주 \(Format.short(target))부"
        }
        return L10n.tr(raw)
    }

    @MainActor
    var bookTitle: String? { book.flatMap { file in Library.books.first { $0.file == file }?.displayTitle } }

    /// 출판사가 과제를 줄 때 하는 말.
    @MainActor
    var letter: String {
        let raw: String = switch kind {
        case .characters: "출판사에서 편지가 왔습니다. 이번 주에 \(Format.integer(target))자를 보내 달랍니다"
        case .finish: "출판사에서 편지가 왔습니다. 이번 주 안에 \(bookTitle.map { "「\($0)」" } ?? "원고")을 끝내 달랍니다"
        case .sales: "출판사에서 편지가 왔습니다. 이번 주에 \(Format.integer(target))부는 팔려야 한답니다"
        }
        return L10n.tr(raw)
    }

    var id: String { "\(weekStart.timeIntervalSince1970)-\(kind.rawValue)" }
}

enum Deadlines {
    static let metLines = ["마감을 지켰습니다. 편집자가 커피를 보내 왔습니다", "원고가 제때 갔습니다. 출판사가 선금을 더 얹었습니다",
                           "마감을 맞췄습니다. 작가가 처음으로 편집자를 칭찬했습니다", "제때 끝냈습니다. 편집자가 '다음 주도'라고 적어 보냈습니다"]
    static let failedLines = ["마감을 넘겼습니다. 편집자의 편지가 짧고 차갑습니다", "원고가 늦었습니다. 출판사가 다음 선금을 미뤘습니다",
                              "마감을 못 지켰습니다. 작가는 편지를 안 뜯었습니다", "마감이 지났습니다. 편집자가 직접 찾아오겠답니다"]

    /// 지난주 기록으로 이번 주 과제를 고른다. 글자는 늘 되고, 탈고는 남은 분량이 지난주 글자의 1.2배 안일 때,
    /// 판매는 탈고한 책이 있고 지난주에 팔린 게 있을 때.
    @MainActor
    static func assign(weekStart: Date, lastWeekCharacters: Int, lastWeekSales: Int, remainingInBook: Int, finished: Int, book: String? = nil, roll: Double) -> Deadline {
        var kinds: [Deadline.Kind] = [.characters]
        if remainingInBook > 0, Double(remainingInBook) <= Double(lastWeekCharacters) * 1.2 { kinds.append(.finish) }
        if finished > 0, lastWeekSales > 0 { kinds.append(.sales) }
        let kind = kinds[min(kinds.count - 1, Int(roll * Double(kinds.count)))]
        switch kind {
        case .characters:
            let raised = Double(lastWeekCharacters) * 1.1
            let unit = raised >= 100_000 ? 10_000.0 : 5_000.0
            let target = max(10_000, Int((raised / unit).rounded(.up) * unit))
            return Deadline(weekStart: weekStart, kind: .characters, target: target)
        case .finish:
            return Deadline(weekStart: weekStart, kind: .finish, target: finished + 1, base: finished, book: book)
        case .sales:
            let target = max(100, Int((Double(lastWeekSales) * 1.2 / 100).rounded(.up) * 100))
            return Deadline(weekStart: weekStart, kind: .sales, target: target)
        }
    }
}
