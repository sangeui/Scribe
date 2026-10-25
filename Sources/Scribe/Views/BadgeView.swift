import SwiftUI

extension PixelIcon {
    static let book = [
        ".#######.",
        "##.....##",
        "##.###.##",
        "##.....##",
        "##.###.##",
        "##.....##",
        "##.....##",
        ".#######.",
        "..#...#..",
    ]
    static let star = [
        "....#....",
        "....#....",
        "...###...",
        "#########",
        ".#######.",
        "..#####..",
        "..##.##..",
        ".##...##.",
        ".#.....#.",
    ]
    static let trophy = [
        "#########",
        "##.###.##",
        "##.###.##",
        ".#######.",
        "..#####..",
        "...###...",
        "....#....",
        "...###...",
        "..#####..",
    ]
    static let calendar = [
        ".#.....#.",
        "#########",
        "#########",
        "#.......#",
        "#.#.#.#.#",
        "#.......#",
        "#.#.#.#.#",
        "#.......#",
        "#########",
    ]
    static let hourglass = [
        "#########",
        ".#.....#.",
        "..#...#..",
        "...###...",
        "....#....",
        "...#.#...",
        "..#.#.#..",
        ".#.###.#.",
        "#########",
    ]
    static let bolt = [
        ".....##..",
        "....##...",
        "...##....",
        "..######.",
        ".....##..",
        "....##...",
        "...##....",
        "..##.....",
        ".##......",
    ]
    static let question = [
        "..#####..",
        ".##...##.",
        ".##...##.",
        "......##.",
        ".....##..",
        "....##...",
        "....##...",
        ".........",
        "....##...",
    ]
}

// MARK: - 화면

/// 메달 모양. 묶음마다 다르다. 집필은 원, 탈고는 방패, 판매는 동전(겹테), 돌발 상황은 육각, 자연재해는 둥근 네모, 토큰은 마름모, 비밀은 원.
struct MedalShape: Shape {
    let category: BadgeCategory

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: 0.5, dy: 0.5)
        switch category {
        case .books:
            var p = Path()
            p.move(to: CGPoint(x: r.minX + r.width * 0.5, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.22), control: CGPoint(x: r.maxX - r.width * 0.1, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.55))
            p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.1))
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.55), control: CGPoint(x: r.minX, y: r.maxY - r.height * 0.1))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.22))
            p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: CGPoint(x: r.minX + r.width * 0.1, y: r.minY))
            p.closeSubpath()
            return p
        case .events:
            var p = Path()
            for i in 0..<6 {
                let a = CGFloat(i) * .pi / 3 - .pi / 6
                let pt = CGPoint(x: r.midX + cos(a) * r.width / 2, y: r.midY + sin(a) * r.height / 2)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.closeSubpath()
            return p
        case .disasters:
            return Path(roundedRect: r, cornerRadius: r.width * 0.26, style: .continuous)
        case .tokens:
            var p = Path()
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.midY))
            p.closeSubpath()
            return p
        default:
            return Path(ellipseIn: r)
        }
    }
}

/// 메달. 받았으면 등급 색 테두리에 아이콘(또는 작가 초상화), 아직이면 회색, 비밀이면 물음표. 모양은 묶음마다(`MedalShape`).
struct BadgeMedal: View {
    let achievement: Achievement
    let unlocked: Bool
    var size: CGFloat = 46

    var body: some View {
        let tier = achievement.tier
        let ring = max(2, size * 0.065)
        let shape = MedalShape(category: achievement.category)
        ZStack {
            shape.fill(unlocked ? tier.color.opacity(0.16) : Color.secondary.opacity(0.08))
            if unlocked {
                // 금속 느낌: 왼쪽 위가 밝다.
                shape.fill(RadialGradient(colors: [.white.opacity(0.28), .clear], center: UnitPoint(x: 0.3, y: 0.25), startRadius: 0, endRadius: size * 0.6))
                shape.stroke(
                    AngularGradient(colors: [tier.color, tier.highlight, tier.color, tier.highlight, tier.color],
                                    center: .center, angle: .degrees(-40)),
                    lineWidth: ring)
                if achievement.category == .sales {
                    // 동전: 안쪽 겹테
                    shape.stroke(tier.color.opacity(0.5), lineWidth: max(1, ring * 0.4)).padding(ring * 2.2)
                }
            } else {
                shape.stroke(Color.secondary.opacity(0.25), lineWidth: 1.5)
            }
            if !unlocked, achievement.isSecret {
                PixelIconView(rows: PixelIcon.question, color: .secondary.opacity(0.5), scale: size / 18)
            } else if let author = achievement.portrait {
                PortraitFrame(author: author, scale: size * 0.62 / 16)
                    .clipShape(Circle())
                    .saturation(unlocked ? 1 : 0)
                    .opacity(unlocked ? 1 : 0.45)
            } else {
                PixelIconView(rows: achievement.icon, color: unlocked ? tier.color : .secondary.opacity(0.45), scale: size / 18)
            }
        }
        .frame(width: size, height: size)
    }
}

