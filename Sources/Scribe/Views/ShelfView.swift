import SwiftUI

/// 서재. 위에 서재 요약 배너와 원문 발췌가 담긴 작품 카드, 다음 집필 순서 대기열,
/// 아래에 작가별 나무 선반 서가와 클릭 시 펼쳐지는 작가 상세 서랍(능력치·장신구 꾸미기·수록 작품).
struct ShelfPanel: View {
    @Bindable var store: UsageStore
    /// 확인용 그림(`--snapshot`)은 `ScrollView` 를 못 그려서 끈다.
    var scrollable = true

    @State private var selected: Int?
    @State private var expandedAuthor: String?
    @State private var lastExpandedAuthor: String?
    @State private var decorTick = 0
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let progress = store.writing {
            let currentIndex = selected ?? progress.bookIndex
            let safeIndex = Library.books.indices.contains(currentIndex) ? currentIndex : 0
            let activeAuthor = expandedAuthor ?? (RenderMode.offscreen ? Library.books[safeIndex].authorShort : nil)
            OptionalScroll(enabled: scrollable) {
                VStack(alignment: .leading, spacing: 12) {
                    header(progress, selectedBook: Library.books[safeIndex])
                    BookDetail(index: safeIndex, progress: progress,
                               onWriteNext: store.writeNext, onFocusAuthor: store.focusAuthor,
                               onRead: { book, count in
                                   ReaderWindow.shared.show(book: book, count: count)
                                   store.noteRead()
                               })
                    QueueStrip(progress: progress, selected: safeIndex) { selected = $0 }
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("문호 서가").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Spacer()
                            Text("초상화나 이름을 누르면 능력치·장신구가 열립니다").font(.caption2).foregroundStyle(.tertiary)
                        }
                        ForEach(Library.authors, id: \.self) { author in
                            AuthorRow(
                                author: author,
                                progress: progress,
                                selected: safeIndex,
                                expanded: activeAuthor == author,
                                keepDrawerContent: activeAuthor == author || lastExpandedAuthor == author,
                                decorTick: decorTick,
                                onSelectBook: { selected = $0 },
                                onToggleExpand: {
                                    if expandedAuthor == author {
                                        lastExpandedAuthor = author
                                        expandedAuthor = nil
                                    } else {
                                        lastExpandedAuthor = author
                                        expandedAuthor = author
                                    }
                                },
                                onFocusAuthor: store.focusAuthor,
                                onChooseDecor: { accessory in
                                    Decor.choose(accessory, for: author)
                                    decorTick += 1
                                    store.updateFloatingAppearance()
                                }
                            )
                        }
                    }
                }
                .padding(16)
                .animation(.easeOut(duration: 0.18), value: selected)
                .animation(.snappy(duration: 0.25, extraBounce: 0), value: expandedAuthor)
            }
        } else {
            ProgressView()
        }
    }

    /// 서재 상단 배너: 선택된 책의 작가 초상화와 회차·탈고·누적 글자 수·회차 진행 막대.
    private func header(_ progress: WritingProgress, selectedBook: Book) -> some View {
        let totalBooks = max(1, Library.books.count)
        let roundFraction = min(1.0, (Double(progress.finishedInRound) + progress.fraction) / Double(totalBooks))
        let completedAuthors = Library.authors.filter { author in
            let works = Library.books.enumerated().filter { $0.element.authorShort == author }
            return !works.isEmpty && works.allSatisfy {
                if case .done = BookStatus(index: $0.offset, progress: progress) { return true }
                return false
            }
        }.count
        return HStack(spacing: 12) {
            PortraitFrame(author: selectedBook.authorShort, scale: 2.6, scene: true, furniture: progress.studio)
                .id("\(selectedBook.authorShort)-\(decorTick)")
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("서재").font(.headline)
                    Text("\(progress.round + 1)회차")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 1.5)
                        .foregroundStyle(selectedBook.spineColor)
                        .background(selectedBook.spineColor.opacity(0.14), in: Capsule())
                    if completedAuthors > 0 {
                        Text("전집 \(completedAuthors)/\(Library.authors.count)")
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                Text(progress.totalSales > 0
                     ? L10n.tr("누적 \(Format.short(Int(progress.totalCharacters)))자 집필 · 총 \(Format.short(progress.totalSales))부 판매")
                     : L10n.tr("누적 \(Format.short(Int(progress.totalCharacters)))자 집필"))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.14))
                        Capsule().fill(selectedBook.spineColor)
                            .frame(width: max(4, geo.size.width * CGFloat(roundFraction)))
                    }
                }
                .frame(height: 3.5)
                .padding(.top, 2)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(progress.finishedInRound)/\(Library.books.count)")
                    .font(.system(size: 19, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(selectedBook.spineColor)
                    .contentTransition(.numericText())
                Text("탈고").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(
            LinearGradient(colors: [selectedBook.spineColor.opacity(scheme == .dark ? 0.22 : 0.13), selectedBook.spineColor.opacity(0.02)],
                           startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

/// 다음 집필 순서 한 줄 스트립: 현재 책을 중복 표기하지 않고 다음 예정 작품 3편의 흐름만 간결하게 보여 준다.
private struct QueueStrip: View {
    let progress: WritingProgress
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        let upcoming = Array(progress.pendingInRound.prefix(3))
        let orderedIndex = progress.order.flatMap { ord in Library.books.firstIndex { $0.file == ord.book } }
        if !upcoming.isEmpty {
            HStack(spacing: 4) {
                HStack(spacing: 3.5) {
                    Symbol(name: "text.line.first.and.arrowtriangle.forward", size: 9.5)
                    Text("다음").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary)
                }
                .fixedSize()
                .padding(.trailing, 2)

                ForEach(Array(upcoming.enumerated()), id: \.element) { offset, index in
                    let book = Library.books[index]
                    let isSelected = index == selected
                    let isOrdered = orderedIndex == index
                    if offset > 0 {
                        Symbol(name: "chevron.right", size: 7, color: .secondary.opacity(0.45))
                    }
                    Button { onSelect(index) } label: {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(book.spineColor.opacity(offset == 0 ? 0.85 : 0.5))
                                .frame(width: 3, height: 12)
                            Text(book.displayTitle)
                                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? .primary : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                            if isOrdered {
                                Symbol(name: "envelope.fill", size: 8, color: BadgeTier.gold.color)
                            }
                        }
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(
                            isSelected ? book.spineColor.opacity(0.14) : Color.secondary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(isSelected ? book.spineColor.opacity(0.55) : (isOrdered ? BadgeTier.gold.color.opacity(0.45) : .clear), lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .hint(book.displayTitle,
                          [isOrdered ? "\(book.displayAuthor) · 독자 주문 도서 (\(offset + 1)번째 예정)" : "\(book.displayAuthor) · \(offset + 1)번째 집필 예정"],
                          symbol: isOrdered ? "envelope.open" : "book.closed")
                }
            }
        }
    }
}

/// 책 한 권의 상태.
enum BookStatus {
    case done(Date), current(Double), pending

    @MainActor
    init(index: Int, progress: WritingProgress) {
        if let done = progress.finished.last(where: { $0.bookIndex == index && $0.round == progress.round }) {
            self = .done(done.date)
        } else if index == progress.bookIndex {
            self = .current(progress.fraction)
        } else {
            self = .pending
        }
    }

    /// 책등이 색으로 찬 비율.
    var fill: Double {
        switch self {
        case .done: 1
        case .current(let f): f
        case .pending: 0
        }
    }

    var isCurrent: Bool { if case .current = self { true } else { false } }
}

/// 고른 작품 한 칸: 책등과 제목, 원제, 상태, 원고지 질감의 실제 원문 발췌 미리보기, 액션 버튼.
private struct BookDetail: View {
    let index: Int
    let progress: WritingProgress
    var onWriteNext: (Int) -> Void = { _ in }
    var onFocusAuthor: (String) -> Void = { _ in }
    var onRead: (Book, Int) -> Void = { _, _ in }
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let book = Library.books[index]
        let status = BookStatus(index: index, progress: progress)
        let pendingOfAuthor = progress.pendingInRound.filter { Library.books[$0].authorShort == book.authorShort }
        let tier = progress.salesTier(of: book)
        let sold = progress.sales(of: book)
        let review = progress.review(of: book)
        let note = progress.finishNote(for: book)
        let publisher = note?.publisher.flatMap(Publisher.init(rawValue:))
        let isOrdered = progress.order?.book == book.file
        let readable: Int? = {
            switch status {
            case .done: book.characters
            case .current: progress.charactersInBook > 0 ? progress.charactersInBook : nil
            case .pending: nil
            }
        }()
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 12) {
                Spine(book: book, status: status, selected: false, height: 46, tier: tier)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(book.displayTitle).font(.callout.weight(.semibold)).lineLimit(1)
                        statusBadge(book: book, status: status)
                        if let publisher {
                            Text(publisher.title).font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .foregroundStyle(.secondary).background(Color.secondary.opacity(0.12), in: Capsule())
                        }
                        if tier != .none {
                            let tierColor = tier >= .bestseller ? BadgeTier.gold.color : tier == .reprint ? BadgeTier.silver.color : book.spineColor
                            Text(tier.title).font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .foregroundStyle(tierColor).background(tierColor.opacity(0.14), in: Capsule())
                        }
                        Spacer(minLength: 0)
                        if let review {
                            Text("★\(review.stars)").font(.caption2.weight(.semibold))
                                .foregroundStyle(BookstoreContent.starColor(review.stars))
                        }
                    }
                    Text("\(book.displayAuthor) · \(book.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text(metaLine(book: book, status: status, note: note, sold: sold, isOrdered: isOrdered))
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            excerptBox(book: book, status: status)
            HStack(spacing: 6) {
                if let readable {
                    pillAction("원고 읽기", symbol: "book.pages", prominent: true, tint: book.spineColor) {
                        onRead(book, readable)
                    }
                }
                if case .pending = status {
                    if progress.pendingInRound.first == index {
                        HStack(spacing: 4) {
                            Symbol(name: "checkmark.circle", size: 10, color: book.spineColor)
                            Text("다음 차례로 집필 예정").font(.caption2.weight(.medium)).foregroundStyle(book.spineColor)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(book.spineColor.opacity(0.1), in: Capsule())
                    } else {
                        pillAction("다음에 쓰기", symbol: "arrow.up.to.line", prominent: true, tint: book.spineColor) {
                            onWriteNext(index)
                        }
                    }
                    if pendingOfAuthor.count >= 2 {
                        pillAction("\(book.displayAuthorShort) 몰아 쓰기", symbol: "books.vertical", prominent: false, tint: book.spineColor) {
                            onFocusAuthor(book.authorShort)
                        }
                    }
                }
                Spacer(minLength: 0)
                if case .done = status, sold > 0, let next = SalesTier.allCases.first(where: { $0.copies > sold }) {
                    Text("\(next.title)까지 \(Format.short(next.copies - sold))부")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func statusBadge(book: Book, status: BookStatus) -> some View {
        switch status {
        case .current:
            Text("쓰는 중 \(Format.percent(progress.fraction * 100))")
                .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                .padding(.horizontal, 6).padding(.vertical, 1.5)
                .foregroundStyle(book.spineColor)
                .background(book.spineColor.opacity(0.14), in: Capsule())
        case .done(let date):
            let green = Color(red: 0.2, green: 0.55, blue: 0.3)
            Text("\(date.formatted(.dateTime.month(.defaultDigits).day())) 탈고")
                .font(.system(size: 9.5, weight: .semibold))
                .padding(.horizontal, 6).padding(.vertical, 1.5)
                .foregroundStyle(green)
                .background(green.opacity(0.14), in: Capsule())
        case .pending:
            let ahead = max(1, (progress.position(of: index) ?? index) - progress.orderPosition)
            Text("\(ahead)편 뒤")
                .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                .padding(.horizontal, 6).padding(.vertical, 1.5)
                .foregroundStyle(.secondary)
                .background(Color.secondary.opacity(0.12), in: Capsule())
        }
    }

    private func metaLine(book: Book, status: BookStatus, note: FinishNote?, sold: Int, isOrdered: Bool) -> String {
        switch status {
        case .done:
            var parts = [L10n.tr("\(Format.integer(book.characters))자")]
            if let days = note?.days, days > 0 { parts.append(L10n.tr("\(days)일 소요")) }
            if sold > 0 { parts.append(L10n.tr("\(Format.integer(sold))부 판매")) }
            return parts.joined(separator: " · ")
        case .current:
            var parts = [L10n.tr("\(Format.integer(progress.charactersInBook)) / \(Format.integer(book.characters))자")]
            if progress.todayCharacters > 0 { parts.append(L10n.tr("오늘 +\(Format.integer(Int(progress.todayCharacters)))자")) }
            if let days = progress.daysToFinish { parts.append(L10n.tr("탈고까지 약 \(days)일")) }
            return parts.joined(separator: " · ")
        case .pending:
            var parts = [L10n.tr("분량 \(Format.integer(book.characters))자")]
            if isOrdered { parts.append(L10n.tr("독자 주문 도서")) }
            return parts.joined(separator: " · ")
        }
    }

    /// 원고지 질감의 실제 원문 구절 발췌 상자.
    private func excerptBox(book: Book, status: BookStatus) -> some View {
        let isWriting: Bool = if case .current = status, progress.charactersInBook > 0 { true } else { false }
        let isPending: Bool = if case .pending = status { true } else { false }
        let snippet = Self.excerpt(for: book, status: status, written: progress.charactersInBook)
        return (Text(snippet) + (isWriting ? Text(" ▍").foregroundColor(book.spineColor) : Text("")))
            .font(isPending ? .system(size: 11.5, design: .serif).italic() : .system(size: 11.5, design: .serif))
            .foregroundStyle(isPending ? Color.secondary : Color.primary.opacity(0.9))
            .lineSpacing(2.5)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10).padding(.vertical, 7.5)
            .background(
                scheme == .dark ? Color(red: 0.14, green: 0.13, blue: 0.12) : Color(red: 0.985, green: 0.975, blue: 0.94),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(scheme == .dark ? 0.1 : 0.07), lineWidth: 1)
            )
    }

    private static func excerpt(for book: Book, status: BookStatus, written: Int) -> String {
        if case .current = status, written > 0 {
            let raw = Library.tail(of: book, upTo: written, length: 170)
            let cleaned = raw
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
            if !cleaned.isEmpty { return cleaned }
        }
        if let opening = book.opening, !opening.isEmpty {
            return opening
        }
        let raw = Library.prefix(of: book, count: 320)
        let lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        // 첫 줄이 짧은 제목/장 번호 줄이면 그 다음 줄부터 이어 붙여 본문 문장이 보이게 한다.
        let bodyLines = lines.count > 1 && lines[0].count < 45 ? Array(lines.dropFirst()) : lines
        let joined = bodyLines.joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return joined.isEmpty ? book.title : joined
    }

    @ViewBuilder
    private func pillAction(_ title: String, symbol: String, prominent: Bool, tint: Color, run: @escaping () -> Void) -> some View {
        if RenderMode.offscreen {
            ChipLabel(title: title, prominent: prominent)
        } else {
            Button(action: run) {
                HStack(spacing: 4) {
                    Symbol(name: symbol, size: 10, color: prominent ? .white : .primary)
                    Text(L10n.tr(title)).font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .background(prominent ? tint : Color.secondary.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

/// 작가별 서가 카드: 초상화와 이름, 나무 선반 위의 책등들, 그리고 클릭 시 펼쳐지는 슬림 서랍(1줄 능력치 바 · 1줄 장신구 아이콘 타일).
private struct AuthorRow: View {
    let author: String
    let progress: WritingProgress
    let selected: Int
    let expanded: Bool
    var keepDrawerContent = true
    let decorTick: Int
    let onSelectBook: (Int) -> Void
    let onToggleExpand: () -> Void
    let onFocusAuthor: (String) -> Void
    let onChooseDecor: (Accessory?) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let works = Library.books.enumerated().filter { $0.element.authorShort == author }
        let firstBook = works.first?.element
        let displayAuthor = firstBook?.displayAuthor ?? author
        let shortAuthor = firstBook?.displayAuthorShort ?? author
        let tint = firstBook?.spineColor ?? .secondary
        let done = works.filter { if case .done = BookStatus(index: $0.offset, progress: progress) { true } else { false } }.count
        let isWritingAuthor = works.contains { $0.offset == progress.bookIndex }
        let isSelectedAuthor = works.contains { $0.offset == selected }
        let pendingCount = progress.pendingInRound.filter { Library.books[$0].authorShort == author }.count
        let sold = works.reduce(0) { $0 + progress.sales(of: $1.element) }
        let sheet = progress.sheet(for: author)
        let perks = StatPerks(sheet)
        let chosenDecor = Decor.chosen(for: author)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Button(action: onToggleExpand) {
                    PortraitFrame(author: author, scale: 2.2)
                        .id("\(author)-\(decorTick)")
                }
                .buttonStyle(.plain)
                .hint(displayAuthor, ["초상화나 작가 이름을 눌러 능력치·장신구 서랍을 엽니다."], symbol: "person.text.rectangle")

                VStack(alignment: .leading, spacing: 5) {
                    // 1단: 작가 이름 + 상태 배지 + 간결 요약 + 우측 메타/화살표
                    Button(action: onToggleExpand) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(displayAuthor).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                            if done == works.count && !works.isEmpty {
                                Text("완간")
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .padding(.horizontal, 4.5).padding(.vertical, 1)
                                    .foregroundStyle(BadgeTier.gold.color)
                                    .background(BadgeTier.gold.color.opacity(0.15), in: Capsule())
                            } else if isWritingAuthor {
                                Text("집필 중")
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .padding(.horizontal, 4.5).padding(.vertical, 1)
                                    .foregroundStyle(tint)
                                    .background(tint.opacity(0.14), in: Capsule())
                            }
                            Text(summaryText(done: done, total: works.count, sold: sold))
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1)
                            Spacer(minLength: 4)
                            HStack(spacing: 4) {
                                if let chosenDecor {
                                    Text(chosenDecor.title)
                                        .font(.system(size: 9.5))
                                        .foregroundStyle(.tertiary)
                                }
                                if sheet.total > 0 {
                                    Text("+\(sheet.total)")
                                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                                        .padding(.horizontal, 4.5).padding(.vertical, 1)
                                        .foregroundStyle(.secondary)
                                        .background(Color.secondary.opacity(0.1), in: Capsule())
                                }
                                Symbol(name: "chevron.down", size: 8)
                                    .rotationEffect(.degrees(expanded ? 180 : 0))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // 2단: 나무 선반 위 책등들 (선반 폭을 넘기면 자동으로 다음 단 선반으로 줄바꿈)
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(shelfRows(for: works, maxWidth: 276).enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(alignment: .bottom, spacing: 3) {
                                    ForEach(row, id: \.element.id) { index, book in
                                        Spine(book: book, status: BookStatus(index: index, progress: progress),
                                              selected: index == selected, height: 25, tier: progress.salesTier(of: book))
                                            .onTapGesture { onSelectBook(index) }
                                            .hint(book.displayTitle, [workHintLine(index: index, book: book)], symbol: "book.closed")
                                    }
                                    Spacer(minLength: 0)
                                }
                                shelfLedge(tint: tint)
                            }
                        }
                    }
                }
            }

            // 3단: 슬림 작가 서랍 (1줄 체력·능력치 바 + 1줄 초상화 장신구 아이콘 스트립 및 몰아 쓰기 버튼)
            Collapsible(progress: expanded ? 1 : 0, topSpacing: 8) {
                if keepDrawerContent {
                    VStack(alignment: .leading, spacing: 7) {
                        Divider().opacity(0.4)
                        compactStatsBar(sheet: sheet, perks: perks, shortAuthor: shortAuthor)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .center, spacing: 5) {
                                Text("초상화 장신구").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary)
                                Text("· \(chosenDecor?.title ?? L10n.tr("착용 없음"))").font(.system(size: 9.5)).foregroundStyle(.tertiary)
                                Spacer()
                                if pendingCount >= 2 {
                                    focusAuthorButton(shortAuthor: shortAuthor, tint: tint)
                                }
                            }
                            HStack(spacing: 4.5) {
                                decorIconTile(nil, shortAuthor: shortAuthor)
                                ForEach(Decor.all) { accessory in
                                    decorIconTile(accessory, shortAuthor: shortAuthor)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7.5)
        .background(
            isSelectedAuthor || expanded
                ? tint.opacity(scheme == .dark ? 0.11 : 0.065)
                : Color.secondary.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isSelectedAuthor || expanded ? tint.opacity(0.32) : Color.primary.opacity(0.04), lineWidth: 1)
        )
    }

    private func summaryText(done: Int, total: Int, sold: Int) -> String {
        L10n.tr(sold > 0 ? "\(done)/\(total)편 · \(Format.short(sold))부" : "\(done)/\(total)편")
    }

    private func shelfRows(for works: [(offset: Int, element: Book)], maxWidth: CGFloat) -> [[(offset: Int, element: Book)]] {
        var rows: [[(offset: Int, element: Book)]] = []
        var current: [(offset: Int, element: Book)] = []
        var width: CGFloat = 0
        for item in works {
            let w = Spine.width(for: item.element, height: 25)
            let needed = current.isEmpty ? w : w + 3
            if !current.isEmpty && width + needed > maxWidth {
                rows.append(current)
                current = [item]
                width = w
            } else {
                current.append(item)
                width += needed
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }

    @ViewBuilder
    private func focusAuthorButton(shortAuthor: String, tint: Color) -> some View {
        if RenderMode.offscreen {
            ChipLabel(title: "\(shortAuthor) 몰아 쓰기")
        } else {
            Button { onFocusAuthor(author) } label: {
                HStack(spacing: 3) {
                    Symbol(name: "books.vertical", size: 8.5, color: tint)
                    Text("\(shortAuthor) 몰아 쓰기").font(.system(size: 9.5, weight: .semibold))
                }
                .padding(.horizontal, 7).padding(.vertical, 2.5)
                .foregroundStyle(tint)
                .background(tint.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func workHintLine(index: Int, book: Book) -> String {
        switch BookStatus(index: index, progress: progress) {
        case .done:
            let sold = progress.sales(of: book)
            return L10n.tr(sold > 0 ? "\(book.title) · 탈고 (\(Format.integer(sold))부 판매)" : "\(book.title) · 탈고 (\(Format.integer(book.characters))자)")
        case .current(let f):
            return L10n.tr("\(book.title) · 쓰는 중 \(Format.percent(f * 100))")
        case .pending:
            let ahead = max(1, (progress.position(of: index) ?? index) - progress.orderPosition)
            return L10n.tr("\(book.title) · \(ahead)편 뒤 예정 (\(Format.integer(book.characters))자)")
        }
    }

    /// 1줄로 압축한 작가 체력 + 5대 능력치 + 다음 상승 토큰 바.
    private func compactStatsBar(sheet: AuthorSheet, perks: StatPerks, shortAuthor: String) -> some View {
        let tired = sheet.stamina < perks.staminaMax * Balance.staminaTiredBelow
        let fraction = max(0, min(1, sheet.stamina / max(1, perks.staminaMax)))
        let heartColor: Color = fraction <= 0.1 ? ChartPalette.critical : tired ? ChartPalette.warning : ChartPalette.rose
        let tokensToNext = max(0, Balance.statTokens - sheet.tokensTowardStat)
        return HStack(spacing: 4) {
            HStack(spacing: 3) {
                Symbol(name: tired ? "heart.slash" : "heart.fill", size: 9, color: heartColor)
                Text("\(Int(sheet.stamina.rounded()))")
                    .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .fixedSize()
            .padding(.horizontal, 6).padding(.vertical, 3.5)
            .background(Color.secondary.opacity(0.08), in: Capsule())
            .hint("체력 \(Int(sheet.stamina.rounded())) / \(Int(perks.staminaMax))",
                  ["새 토큰 100만 개마다 \(String(format: "%.1f", Balance.staminaPerMillion))씩 줄고, 한 시간에 \(Int(Balance.staminaRecoveryPerHour))씩 돌아옵니다.",
                   "끈기가 오르면 최대 체력이 늘고 덜 줄어듭니다."],
                  symbol: "heart")

            ForEach(Stat.allCases, id: \.self) { stat in
                let level = sheet.level(stat)
                HStack(spacing: 2.5) {
                    Symbol(name: stat.symbol, size: 8.5, color: level > 0 ? .primary : .secondary.opacity(0.7))
                    Text("\(stat.title) \(level)")
                        .font(.system(size: 9.5, weight: level > 0 ? .medium : .regular).monospacedDigit())
                        .foregroundStyle(level > 0 ? .primary : .secondary)
                }
                .fixedSize()
                .padding(.horizontal, 5.5).padding(.vertical, 3.5)
                .background(Color.secondary.opacity(level > 0 ? 0.1 : 0.05), in: Capsule())
                .hint("\(stat.title) \(level)",
                      [level > 0 ? "지금: \(stat.effectText(level: level))" : "아직 0입니다.",
                       level < Balance.statMax ? "다음: \(stat.effectText(level: level + 1))" : "끝까지 올랐습니다.",
                       stat.raisedLine],
                      symbol: stat.symbol)
            }

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                Symbol(name: "arrow.up", size: 8, color: .secondary)
                Text(Format.short(tokensToNext))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .fixedSize()
            .hint("다음 능력치까지",
                  ["\(shortAuthor)의 능력치는 새 토큰 \(Format.short(Balance.statTokens)) 개마다 하나가 무작위로 1 오릅니다. \(Format.integer(tokensToNext)) 개 남았습니다."],
                  symbol: "arrow.up")
        }
    }

    /// 책등 아래를 받치는 나무/서재 선반선.
    private func shelfLedge(tint: Color) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(scheme == .dark ? 0.35 : 0.24),
                            Color(red: 0.42, green: 0.30, blue: 0.20).opacity(scheme == .dark ? 0.45 : 0.28)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 4)
            Rectangle()
                .fill(Color.white.opacity(scheme == .dark ? 0.12 : 0.35))
                .frame(height: 1)
                .padding(.horizontal, 1)
        }
    }

    /// 1줄 아이콘 스트립용 장신구 타일: 텍스트 없이 24×24 초상화 아이콘만 노출하고 이름·해금 조건은 툴팁으로 안내.
    private func decorIconTile(_ accessory: Accessory?, shortAuthor: String) -> some View {
        let unlocked = accessory.map { Decor.isUnlocked($0, progress: progress) } ?? true
        let isChosen = Decor.chosen(for: author)?.id == accessory?.id
        let rows = accessory.map { Decor.apply(Portraits.rows(author), accessory: $0) } ?? Portraits.rows(author)
        let title = accessory?.title ?? L10n.tr("착용 안 함")
        let lockedBy = accessory?.unlock.flatMap { Achievements.byID($0)?.title }
        return Button {
            guard unlocked else { return }
            onChooseDecor(accessory)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                PixelFrame(rows: rows, scale: 24 / CGFloat(Portraits.size), palette: Portraits.palette)
                    .frame(width: 24, height: 24)
                    .background(Portraits.backdrop(author))
                    .clipShape(RoundedRectangle(cornerRadius: 5.5, style: .continuous))
                    .saturation(unlocked ? 1 : 0)
                    .opacity(unlocked ? 1 : 0.32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .stroke(isChosen ? ChartPalette.series[0] : Color.primary.opacity(0.08), lineWidth: isChosen ? 1.8 : 0.8)
                    )
                if !unlocked {
                    Symbol(name: "lock.fill", size: 6.5, color: .secondary)
                        .padding(2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 5.5, style: .continuous))
        }
        .buttonStyle(.plain)
        .hint(title,
              unlocked
                  ? [isChosen ? "현재 \(shortAuthor)에게 착용 중입니다." : "누르면 \(shortAuthor)에게 착용합니다."]
                  : ["성과 \"\(lockedBy ?? "업적")\" 달성 시 열립니다."],
              symbol: unlocked ? "sparkles" : "lock")
    }
}

/// 책등 하나. 분량만큼 넓고 양장본 장식선과 책갈피, 판매 단계 띠가 그려진다.
struct Spine: View {
    let book: Book
    let status: BookStatus
    let selected: Bool
    var height: CGFloat = 26
    var tier: SalesTier = .none

    static func width(for book: Book, height: CGFloat = 26) -> CGFloat {
        let scale = (Double(book.characters) / 1_000_000).squareRoot()
        return height <= 26 ? 11.5 + CGFloat(scale) * 15 : 14 + CGFloat(scale) * 18
    }

    var body: some View {
        let color = book.spineColor
        // 폭은 분량의 제곱근에 비례(선반 책등은 12~27pt, 상세 카드 책등은 15~34pt).
        let width = Self.width(for: book, height: height)
        let fill = status.fill
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(color.opacity(0.14))
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(color)
                .frame(height: fill > 0 ? max(3, height * CGFloat(fill)) : 0)
            // 탈고한 책은 양장본 가죽 광택과 상단 금박 장식선.
            if fill >= 1 {
                LinearGradient(colors: [.white.opacity(0.20), .clear, .black.opacity(0.14)], startPoint: .leading, endPoint: .trailing)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                VStack {
                    Rectangle().fill( Color.white.opacity(0.28) ).frame(height: 1)
                        .padding(.horizontal, 2.5).padding(.top, 3.5)
                    Spacer()
                }
            }
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(fill >= 1 ? Color.black.opacity(0.12) : color.opacity(0.42), lineWidth: 1)
            if status.isCurrent {
                Rectangle().fill(ChartPalette.critical)
                    .frame(width: 3, height: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 3).offset(y: -2)
            }
            // 판매 단계 띠: 재판은 은색, 베스트셀러부터 금색.
            if tier >= .reprint {
                Rectangle().fill(tier >= .bestseller ? BadgeTier.gold.color : BadgeTier.silver.color)
                    .frame(height: 2.5)
                    .padding(.horizontal, 2.5).padding(.bottom, 3)
            }
        }
        .frame(width: width, height: height)
        .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
            .stroke(Color.primary.opacity(selected ? 0.85 : 0), lineWidth: 1.5))
        .offset(y: selected ? -2 : 0)
        .contentShape(Rectangle())
    }
}
