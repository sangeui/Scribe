import AppKit
import SwiftUI

// MARK: - 화면

struct VillageView: View {
    let progress: WritingProgress
    let state: VillageState
    var animated = true
    var date = Date()
    var mood: Mood = .focused
    /// 5시간 한도. 남은 만큼 작업실 앞에 장작이 쌓인다.
    var fuel: LimitRow?
    /// 풀밭의 물건을 줍는다. 주운 아이템 이름.
    var onPickup: @MainActor () -> String? = { nil }
    /// 손님에게 책을 권한다. 결과 한 줄.
    var onRecommend: @MainActor () -> String? = { nil }
    var onEnter: @MainActor (VillageBuilding) -> Void = { _ in }

    /// 오늘 물건이 떨어진 타일. 날마다 자리가 다르다.
    private var pickupTile: (col: Int, row: Int)? {
        guard progress.pickupAvailable else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return (1 + (day * 7) % (VillageMap.cols - 2), 6)
    }

    var body: some View {
        let scene = VillageMap.Scene(progress: progress, date: date, fuel: fuel)
        let scale = VillageMap.scale
        let tile = CGFloat(VillageMap.tile) * scale
        VStack(alignment: .leading, spacing: 8) {
            framedMap(scene: scene)
                .onAppear { handleAppear() }
                .onChange(of: fuel == nil) { _, missing in state.woodpile = !missing }
                .onChange(of: customerCount.count) { _, count in state.setCustomers(count, leaving: customerCount.leaving) }
                .onChange(of: progress.pickupAvailable) { _, _ in state.pickupTile = pickupTile }
                .onChange(of: state.pendingInteraction) { _, target in handleInteraction(target) }
                .onChange(of: state.pendingAction) { _, action in handleAction(action) }
            helpFooter
        }
        .onTapGesture { handleTap(at: $0, scale: scale, tile: tile) }
        .onContinuousHover { phase in
            switch phase {
            case .active(let p) where p.y < CGFloat(VillageMap.height) * scale && clickable(col: Int(p.x / tile), row: Int(p.y / tile)):
                NSCursor.pointingHand.set()
            default:
                NSCursor.arrow.set()
            }
        }
    }

    private func framedMap(scene: VillageMap.Scene) -> some View {
        let scale = VillageMap.scale
        let frameShape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        let borderColor = Color(red: 57 / 255, green: 57 / 255, blue: 57 / 255)
        return mapCanvas(scene: scene)
            .frame(width: CGFloat(VillageMap.width) * scale, height: CGFloat(VillageMap.height) * scale)
            .overlay(DayPart.tint(at: date).opacity(0.55).allowsHitTesting(false))
            .overlay(WeatherOverlay(weather: progress.weather, animated: animated))
            .overlay(weatherLayer(scene.weather))
            .animation(.easeOut(duration: 0.18), value: state.dialogue)
            .clipShape(frameShape)
            .overlay(frameShape.stroke(borderColor, lineWidth: 2))
    }

    private func handleAppear() {
        state.setCustomers(customerCount.count, leaving: customerCount.leaving)
        state.pickupTile = pickupTile
        state.woodpile = fuel != nil
        if animated { state.resume() }
    }