/// 팝오버 옆에 여는 성과 화면.
struct BadgePanel: View {
    @Bindable var store: UsageStore
    var scrollable = true

    var body: some View {
        if let progress = store.writing {
            BadgeContent(progress: progress, scrollable: scrollable,
                         onToggleBadge: { store.toggleBadge($0) },
                         onSelectPatron: { store.selectPatronTitle($0) })
        } else {
            ProgressView()
        }
    }
}

struct BadgeContent: View {
    let progress: WritingProgress
    var scrollable = true
    var onToggleBadge: @MainActor (String) -> Void = { _ in }
    var onSelectPatron: @MainActor (String?) -> Void = { _ in }
    /// 목표 묶음 가운데 보여 주는 것. nil 이면 처음 묶음.
    @State private var category: BadgeCategory?
    /// 받은 뱃지를 다 펼쳤는지. 기본은 최근 10개.
    @State private var showsAllBadges = false
    /// 후원자 칭호 선택 서랍을 펼쳤는지.
    @State private var showsPatronPicker = false

    var body: some View {
        if scrollable { ScrollView { content } } else { content }
    }

    /// 기록을 읽기만 하는 실행(`--snapshot`)은 성과를 적지 않으니, 조건을 채운 것도 달성으로 보여 준다.
    /// 매일 성과는 오늘 이뤘는지 본다.
    private func earned(_ a: Achievement) -> Bool {
        if a.daily { return earnedToday(a) }
        return progress.badges[a.id] != nil || a.isMet(progress.facts)
    }
    private func earnedToday(_ a: Achievement) -> Bool {
        (progress.badges[a.id].map { Calendar.current.isDateInToday($0) } ?? false) || a.isMet(progress.facts)
    }
    private func date(_ a: Achievement) -> Date { progress.badges[a.id] ?? .now }

