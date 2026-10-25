import AppKit
import SwiftUI

/// 데스크톱에 늘 떠 있는 상시 창. 지금 쓰는 작품을 보여 준다.
/// 안의 그림은 알약과 미니를 다 담는 고정 캔버스(296×92)에 그리고, 창은 그 가운데 지금 보이는 부분에
/// 패딩을 더한 만큼만 차지한다. 모양이 바뀌는 동안은 프레임마다 창 크기를 다시 맞춘다.
/// 드래그로 옮길 수 있고, 캔버스의 왼쪽 위 모서리(화면 좌표)를 기억한다.
@MainActor
final class FloatingWindowController {
    nonisolated static let visibleKey = "floatingVisible"
    /// 캔버스 왼쪽 위 모서리(화면 좌표). 예전 이름 그대로 둔다.
    nonisolated static let originKey = "floatingTopLeft"
    nonisolated static let opacityKey = "floatingOpacity"
    /// 보이는 부분 둘레에 두는 여백.
    static let padding: CGFloat = 6

    static var opacity: Double {
        let v = UserDefaults.standard.object(forKey: opacityKey) as? Double
        return min(1, max(0.3, v ?? 1))
    }

    private var panel: NSPanel?
    private var moveObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    /// 초상화 클릭·모드 전환·드래그를 잡는다.
    private var clickMonitor: Any?
    private var mouseDownAt: NSPoint?
    private var mouseDownScreen: NSPoint?
    private var dragStartCanvasTopLeft = NSPoint.zero
    private var isDragging = false
    private let store: UsageStore
    /// 캔버스 왼쪽 위 모서리(화면 좌표, y 는 위로 큼).
    private var canvasTopLeft = NSPoint.zero
    /// 캔버스 안에서 지금 보이는 부분.
    private var visible = FloatingMorph.visibleRect(morph: FloatingStyle.current == .pill ? 1 : 0)
    /// `apply(visible:)` 로 옮기는 중에는 didMove 를 사용자 드래그로 보지 않는다.
    private var applying = false

    init(store: UsageStore) {
        self.store = store
    }

    func setVisible(_ visible: Bool) {
        if visible {
            if panel == nil { makePanel() }
            applyAppearance()
            panel?.orderFrontRegardless()
        } else {
            panel?.orderOut(nil)
        }
        UserDefaults.standard.set(visible, forKey: Self.visibleKey)
    }

    /// 설정의 투명도를 창에 적용한다.
    func applyAppearance() {
        panel?.alphaValue = Self.opacity
    }

