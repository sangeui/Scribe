import AppKit
import Charts
import SwiftUI

// 팝오버 옆에 여는 Claude 사용량 화면. 오늘 합계, 한도, 시간대별·일별 추이, 모델과 토큰 종류.
// 색은 dataviz 스킬의 기본 팔레트를 따른다. 범주 색은 정해진 순서로만 쓰고(3개 넘는 모델은 "기타"),
// 크기는 파란색 하나, 한도는 상태 색(여유·주의·위험)에 글자 표시를 함께 붙인다.

/// 밝은·어두운 모드에서 따로 고른 색.
enum ChartPalette {
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
                           blue: CGFloat(hex & 0xff) / 255, alpha: 1)
        })
    }

    /// 범주 1~4번: 만년필 블루블랙(슬레이트), 테라코타(시나몬), 세이지(고서 초록), 앤티크 황동(오커).
    static let series = [
        dynamic(0x4a6278, 0x6c879e),
        dynamic(0x9e5b45, 0xb8745d),
        dynamic(0x4e6b58, 0x6b8c76),
        dynamic(0x9a7838, 0xb89452),
    ]
    /// "기타"는 범주 색이 아닌 회색.
    static let other = dynamic(0x9c9992, 0x6b6965)
    static let magnitude = series[0]

    static let good = dynamic(0x4e6b58, 0x6b8c76)
    static let warning = dynamic(0xa67332, 0xc28d48)
    static let critical = dynamic(0x9e423d, 0xba5a54)
    static let rose = dynamic(0x8c4f4f, 0xa86868)

    /// 한도 %에 따른 상태 색과 이름. 색만으로 뜻을 전하지 않게 이름을 같이 쓴다.
    static func limitStatus(_ percent: Double) -> (Color, String) {
        percent >= 90 ? (critical, L10n.tr("위험")) : percent >= 70 ? (warning, L10n.tr("주의")) : (good, L10n.tr("여유"))
    }
}

/// `claude-opus-5-5` → `Opus 5.5`, 날짜 꼬리(`-20260101`)는 뗀다. 공백이 있는 표시 이름(`Gemini 4 Argon (High)`)은 그대로 쓴다.
func displayModelName(_ id: String) -> String {
    if id.contains(" ") { return id }
    var parts = id.split(separator: "-").map(String.init)
    if parts.first == "claude" { parts.removeFirst() }
    if let last = parts.last, last.count == 8, last.allSatisfy(\.isNumber) { parts.removeLast() }
    guard let name = parts.first else { return id }
    if name.lowercased() == "gemini" {
        let rest = parts.dropFirst().map { part -> String in
            part.allSatisfy({ $0.isNumber || $0 == "." }) ? part : (part.prefix(1).uppercased() + part.dropFirst())
        }.joined(separator: " ")
        return "Gemini" + (rest.isEmpty ? "" : " " + rest)
    }
    let version = parts.dropFirst().joined(separator: ".")
    return name.prefix(1).uppercased() + name.dropFirst() + (version.isEmpty ? "" : " " + version)
}

struct UsageDashboard: View {
    @Bindable var store: UsageStore
    /// 확인용 그림(`--snapshot`)은 `ScrollView` 를 못 그려서 끈다.
    var scrollable = true

    var body: some View {
        if scrollable {
            ScrollView { content }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            TodayHero(snapshot: store.snapshot, source: store.agentSource, plan: store.plan).dashboardCard()
            switch store.agentSource {
            case .antigravity:
                AntigravityStatusCard(snapshot: store.snapshot, writing: store.writing).dashboardCard()
            case .claude:
                LimitGauges(limits: store.limits, message: store.limitsMessage, needsLogin: store.needsLogin, updatedAt: store.limitsUpdatedAt,
                            refreshing: store.isRefreshing) { Task { await store.refreshNow() } }
                    .dashboardCard()
            case .all:
                if let snapshot = store.snapshot {
                    AgentShareCard(snapshot: snapshot).dashboardCard()
                }
                if !store.limits.isEmpty || store.limitsMessage != nil {
                    LimitGauges(limits: store.limits, message: store.limitsMessage, needsLogin: store.needsLogin, updatedAt: store.limitsUpdatedAt,
                                refreshing: store.isRefreshing) { Task { await store.refreshNow() } }
                        .dashboardCard()
                }
            }
            if let snapshot = store.snapshot {
                UsageInsightsCard(snapshot: snapshot).dashboardCard()
                HourlyChart(hours: snapshot.todayByHour, now: snapshot.generatedAt).dashboardCard()
                DailyChart(days: Array(snapshot.days.suffix(14))).dashboardCard()
                ModelBreakdown(models: snapshot.todayByModel)
            }
        }
        .padding(14)
    }
}

