import AppKit
import Charts
import SwiftUI

// MARK: - 시간대별

struct HourlyChart: View {
    let hours: [Int]
    let now: Date
    @State private var selected: Int?

    var body: some View {
        let current = Calendar.current.component(.hour, from: now)
        let peak = hours.enumerated().max { $0.element < $1.element }
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "오늘 시간대별",
                         detail: selected.map { "\($0)시 · \(Format.tokens(hours[$0]))" }
                            ?? peak.map { $0.element > 0 ? "가장 많이 쓴 때 \($0.offset)시 · \(Format.tokens($0.element))" : "" },
                         highlighted: selected != nil)
            Chart {
                ForEach(Array(hours.enumerated()), id: \.offset) { hour, tokens in
                    // 숫자 x 축이라 막대 폭을 비율로 주면 그려지지 않는다. 포인트로 준다.
                    BarMark(x: .value("시", hour), y: .value("토큰", tokens), width: .fixed(9))
                        .foregroundStyle(ChartPalette.magnitude.opacity(hour == current || hour == selected ? 1 : 0.55))
                        .cornerRadius(3)
                }
            }
            .chartXScale(domain: -0.5...23.5)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18]) { value in
                    AxisValueLabel { if let h = value.as(Int.self) { Text("\(h)시") } }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                    AxisValueLabel { if let n = value.as(Int.self) { Text(Format.tokens(n)) } }
                }
            }
            .chartOverlay { proxy in
                HoverReader(proxy: proxy) { x in
                    selected = x.flatMap { (proxy.value(atX: $0) as Double?).map { Int($0.rounded()) } }
                        .flatMap { (0..<24).contains($0) ? $0 : nil }
                }
            }
            .frame(height: 110)
        }
    }
}

// MARK: - 일별

struct DailyChart: View {
    let days: [DayUsage]
    @State private var selected: Date?

    var body: some View {
        let past = days.dropLast().filter { $0.tokens > 0 }
        let average = past.isEmpty ? 0 : past.reduce(0) { $0 + $1.tokens } / past.count
        let pick = selected.flatMap { s in days.first { Calendar.current.isDate($0.day, inSameDayAs: s) } }
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "최근 14일",
                         detail: pick.map {
                             "\($0.day.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated))) · \(Format.tokens($0.tokens)) · \(Format.cost($0.cost))"
                         } ?? (average > 0 ? "평균 \(Format.tokens(average))" : nil),
                         highlighted: pick != nil)
            Chart {
                ForEach(days) { day in
                    let isToday = Calendar.current.isDateInToday(day.day)
                    let isPicked = pick?.day == day.day
                    BarMark(x: .value("날짜", day.day, unit: .day), y: .value("토큰", day.tokens), width: .ratio(0.7))
                        .foregroundStyle(ChartPalette.magnitude.opacity(isToday || isPicked ? 1 : 0.55))
                        .cornerRadius(3)
                }
                if average > 0 {
                    RuleMark(y: .value("평균", average))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                    AxisValueLabel { if let n = value.as(Int.self) { Text(Format.tokens(n)) } }
                }
            }
            .chartOverlay { proxy in
                HoverReader(proxy: proxy) { x in
                    selected = x.flatMap { proxy.value(atX: $0) as Date? }
                }
            }
            .frame(height: 120)
        }
    }
}

/// 차트 위에서 마우스가 움직이면 x 위치를, 벗어나면 nil 을 준다.
private struct HoverReader: View {
    let proxy: ChartProxy
    let onChange: (CGFloat?) -> Void

    var body: some View {
        GeometryReader { geo in
            Rectangle().fill(.clear).contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point):
                        guard let frame = proxy.plotFrame.map({ geo[$0] }) else { return onChange(nil) }
                        onChange(point.x - frame.origin.x)
                    case .ended:
                        onChange(nil)
                    }
                }
        }
    }
}

// MARK: - 모델과 토큰 종류

struct ModelBreakdown: View {
    let models: [ModelUsage]

    private struct Slice: Identifiable {
        let id: String
        let name: String
        let tokens: Int
        let color: Color
        var cost: Double?
        var detail: String?
    }