    /// 보이는 부분이 바뀌면(모양 전환 중 매 프레임) 창을 그 부분 + 패딩으로 맞춘다. 캔버스는 화면에서 움직이지 않는다.
    func apply(visible rect: CGRect) {
        visible = rect
        guard let panel else { return }
        applying = true
        var target = frame(for: rect)
        // 화면 밖으로 나가면 안으로 민다. 창이 걸친 화면(없으면 주 화면)의 보이는 영역 기준.
        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(target) }) ?? NSScreen.main {
            let bounds = screen.visibleFrame
            var shift = CGPoint.zero
            if target.maxX > bounds.maxX { shift.x = bounds.maxX - target.maxX }
            if target.minX < bounds.minX { shift.x = bounds.minX - target.minX }
            if target.maxY > bounds.maxY { shift.y = bounds.maxY - target.maxY }
            if target.minY < bounds.minY { shift.y = bounds.minY - target.minY }
            if shift != .zero {
                canvasTopLeft.x += shift.x
                canvasTopLeft.y += shift.y
                target = target.offsetBy(dx: shift.x, dy: shift.y)
                UserDefaults.standard.set(NSStringFromPoint(canvasTopLeft), forKey: Self.originKey)
            }
        }
        panel.setFrame(target, display: true)
        let inside = NSMouseInRect(NSEvent.mouseLocation, target, false)
        if store.isFloatingHovered != inside {
            store.isFloatingHovered = inside
        }
        // 창 그림자는 알약에만. 미니는 바탕이 없어서 그림자가 진행 고리 둘레에 줄 하나로 남는다.
        let shadow = rect.width >= 150
        if panel.hasShadow != shadow {
            panel.hasShadow = shadow
            panel.invalidateShadow()
        }
        applying = false
    }

    private func frame(for rect: CGRect) -> NSRect {
        let p = Self.padding
        let width = rect.width + p * 2, height = rect.height + p * 2
        let x = canvasTopLeft.x + rect.minX - p
        let top = canvasTopLeft.y - (rect.minY - p)
        return NSRect(x: x, y: top - height, width: width, height: height)
    }

    private func makePanel() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: CGSize(width: 100, height: 100)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let hosting = FloatingHostingView(rootView: FloatingView(store: store))
        hosting.onHoverChange = { [weak self] hovered in
            MainActor.assumeIsolated {
                guard let self, !self.isDragging else { return }
                self.store.isFloatingHovered = hovered
            }
        }
        // 크기는 여기서 직접 맞춘다. 뷰 크기를 따라가게 두면 전환 중에 서로 끌어당긴다.
        hosting.sizingOptions = []
        panel.contentView = hosting

        // 기억된 자리에 창이 들어가는 화면이 없으면(Dock 뒤에 숨거나 화면 밖으로 나간 경우) 주 화면 오른쪽 위에 둔다.
        let saved = UserDefaults.standard.string(forKey: Self.originKey).flatMap { NSPointFromString($0) }
        if let saved {
            canvasTopLeft = saved
            let candidate = frame(for: visible)
            if !NSScreen.screens.contains(where: { $0.visibleFrame.contains(candidate) }) {
                canvasTopLeft = Self.defaultCanvasTopLeft(visible: visible)
            }
        } else {
            canvasTopLeft = Self.defaultCanvasTopLeft(visible: visible)
        }
        self.panel = panel
        apply(visible: visible)
        // 드래그 이동·초상화 클릭·모드 전환 버튼 클릭·더블클릭을 화면 좌표 기준으로 직접 처리한다.
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self, weak panel] event in
            let type = event.type
            let location = event.locationInWindow
            let clickCount = event.clickCount
            let samePanel = event.window === panel
            MainActor.assumeIsolated {
                guard let self, let panel, samePanel else { return }
                switch type {
                case .leftMouseDown:
                    self.mouseDownAt = location
                    self.mouseDownScreen = NSEvent.mouseLocation
                    self.dragStartCanvasTopLeft = self.canvasTopLeft
                    self.isDragging = false
                case .leftMouseDragged:
                    guard let downScreen = self.mouseDownScreen,
                          let downInWindow = self.mouseDownAt,
                          !self.isOnCureButton(downInWindow, in: panel) else { return }
                    let nowScreen = NSEvent.mouseLocation
                    let dx = nowScreen.x - downScreen.x
                    let dy = nowScreen.y - downScreen.y
                    if self.isDragging || hypot(dx, dy) >= 3 {
                        self.isDragging = true
                        self.applying = true
                        self.canvasTopLeft = NSPoint(x: self.dragStartCanvasTopLeft.x + dx,
                                                     y: self.dragStartCanvasTopLeft.y + dy)
                        panel.setFrameOrigin(self.frame(for: self.visible).origin)
                        self.applying = false
                    }
                case .leftMouseUp:
                    guard self.mouseDownScreen != nil else { return }
                    self.mouseDownScreen = nil
                    self.mouseDownAt = nil
                    if self.isDragging {
                        self.isDragging = false
                        self.apply(visible: self.visible)
                        UserDefaults.standard.set(NSStringFromPoint(self.canvasTopLeft), forKey: Self.originKey)
                        return
                    }
                    if self.isOnModeSwitchButton(location, in: panel) {
                        FloatingStyle.toggle()
                    } else if clickCount == 2, !self.isOnCureButton(location, in: panel) {
                        FloatingStyle.toggle()
                    } else if clickCount == 1, self.isOnPortrait(location, in: panel) {
                        self.store.tapPortrait()
                    }
                default:
                    break
                }
            }
            return event
        }
        // 모니터를 떼거나 붙이면 다시 화면 안으로.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { if let self { self.apply(visible: self.visible) } }
        }

        // 외부 요인으로 창이 옮겨졌을 때도 캔버스 모서리를 동기화한다.
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self, weak panel] _ in
            MainActor.assumeIsolated {
                guard let self, let panel, panel.isVisible, !self.applying, !self.isDragging else { return }
                let p = Self.padding
                self.canvasTopLeft = NSPoint(x: panel.frame.minX - (self.visible.minX - p),
                                             y: panel.frame.maxY + (self.visible.minY - p))
                UserDefaults.standard.set(NSStringFromPoint(self.canvasTopLeft), forKey: Self.originKey)
            }
        }
    }

    /// 창 안의 점(왼쪽 아래 기준)이 초상화 왼쪽 위 모드 전환 버튼(지름 20pt) 안인지.
    private func isOnModeSwitchButton(_ point: NSPoint, in panel: NSPanel) -> Bool {
        let p = Self.padding
        let isPill = visible.width >= 150
        let r = (isPill ? FloatingPill.portraitSize : FloatingMini.portraitSize) / 2
        let center = CGPoint(x: FloatingView.portraitCenter.x - r * 0.72,
                             y: FloatingView.portraitCenter.y - r * 0.72)
        let x = p - visible.minX + center.x
        let y = panel.frame.height - (p - visible.minY + center.y)
        return hypot(point.x - x, point.y - y) <= 12
    }

    /// 알약 모드에서 돌발 상황 치료 버튼 영역인지(더블클릭 전환이 치료 버튼 연타와 겹치지 않도록).
    private func isOnCureButton(_ point: NSPoint, in panel: NSPanel) -> Bool {
        guard visible.width >= 150, store.writing?.event != nil else { return false }
        let p = Self.padding
        let canvasX = point.x - (p - visible.minX)
        let canvasY = (panel.frame.height - point.y) - (p - visible.minY)
        return canvasX >= 190 && canvasY <= 44
    }

    /// 창 안의 점(왼쪽 아래 기준)이 초상화 원 안인지. 캔버스는 창 안에서 `padding - visible.origin` 만큼 밀려 있다.
    private func isOnPortrait(_ point: NSPoint, in panel: NSPanel) -> Bool {
        let p = Self.padding
        let center = FloatingView.portraitCenter
        let x = p - visible.minX + center.x
        let y = panel.frame.height - (p - visible.minY + center.y)
        let radius = (visible.width >= 150 ? FloatingPill.portraitSize : FloatingMini.portraitSize) / 2
        return hypot(point.x - x, point.y - y) <= radius
    }

    /// 주 화면 오른쪽 위, 가장자리에서 16pt 안쪽에 보이는 부분이 오도록 하는 캔버스 모서리.
    private static func defaultCanvasTopLeft(visible: CGRect) -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let frame = screen.visibleFrame
        let p = padding
        return NSPoint(x: frame.maxX - 16 - visible.width - p - (visible.minX - p),
                       y: frame.maxY - 16 + (visible.minY - p))
    }
}