    @ViewBuilder
    private func mapCanvas(scene: VillageMap.Scene) -> some View {
        let dark = scene.dark
        let scale = VillageMap.scale
        let tile = CGFloat(VillageMap.tile) * scale
        let rows = VillageMap.rows(scene)
        let raining = scene.weather == .rain || scene.weather == .storm
        let umbrellas: [Color] = [
            Color(red: 0.8, green: 0.33, blue: 0.26),
            Color(red: 0.4, green: 0.44, blue: 0.76),
            Color(red: 0.92, green: 0.85, blue: 0.4),
            Color(red: 0.42, green: 0.72, blue: 0.24),
        ]
        ZStack(alignment: .topLeading) {
            PixelFrame(rows: rows, scale: scale, palette: VillageMap.palette(dark: dark, weather: scene.weather))
            ambientSprites(scene: scene, scale: scale, tile: tile)
            ForEach(state.npcs) { npc in
                sprite(Player.customerRows(npc.id, facing: npc.facing, step: npc.step),
                       palette: Player.customers[npc.id % Player.customers.count].palette,
                       x: npc.x, y: npc.y, dark: dark,
                       umbrella: raining ? umbrellas[(npc.id + 1) % umbrellas.count] : nil)
            }
            if let building = state.entering {
                let doorX = building == .storage ? 26 : 36
                PixelFrame(rows: VillageTiles.doorOpen, scale: scale, palette: VillageMap.palette(dark: dark, weather: scene.weather))
                    .offset(x: (CGFloat(building.left) * 16 + CGFloat(doorX)) * scale, y: CGFloat(building.top * 16 + 29) * scale)
            }
            if let bubble = bubble {
                workshopBubble(bubble, tile: tile)
            }
            buildingLabels(tile: tile)
            sprite(Player.rows(facing: state.facing, step: state.step), palette: Player.palette, x: state.x, y: state.y, dark: dark,
                   umbrella: raining ? umbrellas[0] : nil)
            if state.dialogue == nil, !state.isEntering, let prompt = actionPrompt {
                ActionPrompt(symbol: prompt.symbol, label: prompt.label, animated: animated)
                    .position(x: min(max(CGFloat(state.x) * tile + tile / 2, 44), CGFloat(VillageMap.width) * scale - 44).rounded(),
                              y: (CGFloat(state.y) * tile - tile * 0.42).rounded())
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
            }
            Color.black.opacity(state.isEntering ? 1 : 0)
                .frame(width: CGFloat(VillageMap.width) * scale, height: CGFloat(VillageMap.height) * scale)
                .animation(.easeIn(duration: 0.35), value: state.isEntering)
                .allowsHitTesting(false)
            if let dialogue = state.dialogue {
                DialogueBox(dialogue: dialogue)
                    .frame(width: CGFloat(VillageMap.width) * scale - 12)
                    .offset(x: 6, y: CGFloat(VillageMap.height) * scale - 58)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func ambientSprites(scene: VillageMap.Scene, scale: CGFloat, tile: CGFloat) -> some View {
        let dark = scene.dark
        return TimelineView(.periodic(from: .now, by: animated ? 0.5 : 3600)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate * 2)
            let frame = animated ? tick % 2 : 0
            ZStack(alignment: .topLeading) {
                ForEach([2, 7, 11], id: \.self) { col in
                    PixelFrame(rows: VillageTiles.flowerHeads, scale: scale, palette: VillageMap.palette(dark: dark, weather: scene.weather))
                        .offset(x: CGFloat(col) * tile + (frame == 0 ? 0 : scale), y: 6 * tile)
                }
                if scene.workshopSmoke {
                    PixelFrame(rows: frame == 0 ? VillageTiles.smokeA : VillageTiles.smokeB, scale: scale, palette: ["e": Color.white.opacity(dark ? 0.35 : 0.75)])
                        .offset(x: (CGFloat(VillageBuilding.workshop.left) * 16 + 44) * scale, y: tile - 13 * scale)
                }
                if let pickup = pickupTile {
                    PixelFrame(rows: frame == 0 ? VillageTiles.sparkleA : VillageTiles.sparkleB, scale: scale, palette: ["k": Color(red: 0.98, green: 0.86, blue: 0.3)])
                        .offset(x: CGFloat(pickup.col) * tile + 4 * scale, y: CGFloat(pickup.row) * tile + 4 * scale)
                }
                if animated, tick % 40 < 10 {
                    let flight = CGFloat(tick % 40) / 10
                    PixelFrame(rows: frame == 0 ? VillageTiles.birdA : VillageTiles.birdB, scale: scale, palette: ["x": Color(red: 0.2, green: 0.2, blue: 0.23)])
                        .offset(x: -16 + (CGFloat(VillageMap.width) * scale + 32) * flight, y: 0.25 * tile + sin(flight * 6) * 3)
                }
            }
        }
    }

    private func workshopBubble(_ bubble: (icon: [String], color: Color), tile: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Color.white)
            RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.85), lineWidth: 2)
            PixelIconView(rows: bubble.icon, color: bubble.color, scale: 2)
        }
        .frame(width: 26, height: 26)
        .overlay(alignment: .bottom) {
            Triangle().fill(Color.white).frame(width: 8, height: 5).offset(y: 5)
                .overlay(Triangle().stroke(Color.black.opacity(0.85), lineWidth: 1.5).frame(width: 8, height: 5).offset(y: 5))
        }
        .position(x: (CGFloat(VillageBuilding.workshop.left) + 1.4) * tile, y: 1.25 * tile)
        .transition(.scale.combined(with: .opacity))
    }

    private func buildingLabels(tile: CGFloat) -> some View {
        ForEach(VillageBuilding.allCases, id: \.self) { building in
            let on = VillageMap.door(col: state.col, row: state.row) == building
            Text(building.title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .foregroundStyle(on ? Color.white : Color.black)
                .background(on ? Color.black.opacity(0.85) : Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.85), lineWidth: 1.5))
                .position(x: (CGFloat(building.left) + 2) * tile, y: (CGFloat(building.top) - 0.5) * tile)
        }
    }

    private var helpFooter: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(help.line).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let more = help.more {
                    Text(more).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Text(help.close).font(.caption2).foregroundStyle(.tertiary).fixedSize()
        }
    }

    private func handleInteraction(_ target: VillageState.Target?) {
        guard let target else { return }
        state.pendingInteraction = nil
        state.talkTurn += 1
        let turn = state.talkTurn
        switch target {
        case .npc(let id): state.dialogue = VillageTalk.customer(id, progress: progress, now: date, turn: turn, leaving: customerCount.leaving)
        case .window: state.dialogue = VillageTalk.author(progress: progress, now: date, mood: mood, turn: turn)
        case .shopWindow: state.dialogue = VillageTalk.shopkeeper(progress: progress, now: date, turn: turn)
        case .mailbox: state.dialogue = VillageTalk.mailbox(progress: progress, now: date)
        case .signpost: state.dialogue = VillageTalk.signpost(progress: progress, now: date)
        case .crates: state.dialogue = VillageTalk.crates(progress: progress)
        case .woodpile: state.dialogue = fuel.map { VillageTalk.woodpile($0, now: date) }
        case .pickup:
            let name = onPickup()
            state.dialogue = Dialogue(name: "풀밭", pages: [name.map { "\($0)(을|를) 주웠습니다".resolvedParticles } ?? "아무것도 없습니다"])
        }
    }

    private func handleAction(_ action: Dialogue.Action?) {
        guard let action else { return }
        state.pendingAction = nil
        if action == .recommend {
            state.dialogue = Dialogue(name: "손님", pages: [onRecommend() ?? "오늘은 그만 권하는 게 좋겠습니다"])
        }
    }

    private func handleTap(at location: CGPoint, scale: CGFloat, tile: CGFloat) {
        guard location.y < CGFloat(VillageMap.height) * scale, location.x >= 0 else { return }
        if state.dialogue != nil { state.press(.enter); return }
        let col = Int(location.x / tile), row = Int(location.y / tile)
        // 벽의 창문·우체통·상자·진열창이면 그 앞까지 가서 본다. 나머지 건물 자리는 바로 들어간다.
        if !(row == 3 && state.thing(at: col, row) != nil),
           let building = VillageBuilding.allCases.first(where: { ($0.left...($0.left + 3)).contains(col) && (max(0, $0.top - 1)...($0.top + 2)).contains(row) }) {
            state.stand(at: building)
            onEnter(building)
            return
        }
        state.walk(toward: col, row)
    }

    /// 날씨 겹. 안개는 흰 띠가 천천히 흐르고 위쪽이 뿌옇고, 흐림은 가라앉은 위로 구름 그림자가 지나가고, 폭풍은 어둡다가 번개가 치고, 더위는 아지랑이처럼 누런 빛이 돈다.
    @ViewBuilder
    private func weatherLayer(_ weather: Weather) -> some View {
        let w = CGFloat(VillageMap.width) * VillageMap.scale, h = CGFloat(VillageMap.height) * VillageMap.scale
        TimelineView(.periodic(from: .now, by: animated ? 0.5 : 3600)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate * 2)
            let drift = animated ? CGFloat(tick % 60) / 60 : 0.3
            ZStack(alignment: .topLeading) {
                switch weather {
                case .fog:
                    LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.18), .white.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                    ForEach(0..<3, id: \.self) { i in
                        Capsule().fill(Color.white.opacity(0.28))
                            .frame(width: w * 0.7, height: 22)
                            .blur(radius: 10)
                            .offset(x: -w * 0.4 + w * 1.1 * ((drift + CGFloat(i) * 0.37).truncatingRemainder(dividingBy: 1)), y: 30 + CGFloat(i) * 52)
                    }
                case .cloudy:
                    Color.black.opacity(0.1)
                    ForEach(0..<2, id: \.self) { i in
                        Ellipse().fill(Color.black.opacity(0.14))
                            .frame(width: w * 0.5, height: 70)
                            .blur(radius: 14)
                            .offset(x: -w * 0.3 + w * 1.3 * ((drift + CGFloat(i) * 0.5).truncatingRemainder(dividingBy: 1)), y: 20 + CGFloat(i) * 80)
                    }
                case .storm:
                    Color.black.opacity(0.22)
                    Color.white.opacity(animated && tick % 17 == 0 ? 0.75 : 0)
                        .animation(.easeOut(duration: 0.45), value: tick)
                case .heat:
                    LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.4).opacity(0.18), .clear], startPoint: .top, endPoint: .center)
                default:
                    EmptyView()
                }
            }
            .frame(width: w, height: h)
            .clipped()
            .allowsHitTesting(false)
        }
    }

    /// 사람 하나. 발밑 그림자와 함께 타일 자리에.
    private func sprite(_ rows: [String], palette: [Character: Color], x: Double, y: Double, dark: Bool, umbrella: Color? = nil) -> some View {
        let tile = CGFloat(VillageMap.tile) * VillageMap.scale
        return ZStack {
            Ellipse().fill(Color.black.opacity(dark ? 0.35 : 0.22)).frame(width: tile * 0.7, height: tile * 0.28).offset(y: tile * 0.36)
            PixelFrame(rows: rows, scale: VillageMap.scale, palette: shade(palette, dark: dark))
            if let umbrella {
                PixelFrame(rows: VillageTiles.umbrella, scale: VillageMap.scale,
                           palette: shade(["x": Color(red: 0.2, green: 0.2, blue: 0.23), "U": umbrella], dark: dark))
                    .offset(x: 2, y: -tile * 0.62)
            }
        }
        .position(x: (CGFloat(x) * tile + tile / 2).rounded(), y: (CGFloat(y) * tile + tile / 2 - 4).rounded())
    }

    /// 서점 앞 손님 수. 재고가 있으면 한 사람, 좋은 사건·광고마다 한 사람씩 더(넷까지). 품절이면 돌아서는 한 사람.
    private var customerCount: (count: Int, leaving: Bool) {
        if !progress.shop.reprints.isEmpty && progress.books(in: .window).isEmpty && progress.books(in: .counter).isEmpty { return (1, true) }
        let stocked = !progress.books(in: .window).isEmpty || !progress.books(in: .counter).isEmpty || !progress.books(in: .shelf).isEmpty
        guard stocked else { return (0, false) }
        let n = min(4, 1 + progress.shopBoosts.filter { $0.value > 1 }.count + progress.ads.count)
        // 더운 날은 손님이 덜 온다.
        return (progress.weather == .heat ? max(1, n - 1) : n, false)
    }

    /// 작업실 위 말풍선. 돌발 상황이면 그 아이콘, 3분 안의 재해면 주황 아이콘.
    private var bubble: (icon: [String], color: Color)? {
        if let event = progress.event { return (event.icon, .black) }
        if let disaster = progress.recentDisaster(within: 180), let kind = Disasters.byID(disaster.event) { return (kind.icon, .orange) }
        return nil
    }

    /// 밤이면 손님도 어둡게.
    private func shade(_ palette: [Character: Color], dark: Bool) -> [Character: Color] {
        guard dark else { return palette }
        return palette.reduce(into: [:]) { result, pair in
            let c = NSColor(pair.value).usingColorSpace(.deviceRGB) ?? .gray
            result[pair.key] = Color(red: c.redComponent * 0.3 + 0.03, green: c.greenComponent * 0.36 + 0.05, blue: c.blueComponent * 0.55 + 0.18)
        }
    }

    /// 클릭하면 무슨 일이 나는 자리. 건물, 사람, 물건.
    private func clickable(col: Int, row: Int) -> Bool {
        if state.thing(at: col, row) != nil { return true }
        return VillageBuilding.allCases.contains { ($0.left...($0.left + 3)).contains(col) && (max(0, $0.top - 1)...($0.top + 2)).contains(row) }
    }

    /// 맵 아래 조작 안내. 지금 할 수 있는 일은 머리 위 표시가 맡고, 여기는 기본 조작만.
    private var help: (line: String, more: String?, close: String) {
        let close = state.dialogue == nil ? "Esc 닫기" : "Esc 대화 닫기"
        if let dialogue = state.dialogue {
            if !dialogue.isLast { return ("Return 이나 클릭으로 다음 말을 봅니다.", nil, close) }
            if !dialogue.options.isEmpty { return ("← → 로 고르고, Return 으로 정합니다.", nil, close) }
            return ("Return 이나 클릭으로 대화를 마칩니다.", nil, close)
        }
        return ("방향키나 클릭으로 걷고, 머리 위에 뜬 일은 Return 으로 합니다.", nil, close)
    }

    /// 머리 위에 띄울 행동. 앞에 선 것이 있으면 그 일, 문 앞이면 들어가기.
    private var actionPrompt: (symbol: String, label: String)? {
        if let target = state.target ?? state.nearby?.1 {
            return switch target {
            case .npc: ("bubble.left", "말 걸기")
            case .window: ("hand.tap", "창문 두드리기")
            case .mailbox: ("envelope", "우체통 열기")
            case .signpost: ("signpost.right", "팻말 읽기")
            case .crates: ("shippingbox", "상자 보기")
            case .shopWindow: ("storefront", "진열창 보기")
            case .pickup: ("sparkles", "줍기")
            case .woodpile: ("flame", "장작 보기")
            }
        }
        if VillageMap.door(col: state.col, row: state.row) != nil { return ("door.left.hand.open", "들어가기") }
        return nil
    }
}

