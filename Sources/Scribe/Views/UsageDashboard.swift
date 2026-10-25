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
private extension View {
    func dashboardCard() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.secondary.opacity(0.12)))
    }
}

/// 섹션 제목. 오른쪽 `detail` 은 평소엔 요약, 차트에 마우스를 올리면 그 막대의 값이다.
private struct SectionTitle: View {
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

// MARK: - 시간대별

private struct HourlyChart: View {
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

private struct DailyChart: View {
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

private struct ModelBreakdown: View {
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
private struct StackedBar: View {
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