/// 토큰 통계를 바탕으로 캐시 비용 절감액, 대화 문맥 밀도, 14일 작업 리듬·주간 추세 인사이트를 요약해 보여 주는 카드.
private struct UsageInsightsCard: View {
    let snapshot: UsageSnapshot

    var body: some View {
        let hasAnyTokens = snapshot.days.contains { $0.tokens > 0 }
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "토큰 인사이트", detail: "최근 14일 분석")
            if !hasAnyTokens {
                Text("토큰 기록이 쌓이면 캐시 절감액·문맥 밀도·몰입 시간대 인사이트가 나타납니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                cacheInsightRow
                Divider().opacity(0.4)
                contextDensityRow
                Divider().opacity(0.4)
                rhythmAndTrendRow
            }
        }
    }

    private var cacheInsightRow: some View {
        let badge: String = {
            if snapshot.todayCacheSavedCost > 0 {
                return L10n.tr("오늘 \(Format.cost(snapshot.todayCacheSavedCost)) 절약 · -\(Format.percent(snapshot.todayCacheSavingsPercent))")
            }
            if snapshot.twoWeekCacheSavedCost > 0 {
                return L10n.tr("14일 \(Format.cost(snapshot.twoWeekCacheSavedCost)) 절약 · -\(Format.percent(snapshot.twoWeekCacheSavingsPercent))")
            }
            return L10n.tr("캐시 적중 \(Format.percent(snapshot.todayCacheHitPercent))")
        }()
        let subtitle: String = {
            if snapshot.todayCacheHitPercent >= 75 {
                return L10n.tr("캐시 적중률 \(Format.percent(snapshot.todayCacheHitPercent)) · 최근 14일 누적 \(Format.cost(snapshot.twoWeekCacheSavedCost)) 아낌")
            }
            if snapshot.today.tokens > 0 {
                return L10n.tr("캐시 적중률 \(Format.percent(snapshot.todayCacheHitPercent)) · 한 대화 흐름을 이어 가면 캐시 재사용률이 높아집니다")
            }
            return L10n.tr("최근 14일 캐시 읽기로 추정 API 원가의 \(Format.percent(snapshot.twoWeekCacheSavingsPercent))(\(Format.cost(snapshot.twoWeekCacheSavedCost)))를 아꼈습니다")
        }()
        return insightRow(
            symbol: "arrow.triangle.2.circlepath.circle",
            color: ChartPalette.series[2],
            title: L10n.tr("캐시 절감 효과"),
            badge: badge,
            subtitle: subtitle,
            hintTitle: L10n.tr("프롬프트 캐시 절감 추정액"),
            hintLines: [
                L10n.tr("캐시에서 읽은 토큰을 일반 입력 단가로 냈을 때와 비교해 아낀 금액입니다."),
                L10n.tr("오늘 절감: \(Format.cost(snapshot.todayCacheSavedCost)) · 최근 14일 절감: \(Format.cost(snapshot.twoWeekCacheSavedCost))")
            ]
        )
    }

    private var contextDensityRow: some View {
        let avg = snapshot.todayAvgTokensPerTurn
        let isHeavy = avg >= 150_000
        let badge: String = snapshot.todayTurns > 0
            ? L10n.tr("\(snapshot.todayTurns)턴 · 평균 \(Format.tokens(avg))")
            : L10n.tr("오늘 응답 없음")
        let subtitle: String = {
            if isHeavy {
                return L10n.tr("문맥 비대화 감지(최대 \(Format.tokens(snapshot.todayPeakTurnTokens))) · 새 대화나 /compact 로 문맥을 줄이면 유리합니다")
            }
            if snapshot.todayTurns > 0 {
                return L10n.tr("적정 문맥 크기 유지 중 · 단일 응답 최대 \(Format.tokens(snapshot.todayPeakTurnTokens))")
            }
            return L10n.tr("대화가 시작되면 응답당 평균 문맥 크기와 비대화 여부를 진단합니다")
        }()
        return insightRow(
            symbol: "text.bubble",
            color: isHeavy ? ChartPalette.warning : ChartPalette.series[0],
            title: L10n.tr("대화 문맥 밀도"),
            badge: badge,
            subtitle: subtitle,
            hintTitle: L10n.tr("턴당 평균 문맥 크기"),
            hintLines: [
                L10n.tr("대화가 길어질수록 매 응답마다 이전 대화 전체를 다시 읽어들여 턴당 토큰 소모가 커집니다."),
                L10n.tr("턴당 평균이 크게 치솟으면 주제가 바뀔 때 새 대화를 열거나 문맥을 압축하는 것이 효율적입니다.")
            ]
        )
    }

    private var rhythmAndTrendRow: some View {
        let focus = snapshot.focusWindow
        let badge = focus?.title ?? L10n.tr("집계 중")
        let subtitle: String = {
            if let focus, let wow = snapshot.weekOverWeekPercent {
                let sign = wow >= 0 ? "+" : ""
                return L10n.tr("주력 시간대 비중 \(Format.percent(focus.sharePercent))(피크 \(focus.peakHour)시) · 최근 7일 \(Format.tokens(snapshot.recentSevenDayTokens))(직전 주 \(sign)\(Int(wow.rounded()))%)")
            }
            if let focus {
                return L10n.tr("주력 시간대 비중 \(Format.percent(focus.sharePercent))(피크 \(focus.peakHour)시) · 최근 7일 누적 \(Format.tokens(snapshot.recentSevenDayTokens)) (\(Format.cost(snapshot.recentSevenDayCost)))")
            }
            return L10n.tr("최근 7일 누적 \(Format.tokens(snapshot.recentSevenDayTokens)) · \(Format.cost(snapshot.recentSevenDayCost))")
        }()
        return insightRow(
            symbol: "clock.arrow.2.circlepath",
            color: ChartPalette.series[3],
            title: L10n.tr("작업 리듬 · 추세"),
            badge: badge,
            subtitle: subtitle,
            hintTitle: L10n.tr("14일 몰입 시간대 및 주간 추세"),
            hintLines: [
                L10n.tr("최근 14일 시간대별 토큰 분포에서 가장 비중이 높은 6시간 구간과 피크 시각을 분석합니다."),
                L10n.tr("최근 7일 합계: \(Format.tokens(snapshot.recentSevenDayTokens)) (\(Format.cost(snapshot.recentSevenDayCost)))")
            ]
        )
    }

    private func insightRow(symbol: String, color: Color, title: String, badge: String, subtitle: String,
                            hintTitle: String, hintLines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Symbol(name: symbol, size: 11, color: color)
                Text(title).font(.caption.weight(.semibold))
                Spacer(minLength: 6)
                Text(badge)
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(color)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(color.opacity(0.12), in: Capsule())
            }
            Text(subtitle)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .hint(hintTitle, hintLines, symbol: symbol)
    }
}

