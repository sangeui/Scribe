import SwiftUI

/// 상시 창의 둥근 초상화. 진행률을 둘레의 고리로 보여 주고, 가만히 있지 않도록
/// 몇 초에 한 번 눈을 깜빡이고 천천히 숨 쉬듯 커졌다 작아진다. 돌발 상황이면 그 상황 그림을 그린다.
struct LivePortrait: View {
    let author: String
    var size: CGFloat = 56
    /// 0...1. nil 이면 고리를 그리지 않는다.
    var fraction: Double?
    var ringColor: Color = .primary.opacity(0.7)
    /// 돌발 상황. 졸면 눈을 감고, 자리를 비우면 빈 의자가 된다(`Portraits.rows(_:event:)`).
    var event: AuthorEvent? = nil
    /// 기분. 눈치면 곁눈질, 농땡이면 창밖을 본다.
    var mood: Mood = .focused
    /// 확인용 그림처럼 시간이 흐르지 않는 곳에서는 끈다.
    var animated = true
    /// 작가 교대. 그 시각부터 1.6초는 떠나는 작가, 3.2초까지는 빈 의자, 그 뒤 새 작가.
    var transition: (from: String, at: Date)? = nil
    /// 카페인으로 손이 떨린다.
    var tremble = false
    /// 표정. 비평·재해·카페인·밤에 따라.
    var expression: Expression = .neutral
    /// 창밖 날씨. nil 이면 맑음으로 그린다.
    var weather: Weather? = nil
    /// 하루의 때. nil 이면 지금 시각으로(확인용 그림에서는 낮).
    var dayPart: DayPart? = nil
    /// 작업실 가구.
    var furniture: [String] = []

    var body: some View {
        if animated {
            // 깜빡임과 숨쉬기만 있어 10fps 면 충분하다.
            TimelineView(.animation(minimumInterval: 1.0 / 10)) { context in
                face(at: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            face(at: 0.5)
        }
    }

    private func face(at t: TimeInterval) -> some View {
        let ring: CGFloat = fraction == nil ? 0 : max(2.5, size * 0.055)
        let inner = size - ring * 2 - (fraction == nil ? 0 : 3)
        // 작가마다 깜빡이는 때가 조금씩 다르게. 4.3초마다 0.14초 감는다.
        let seed = Double(author.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 100) / 25
        let phase = (t + seed).truncatingRemainder(dividingBy: 4.3)
        let closed = phase < 0.14
        let part = dayPart ?? (animated ? DayPart.current(Date(timeIntervalSinceReferenceDate: t)) : .day)
        // 빈 의자는 숨 쉬지 않고, 졸 때는 느리고 깊게 숨 쉰다.
        let napping = event?.id == "nap"
        let breath = animated && event?.leavesDesk != true
            ? 1 + (napping ? 0.03 : 0.018) * sin(t * 2 * .pi / (napping ? 5 : 3.2)) : 1
        // 교대 장면: 떠나는 작가 → 빈 의자 → 새 작가.
        let elapsed = transition.map { t - $0.at.timeIntervalSinceReferenceDate } ?? .infinity
        let shownAuthor = elapsed < 3.2 ? (transition?.from ?? author) : author
        let shownEvent: AuthorEvent? = elapsed < 1.6 ? nil : elapsed < 3.2 ? AuthorEvents.away : event
        let shownMood: Mood = elapsed < 3.2 ? .focused : mood
        let shownExpression: Expression = elapsed < 3.2 ? .neutral : expression
        let shake: CGFloat = tremble && animated && event == nil ? (Int(t * 10) % 2 == 0 ? 0.6 : -0.6) : 0
        // 책상 장면 위에 초상화. 밤에는 촛불이 흔들린다.
        var scene = Portraits.scene(dayPart: part, weather: weather, event: shownEvent, furniture: furniture)
        if part.isDark, shownEvent?.id != "dark", animated, Int(t * 6) % 2 == 0 { scene = Portraits.overlay(scene, ["o"], x: 22, y: 15) }
        let portrait = Self.rows(shownAuthor, event: shownEvent, mood: shownMood, expression: shownExpression, eyesClosed: closed)
        let rows = Portraits.compose(scene: scene, portrait: portrait)
        let palette = Portraits.palette(event: shownEvent, dayPart: part, weather: weather)
        return ZStack {
            if let fraction {
                Circle().stroke(Color.primary.opacity(0.1), lineWidth: ring)
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(fraction, 0.004), 1)))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: ring, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            PixelFrame(rows: rows, scale: inner / CGFloat(Portraits.size), palette: palette)
                .frame(width: inner, height: inner)
                .scaleEffect(breath, anchor: .bottom)
                .offset(x: shake)
                .background(Portraits.backdrop(shownAuthor, event: shownEvent).brightness(part.isDark && shownEvent?.id != "dark" ? -0.14 : 0))
                .clipShape(Circle())
        }
        .frame(width: size - ring, height: size - ring)
        .frame(width: size, height: size)
    }

