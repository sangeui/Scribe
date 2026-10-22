import AppKit
import SwiftUI

/// 설정의 네 탭. 상시 창(모양·초상화), 집필(규칙·작가 기분), 알림, 기록(파일·서재·정보).
enum SettingsTab: Int, CaseIterable {
    case floating, writing, notifications, records

    var title: String {
        switch self {
        case .floating: "상시 창"
        case .writing: "집필"
        case .notifications: "알림"
        case .records: "기록"
        }
    }

    var symbol: String {
        switch self {
        case .floating: "macwindow"
        case .writing: "book"
        case .notifications: "bell"
        case .records: "folder"
        }
    }

    /// 고른 탭은 다음에 열 때도 그대로.
    nonisolated static let key = "settingsTab"

    @MainActor @ViewBuilder
    func content(store: UsageStore) -> some View {
        switch self {
        case .floating: FloatingSettings(store: store)
        case .writing: WritingSettings(store: store)
        case .notifications: NotificationSettings(store: store)
        case .records: RecordSettings(store: store)
        }
    }
}

/// macOS 설정 창. 팝오버를 못 찾을 때와 확인용(`--open-settings`)으로만 쓴다. 평소에는 팝오버 옆 패널(`SettingsPanel`)로 연다.
/// 글은 한 줄씩만 두고 설명은 마우스를 올리면 나오는 힌트 카드에 둔다.
struct SettingsView: View {
    @Bindable var store: UsageStore
    /// 확인용 `--settings-tab n` 이 있으면 그 탭으로 연다.
    @State private var tab: Int = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--settings-tab"), i + 1 < args.count, let n = Int(args[i + 1]) else { return 0 }
        return n
    }()

    var body: some View {
        TabView(selection: $tab) {
            ForEach(SettingsTab.allCases, id: \.self) { candidate in
                candidate.content(store: store)
                    .hintHost()
                    .tabItem { Label(candidate.title, systemImage: candidate.symbol) }
                    .tag(candidate.rawValue)
            }
        }
        .frame(width: 480, height: 560)
    }
}

/// 팝오버 옆에 뜨는 설정. 다른 패널처럼 위에 제목과 탭 넷, 아래에 그 탭의 내용. 힌트 카드는 패널이 그린다.
struct SettingsPanel: View {
    @Bindable var store: UsageStore
    @AppStorage(SettingsTab.key) private var tabRaw = SettingsTab.floating.rawValue

