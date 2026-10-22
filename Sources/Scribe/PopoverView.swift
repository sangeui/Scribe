import SwiftUI

struct PopoverView: View {
    @Bindable var store: UsageStore
    @Environment(\.openSettings) private var openSettings
    /// `--snapshot` 은 스크롤 없이 전체를 그린다. 오프스크린 렌더링에서는 높이 측정이 안 돈다.
    var scrollable = true

    /// 내용 높이. 창은 이 높이까지만 늘어나고 그보다 길면 스크롤한다.
    @State private var contentHeight: CGFloat = 600
    /// 마을 맵. 방향키를 누르면 열리고, 건물에 들어가거나 Esc 로 닫는다.
    @State private var village = VillageState()
    @State private var showsVillage = false
    /// 살롱(작가들이 모인 방). 마을의 살롱 문으로 들어간다.
    @State private var salon = SalonState()
    @State private var showsSalon = false

    var body: some View {
        if scrollable {
            let height = min(contentHeight, Self.maxHeight)
            ScrollView {
                content
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .frame(width: 380)
            .frame(height: height)
            // 메뉴바 창은 내용이 커지면 따라 커지지만 작아질 때는 그대로 남아 위아래가 빈다. 직접 맞춘다.
            .background(WindowSizer(contentSize: CGSize(width: 380, height: height)))
        } else {
            content.frame(width: 380)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsSalon, let writing = store.writing {
                salonSection(writing)
            } else if showsVillage, let writing = store.writing {
                villageSection(writing)
            } else {
                writingSection
                Divider()
                usageSection
            }
            Divider()
            footer
        }
        .padding(16)
        .hintHost()
        .background {
            if !RenderMode.offscreen {
                KeyCatcher(onKey: handle, gameKeys: showsVillage || showsSalon)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsVillage)
        .animation(.easeOut(duration: 0.2), value: showsSalon)
    }

    // MARK: 마을

    private func villageSection(_ writing: WritingProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                sectionTitle("마을")
                Spacer()
                Button { village.stop(); showsVillage = false } label: { Symbol(name: "xmark", size: 11) }
                    .buttonStyle(.plain)
                    .hint("닫기", ["Esc 를 눌러도 닫힙니다."], symbol: "xmark")
            }
            VillageView(progress: writing, state: village, mood: store.mood, fuel: store.effectiveFuelLimit,
                        onPickup: store.pickup, onRecommend: store.recommend) { enter($0) }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func salonSection(_ writing: WritingProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                sectionTitle("살롱")
                Spacer()
                Button { leaveSalon() } label: { Symbol(name: "arrow.uturn.backward", size: 11) }
                    .buttonStyle(.plain)
                    .hint("나가기", ["Esc 를 눌러도 마을로 나갑니다."], symbol: "arrow.uturn.backward")
            }
            SalonView(progress: writing, state: salon, mood: store.mood, onInvite: store.invite, onLeave: leaveSalon)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    /// 방향키면 마을을 열거나 걷고(누르고 있으면 계속), 문 앞에서 ↑·Return 이면 들어가고, Esc 면 닫는다. 받았으면 true.
    private func handle(_ key: VillageState.Key, down: Bool) -> Bool {
        guard store.writing != nil else { return false }
        if showsSalon {
            guard down else { return true }
            if key == .escape, salon.dialogue == nil { leaveSalon(); return true }
            salon.press(key)
            return true
        }
        if !showsVillage {
            guard down, key != .escape, key != .enter else { return false }
            village.stand(at: SidePanel.shared.current == .bag ? .storage : SidePanel.shared.current == .bookstore ? .bookstore : .workshop)
            village.onEnter = { enter($0) }
            showsVillage = true
            return true
        }
        if !down { village.release(key); return true }
        if key == .escape {
            if village.dialogue != nil { village.press(.escape); return true }
            village.stop(); showsVillage = false; return true
        }
        village.onEnter = { enter($0) }
        village.press(key)
        return true
    }

    private func enter(_ building: VillageBuilding) {
        village.stop()
        showsVillage = false
        switch building {
        case .workshop:
            if SidePanel.shared.isShowing { SidePanel.shared.close() }
        case .storage: SidePanel.shared.open(.bag, store: store)
        case .bookstore: SidePanel.shared.open(.bookstore, store: store)
        case .salon:
            salon.enter()
            showsSalon = true
        }
    }

    /// 살롱에서 나온다. 맵의 살롱 문 앞에 선다.
    private func leaveSalon() {
        salon.leave()
        showsSalon = false
        village.stand(at: .salon)
        village.onEnter = { enter($0) }
        showsVillage = true
    }

    // MARK: 사용량

    /// 한 줄 요약만 두고, 누르면 옆에 사용량 화면(`UsageDashboard`)을 연다.
    private var usageSection: some View {
        UsageSummaryRow(store: store) { SidePanel.shared.toggle(.usage, store: store) }
    }

    /// 화면 높이에서 메뉴바와 여백을 뺀 만큼.
    private static var maxHeight: CGFloat {
        let screen = NSScreen.main?.visibleFrame.height ?? 800
        return min(820, screen - 40)
    }

    // MARK: 집필

    private var writingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                sectionTitle("집필")
                Spacer()
                let badge = store.agentSource == .antigravity ? "Antigravity" : (store.plan ?? (store.agentSource == .all ? "통합" : nil))
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(.green.opacity(0.18), in: Capsule())
                }
            }
            if let snapshot = store.snapshot, snapshot.scannedFiles == 0 {
                NoLogsNote(source: store.agentSource)
            }
            if let writing = store.writing {
                WritingView(progress: writing, onUse: store.use, onBag: {
                    SidePanel.shared.toggle(.bag, store: store)
                }, onBadges: {
                    SidePanel.shared.toggle(.badges, store: store)
                }, onDismissFinish: store.dismissFinish, onDismissWeekly: store.dismissWeekly, heldNews: store.heldNews,
                onChoose: { store.choose($0) }, quarrel: store.quarrel, handoff: store.handoff, onBookstore: {
                    SidePanel.shared.toggle(.bookstore, store: store)
                }, onIgnite: store.igniteInspiration, onChoosePublisher: store.choosePublisher, onAnswerBet: store.answerBet, onVillage: {
                    village.stand(at: .workshop)
                    village.onEnter = { enter($0) }
                    showsVillage = true
                }) {
                    SidePanel.shared.toggle(.shelf, store: store)
                }
            } else {
                // 기록을 읽는 동안: 가운데 깃펜과 한 줄.
                VStack(spacing: 10) {
                    LoadingBadge()
                    Text("기록을 읽는 중").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
            }
        }
    }

    // MARK: 아래쪽

    private var footer: some View {
        HStack {
            Button {
                // 다른 패널처럼 팝오버 옆에 연다. 팝오버 창을 못 찾으면 따로 설정 창을 띄운다.
                if !SidePanel.shared.toggle(.settings, store: store) {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
            } label: {
                Symbol(name: "gearshape", size: 13)
            }
            .buttonStyle(.plain)
            .hint("설정", ["상시 창 모양과 초상화 꾸미기, 집필 수치, 알림과 방해 금지 시간."], symbol: "gearshape")
            Spacer()
            if let s = store.snapshot {
                Text("로그 \(s.scannedFiles)개 · \(s.generatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Button {
                Task { await store.refreshNow() }
            } label: {
                Symbol(name: "arrow.clockwise", size: 13)
            }
            .buttonStyle(.plain)
            .disabled(store.isRefreshing)
            .hint("새로고침", ["로그를 다시 훑고 Keychain 의 한도를 다시 읽습니다. 평소에는 15초마다 저절로 합니다."], symbol: "arrow.clockwise")
            Button("종료") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }
}

/// 선택한 에이전트의 기록이 하나도 없을 때. 어디를 읽는지와 무엇을 하면 되는지만 짧게.
private struct NoLogsNote: View {
    var source: AgentSource = .all

    private var title: String {
        switch source {
        case .antigravity: "Antigravity 기록이 없습니다"
        case .claude: "Claude Code 기록이 없습니다"
        case .all: "에이전트 대화 기록이 없습니다"
        }
    }

    private var bodyText: String {
        switch source {
        case .antigravity:
            "Antigravity 또는 Gemini CLI 를 한 번 쓰면 기록이 생기고, 그때부터 집필이 시작됩니다. 별도 로그인이나 연결은 필요 없습니다."
        case .claude:
            "Claude Code 를 한 번 쓰면 기록이 생기고, 그때부터 집필이 시작됩니다. 로그인이나 연결은 필요 없습니다."
        case .all:
            "Antigravity 나 Claude Code 를 한 번 쓰면 기록이 생기고, 그때부터 집필이 시작됩니다. 아래에서 다른 데이터 소스를 골라 볼 수도 있습니다."
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Symbol(name: "doc.text.magnifyingglass", size: 14)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.callout.weight(.semibold))
                Text(bodyText)
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(source.logPathDisplay).font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                    Button("Finder 에서 보기") {
                        let home = FileManager.default.homeDirectoryForCurrentUser
                        let target: URL
                        if source == .claude {
                            let folder = home.appendingPathComponent(".claude/projects")
                            target = FileManager.default.fileExists(atPath: folder.path) ? folder : home.appendingPathComponent(".claude")
                        } else {
                            let folder = home.appendingPathComponent(".gemini/antigravity/brain")
                            target = FileManager.default.fileExists(atPath: folder.path) ? folder : home.appendingPathComponent(".gemini")
                        }
                        NSWorkspace.shared.activateFileViewerSelecting([target])
                    }
                    .buttonStyle(.plain).font(.caption2).foregroundStyle(.secondary).underline()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .hint("기록을 읽는 곳", ["Antigravity(~/.gemini/antigravity/brain/**/transcript.jsonl), Gemini CLI(~/.gemini/tmp), Claude Code(~/.claude/projects/**/*.jsonl) 로그를 15초마다 읽습니다.",
                              "바뀐 파일만 다시 읽으며 네트워크로 대화 내용을 보내지 않습니다."], symbol: "doc.text.magnifyingglass")
    }
}

/// 자신이 든 창의 크기를 `contentSize` 로 맞춘다. 위쪽 모서리는 두고 아래로만 줄거나 늘어난다.
private struct WindowSizer: NSViewRepresentable {
    let contentSize: CGSize

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        PopoverHost.window = view.window
        // 다음 런루프로 미루면 내용이 먼저 줄고 창이 한 프레임 뒤에 따라와 덜컹인다. 같은 프레임에 맞춘다.
        guard let window = view.window, window.contentView?.frame.size != contentSize else { return }
        let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        window.setContentSize(contentSize)
        window.setFrameTopLeftPoint(topLeft)
    }
}