/// Antigravity 전용 상태 카드. Claude 의 OAuth 한도 고리 대신 Antigravity 세션 현황(캐시 효율·영감 게이지·최근 5시간 토큰·대화 수)을 보여 준다.
private struct AntigravityStatusCard: View {
    let snapshot: UsageSnapshot?
    let writing: WritingProgress?

    var body: some View {
        let cacheHit = snapshot?.todayCacheHitPercent ?? 0
        let inspiration = (writing?.inspirationFraction ?? 0) * 100
        let fiveHour = snapshot?.recentFiveHourTokens ?? 0
        let files = snapshot?.filesByProvider[.antigravity] ?? snapshot?.scannedFiles ?? 0
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Antigravity 세션 현황", detail: "대화 \(files)개 감지")
            HStack(alignment: .top, spacing: 12) {
                metricRing(title: "캐시 효율", percent: cacheHit, subtitle: "입력 중 캐시 읽기", color: ChartPalette.series[2])
                    .frame(maxWidth: .infinity)
                metricRing(title: "영감 게이지", percent: inspiration, subtitle: writing?.inspirationReady == true ? "켜기 준비됨" : "읽기 토큰 누적", color: ChartPalette.series[3])
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("최근 5시간").font(.caption2).foregroundStyle(.secondary)
                        Text(Format.tokens(fiveHour))
                            .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 1) {
                        Text("읽는 경로").font(.caption2).foregroundStyle(.secondary)
                        Button {
                            let home = FileManager.default.homeDirectoryForCurrentUser
                            let brain = home.appendingPathComponent(".gemini/antigravity/brain")
                            let fallback = home.appendingPathComponent(".gemini")
                            NSWorkspace.shared.activateFileViewerSelecting([FileManager.default.fileExists(atPath: brain.path) ? brain : fallback])
                        } label: {
                            Text("~/.gemini/antigravity/brain")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .underline()
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func metricRing(title: String, percent: Double, subtitle: String, color: Color) -> some View {
        let clamped = min(max(percent, 0), 100)
        return VStack(spacing: 5) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: CGFloat(max(clamped, 0.5) / 100))
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(Format.percent(clamped))
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
            }
            .frame(width: 66, height: 66)
            Text(L10n.tr(title)).font(.caption.weight(.medium)).lineLimit(1)
            Text(L10n.tr(subtitle)).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}

/// 통합 모드일 때 에이전트별(Antigravity vs Claude Code) 오늘 토큰 비중을 보여 준다.
private struct AgentShareCard: View {
    let snapshot: UsageSnapshot

    var body: some View {
        let agyTokens = snapshot.todayByProvider[.antigravity] ?? 0
        let claudeTokens = snapshot.todayByProvider[.claude] ?? 0
        let total = max(1, agyTokens + claudeTokens)
        let agyCost = snapshot.todayCostByProvider[.antigravity] ?? 0
        let claudeCost = snapshot.todayCostByProvider[.claude] ?? 0
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "오늘 에이전트별 비중", detail: "합계 \(Format.tokens(agyTokens + claudeTokens))")
            StackedBar(slices: [
                (agyTokens, ChartPalette.series[0]),
                (claudeTokens, ChartPalette.series[1]),
            ])
            providerRow(name: "Antigravity · Gemini", tokens: agyTokens, cost: agyCost, total: total, color: ChartPalette.series[0],
                        files: snapshot.filesByProvider[.antigravity] ?? 0)
            providerRow(name: "Claude Code", tokens: claudeTokens, cost: claudeCost, total: total, color: ChartPalette.series[1],
                        files: snapshot.filesByProvider[.claude] ?? 0)
        }
    }