/// 머리 위 행동 표시. 검은 작은 상자에 아이콘과 짧은 말, 아래로 꼬리. 0.5초마다 살짝 오르내린다.
struct ActionPrompt: View {
    let symbol: String
    let label: String
    var animated = true
    /// 꼬리를 위로. 머리 아래에 둘 때.
    var tailUp = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: animated ? 0.5 : 3600)) { context in
            let up = animated && Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            let ink = Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.92)
            VStack(spacing: 0) {
                if tailUp { Triangle().fill(ink).frame(width: 7, height: 4).rotationEffect(.degrees(180)) }
                HStack(spacing: 4) {
                    Symbol(name: symbol, size: 9, color: .white)
                    Text(label).font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("⏎").font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(ink, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.35), lineWidth: 1))
                if !tailUp { Triangle().fill(ink).frame(width: 7, height: 4) }
            }
            .fixedSize()
            .offset(y: up ? -1 : 1)
        }
    }
}

/// 팝오버 창의 키 입력을 받는다. 이 뷰가 든 창에서 난 키만 본다.
struct KeyCatcher: NSViewRepresentable {
    /// 키와 눌렀는지(true)·뗐는지(false). 받았으면 true 를 돌려준다.
    var onKey: @MainActor (VillageState.Key, Bool) -> Bool
    /// 마을이 열려 있을 때만 Space 와 WASD 를 받는다. 닫혀 있을 때는 글자 입력을 건드리지 않는다.
    var gameKeys = false

