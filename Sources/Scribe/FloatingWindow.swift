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
    /// 초상화 클릭을 잡는다. 드래그는 창 옮기기로 두고, 누른 자리에서 뗀 것만 클릭으로 본다.
    private var clickMonitor: Any?
    private var mouseDownAt: NSPoint?
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
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let hosting = NSHostingView(rootView: FloatingView(store: store))
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
        // 초상화를 누르면 작가가 한마디 한다. `isMovableByWindowBackground` 를 살리려고 제스처 대신 이벤트를 본다.
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self, weak panel] event in
            let type = event.type
            let location = event.locationInWindow
            let samePanel = event.window === panel
            MainActor.assumeIsolated {
                guard let self, let panel, samePanel else { return }
                if type == .leftMouseDown {
                    self.mouseDownAt = location
                } else if let down = self.mouseDownAt {
                    self.mouseDownAt = nil
                    if hypot(location.x - down.x, location.y - down.y) < 3, self.isOnPortrait(location, in: panel) { self.store.tapPortrait() }
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

        // 사용자가 끌어서 옮긴 것만 저장한다. 창 위치에서 캔버스 모서리를 거꾸로 구한다.
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self, weak panel] _ in
            MainActor.assumeIsolated {
                guard let self, let panel, panel.isVisible, !self.applying else { return }
                let p = Self.padding
                self.canvasTopLeft = NSPoint(x: panel.frame.minX - (self.visible.minX - p),
                                             y: panel.frame.maxY + (self.visible.minY - p))
                UserDefaults.standard.set(NSStringFromPoint(self.canvasTopLeft), forKey: Self.originKey)
            }
        }
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

    private var style: FloatingStyle { FloatingStyle(rawValue: styleRaw) ?? .pill }

    var body: some View {
        Group {
            if let w = store.writing {
                FloatingMorph(morph: style == .pill ? 1 : 0, progress: w, featured: featured.isEmpty ? nil : featured,
                              onUse: store.use, onVisibleRect: store.updateFloatingFrame,
                              mood: store.mood, moodLine: store.moodLine(within: 180),
                              handoff: store.handoff.map { ($0.from, $0.date) })
            } else {
                // 기록을 읽는 동안: 초상화가 올 자리에 같은 크기의 유리 원, 안에 깃펜이 숨 쉬듯 밝아졌다 어두워진다.
                LoadingBadge()
                    .position(FloatingView.portraitCenter)
                    .frame(width: FloatingView.size.width, height: FloatingView.size.height, alignment: .topLeading)
            }
        }
        .animation(.spring(duration: 0.55, bounce: 0.2), value: style)
        .contextMenu {
            ForEach(FloatingStyle.allCases, id: \.self) { candidate in
                Button(candidate.title + (candidate == style ? " ✓" : "")) {
                    styleRaw = candidate.rawValue
                }
            }
            Divider()
            Button("숨기기") { store.setFloatingVisible(false) }
        }
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
                let size = FloatingMini.portraitSize + (FloatingPill.portraitSize - FloatingMini.portraitSize) * m
                LivePortrait(author: other ?? book.authorShort, size: size,
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
                        .position(x: FloatingView.portraitCenter.x + size * 0.36, y: FloatingView.portraitCenter.y + size * 0.36)
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
        .help("기록을 읽는 중입니다")
    }
}