    var body: some View {
        let total = max(1, models.reduce(0) { $0 + $1.tokens })
        // 범주 색은 3개까지. 나머지는 "기타"로 묶는다.
        let top = models.prefix(3).enumerated().map { i, m in
            Slice(id: m.model, name: displayModelName(m.model), tokens: m.tokens, color: ChartPalette.series[i],
                  cost: m.cost, detail: m.model)
        }
        let rest = models.dropFirst(3)
        let slices = top + (rest.isEmpty ? [] : [Slice(
            id: "other", name: L10n.tr("기타 \(rest.count)개"), tokens: rest.reduce(0) { $0 + $1.tokens }, color: ChartPalette.other,
            cost: rest.reduce(0.0) { $0 + ($1.cost ?? 0) }, detail: rest.map(\.model).joined(separator: ", "))])
        let kinds = [
            Slice(id: "input", name: L10n.tr("입력"), tokens: models.reduce(0) { $0 + $1.input }, color: ChartPalette.series[0]),
            Slice(id: "output", name: L10n.tr("출력"), tokens: models.reduce(0) { $0 + $1.output }, color: ChartPalette.series[1]),
            Slice(id: "write", name: L10n.tr("캐시 쓰기"), tokens: models.reduce(0) { $0 + $1.cacheWrite }, color: ChartPalette.series[2]),
            Slice(id: "read", name: L10n.tr("캐시 읽기"), tokens: models.reduce(0) { $0 + $1.cacheRead }, color: ChartPalette.series[3]),
        ]
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "오늘 모델별")
                if models.isEmpty {
                    Text("오늘 기록이 없습니다.").font(.caption).foregroundStyle(.secondary)
                } else {
                    StackedBar(slices: slices.map { ($0.tokens, $0.color) })
                    ForEach(slices) { slice in
                        legendRow(slice, total: total, trailing: slice.cost.map(Format.cost) ?? L10n.tr("단가 없음"))
                            .hint(slice.name, [slice.detail ?? "", "토큰 \(Format.integer(slice.tokens))개 · \(Self.share(slice.tokens, of: total))"]
                                  + (slice.cost.map { ["API 단가로 \(Format.cost($0))"] } ?? ["단가표에 없는 모델이라 비용은 모릅니다."]), symbol: "cpu")
                    }
                }
            }
            .dashboardCard()
            if !models.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(text: "오늘 토큰 종류")
                    StackedBar(slices: kinds.map { ($0.tokens, $0.color) })
                    ForEach(kinds) { kind in
                        legendRow(kind, total: total, trailing: nil)
                            .hint(kind.name, [Self.kindExplanation[kind.id] ?? "", "토큰 \(Format.integer(kind.tokens))개 · \(Self.share(kind.tokens, of: total))"], symbol: "doc.text")
                    }
                }
                .dashboardCard()
            }
        }
    }

    private static let kindExplanation = [
        "input": "프롬프트로 보낸 토큰입니다. 작가가 읽는 양으로 쳐서 영감 게이지에 쌓입니다.",
        "output": "답으로 받은 토큰입니다.",
        "write": "캐시에 저장한 토큰입니다. 단가는 입력의 1.25~2배. 영감 게이지에 쌓입니다.",
        "read": "캐시에서 읽은 토큰입니다. 단가는 입력의 10분의 1. 영감 게이지에 쌓입니다.",
    ]

    /// 0.1% 아래는 0% 대신 "0.1% 미만"으로.
    private static func share(_ part: Int, of total: Int) -> String {
        let p = Double(part) / Double(total) * 100
        return part > 0 && p < 0.1 ? L10n.tr("0.1% 미만") : Format.percent((p * 10).rounded() / 10)
    }

    private func legendRow(_ slice: Slice, total: Int, trailing: String?) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(slice.color).frame(width: 9, height: 9)
            Text(slice.name).font(.callout).lineLimit(1)
            Spacer()
            Text(Self.share(slice.tokens, of: total))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Text(Format.tokens(slice.tokens)).font(.callout.monospacedDigit())
                .frame(width: 64, alignment: .trailing)
            if let trailing {
                Text(trailing).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .trailing)
            }
        }
    }
}

/// 가로 누적 막대. 조각 사이에 2pt 틈을 둔다.
struct StackedBar: View {
    let slices: [(Int, Color)]