/// 비활성 상태(`nonactivatingPanel`)에서도 마우스 진입·이탈과 첫 클릭을 즉시 전달하는 호스팅 뷰.
private final class FloatingHostingView<Content: View>: NSHostingView<Content> {
    var onHoverChange: ((Bool) -> Void)?
    private var hoverArea: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverChange?(false)
    }
}

/// 상시 창 내용. 설정의 모양을 읽어 `FloatingMorph` 에 넘기고, 보이는 부분이 바뀌면 창 크기를 맞추게 한다.
struct FloatingView: View {
    /// 알약(284×68, (12, 12)에 둔다)과 미니(92×92)를 다 담는 캔버스.
    static let size = CGSize(width: 296, height: 92)
    /// 상시 창에 늘 띄울 작가(`authorShort`). 비어 있으면 지금 쓰는 작가.
    nonisolated static let featuredKey = "floatingFeaturedAuthor"
    /// 초상화 중심. 알약: 12 + 9 + 25 = 46, 미니: 92 / 2 = 46.
    static let portraitCenter = CGPoint(x: 46, y: 46)

    @Bindable var store: UsageStore
    @AppStorage(featuredKey) private var featured = ""
    @AppStorage(FloatingStyle.key) private var styleRaw = FloatingStyle.pill.rawValue
    @AppStorage(FloatingWindowController.opacityKey) private var opacity = 1.0

    private var style: FloatingStyle { FloatingStyle(rawValue: styleRaw) ?? .pill }

