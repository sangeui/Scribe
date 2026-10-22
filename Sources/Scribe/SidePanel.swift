import AppKit
import SwiftUI

/// 메뉴 팝오버 창. 팝오버 내용이 붙은 창을 `WindowSizer` 가 알려 준다.
@MainActor
enum PopoverHost {
    weak static var window: NSWindow?
}

/// 메뉴 팝오버 옆에 붙는 패널. 팝오버의 자식 창이라 팝오버가 닫히면 같이 닫힌다.
/// 버튼만 있는 화면을 띄운다. 키 창이 되면 팝오버가 포커스를 잃고 닫혀 버리기 때문이다.
@MainActor
final class SidePanel {
    enum Kind {
        case shelf, bag, usage, badges, bookstore, settings

        var size: CGSize {
            switch self {
            case .shelf: CGSize(width: 420, height: 600)
            case .bag: CGSize(width: 380, height: 520)
            case .usage: CGSize(width: 400, height: 720)
            case .badges: CGSize(width: 400, height: 620)
            case .bookstore: CGSize(width: 420, height: 640)
            case .settings: CGSize(width: 480, height: 620)
            }
        }
    }

    static let shared = SidePanel()

    private var panel: NSPanel?
    private var kind: Kind?
    private var observer: NSObjectProtocol?

    var isShowing: Bool { panel?.isVisible ?? false }
    /// 떠 있는 패널의 종류.
    var current: Kind? { isShowing ? kind : nil }

    /// 그 패널을 연다. 이미 떠 있으면 그대로 둔다.
    func open(_ kind: Kind, store: UsageStore) {
        if current == kind { return }
        toggle(kind, store: store)
    }

    /// 패널을 팝오버 옆에 띄우거나, 같은 것이 떠 있으면 닫는다. 팝오버 창을 못 찾으면 false.
    @discardableResult
    func toggle(_ kind: Kind, store: UsageStore) -> Bool {
        if isShowing, self.kind == kind {
            close()
            return true
        }
        close()
        guard let parent = PopoverHost.window, parent.isVisible else { return false }

        let size = kind.size
        let content: AnyView = switch kind {
        case .shelf: AnyView(ShelfPanel(store: store))
        case .bag: AnyView(BagPanel(store: store))
        case .usage: AnyView(UsageDashboard(store: store))
        case .badges: AnyView(BadgePanel(store: store))
        case .bookstore: AnyView(BookstorePanel(store: store))
        case .settings: AnyView(SettingsPanel(store: store))
        }
        let hosting = NSHostingView(rootView: content
            .frame(width: size.width, height: size.height)
            .hintHost()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.12))))
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = parent.level
        panel.contentView = hosting
        panel.setContentSize(size)

        // 오른쪽에 자리가 있으면 오른쪽, 없으면 왼쪽. 위쪽 모서리를 팝오버와 맞춘다.
        let gap: CGFloat = 8
        let screen = (parent.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        var x = parent.frame.maxX + gap
        if x + size.width > screen.maxX { x = parent.frame.minX - gap - size.width }
        x = max(screen.minX, x)
        let y = min(parent.frame.maxY, screen.maxY) - size.height
        panel.setFrameOrigin(NSPoint(x: x, y: max(screen.minY, y)))

        parent.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        self.panel = panel
        self.kind = kind

        // 팝오버가 사라지면(가려지거나 닫히면) 패널도 닫는다.
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: parent, queue: .main
        ) { [weak parent] _ in
            MainActor.assumeIsolated {
                guard let parent, !parent.occlusionState.contains(.visible) else { return }
                SidePanel.shared.close()
            }
        }
        return true
    }

    /// 확인용: 메뉴바 깃펜을 눌러 팝오버를 연다. 상태 막대 창의 단추를 찾아 누른다. 다른 앱이 앞에 있으면 안 열릴 수 있어 앱을 앞으로 가져온 뒤 누르고, 그래도 안 열리면 한 번 더 누른다.
    static func openPopoverForTesting() async {
        for attempt in 0..<2 {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where String(describing: type(of: window)).contains("StatusBar") {
                if let button = findButton(in: window.contentView) { button.performClick(nil); break }
            }
            try? await Task.sleep(for: .milliseconds(800))
            if PopoverHost.window?.isVisible == true || attempt == 1 { return }
        }
    }

    private static func findButton(in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        if let button = view as? NSButton { return button }
        for sub in view.subviews { if let found = findButton(in: sub) { return found } }
        return nil
    }

    func close() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        kind = nil
        guard let panel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        self.panel = nil
    }
}