    var body: some View {
        let total = max(1, slices.reduce(0) { $0 + $1.0 })
        let visible = slices.filter { $0.0 > 0 }
        GeometryReader { geo in
            let gaps = CGFloat(max(0, visible.count - 1)) * 2
            HStack(spacing: 2) {
                ForEach(Array(visible.enumerated()), id: \.offset) { _, slice in
                    Rectangle().fill(slice.1)
                        .frame(width: max(2, (geo.size.width - gaps) * CGFloat(slice.0) / CGFloat(total)))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .frame(height: 10)
    }
}

// MARK: - 팝오버 요약 줄

/// 팝오버 하단의 사용자(후원자) 구역. 사용자의 후원 칭호·3칸 훈장 진열대와 오늘 토큰 사용량을 함께 보여 준다.
struct UsageSummaryRow: View {
    @Bindable var store: UsageStore
    var onBadges: () -> Void = {}
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let writing = store.writing, writing.patronTitle != nil || !writing.equippedBadges.isEmpty {
                patronIdentityBar(writing)
            }
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.agentSource.summaryTitle).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        if let today = store.snapshot?.today {
                            Text("오늘 \(Format.tokens(today.tokens)) · \(Format.cost(today.cost))")
                                .font(.callout.weight(.medium).monospacedDigit())
                        }
                    }
                    Spacer()
                    if store.agentSource == .antigravity {
                        if let snapshot = store.snapshot, snapshot.today.tokens > 0 {
                            miniCacheGauge(snapshot.todayCacheHitPercent)
                        }
                    } else {
                        ForEach(store.limits.prefix(3)) { row in
                            miniGauge(row)
                        }
                        if store.limitsMessage != nil {
                            Symbol(name: store.needsLogin ? "person.crop.circle.badge.exclamationmark" : "exclamationmark.triangle", size: 12,
                                   color: store.needsLogin ? .secondary : ChartPalette.warning)
                                .hint(store.needsLogin ? "로그인이 만료됐습니다" : "한도를 못 읽었습니다",
                                      store.needsLogin ? ["Claude Code 를 한 번 쓰면 이어집니다. 다음 갱신 때 저절로 다시 읽습니다."] : [store.limitsMessage ?? ""],
                                      symbol: store.needsLogin ? "person.crop.circle.badge.exclamationmark" : "exclamationmark.triangle")
                        }
                    }
                    Text("›").font(.callout).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func patronIdentityBar(_ writing: WritingProgress) -> some View {
        let equipped = writing.equippedBadges.compactMap { Achievements.byID($0) }
        let patron = writing.patronAchievement
        let titleText = patron?.patronTitle ?? L10n.tr("익명의 후원인")
        var hintLines: [String] = []
        if let patron {
            hintLines.append("\"\(patron.patronTitle ?? "")\" (\(patron.title) 달성 보상)")
        }
        if equipped.isEmpty {
            hintLines.append("성과 화면에서 받은 뱃지를 최대 3개까지 훈장 진열대에 장식해 추가 효과를 얻을 수 있습니다.")
        } else {
            for badge in equipped {
                hintLines.append("진열: \(badge.title) (\(badge.slotPerk.shortText))")
            }
        }
        hintLines.append("누르면 나의 후원자 칭호와 훈장 진열대를 변경합니다.")
        return Button(action: onBadges) {
            HStack(spacing: 7) {
                Symbol(name: "seal.fill", size: 10, color: patron?.tier.color ?? BadgeTier.gold.color)
                Text("나의 후원 칭호")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(titleText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    ForEach(0..<Perks.maxEquipped, id: \.self) { index in
                        if index < equipped.count {
                            BadgeMedal(achievement: equipped[index], unlocked: true, size: 15)
                        } else {
                            Circle()
                                .strokeBorder(Color.secondary.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                .frame(width: 13, height: 13)
                        }
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .hint("나의 후원 칭호 · \(titleText)", hintLines, symbol: "seal")
    }

    private func miniCacheGauge(_ percent: Double) -> some View {
        let clamped = min(max(percent, 0.5), 100)
        return ZStack {
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 3)
            Circle().trim(from: 0, to: CGFloat(clamped / 100))
                .stroke(ChartPalette.series[0], style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(percent.rounded()))").font(.system(size: 9, weight: .semibold).monospacedDigit())
        }
        .frame(width: 26, height: 26)
        .hint("캐시 읽기 \(Format.percent(percent))", ["오늘 입력 토큰 가운데 캐시에서 읽은 비율입니다."], symbol: "bolt.circle")
    }

    private func miniGauge(_ row: LimitRow) -> some View {
        let (color, status) = ChartPalette.limitStatus(row.percent)
        return ZStack {
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 3)
            Circle().trim(from: 0, to: CGFloat(min(max(row.percent, 0.5), 100) / 100))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(row.percent.rounded()))").font(.system(size: 9, weight: .semibold).monospacedDigit())
        }
        .frame(width: 26, height: 26)
        .hint("\(row.displayName) \(Format.percent(row.percent))", [status], symbol: "gauge.with.needle")
    }
}