    var body: some View {
        Group {
            if let w = store.writing {
                FloatingMorph(morph: style == .pill ? 1 : 0, progress: w, featured: featured.isEmpty ? nil : featured,
                              onUse: store.use, onVisibleRect: store.updateFloatingFrame,
                              mood: store.mood, moodLine: store.moodLine(within: 180),
                              handoff: store.handoff.map { ($0.from, $0.date) },
                              isHovered: store.isFloatingHovered)
            } else {
                // 기록을 읽는 동안: 초상화가 올 자리에 같은 크기의 유리 원, 안에 깃펜이 숨 쉬듯 밝아졌다 어두워진다.
                LoadingBadge()
                    .position(FloatingView.portraitCenter)
                    .frame(width: FloatingView.size.width, height: FloatingView.size.height, alignment: .topLeading)
            }
        }
        .animation(.spring(duration: 0.55, bounce: 0.2), value: style)
        .contextMenu {
            if let w = store.writing, let event = w.event {
                let count = w.cureCount
                let item = w.cureItem ?? event.cure
                Button(L10n.tr(count > 0 ? "\(item.title) 권하기 (×\(count))" : "\(event.cure.role.title) 아이템 없음")) {
                    store.use(item)
                }
                .disabled(count == 0)
                Divider()
            }
            ForEach(FloatingStyle.allCases, id: \.self) { candidate in
                Button(candidate.title + (candidate == style ? " ✓" : "")) {
                    styleRaw = candidate.rawValue
                }
            }
            Menu(L10n.tr("대표 작가")) {
                Button(L10n.tr("쓰는 작가") + (featured.isEmpty ? " ✓" : "")) {
                    featured = ""
                }
                Divider()
                ForEach(Library.authors, id: \.self) { author in
                    let label = Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author
                    Button(label + (featured == author ? " ✓" : "")) {
                        featured = author
                    }
                }
            }
            Menu(L10n.tr("투명도")) {
                ForEach([1.0, 0.85, 0.7, 0.5], id: \.self) { level in
                    let pct = "\(Int((level * 100).rounded()))%"
                    let selected = abs(opacity - level) < 0.03
                    Button(pct + (selected ? " ✓" : "")) {
                        opacity = level
                        store.updateFloatingAppearance()
                    }
                }
            }
            Divider()
            Button("숨기기") { store.setFloatingVisible(false) }
        }
        .environment(\.locale, store.languageLocale)
        .id(store.language)
    }
}

/// 두 모양 사이를 `morph`(0 미니 … 1 알약)로 그린다. `Animatable` 이라 바깥의 애니메이션이 `morph` 를 프레임마다 채워 준다.
/// 초상화는 제자리에서 64→50pt 로 줄고, 유리 알약은 초상화 원(68)에서 오른쪽으로 자라나며, 미니의 꼬리표와 배지는 흐려진다.
/// 창은 캔버스에서 지금 보이는 부분(`visibleRect`)에 패딩을 더한 크기만 차지하고, 캔버스는 그 안에서 밀려 보인다.
struct FloatingMorph: View, Animatable {
    // `View` 는 메인 액터에 묶이지만 `Animatable` 은 아니라서, 보간되는 값만 격리에서 뺀다.
    nonisolated var morph: CGFloat
    let progress: WritingProgress
    let featured: String?
    let onUse: @MainActor (ItemKind) -> Void
    var onVisibleRect: @MainActor (CGRect) -> Void = { _ in }
    var mood: Mood = .focused
    var moodLine: String? = nil
    var handoff: (from: String, at: Date)? = nil
    var isHovered: Bool = false

    nonisolated var animatableData: CGFloat {
        get { morph }
        set { morph = newValue }
    }

    /// 캔버스 안에서 알약이 차지하는 곳.
    static let pillRect = CGRect(x: 12, y: 12, width: 284, height: 68)
    /// 미니가 차지하는 곳: 초상화 원(14…78)과 오른쪽 위 배지, 아래 % 꼬리표까지.
    static let miniRect = CGRect(x: 12, y: 10, width: 70, height: 76)