    private func providerRow(name: String, tokens: Int, cost: Double, total: Int, color: Color, files: Int) -> some View {
        let pct = tokens > 0 ? Format.percent((Double(tokens) / Double(total) * 1000).rounded() / 10) : "0%"
        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9)
            Text(name).font(.callout).lineLimit(1)
            Text("로그 \(files)개").font(.caption2).foregroundStyle(.tertiary)
            Spacer()
            Text(pct).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Text(Format.tokens(tokens)).font(.callout.monospacedDigit()).frame(width: 64, alignment: .trailing)
            Text(Format.cost(cost)).font(.callout.monospacedDigit()).foregroundStyle(.secondary).frame(width: 72, alignment: .trailing)
        }
    }
}

/// 섹션마다 둥근 카드에 담아 구분한다.
extension View {
    func dashboardCard() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.secondary.opacity(0.12)))
    }
}

/// 섹션 제목. 오른쪽 `detail` 은 평소엔 요약, 차트에 마우스를 올리면 그 막대의 값이다.
struct SectionTitle: View {
    let text: String
    var detail: String?
    /// 마우스로 고른 값이면 진하게.
    var highlighted = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.tr(text)).font(.subheadline.weight(.semibold))
            Spacer()
            if let detail {
                Text(L10n.tr(detail)).font(.caption.monospacedDigit())
                    .foregroundStyle(highlighted ? .primary : .secondary)
            }
        }
    }
}

// MARK: - 오늘

private struct TodayHero: View {
    let snapshot: UsageSnapshot?
    var source: AgentSource = .all
    let plan: String?