    func makeNSView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.onKey = onKey
        view.gameKeys = gameKeys
        return view
    }

    func updateNSView(_ view: KeyCatcherView, context: Context) {
        view.onKey = onKey
        view.gameKeys = gameKeys
    }

    final class KeyCatcherView: NSView {
        var onKey: (@MainActor (VillageState.Key, Bool) -> Bool)?
        var gameKeys = false
        private var monitor: Any?

        /// 창에서 떨어지면 모니터를 뗀다. deinit 에서는 못 떼니 여기서.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
                guard let self, event.window === self.window else { return event }
                // 자동 반복은 쓰지 않는다. 누르고 있는 동안은 걷기 루프가 알아서 간다.
                if event.type == .keyDown, event.isARepeat { return nil }
                let down = event.type == .keyDown
                let key: VillageState.Key
                switch event.keyCode {
                case 126: key = .up
                case 125: key = .down
                case 123: key = .left
                case 124: key = .right
                case 36, 76: key = .enter
                case 53: key = .escape
                case 49, 13, 0, 1, 2:
                    guard self.gameKeys, event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
                    key = switch event.keyCode {
                    case 13: .up
                    case 0: .left
                    case 1: .down
                    case 2: .right
                    default: .enter
                    }
                default: return event
                }
                let handled = MainActor.assumeIsolated { self.onKey?(key, down) ?? false }
                return handled ? nil : event
            }
        }
    }
}

/// 말풍선 꼬리.
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// 게임의 글상자. 흰 바탕에 검은 테두리, 이름표, 두 줄 글, 더 있으면 ▼, 선택지는 ▶ 로 고른다.
struct DialogueBox: View {
    let dialogue: Dialogue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dialogue.name)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .foregroundStyle(.white)
                .background(Color(red: 0.2, green: 0.2, blue: 0.23), in: RoundedRectangle(cornerRadius: 3))
            Text(dialogue.pages[min(dialogue.page, dialogue.pages.count - 1)])
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 14) {
                if dialogue.isLast, !dialogue.options.isEmpty {
                    ForEach(Array(dialogue.options.enumerated()), id: \.offset) { i, option in
                        Text((i == dialogue.selected ? "▶ " : "   ") + option.label)
                            .font(.system(size: 10, weight: i == dialogue.selected ? .bold : .regular, design: .rounded))
                            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))
                    }
                }
                Spacer(minLength: 0)
                if !dialogue.isLast { Text("▼").font(.system(size: 8)).foregroundStyle(.secondary) }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(red: 0.2, green: 0.2, blue: 0.23), lineWidth: 2))
    }
}