    private var tab: SettingsTab { SettingsTab(rawValue: tabRaw) ?? .floating }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Symbol(name: "gearshape", size: 13)
                    Text("설정").font(.headline)
                    Spacer()
                    Text(version).font(.caption2).foregroundStyle(.tertiary)
                }
                HStack(spacing: 6) {
                    ForEach(SettingsTab.allCases, id: \.self) { candidate in
                        tabButton(candidate)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)
            tab.content(store: store)
                .id(tab)
                .transition(.opacity)
        }
        .animation(.easeOut(duration: 0.15), value: tabRaw)
    }

    private func tabButton(_ candidate: SettingsTab) -> some View {
        let on = candidate == tab
        return Button { tabRaw = candidate.rawValue } label: {
            HStack(spacing: 5) {
                Symbol(name: candidate.symbol, size: 11, color: on ? .primary : .secondary)
                Text(candidate.title).font(.caption.weight(.semibold)).foregroundStyle(on ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(on ? 0.18 : 0.07), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var version: String {
        guard let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return "개발 빌드" }
        return "Scribe " + short
    }
}

/// 시각 고르기. 메뉴 대신 −/＋ 버튼이라 팝오버 옆 패널에서도 팝오버가 닫히지 않는다.
private struct HourStepper: View {
    @Binding var hour: Int

    var body: some View {
        HStack(spacing: 2) {
            step("minus") { hour = (hour + 23) % 24 }
            Text("\(hour)시").font(.callout.monospacedDigit()).frame(width: 38)
            step("plus") { hour = (hour + 1) % 24 }
        }
        .padding(.horizontal, 2).padding(.vertical, 2)
        .background(Color.secondary.opacity(0.1), in: Capsule())
    }

    private func step(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Symbol(name: symbol, size: 9)
                .frame(width: 20, height: 20)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// 설정 공통: 한 줄 설명.
private struct Note: View {
    let text: String
    var body: some View { Text(text).font(.caption).foregroundStyle(.secondary) }
}

// MARK: - 상시 창

/// 상시 창: 켜기와 모양·투명도, 초상화(대표 작가·꾸미기).
struct FloatingSettings: View {
    @Bindable var store: UsageStore
    @AppStorage(FloatingWindowController.opacityKey) private var opacity = 1.0
    @AppStorage(FloatingView.featuredKey) private var featured = ""
    @AppStorage(FloatingStyle.key) private var styleRaw = FloatingStyle.pill.rawValue
    @State private var decorAuthor = ""
    @State private var decorTick = 0

    private var style: FloatingStyle { FloatingStyle(rawValue: styleRaw) ?? .pill }

    var body: some View {
        Form {
            Section {
                Toggle("데스크톱에 상시 표시", isOn: $store.isFloatingVisible)
                    .hint("상시 창", ["다른 창 위에 늘 떠 있고 드래그로 옮길 수 있습니다.", "창을 오른쪽 클릭하면 모양을 바꾸거나 숨길 수 있습니다."], symbol: "macwindow")
                HStack(alignment: .top, spacing: 12) {
                    ForEach(FloatingStyle.allCases, id: \.self) { candidate in
                        styleCard(candidate)
                    }
                }
                .padding(.vertical, 4)
                LabeledContent("투명도") {
                    Slider(value: $opacity, in: 0.3...1, step: 0.05)
                        .frame(width: 200)
                        .onChange(of: opacity) { store.updateFloatingAppearance() }
                    Text("\(Int((opacity * 100).rounded()))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
            Section {
                LabeledContent("대표 작가") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            portraitChoice("", title: "쓰는 작가", author: store.writing?.book?.authorShort ?? "Shakespeare")
                            ForEach(Library.authors, id: \.self) { author in
                                portraitChoice(author, title: Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author, author: author)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .hint("대표 작가", ["고른 작가의 초상화가 상시 창에 늘 나옵니다.", "글은 지금 쓰는 작품과 작가를 보여 줍니다."], symbol: "person.crop.square")
                let author = decorAuthor.isEmpty ? (store.writing?.book?.authorShort ?? "Shakespeare") : decorAuthor
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text("꾸미기")
                        Spacer()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Library.authors, id: \.self) { candidate in
                                    smallPortrait(candidate, selected: candidate == author) { decorAuthor = candidate }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(maxWidth: 290)
                    }
                    FlowLayout(spacing: 6) {
                        decorChoice(nil, for: author)
                        ForEach(Decor.all) { decorChoice($0, for: author) }
                    }
                    .id(decorTick)
                }
                .hint("초상화 꾸미기", ["오른쪽에서 작가를 고르고 아래에서 장신구를 고릅니다. 성과를 이루면 장신구가 열립니다.", "상시 창·팝오버·서재의 초상화에 모두 보입니다."], symbol: "sparkles")
            } header: {
                Text("초상화")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    /// 모양 카드. 실제 상시 창을 작게 그려 보여 주고, 누르면 고른다.
    private func styleCard(_ candidate: FloatingStyle) -> some View {
        let selected = candidate == style
        return Button {
            styleRaw = candidate.rawValue
            store.updateFloatingAppearance()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if let w = store.writing {
                        switch candidate {
                        case .pill: FloatingPill(progress: w, animated: false).scaleEffect(0.62)
                        case .mini: FloatingMini(progress: w, animated: false).scaleEffect(0.85)
                        }
                    }
                }
                .frame(width: 190, height: 80)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(candidate.title).font(.callout.weight(selected ? .semibold : .regular))
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.accentColor.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hint(candidate.title, [candidate.detail], symbol: candidate == .pill ? "capsule" : "circle")
    }

    private func portraitChoice(_ value: String, title: String, author: String) -> some View {
        let selected = featured == value
        return Button { featured = value } label: {
            VStack(spacing: 3) {
                PortraitFrame(author: author, scale: 2)
                    .overlay(RoundedRectangle(cornerRadius: 32 * 0.22, style: .continuous)
                        .stroke(selected ? Color.accentColor : .clear, lineWidth: 2))
                Text(title).font(.system(size: 9, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .primary : .secondary).lineLimit(1)
            }
            .frame(width: 44)
        }
        .buttonStyle(.plain)
    }

    private func smallPortrait(_ author: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PortraitFrame(author: author, scale: 1.75)
                .overlay(RoundedRectangle(cornerRadius: 28 * 0.22, style: .continuous)
                    .stroke(selected ? Color.accentColor : .clear, lineWidth: 2))
                .opacity(selected ? 1 : 0.7)
        }
        .buttonStyle(.plain)
        .hint(Library.books.first { $0.authorShort == author }?.displayAuthor ?? author, [], symbol: "person")
    }

    /// 장신구 하나. 그 작가에게 씌운 모습을 작게 보여 주고, 누르면 고른다. 안 열린 것은 흐리게.
    private func decorChoice(_ accessory: Accessory?, for author: String) -> some View {
        let unlocked = accessory.map { Decor.isUnlocked($0, progress: store.writing) } ?? true
        let selected = Decor.chosen(for: author)?.id == accessory?.id
        let rows = accessory.map { Decor.apply(Portraits.rows(author), accessory: $0) } ?? Portraits.rows(author)
        let lockedBy = accessory?.unlock.flatMap { Achievements.byID($0)?.title }
        return Button {
            guard unlocked else { return }
            Decor.choose(accessory, for: author)
            decorTick += 1
        } label: {
            VStack(spacing: 3) {
                PixelFrame(rows: rows, scale: 32 / CGFloat(Portraits.size), palette: Portraits.palette)
                    .frame(width: 32, height: 32)
                    .background(Portraits.backdrop(author))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(selected ? Color.accentColor : Color.white.opacity(0.12), lineWidth: selected ? 2 : 1))
                    .saturation(unlocked ? 1 : 0)
                    .opacity(unlocked ? 1 : 0.4)
                Text(accessory?.title ?? "없음").font(.system(size: 9, weight: selected ? .semibold : .regular))
                    .foregroundStyle(unlocked ? (selected ? .primary : .secondary) : .tertiary)
            }
            .frame(width: 50)
        }
        .buttonStyle(.plain)
        .hint(accessory?.title ?? "장신구 없음",
              unlocked ? (accessory == nil ? ["장신구를 씌우지 않습니다."] : ["누르면 \(Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author)에게 씌웁니다."])
              : ["성과 \"\(lockedBy ?? "")\"를 이루면 열립니다."], symbol: unlocked ? "checkmark.circle" : "lock")
    }
}

// MARK: - 데이터 소스 (공통 섹션)

/// 설정에서 토큰 공급 에이전트(Antigravity / Claude Code / 통합)를 직접 고르는 섹션.
struct AgentSourceSection: View {
    @Bindable var store: UsageStore

    var body: some View {
        let byProvider = store.snapshot?.todayByProvider ?? [:]
        let filesByProvider = store.snapshot?.filesByProvider ?? [:]
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(AgentSource.allCases) { candidate in
                        sourceButton(candidate, byProvider: byProvider, filesByProvider: filesByProvider)
                    }
                }
                Note(text: store.agentSource.detail)
            }
            .padding(.vertical, 2)
            .hint("데이터 소스 · 토큰 공급 에이전트",
                  ["어느 에이전트의 대화 로그에서 토큰 사용량을 읽어 집필하고 사용량 화면을 보여 줄지 직접 고릅니다.",
                   "바꾸더라도 지금까지 쓴 글자 수는 그대로 남고, 바꾼 뒤 새로 늘어나는 토큰부터 이어서 씁니다."],
                  symbol: "cpu")
            LabeledContent("읽는 곳") {
                Text(store.agentSource.logPathDisplay)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .hint("로컬 대화 로그",
                  ["Antigravity(~/.gemini/antigravity/brain), Gemini CLI(~/.gemini/tmp), Claude Code(~/.claude/projects) 로그를 15초마다 읽습니다.",
                   "바뀐 파일만 다시 읽으며, Claude Code 모드의 한도만 Keychain 의 로그인 정보를 씁니다."],
                  symbol: "doc.text.magnifyingglass")
        } header: {
            Text("데이터 소스")
        }
    }

    private func sourceButton(_ candidate: AgentSource, byProvider: [AgentProvider: Int], filesByProvider: [AgentProvider: Int]) -> some View {
        let selected = store.agentSource == candidate
        let tokens: Int = switch candidate {
        case .antigravity: byProvider[.antigravity] ?? 0
        case .claude: byProvider[.claude] ?? 0
        case .all: (byProvider[.antigravity] ?? 0) + (byProvider[.claude] ?? 0)
        }
        let files: Int = switch candidate {
        case .antigravity: filesByProvider[.antigravity] ?? 0
        case .claude: filesByProvider[.claude] ?? 0
        case .all: (filesByProvider[.antigravity] ?? 0) + (filesByProvider[.claude] ?? 0)
        }
        return Button {
            store.setAgentSource(candidate)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(selected ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 7, height: 7)
                    Text(candidate.title)
                        .font(.callout.weight(selected ? .semibold : .medium))
                        .lineLimit(1)
                }
                Text("오늘 \(Format.tokens(tokens))")
                    .font(.caption2.monospacedDigit().weight(.medium))
                    .foregroundStyle(selected ? .primary : .secondary)
                Text("로그 \(files)개")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selected ? Color.accentColor.opacity(0.75) : Color.secondary.opacity(0.16), lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 집필

/// 집필: 데이터 소스 선택, 지금 적용되는 규칙(금 뱃지 효과 반영)과 작가 기분.
struct WritingSettings: View {
    @Bindable var store: UsageStore
    @AppStorage(MoodJudge.enabledKey) private var moodEnabled = true
    @AppStorage(MoodJudge.slackMinutesKey) private var slackMinutes = 30

    var body: some View {
        let perks = store.writing?.perks ?? Perks()
        let chars = Writing.charactersPerMillionTokens * (1 + perks.characterBonus)
        let perItem = Double(Balance.tokensPerItem) * perks.itemTokens
        let chance = Balance.eventChancePerMillion * perks.eventChance
        let minutes = (Double(Balance.eventMinutes.lowerBound) * perks.eventDuration, Double(Balance.eventMinutes.upperBound) * perks.eventDuration)
        let refusal = max(0, Balance.refusalChance - perks.refusalDelta)
        let wait = (Double(Balance.refusalMinutes.lowerBound) * perks.refusalWait, Double(Balance.refusalMinutes.upperBound) * perks.refusalWait)
        Form {
            AgentSourceSection(store: store)
            Section {
                rule("글자", "100만 토큰마다 \(Format.integer(Int(chars.rounded())))자", changed: perks.characterBonus > 0,
                     hint: ["모든 토큰(입력·출력·캐시)을 합쳐 셉니다.", "영감의 날엔 \(Int(Balance.inspirationMultiplier))배, 비 오는 날엔 5% 더."])
                rule("아이템", "토큰 \(Format.tokens(Int(perItem)))개마다 하나", changed: perks.itemTokens < 1,
                     hint: ["멈춘 동안 쓴 토큰도 셉니다. 한 종류는 \(Balance.itemCap)개까지.", "같은 아이템 \(Balance.exchangeCost)개는 다른 하나로 바꿀 수 있습니다."])
                rule("돌발 상황", "100만 토큰마다 \(Format.percent(chance * 100)) · \(Int(minutes.0.rounded()))~\(Int(minutes.1.rounded()))분", changed: perks.eventChance < 1 || perks.eventDuration < 1,
                     hint: ["새 토큰 100만 개마다 한 번 추첨합니다. 손님 작가가 있으면 생기지 않습니다.", "맞는 아이템을 권하면 바로 끝나고, 없으면 시간이 지나 저절로 끝납니다."])
                rule("거절", "\(Format.percent(refusal * 100)) · 기다림 \(Int(wait.0.rounded()))~\(Int(wait.1.rounded()))분", changed: perks.refusalDelta > 0 || perks.refusalWait < 1,
                     hint: ["아이템을 권하면 이 확률로 거절합니다.", "같은 상황에서 거절당할수록 \(Int(Balance.refusalDecay * 100))%p씩 낮아집니다."])
                rule("자연재해", "100만 토큰마다 \(Format.percent(Balance.disasterChancePerMillion * 100)) · 원고 \(Int((Balance.disasterLoss.lowerBound * perks.disasterLoss * 100).rounded()))~\(Int((Balance.disasterLoss.upperBound * perks.disasterLoss * 100).rounded()))%", changed: perks.disasterLoss < 1,
                     hint: ["집필은 멈추지 않고 지금 책의 원고 일부를 잃습니다. 탈고한 책은 그대로입니다.", "금고·사본이 있으면 하나가 저절로 쓰여 잃지 않습니다. 폭풍 날은 확률 2.5배."])
                rule("사건·비평·마감", "100만 토큰마다 \(Format.percent(Balance.dilemmaChancePerMillion * 100)) · 탈고 뒤 \(Int(Balance.reviewHours.lowerBound))~\(Int(Balance.reviewHours.upperBound))시간 · 월요일", changed: false,
                     hint: ["선택지가 있는 사건은 앞 사건 뒤 \(Int(Balance.dilemmaCooldown / 3600))시간을 쉬고 다시 추첨합니다.", "비평은 탈고 뒤 실리고, 마감은 월요일마다 지난주 기록으로 냅니다."])
                Note(text: "노란 점은 금 뱃지 효과가 들어간 값입니다.")
            } header: {
                Text("규칙")
            }
            Section {
                Toggle("작가가 눈치를 봅니다", isOn: $moodEnabled)
                    .hint("작가 기분", ["마지막 입력 뒤 지난 시간과 토큰 흐름으로 정합니다. 무엇을 쳤는지는 모릅니다.",
                                      "쓰는데 토큰이 10분 없으면 곁눈질, 15분 넘게 자리를 비웠는데 토큰이 오면 혼자 열심, 둘 다 조용하면 농땡이.",
                                      "글자·아이템·판매에는 영향이 없습니다."], symbol: "eye")
                Picker("농땡이까지", selection: $slackMinutes) {
                    Text("15분").tag(15); Text("30분").tag(30); Text("60분").tag(60)
                }
                .pickerStyle(.segmented)
                .disabled(!moodEnabled)
            } header: {
                Text("작가 기분")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func rule(_ title: String, _ value: String, changed: Bool, hint lines: [String]) -> some View {
        LabeledContent(title) {
            HStack(spacing: 5) {
                if changed { Circle().fill(BadgeTier.gold.color).frame(width: 6, height: 6) }
                Text(value).foregroundStyle(.secondary)
            }
        }
        .hint(title, lines + (changed ? ["노란 점: 금 뱃지 효과가 들어간 값입니다."] : []), symbol: "slider.horizontal.3")
    }
}

// MARK: - 알림

/// 알림: 권한 상태, 방해 금지, 잠금 화면.
struct NotificationSettings: View {
    @Bindable var store: UsageStore
    @AppStorage(QuietHours.enabledKey) private var quietEnabled = true
    @AppStorage(QuietHours.startKey) private var quietStart = 23
    @AppStorage(QuietHours.endKey) private var quietEnd = 8
    @AppStorage(LockProgress.enabledKey) private var lockEnabled = true
    @AppStorage(LockProgress.minutesKey) private var lockMinutes = 60

    var body: some View {
        Form {
            Section {
                LabeledContent("상태") {
                    HStack(spacing: 6) {
                        Circle().fill(color).frame(width: 8, height: 8)
                        Text(store.notificationStatus.title)
                        Spacer()
                        Button("다시 확인") { Task { await store.refreshNotificationStatus() } }.controlSize(.small)
                        Button("시스템 설정") { store.openNotificationSettings() }.controlSize(.small)
                    }
                }
                .hint("알림 권한 · \(store.notificationStatus.title)", [explanation], symbol: "bell.badge")
                LabeledContent("시험") {
                    Button("시험 알림 보내기") { store.sendTestNotification() }
                        .controlSize(.small)
                        .disabled(store.notificationStatus == .unavailable)
                }
                .hint("무엇을 알리나", ["돌발 상황(아이템이 있으면 \"아이템 권하기\" 버튼), 돌아옴, 자연재해, 행운, 성과, 탈고, 판매 단계, 비평, 사건, 마감, 영감 게이지, 지난주 돌아보기.",
                                    "1분 안에 여러 개가 생기면 \"소식 n건\" 하나로 묶습니다."], symbol: "list.bullet")
            } header: {
                Text("권한")
            }
            Section {
                Toggle("알림을 모아 두었다가 끝나면 한 번에", isOn: $quietEnabled)
                    .hint("방해 금지", ["이 시간에는 알림을 보내지 않고 모아 둡니다. 끝나면 요약 하나로 보냅니다.", "모아 둔 동안은 팝오버에 \"방해 금지 · 소식 n건\"으로 보입니다."], symbol: "moon.zzz")
                LabeledContent("시간") {
                    HStack(spacing: 6) {
                        HourStepper(hour: $quietStart)
                        Text("부터").foregroundStyle(.secondary)
                        HourStepper(hour: $quietEnd)
                        Text("까지").foregroundStyle(.secondary)
                    }
                }
                .disabled(!quietEnabled)
            } header: {
                Text("방해 금지")
            }
            Section {
                Toggle("화면이 잠긴 동안 진행을 알립니다", isOn: $lockEnabled)
                    .hint("잠금 화면", ["잠긴 동안 글자가 늘었을 때만 진행률과 늘어난 글자, 돌발 상황 수를 보냅니다.",
                                      "시스템 설정 > 알림 > Scribe 의 \"잠금 화면에 표시\"가 켜져 있어야 합니다."], symbol: "lock")
                Picker("간격", selection: $lockMinutes) {
                    Text("30분").tag(30); Text("60분").tag(60); Text("2시간").tag(120)
                }
                .pickerStyle(.segmented)
                .disabled(!lockEnabled)
            } header: {
                Text("잠금 화면")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .task { await store.refreshNotificationStatus(ask: false) }
    }

    private var color: Color {
        switch store.notificationStatus {
        case .allowed: .green
        case .denied: .orange
        case .notAsked, .unavailable: .secondary
        }
    }

    private var explanation: String {
        switch store.notificationStatus {
        case .allowed:
            return "알림 센터로 보냅니다. 누르면 Scribe 가 열립니다."
        case .denied:
            return "macOS 가 권한을 거절했습니다(ad-hoc 서명이면 그럴 수 있습니다). 시스템 설정 > 알림에서 Scribe 를 켜 주세요. 그 전까지는 스크립트 편집기 이름의 간이 알림으로 갑니다."
        case .notAsked:
            return "첫 알림을 보낼 때 권한을 묻습니다. 시험 알림을 보내면 바로 묻습니다."
        case .unavailable:
            return "swift run 으로 띄운 실행 파일은 알림 센터를 쓸 수 없습니다. scripts/build-app.sh 로 만든 앱에서만 보냅니다."
        }
    }
}

// MARK: - 기록

/// 기록: 데이터 소스 선택, 파일 위치와 내보내기·가져오기, 서재 통계, 앱 정보.
struct RecordSettings: View {
    @Bindable var store: UsageStore

    var body: some View {
        Form {
            AgentSourceSection(store: store)
            Section {
                LabeledContent("파일") {
                    HStack(spacing: 8) {
                        Text(WritingStore.defaultURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        Button("Finder") { NSWorkspace.shared.activateFileViewerSelecting([WritingStore.defaultURL]) }.controlSize(.small)
                    }
                }
                .hint("기록 파일", ["날짜별 글자 수, 아이템, 돌발 상황·사건·비평 기록, 성과, 판매가 들어 있습니다.",
                                  "저장할 때마다 직전 파일을 writing.backup.json 으로 남기고, 읽지 못하는 파일은 broken-<시각>.json 으로 옮깁니다."], symbol: "doc")
                LabeledContent("옮기기") {
                    HStack(spacing: 8) {
                        Button("내보내기…") { store.exportRecordInteractively() }.controlSize(.small)
                        Button("가져오기…") { store.importRecordInteractively() }.controlSize(.small)
                        if let message = store.transferMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .hint("다른 Mac 으로", ["내보낸 파일을 그쪽에서 가져오면 됩니다.", "가져오면 지금 기록은 imported-backup-<시각>.json 으로 남기고 바꿉니다. 토큰 기준선은 다시 잡습니다."], symbol: "arrow.left.arrow.right")
            } header: {
                Text("기록")
            }
            Section {
                LabeledContent("작품") { Text("\(Library.books.count)편 · 작가 \(Library.authors.count)명 · \(Format.tokens(Library.roundCharacters))자").foregroundStyle(.secondary) }
                    .hint("원문", ["Books/manifest.json 에 순서와 글자 수가 있습니다."], symbol: "books.vertical")
                LabeledContent("출처") {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Project Gutenberg 퍼블릭 도메인 텍스트").foregroundStyle(.secondary)
                            Button("gutenberg.org") { NSWorkspace.shared.open(URL(string: "https://www.gutenberg.org")!) }.controlSize(.small)
                        }
                        Text("괴테는 19세기 영어 번역(보일런·베이어드 테일러·스완윅·프로싱엄·보링·칼라일). 앞뒤 안내문과 Project Gutenberg 표기는 뗐습니다.")
                            .font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.trailing)
                    }
                }
                .hint("원서 출처", ["원문은 모두 저작권이 끝난 퍼블릭 도메인 텍스트이고 Project Gutenberg 에서 가져왔습니다.", "한국어 번역본은 번역자 저작권이 있어 넣지 않았습니다. 제목과 작가 이름만 한국어로 보여 줍니다."], symbol: "text.book.closed")
                if let w = store.writing {
                    LabeledContent("진행") { Text("\(w.round + 1)회차 · \(w.finishedInRound)편 탈고 · 모두 \(Format.integer(Int(w.totalCharacters)))자").foregroundStyle(.secondary) }
                    LabeledContent("성과") { Text("\(w.badges.count)개 · 아이템 \(ItemKind.allCases.reduce(0) { $0 + w.count($1) })개 · 판매 \(Format.integer(w.totalSales))부").foregroundStyle(.secondary) }
                }
            } header: {
                Text("서재")
            }
            Section {
                LabeledContent("Scribe") {
                    Text(version).foregroundStyle(.secondary)
                }
                .hint("Scribe", ["Claude Code 토큰 사용량을 고전 집필로 바꿔 보여 주는 메뉴바 앱입니다.", "번들 ID local.scribe · ad-hoc 서명"], symbol: "info.circle")
            } header: {
                Text("정보")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var version: String {
        guard let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return "개발 빌드" }
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(short) (\($0))" } ?? short
    }
}