    /// 눈(`e`)을 그늘진 피부(`S`)로 바꿔 감은 눈을 만든다.
    private static func rows(_ author: String, event: AuthorEvent?, mood: Mood, expression: Expression, eyesClosed: Bool) -> [String] {
        let rows = Portraits.rows(author, event: event, mood: mood, expression: expression)
        guard eyesClosed else { return rows }
        return rows.map { $0.replacingOccurrences(of: "e", with: "S") }
    }
}

/// 상시 창: 가로로 긴 반투명 알약. 왼쪽에 둥근 초상화와 진행 고리, 오른쪽 위에 제목과 작가,
/// 아래에 지금 쓰는 문장. 돌발 상황이면 아래 줄에 상황을 다 보여 주고 아이템 버튼은 위 줄로 올린다.
/// `featured` 에 다른 작가를 주면 초상화만 그 작가로 바뀐다. 글자는 늘 지금 쓰는 작품과 작가다.
struct FloatingPill: View {
    static let size = FloatingStyle.pill.size
    /// 초상화 지름. 상시 창은 초상화를 따로 그려 모드 전환 때 이어지게 한다.
    static let portraitSize: CGFloat = 50

    let progress: WritingProgress
    var featured: String? = nil
    var animated = true
    /// false 면 초상화 자리만 비워 둔다(`FloatingView` 가 따로 그린다).
    var showsPortrait = true
    /// 유리 알약의 폭. 전환 중에는 초상화 원(68)에서 284까지 자란다. 안의 글은 284 폭 그대로 두고 잘라 낸다.
    var width: CGFloat = FloatingPill.size.width
    /// 안의 글과 배지의 불투명도. 전환 중 알약이 어느 정도 자란 뒤에 나타나게 한다.
    var contentOpacity: CGFloat = 1
    /// 하루의 때. 바탕 색조와 글자색을 정한다. nil 이면(확인용 그림) 입히지 않는다.
    var dayPart: DayPart? = nil
    /// 색조를 정하는 시각. 있으면 때 대신 이 시각의 연속 색조를 쓴다.
    var tintDate: Date? = nil
    /// 작가의 기분과 그 한 줄(3분 동안).
    var mood: Mood = .focused
    var moodLine: String? = nil
    /// 작가 교대 장면(떠난 작가, 때).
    var handoff: (from: String, at: Date)? = nil
    var onUse: @MainActor (ItemKind) -> Void = { _ in }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let book = progress.book {
            let other = featured.flatMap { $0 == book.authorShort ? nil : $0 }
            let event = progress.event
            let ink = PillInk.resolve(scheme: scheme, tint: tintDate.map { DayPart.tint(at: $0) } ?? dayPart?.tint, weather: progress.weather.tint)
            HStack(spacing: 10) {
                if showsPortrait {
                    LivePortrait(author: other ?? book.authorShort, size: Self.portraitSize, fraction: progress.fraction,
                                 event: other == nil ? event : nil, mood: other == nil ? mood : .focused, animated: animated,
                                 transition: other == nil ? handoff : nil, tremble: other == nil && progress.caffeinated,
                                 expression: other == nil ? progress.expression : .neutral, weather: progress.weather, dayPart: dayPart,
                                 furniture: progress.studio)
                } else {
                    Color.clear.frame(width: Self.portraitSize, height: Self.portraitSize)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(book.displayTitle).font(.system(size: 12, weight: .semibold)).foregroundStyle(ink.primary)
                            .layoutPriority(1)
                        Text(book.displayAuthorShort).font(.system(size: 10)).foregroundStyle(ink.secondary).fixedSize()
                        Spacer(minLength: 4)
                        if let event {
                            useButton(progress.cureItem ?? event.cure, count: progress.cureCount)
                        } else {
                            Text(Format.percent(progress.fraction * 100))
                                .font(.system(size: 9, weight: .medium).monospacedDigit()).foregroundStyle(ink.secondary)
                        }
                    }
                    .lineLimit(1)
                    if event == nil, let recent = progress.recentDisaster(within: 180),
                       let disaster = Disasters.byID(recent.event), let lost = recent.lostCharacters {
                        HStack(spacing: 4) {
                            PixelIconView(rows: disaster.icon, color: .orange, scale: 10 / 9)
                            MarqueeText(text: recent.endedBy.flatMap(ItemKind.init(rawValue:)).map { disaster.shortShieldedText($0) } ?? disaster.shortText(lost: lost), color: ink.secondary, animated: animated)
                        }
                    } else if let note = progress.recentNote(within: 180), let icon = note.icon,
                              event == nil || note.kind == .refused {
                        // 돌아온 직후 3분은 돌아온 말을, 거절당한 직후 3분은 거절한 말을, 행운은 그 말을 보여 준다.
                        HStack(spacing: 4) {
                            PixelIconView(rows: icon, color: note.kind == .luck ? BadgeTier.gold.color
                                          : ink.faint, scale: 10 / 9)
                            MarqueeText(text: note.text, color: ink.secondary, animated: animated)
                        }
                    } else if event == nil, let moodLine {
                        // 기분 한 줄. 눈치·농땡이·돌아옴.
                        MarqueeText(text: moodLine, color: ink.secondary, animated: animated)
                    } else if let event {
                        // 픽셀 아이콘은 .secondary 같은 의미 색을 비트맵으로 바꾸지 못해 검게 나온다. 실제 색을 준다.
                        AuthorStatusLine(event: event, color: ink.faint, fontSize: 10)
                            .fixedSize()
                    } else {
                        ManuscriptText(book: book, target: progress.charactersInBook, fontSize: 11,
                                       singleLine: true, color: .primary.opacity(0.85), tempo: progress.caffeinated ? Balance.caffeineTempo : 1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 15)
                    }
                }
            }
            .opacity(contentOpacity)
            .padding(.leading, 9).padding(.trailing, 18)
            .frame(width: Self.size.width, height: Self.size.height, alignment: .leading)
            .frame(width: width, height: Self.size.height, alignment: .leading)
            .clipShape(Capsule())
            // 날씨 색이 옅게 깔리고, 비나 눈이 오면 유리 위에 내린다.
            // 날씨 바탕(흐림·비·폭풍·눈·안개·더위)이 유리 위에 깔리고, 비나 눈이 오면 그 위에 내린다.
            .background(WeatherBackdrop(weather: progress.weather, animated: animated).clipShape(Capsule()))
            .overlay(WeatherOverlay(weather: progress.weather, animated: animated).clipShape(Capsule()))
            // 확인용 그림(ImageRenderer)은 글래스를 그리지 못해 알약째 비어 나온다. 그때는 반투명 재질로.
            // 밤에는 유리에 남색이 옅게 든다. 초상화의 밤 색과 맞춘다.
            .modifier(PillBackground(glass: animated, tint: tintDate.map { DayPart.tint(at: $0) } ?? dayPart?.tint))
            // 바탕이 어두우면 고리·배지도 어두운 모양 색으로. 글자는 위에서 직접 정했다.
            .environment(\.colorScheme, ink.dark ? .dark : .light)
            // 때가 바뀌면 유리를 새로 만든다. 색조만 바꾸면 유리가 전 색을 그대로 들고 있었다.
            .id(tintDate.map { "\(DayPart.tintKey(at: $0))" } ?? dayPart?.rawValue ?? "")
            .help("\(book.displayTitle) · \(book.displayAuthor)\n\(Format.integer(progress.charactersInBook)) / \(Format.integer(book.characters))자 · 오늘 \(Format.integer(Int(progress.todayCharacters)))자\n\(progress.weather.line)")
        }
    }

    private func useButton(_ cure: ItemKind, count: Int) -> some View {
        Button { onUse(cure) } label: {
            Text(count > 0 ? "\(cure.shortTitle) ×\(count)" : "\(cure.shortTitle) 없음")
                .font(.system(size: 9, weight: .semibold))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .foregroundStyle(count > 0 ? Color(nsColor: .windowBackgroundColor) : .secondary)
                .background(count > 0 ? Color.primary.opacity(0.85) : Color.secondary.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
        .fixedSize()
    }
}

/// 알약 바탕. macOS 26 이상은 리퀴드 글래스, 그 아래는 반투명 재질.
struct PillBackground<S: Shape>: ViewModifier {
    var glass = true
    var shape: S
    /// 하루의 때에 따라 유리에 옅게 입히는 색. nil 이면 입히지 않는다.
    var tint: Color?

    init(glass: Bool = true, shape: S = Capsule(), tint: Color? = nil) {
        self.glass = glass
        self.shape = shape
        self.tint = tint
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *), glass {
            // 유리의 tint 는 옅어서 티가 안 난다. 색을 유리 위에 직접 칠한다.
            content.glassEffect(.regular, in: shape)
                .overlay(shape.fill(tint ?? .clear).allowsHitTesting(false))
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(.regularMaterial, in: shape)
            .overlay(shape.fill(tint ?? .clear).allowsHitTesting(false))
            .overlay(shape.stroke(.primary.opacity(0.08)))
    }
}

/// 상시 창 모양. 설정에서 고른다.
enum FloatingStyle: String, CaseIterable {
    case pill, mini

    nonisolated static let key = "floatingStyle"

    static var current: FloatingStyle {
        FloatingStyle(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .pill
    }

    var title: String {
        switch self {
        case .pill: "알약"
        case .mini: "미니"
        }
    }

    var detail: String {
        switch self {
        case .pill: "초상화, 제목과 작가, 지금 쓰는 문장 한 줄"
        case .mini: "바탕 없이 초상화와 진행 고리만. 깃펜이 움직이면 쓰는 중"
        }
    }

    var size: CGSize {
        switch self {
        case .pill: CGSize(width: 284, height: 68)
        case .mini: CGSize(width: 92, height: 92)
        }
    }
}

/// 상시 창 미니 모드: 바탕 없이 둥근 초상화와 진행 고리, 아래에 % 꼬리표. 오른쪽 위 깃펜이 움직이면 쓰는 중이고,
/// 돌발 상황이면 그 상황 아이콘이 선다.
struct FloatingMini: View {
    static let size = FloatingStyle.mini.size
    /// 초상화 지름. 창 틀(92)은 그대로 두고 그 가운데에 둔다. 알약과 중심이 같아야 전환이 이어진다.
    static let portraitSize: CGFloat = 64

    let progress: WritingProgress
    var featured: String? = nil
    var animated = true
    /// false 면 초상화 자리만 비워 둔다(`FloatingView` 가 따로 그린다).
    var showsPortrait = true
    /// 하루의 때. nil 이면(확인용 그림) 색조를 입히지 않는다.
    var dayPart: DayPart? = nil
    /// 색조를 정하는 시각. 있으면 때 대신 이 시각의 연속 색조를 쓴다.
    var tintDate: Date? = nil
    var mood: Mood = .focused
    var onUse: @MainActor (ItemKind) -> Void = { _ in }

    @Environment(\.colorScheme) private var scheme

    private var tint: Color? { tintDate.map { DayPart.tint(at: $0) } ?? dayPart?.tint }
    private var ink: PillInk { PillInk.resolve(scheme: scheme, tint: tint, weather: progress.weather.tint) }

    var body: some View {
        if let book = progress.book {
            let other = featured.flatMap { $0 == book.authorShort ? nil : $0 }
            let event = progress.event
            let disaster = progress.recentDisaster(within: 180)
            ZStack(alignment: .bottom) {
                Group {
                    if showsPortrait {
                        LivePortrait(author: other ?? book.authorShort, size: Self.portraitSize, fraction: progress.fraction,
                                     event: other == nil ? event : nil, mood: other == nil ? mood : .focused, animated: animated,
                                     tremble: other == nil && progress.caffeinated,
                                     expression: other == nil ? progress.expression : .neutral, weather: progress.weather, dayPart: dayPart,
                                     furniture: progress.studio)
                    } else {
                        Color.clear.frame(width: Self.portraitSize, height: Self.portraitSize)
                    }
                }
                .padding(.bottom, (Self.size.height - Self.portraitSize) / 2)
                // 아래: %. 초상화 아래 가장자리에 반쯤 걸친다.
                Text(Format.percent(progress.fraction * 100))
                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    .foregroundStyle(ink.primary)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .modifier(PillBackground(glass: false, tint: tint))
                    .padding(.bottom, (Self.size.height - Self.portraitSize) / 2 - 7)
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .contentShape(Circle())
            .environment(\.colorScheme, ink.dark ? .dark : .light)
            .id(tintDate.map { "\(DayPart.tintKey(at: $0))" } ?? dayPart?.rawValue ?? "")
            .overlay(alignment: .topLeading) {
                // 초상화 원의 오른쪽 위(45°)에 걸친다.
                let r = Self.portraitSize / 2
                badge(event: event, disaster: disaster)
                    .position(x: Self.size.width / 2 + r * 0.72, y: Self.size.height / 2 - r * 0.72)
            }
            .help(helpText(book, event: event))
            .contextMenu {
                if let event {
                    let count = progress.cureCount
                    let item = progress.cureItem ?? event.cure
                    Button(count > 0 ? "\(item.title) 권하기 (×\(count))" : "\(event.cure.role.title) 아이템 없음") { onUse(item) }
                        .disabled(count == 0)
                }
            }
        }
    }

    /// 오른쪽 위 깃펜 배지. 쓰는 중이면 메뉴바와 같은 4프레임, 멈추면 상황 아이콘, 재해 직후면 주황 불꽃.
    private func badge(event: AuthorEvent?, disaster: EventRecord?) -> some View {
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: 0.3)) { context in
                    badgeFrame(tick: Int(context.date.timeIntervalSinceReferenceDate / 0.3), event: event, disaster: disaster)
                }
            } else {
                badgeFrame(tick: 1, event: event, disaster: disaster)
            }
        }
        .frame(width: 22, height: 22)
        .modifier(PillBackground(glass: false, shape: Circle(), tint: tint))
    }

    private func badgeFrame(tick: Int, event: AuthorEvent?, disaster: EventRecord?) -> some View {
        Group {
            if let disaster, let kind = Disasters.byID(disaster.event) {
                PixelIconView(rows: kind.icon, color: .orange, scale: 1.2)
            } else if let event {
                PixelIconView(rows: event.icon, color: .secondary, scale: 1.2)
            } else if mood == .slacking {
                PixelFrame(rows: MenuBarFrames.standing, scale: 0.95, palette: ["#": .secondary])
            } else {
                PixelFrame(rows: MenuBarFrames.writing[tick % MenuBarFrames.writing.count], scale: 0.95, palette: ["#": .primary])
            }
        }
    }

    private func helpText(_ book: Book, event: AuthorEvent?) -> String {
        var lines = ["\(book.displayTitle) · \(book.displayAuthor)",
                     "\(Format.integer(progress.charactersInBook)) / \(Format.integer(book.characters))자 · 오늘 \(Format.integer(Int(progress.todayCharacters)))자"]
        if let event { lines.append("멈춤: \(event.text)") }
        return lines.joined(separator: "\n")
    }
}

/// 알약 글자색. 유리 바탕(시스템 모양)에 시각 색조와 날씨 색을 겹친 밝기를 재서, 어두우면 흰 글자, 밝으면 검은 글자를 쓴다.
/// 시스템의 .secondary 는 바탕이 어두우면 너무 흐려서 비율을 직접 정한다.
struct PillInk {
    let dark: Bool
    let primary: Color
    let secondary: Color
    /// 아이콘과 상황 줄.
    let faint: Color

    static func resolve(scheme: ColorScheme, tint: Color?, weather: Color?) -> PillInk {
        var luminance = scheme == .dark ? 0.22 : 0.86
        for color in [tint, weather].compactMap({ $0 }) {
            guard let c = NSColor(color).usingColorSpace(.deviceRGB) else { continue }
            let lum = 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
            luminance = luminance * (1 - c.alphaComponent) + lum * c.alphaComponent
        }
        let dark = luminance < 0.5
        return PillInk(dark: dark,
                       primary: dark ? .white : Color(white: 0.08),
                       secondary: dark ? .white.opacity(0.8) : .black.opacity(0.64),
                       faint: dark ? .white.opacity(0.7) : .black.opacity(0.58))
    }
}