    /// 전환 정도에 따라 보이는 부분. 두 사각형 사이를 곧게 잇는다.
    static func visibleRect(morph: CGFloat) -> CGRect {
        let m = min(max(morph, 0), 1)
        func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * m }
        return CGRect(x: lerp(miniRect.minX, pillRect.minX), y: lerp(miniRect.minY, pillRect.minY),
                      width: lerp(miniRect.width, pillRect.width), height: lerp(miniRect.height, pillRect.height))
    }

    var body: some View {
        // 하루의 때는 1분마다 다시 본다. 몸체가 다시 그려지지 않아도 때가 바뀌면 색이 따라가야 한다.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            canvas(dayPart: DayPart.current(context.date), at: context.date)
        }
    }

    private func canvas(dayPart: DayPart, at date: Date) -> some View {
        let m = min(max(morph, 0), 1)
        let rect = Self.visibleRect(morph: m)
        let p = FloatingWindowController.padding
        let other = featured.flatMap { $0 == progress.book?.authorShort ? nil : $0 }
        let portraitSize = FloatingMini.portraitSize + (FloatingPill.portraitSize - FloatingMini.portraitSize) * m
        let portraitRadius = portraitSize / 2
        let switchCenter = CGPoint(x: FloatingView.portraitCenter.x - portraitRadius * 0.72,
                                   y: FloatingView.portraitCenter.y - portraitRadius * 0.72)
        let tint = DayPart.tint(at: date)
        return ZStack(alignment: .topLeading) {
            // 유리 알약: 초상화 원 크기(68)에서 오른쪽으로 자란다. 글은 어느 정도 자란 뒤에 나타난다.
            FloatingPill(progress: progress, featured: featured, showsPortrait: false,
                         width: 68 + (FloatingPill.size.width - 68) * m,
                         contentOpacity: max(0, (m - 0.35) / 0.65), dayPart: dayPart, tintDate: date, mood: mood, moodLine: moodLine, onUse: onUse)
                .opacity(m < 0.02 ? 0 : 1)
                .offset(x: Self.pillRect.minX, y: Self.pillRect.minY)
                .allowsHitTesting(m > 0.5)
                .zIndex(0)
            if let book = progress.book {
                LivePortrait(author: other ?? book.authorShort, size: portraitSize,
                             fraction: progress.fraction, event: other == nil ? progress.event : nil,
                             mood: other == nil ? mood : .focused,
                             transition: other == nil ? handoff : nil, tremble: other == nil && progress.caffeinated,
                             expression: other == nil ? progress.expression : .neutral, weather: progress.weather, dayPart: dayPart,
                             furniture: progress.studio)
                    .position(FloatingView.portraitCenter)
                    .allowsHitTesting(false)
                    .zIndex(1)
                // 손님 작가는 초상화의 오른쪽 아래에 작게 겹친다.
                if let guest = progress.guestAuthor {
                    PortraitFrame(author: guest, scale: 1.25)
                        .overlay(RoundedRectangle(cornerRadius: 20 * 0.22, style: .continuous).stroke(.white.opacity(0.7), lineWidth: 1.5))
                        .position(x: FloatingView.portraitCenter.x + portraitSize * 0.36, y: FloatingView.portraitCenter.y + portraitSize * 0.36)
                        .allowsHitTesting(false)
                        .zIndex(3)
                }
            }
            // 미니의 꼬리표와 배지: 알약이 되면서 흐려지고 살짝 작아진다.
            FloatingMini(progress: progress, featured: featured, showsPortrait: false, dayPart: dayPart, tintDate: date, mood: mood, onUse: onUse)
                .opacity(1 - m)
                .scaleEffect(1 - 0.12 * m)
                .allowsHitTesting(m < 0.5)
                .zIndex(2)
            // 마우스를 올렸을 때 초상화 왼쪽 위에 나타나는 모양 전환(알약 ↔ 미니) 배지 버튼.
            ZStack {
                Image(systemName: m > 0.5 ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.85))
            }
            .frame(width: 20, height: 20)
            .modifier(PillBackground(glass: false, shape: Circle(), tint: tint))
            .position(switchCenter)
            .opacity(isHovered ? 1 : 0)
            .scaleEffect(isHovered ? 1 : 0.75)
            .animation(.easeOut(duration: 0.16), value: isHovered)
            .allowsHitTesting(false)
            .zIndex(4)
        }
        .frame(width: FloatingView.size.width, height: FloatingView.size.height, alignment: .topLeading)
        // 창 크기(보이는 부분 + 패딩)에 맞춰 캔버스를 밀어 둔다.
        .offset(x: p - rect.minX, y: p - rect.minY)
        .frame(width: rect.width + p * 2, height: rect.height + p * 2, alignment: .topLeading)
        .clipped()
        .onChange(of: m, initial: true) { onVisibleRect(rect) }
    }
}

/// 기록을 읽는 동안 보이는 원. 초상화와 같은 크기와 자리라 데이터가 오면 그 자리에서 초상화로 바뀐다.
struct LoadingBadge: View {
    var body: some View {
        let side = FloatingPill.portraitSize
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let breath = 0.5 + 0.5 * sin(t * 2.2)
            ZStack {
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: 3)
                Circle().trim(from: 0, to: 0.18)
                    .stroke(Color.primary.opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(t * 90))
                PixelIconView(rows: PixelIcon.quill, color: Color.primary.opacity(0.35 + 0.5 * breath), scale: 2)
                    .offset(y: -breath * 1.5)
            }
            .frame(width: side, height: side)
        }
        .modifier(PillBackground(shape: Circle()))
        .help(L10n.tr("기록을 읽는 중입니다"))
    }
}