    private var content: some View {
        let unlocked = Achievements.all.filter { !$0.daily && earned($0) }.sorted { date($0) > date($1) }
        let goals = Achievements.nextGoals(earned: earned)
        let perks = Achievements.all.filter(earned).compactMap { a in a.perk.map { (a, $0) } }
        let secrets = goals.filter(\.isSecret)
        return VStack(alignment: .leading, spacing: 20) {
            header(unlocked)
            patronAndShowcaseCard(unlocked)
            if !perks.isEmpty {
                section("금·은 뱃지 상시 효과") {
                    FlowLayout(spacing: 6) {
                        ForEach(perks, id: \.0.id) { a, perk in
                            HStack(spacing: 5) {
                                BadgeMedal(achievement: a, unlocked: true, size: 16)
                                Text(perk.text).font(.caption2)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(BadgeTier.gold.color.opacity(0.1), in: Capsule())
                            .hint(a.title, [perk.text + (a.daily ? " (오늘만)" : " (계속)"), a.detail], symbol: "star")
                        }
                    }
                }
            }
            section("오늘") {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Achievements.dailies) { a in
                        dailyCell(a).frame(maxWidth: .infinity)
                    }
                }
            }
            if !unlocked.isEmpty {
                section("받은 뱃지 \(unlocked.count) · 눌러서 진열대에 장식") {
                    VStack(alignment: .leading, spacing: 0) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 12) {
                            ForEach(Array(unlocked.prefix(10))) { a in
                                badgeCell(a)
                            }
                        }
                        if unlocked.count > 10 {
                            Collapsible(progress: showsAllBadges ? 1 : 0, topSpacing: 12) {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 12) {
                                    ForEach(Array(unlocked.dropFirst(10))) { a in
                                        badgeCell(a)
                                    }
                                }
                            }
                            Button(L10n.tr(showsAllBadges ? "최근 10개만" : "모두 보기 \(unlocked.count)개")) { showsAllBadges.toggle() }
                                .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                    }
                }
            }
            // 다음 목표: 묶음을 골라 하나씩만 본다. 다 늘어놓으면 스크롤이 너무 길다.
            let categories = BadgeCategory.allCases.filter { c in c != .secret && goals.contains { $0.category == c } }
            if let current = category.flatMap({ categories.contains($0) ? $0 : nil }) ?? categories.first {
                section("다음 목표") {
                    FlowLayout(spacing: 6) {
                        Group {
                            ForEach(categories, id: \.self) { c in
                                let count = goals.filter { $0.category == c }.count
                                Button { category = c } label: {
                                    Text("\(c.title) \(count)")
                                        .font(.caption.weight(c == current ? .semibold : .regular))
                                        .padding(.horizontal, 9).padding(.vertical, 4)
                                        .foregroundStyle(c == current ? Color(nsColor: .windowBackgroundColor) : .primary)
                                        .background(c == current ? Color.primary.opacity(0.85) : Color.secondary.opacity(0.1), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    let items = goals.filter { $0.category == current }
                    VStack(spacing: 0) {
                        ForEach(items) { a in
                            goalRow(a)
                            if a.id != items.last?.id { Divider().opacity(0.4).padding(.leading, 40) }
                        }
                    }
                    .padding(.horizontal, 10)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            if !secrets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("비밀 성과 \(secrets.count)개 · 마우스를 올려 단서 확인").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    FlowLayout(spacing: 6) {
                        ForEach(secrets) { a in
                            BadgeMedal(achievement: a, unlocked: false, size: 24)
                                .hint("비밀 성과 · \(a.tier.name)", [Achievements.secretClue(for: a.id), "달성하기 전까지 정확한 조건은 가려져 있습니다."], symbol: "questionmark.circle")
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy(duration: 0.24, extraBounce: 0), value: showsAllBadges)
        .animation(.snappy(duration: 0.24, extraBounce: 0), value: showsPatronPicker)
        .animation(.snappy(duration: 0.22, extraBounce: 0), value: progress.equippedBadges)
        .animation(.easeOut(duration: 0.18), value: category)
    }

    /// 후원자 칭호와 3칸 훈장 진열대를 묶은 상단 카드.
    private func patronAndShowcaseCard(_ unlocked: [Achievement]) -> some View {
        let patronOptions = Achievements.unlockedPatronAchievements(earned: earned)
        let activePatron = progress.patronAchievement ?? patronOptions.first
        let equipped = progress.equippedBadges.compactMap { Achievements.byID($0) }
        return VStack(alignment: .leading, spacing: 12) {
            patronHeaderSection(activePatron: activePatron, patronOptions: patronOptions)
            Divider().opacity(0.45)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("훈장 진열대").font(.caption.weight(.semibold))
                    Text("\(equipped.count) / \(Perks.maxEquipped)칸")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(L10n.tr(equipped.isEmpty ? "받은 뱃지를 눌러 최대 3개까지 장식하세요" : "진열한 뱃지는 분야별 효과를 발휘합니다"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    ForEach(0..<Perks.maxEquipped, id: \.self) { index in
                        if index < equipped.count {
                            showcaseSlot(equipped[index])
                        } else {
                            emptyShowcaseSlot
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(BadgeTier.gold.color.opacity(0.22), lineWidth: 1))
    }

    private func patronHeaderSection(activePatron: Achievement?, patronOptions: [Achievement]) -> some View {
        let hintLines: [String] = {
            if let active = activePatron {
                return [
                    "\"\(active.patronTitle ?? "")\" (\(active.title) 달성 보상)",
                    "집필 화면과 문학 살롱, 마을에서 작가와 주민들이 후원자님을 이 칭호로 기억합니다."
                ]
            }
            return ["성과를 달성하면 문호들을 후원하는 사용자 전용 칭호가 해금됩니다."]
        }()
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Symbol(name: "seal.fill", size: 13, color: activePatron?.tier.color ?? BadgeTier.gold.color)
                VStack(alignment: .leading, spacing: 1) {
                    Text("나의 후원 칭호").font(.caption2).foregroundStyle(.secondary)
                    Text(activePatron?.patronTitle ?? L10n.tr("첫 성과를 달성하면 칭호가 열립니다"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                if patronOptions.count > 1 {
                    Button { showsPatronPicker.toggle() } label: {
                        HStack(spacing: 4) {
                            Text(L10n.tr(showsPatronPicker ? "접기" : "칭호 변경 \(patronOptions.count)"))
                                .font(.caption2.weight(.medium))
                            Symbol(name: "chevron.down", size: 8)
                                .rotationEffect(.degrees(showsPatronPicker ? 180 : 0))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .hint("나의 후원 칭호", hintLines, symbol: "seal")
            if patronOptions.count > 1 {
                Collapsible(progress: showsPatronPicker ? 1 : 0, topSpacing: 10) {
                    FlowLayout(spacing: 6) {
                        ForEach(patronOptions) { a in
                            if let title = a.patronTitle {
                                patronOptionChip(a, title: title, isSelected: activePatron?.id == a.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private func patronOptionChip(_ a: Achievement, title: String, isSelected: Bool) -> some View {
        Button {
            onSelectPatron(a.id)
        } label: {
            HStack(spacing: 5) {
                Circle().fill(a.tier.color).frame(width: 6, height: 6)
                Text(title)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 9).padding(.vertical, 5)
            .foregroundStyle(isSelected ? .primary : .secondary)
            .background(isSelected ? a.tier.color.opacity(0.22) : Color.secondary.opacity(0.09), in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? a.tier.color.opacity(0.6) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .hint("\(title) · \(a.tier.name)", ["달성 성과: \(a.title) (\(a.detail))", "누르면 이 후원자 칭호를 패용합니다."], symbol: "seal")
    }

    private func showcaseSlot(_ a: Achievement) -> some View {
        Button { onToggleBadge(a.id) } label: {
            VStack(spacing: 5) {
                BadgeMedal(achievement: a, unlocked: true, size: 36)
                Text(a.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(a.slotPerk.shortText)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(a.tier.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8).padding(.horizontal, 6)
            .background(a.tier.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(a.tier.color.opacity(0.38), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .hint("\(a.title) · 진열 중", [a.detail, "진열 효과: \(a.slotPerk.text)", "누르면 진열대에서 내립니다."], symbol: "rosette")
    }

    private var emptyShowcaseSlot: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                Symbol(name: "rosette", size: 12, color: .secondary.opacity(0.3))
            }
            .frame(width: 36, height: 36)
            Text("빈 진열대")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.65))
            Text("뱃지 선택")
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8).padding(.horizontal, 6)
        .background(Color.secondary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(Color.secondary.opacity(0.18)))
    }

    private func badgeCell(_ a: Achievement) -> some View {
        let isEquipped = progress.equippedBadges.contains(a.id)
        let hintTitle = isEquipped ? "\(a.title) · \(a.tier.name) (진열 중)" : "\(a.title) · \(a.tier.name)"
        var hintLines: [String] = [
            a.detail,
            "\(date(a).formatted(.dateTime.year().month(.defaultDigits).day())) 달성",
            "진열 효과: \(a.slotPerk.text)"
        ]
        if let perk = a.perk {
            hintLines.append("상시 효과: \(perk.text)")
        }
        if let patron = a.patronTitle {
            hintLines.append("나의 후원 칭호: \"\(patron)\"")
        }
        if let reward = progress.badgeRewards[a.id] {
            hintLines.append("받음: \(reward)")
        }
        hintLines.append(isEquipped ? "누르면 훈장 진열대에서 내립니다." : "누르면 훈장 진열대에 장식합니다.")
        return Button { onToggleBadge(a.id) } label: {
            VStack(spacing: 4) {
                BadgeMedal(achievement: a, unlocked: true, size: 44)
                    .overlay(alignment: .topTrailing) {
                        if isEquipped {
                            equippedBadgeMark
                        }
                    }
                Text(a.title)
                    .font(.caption2.weight(isEquipped ? .semibold : .medium))
                    .foregroundStyle(isEquipped ? a.tier.color : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hint(hintTitle, hintLines, symbol: "rosette")
    }

    private var equippedBadgeMark: some View {
        Circle()
            .fill(BadgeTier.gold.color)
            .frame(width: 14, height: 14)
            .overlay(Symbol(name: "checkmark", size: 7, color: .white))
            .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
            .offset(x: 2, y: -2)
    }

    /// 제목, 받은 수, 등급별 수, 전체 진행 띠.
    private func header(_ unlocked: [Achievement]) -> some View {
        let total = Achievements.all.filter { !$0.daily }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("성과").font(.headline)
                Text("\(unlocked.count) / \(total)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 10) {
                    ForEach([BadgeTier.gold, .silver, .bronze], id: \.self) { tier in
                        HStack(spacing: 4) {
                            Circle().fill(tier.color).frame(width: 8, height: 8)
                            Text("\(unlocked.filter { $0.tier == tier }.count)")
                                .font(.caption.monospacedDigit().weight(.medium))
                        }
                    }
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.12))
                    Capsule().fill(BadgeTier.gold.color)
                        .frame(width: max(3, geo.size.width * CGFloat(unlocked.count) / CGFloat(max(1, total))))
                }
            }
            .frame(height: 4)
        }
    }

    private func section(_ title: String, @ViewBuilder body: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr(title)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            body()
        }
    }

    /// 매일 성과 한 칸: 오늘 진행이 메달 둘레의 고리로, 아래에 이름과 연속 일수.
    private func dailyCell(_ a: Achievement) -> some View {
        let p = a.progress(progress.facts)
        let fraction = p.target > 0 ? min(1, p.current / p.target) : 0
        let today = earnedToday(a)
        let count = progress.dailyCounts[a.id]
        let subtitle = count.map { $0.streak > 1 ? L10n.tr("\($0.streak)일째") : L10n.tr("\($0.total)번") } ?? "\(Self.short(p.current))"
        var hintLines: [String] = [
            a.detail,
            L10n.tr("오늘 \(Self.short(p.current)) / \(Self.short(p.target))") + (count.map { " · " + L10n.tr("지금까지 \($0.total)번") } ?? "")
        ]
        if let perk = a.perk {
            hintLines.append("효과(그날만): \(perk.text)")
        }
        return VStack(spacing: 5) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.12), lineWidth: 3)
                Circle().trim(from: 0, to: CGFloat(fraction))
                    .stroke(a.tier.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                BadgeMedal(achievement: a, unlocked: today, size: 36)
            }
            .frame(width: 48, height: 48)
            Text(a.title).font(.caption2.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
        .hint(a.title, hintLines, symbol: "sun.max")
    }

    /// 다음 목표 한 줄: 메달, 등급 점, 이름, 조건, 오른쪽에 진행. 효과는 마우스를 올리면.
    private func goalRow(_ a: Achievement) -> some View {
        let p = a.progress(progress.facts)
        let fraction = p.target > 0 ? min(1, p.current / p.target) : 0
        var hintLines: [String] = [a.detail]
        if a.countable {
            hintLines.append("\(Self.short(p.current)) / \(Self.short(p.target))")
        }
        hintLines.append("진열 효과: \(a.slotPerk.text)")
        if let perk = a.perk {
            hintLines.append("상시 효과: \(perk.text)")
        }
        if let patron = a.patronTitle {
            hintLines.append("칭호 보상: \"\(patron)\"")
        }
        if a.chain != nil {
            hintLines.append("이루면 다음 단계가 나옵니다.")
        }
        return HStack(spacing: 10) {
            BadgeMedal(achievement: a, unlocked: false, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Circle().fill(a.tier.color).frame(width: 6, height: 6)
                    Text(a.title).font(.callout.weight(.medium))
                    if a.perk != nil {
                        Text("★").font(.caption2).foregroundStyle(BadgeTier.gold.color)
                    }
                }
                Text(a.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if a.countable {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(Self.short(p.current)) / \(Self.short(p.target))")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.12))
                        Capsule().fill(a.tier.color).frame(width: max(3, 64 * fraction))
                    }
                    .frame(width: 64, height: 3)
                }
            }
        }
        .padding(.vertical, 8)
        .hint("\(a.title) · \(a.tier.name)", hintLines, symbol: "flag")
    }

    private static func short(_ value: Double) -> String {
        value >= 1_000 ? Format.tokens(Int(value)) : Format.integer(Int(value))
    }
}

/// 줄 바꿈하는 가로 배치. 효과 칩에 쓴다.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 368
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