    var body: some View {
        let days = snapshot?.days ?? []
        let today = snapshot?.today
        let yesterday = days.count >= 2 ? days[days.count - 2] : nil
        let past = days.dropLast().suffix(7)
        let average = past.isEmpty ? 0 : past.reduce(0) { $0 + $1.tokens } / past.count
        let badge = source == .antigravity ? source.badgeTitle : (plan ?? source.badgeTitle)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("오늘 · \(source.title)").font(.subheadline.weight(.semibold))
                Spacer()
                Text(badge).font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Format.tokens(today?.tokens ?? 0))
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                Text("토큰").font(.callout).foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Format.cost(today?.cost ?? 0) + (today?.hasUnpriced == true ? "+" : ""))
                        .font(.title3.weight(.semibold).monospacedDigit())
                    Text("API 단가 환산").font(.caption2).foregroundStyle(.secondary)
                }
                .hint("API 단가로 환산한 값", ["구독 요금과는 다릅니다. 같은 양을 API 로 썼다면 얼마인지입니다.",
                                           "입력·출력·캐시 쓰기·캐시 읽기 단가를 모델마다 따로 곱했습니다."]
                      + (L10n.isEnglish ? [] : ["기준 환율: $1 = \(Format.integer(Int(ExchangeRate.currentRate.rounded())))원 (\(ExchangeRate.currentDateString)) · 원본 \(Format.usd(today?.cost ?? 0))"])
                      + (today?.hasUnpriced == true ? ["단가표에 없는 모델이 섞여 있어 실제보다 작습니다."] : []), symbol: "dollarsign.circle")
            }
            HStack(spacing: 14) {
                if let yesterday {
                    Text("어제 \(Format.tokens(yesterday.tokens))")
                }
                if average > 0 {
                    Text("지난 7일 평균 \(Format.tokens(average))")
                }
            }
            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }
}

// MARK: - 한도

private struct LimitGauges: View {
    let limits: [LimitRow]
    let message: String?
    /// 로그인 문제면 안내를 조금 더 길게.
    var needsLogin = false
    var updatedAt: Date?
    var refreshing = false
    var onRefresh: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "한도", detail: updatedAt.map { "\($0.formatted(date: .omitted, time: .shortened)) 기준" })
            if !limits.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(limits) { row in
                        gauge(row).frame(maxWidth: .infinity)
                    }
                }
            }
            if let message {
                // 로그인 만료는 흔한 일이라 경고색을 쓰지 않는다. 한 줄과 다시 읽기 버튼만.
                HStack(spacing: 8) {
                    Symbol(name: needsLogin ? "person.crop.circle.badge.exclamationmark" : "exclamationmark.triangle", size: 12,
                           color: needsLogin ? .secondary : ChartPalette.warning)
                    Text(needsLogin ? L10n.tr("로그인이 만료됐습니다. Claude Code 를 한 번 쓰면 이어집니다.") : L10n.tr(message))
                        .font(.caption).foregroundStyle(needsLogin ? Color.secondary : ChartPalette.warning).lineLimit(2)
                    Spacer(minLength: 0)
                    Button(action: onRefresh) {
                        Text("다시 읽기").font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(refreshing)
                }
            } else if limits.isEmpty {
                Text("불러오는 중…").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func gauge(_ row: LimitRow) -> some View {
        let (color, status) = ChartPalette.limitStatus(row.percent)
        return VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(row.percent, 0.5), 100) / 100))
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(Format.percent(row.percent)).font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                    Text(status).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 70, height: 70)
            Text(row.displayName).font(.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
            if let reset = row.resetsAt {
                Text(Format.until(reset).replacingOccurrences(of: " 초기화", with: "").replacingOccurrences(of: "Resets in ", with: ""))
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .hint("\(row.displayName) · \(Format.percent(row.percent)) 씀", [row.percent < 70 ? "아직 여유가 있습니다." : row.percent < 90 ? "70%를 넘었습니다." : "90%를 넘었습니다. 곧 막힙니다."]
              + (row.resetsAt.map { ["\($0.formatted(date: .abbreviated, time: .shortened))에 초기화됩니다."] } ?? []), symbol: "gauge.with.needle")
    }
}
