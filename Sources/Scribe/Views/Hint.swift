import SwiftUI

// 힌트 카드. 마우스를 올리면 잠시 뒤 제목과 설명 몇 줄이 든 작은 카드가 그 자리 위(자리가 없으면 아래)에 뜬다.
// macOS 의 `.help` 는 한 줄 글자뿐이라, 창 안에서 직접 그린다. 창 맨 위 뷰에 `.hintHost()` 를 한 번 붙이고,
// 힌트를 달 뷰에 `.hint(title, lines)` 를 붙인다. 상시 창처럼 작은 창에는 쓰지 않는다.

struct Hint: Equatable {
    var title: String
    var lines: [String] = []
    /// SF Symbol 이름. 제목 옆에 작게.
    var symbol: String?
}

/// 지금 보여 달라는 힌트와 그 자리.
struct HintRequest {
    let hint: Hint
    let anchor: Anchor<CGRect>
}

struct HintPreferenceKey: PreferenceKey {
    static let defaultValue: HintRequest? = nil
    static func reduce(value: inout HintRequest?, nextValue: () -> HintRequest?) {
        if let next = nextValue() { value = next }
    }
}

/// 마우스를 올린 뒤 0.65초 지나면 힌트를 올린다.
private struct HintModifier: ViewModifier {
    let hint: Hint
    @State private var hovering = false
    @State private var showing = false
    @State private var delay: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                hovering = inside
                delay?.cancel()
                if inside {
                    delay = Task {
                        try? await Task.sleep(for: .milliseconds(650))
                        if !Task.isCancelled, hovering { showing = true }
                    }
                } else {
                    showing = false
                }
            }
            // 힌트가 겹쳐 있으면(머리 전체와 그 안의 날씨처럼) 안쪽 것이 이긴다. 안쪽 값이 이미 있으면 덮어쓰지 않는다.
            .transformAnchorPreference(key: HintPreferenceKey.self, value: .bounds) { value, anchor in
                if value == nil, showing { value = HintRequest(hint: hint, anchor: anchor) }
            }
    }
}

/// 힌트 카드를 그린다. 창 맨 위 뷰에 붙인다.
private struct HintHostModifier: ViewModifier {
    @State private var cardSize = CGSize(width: 240, height: 60)

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(HintPreferenceKey.self) { request in
            GeometryReader { geo in
                if let request {
                    let rect = geo[request.anchor]
                    let above = rect.minY - cardSize.height - 8 >= 0
                    let y = above ? rect.minY - cardSize.height - 6 : rect.maxY + 6
                    let x = min(max(8, rect.midX - cardSize.width / 2), max(8, geo.size.width - cardSize.width - 8))
                    HintCard(hint: request.hint)
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { cardSize = $0 }
                        .offset(x: x, y: y)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.12), value: request?.hint)
        }
    }
}

struct HintCard: View {
    let hint: Hint

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let symbol = hint.symbol {
                    Image(systemName: symbol).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                }
                Text(hint.title).font(.caption.weight(.semibold))
            }
            ForEach(Array(hint.lines.enumerated()), id: \.offset) { _, line in
                Text(line).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(width: 240, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.primary.opacity(0.1)))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }
}

extension View {
    /// 힌트 카드. `lines` 는 설명 몇 줄.
    func hint(_ title: String, _ lines: [String] = [], symbol: String? = nil) -> some View {
        modifier(HintModifier(hint: Hint(title: title, lines: lines, symbol: symbol)))
    }

    func hint(_ hint: Hint) -> some View { modifier(HintModifier(hint: hint)) }

    /// 힌트 카드를 그릴 자리. 창 맨 위 뷰에 한 번.
    func hintHost() -> some View { modifier(HintHostModifier()) }
}

/// 확인용 그림(`ImageRenderer`)을 그리는 중인지. AppKit 버튼과 메뉴는 그려지지 않아(노란 자리표시가 남는다) 글자 알약으로 바꿔 그린다.
enum RenderMode {
    nonisolated(unsafe) static var offscreen = false
}

/// 확인용 그림에서 버튼 자리에 그리는 글자 알약.
struct ChipLabel: View {
    let title: String
    var prominent = false

    var body: some View {
        Text(title).font(.caption.weight(.medium))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(prominent ? ChartPalette.series[0] : Color.secondary.opacity(0.12), in: Capsule())
    }
}

/// 차분한 선 아이콘. 날씨·마감·영감·설정 같은 화면 요소에 쓴다(작품·돌발 상황 그림은 픽셀 그대로).
struct Symbol: View {
    let name: String
    var size: CGFloat = 12
    var color: Color = .secondary
    var weight: Font.Weight = .medium

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
            .frame(width: size + 4, height: size + 4)
    }
}

/// 한 줄에 다 안 들어가는 글을 천천히 옆으로 옮겨 보여 준다. 2초 멈췄다가 끝까지 밀고, 2초 멈췄다가 돌아온다.
/// 들어가면 그대로 둔다. 글 너비는 상태 없이 글꼴로 바로 재서, 그림을 그릴 때도 첫 프레임이 맞다.
struct MarqueeText: View {
    let text: String
    var size: CGFloat = 10
    var color: Color = .secondary
    var animated = true

    private static let speed: Double = 28  // pt/s
    private static let pause: Double = 2

    var body: some View {
        let font = NSFont.systemFont(ofSize: size)
        let textWidth = ceil(NSAttributedString(string: text, attributes: [.font: font]).size().width) + 1
        GeometryReader { geo in
            let overflow = max(0, textWidth - geo.size.width)
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !animated || overflow <= 0)) { context in
                let shift = offset(at: context.date.timeIntervalSinceReferenceDate, overflow: overflow)
                Text(text).font(.system(size: size)).foregroundStyle(color).lineLimit(1).fixedSize()
                    .offset(x: -shift)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
                    .clipped()
                    // 잘린 쪽 끝을 살짝 흐려 더 있다는 것을 보여 준다.
                    .mask(
                        HStack(spacing: 0) {
                            if shift > 0.5 { LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 12) }
                            Color.black
                            if overflow - shift > 0.5 { LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 14) }
                        }
                    )
            }
        }
        .frame(height: ceil(font.ascender - font.descender + font.leading) + 2)
    }

    private func offset(at t: TimeInterval, overflow: CGFloat) -> CGFloat {
        guard overflow > 0 else { return 0 }
        let travel = Double(overflow) / Self.speed
        let period = Self.pause * 2 + travel * 2
        let p = t.truncatingRemainder(dividingBy: period)
        if p < Self.pause { return 0 }
        if p < Self.pause + travel { return CGFloat((p - Self.pause) * Self.speed) }
        if p < Self.pause * 2 + travel { return overflow }
        return overflow - CGFloat((p - Self.pause * 2 - travel) * Self.speed)
    }
}
