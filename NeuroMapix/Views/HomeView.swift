import SwiftUI

enum HomeRoute: Hashable {
    case setup
}

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var launcher: SessionLauncher

    @State private var path: [HomeRoute] = []

    private var palette: Palette { store.palette }

    private var daily: DailyChallenge {
        DailyChallenge.forDate(Date())
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScreenScaffold(title: "NeuroMapix",
                           subtitle: "Offline memory training",
                           palette: palette) {
                summaryRow
                dailyCard
                startCard
                quickModes
                recentRow
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .setup:
                    GameSetupView(onStart: launch)
                }
            }
        }
        .onChange(of: launcher.isPresented) { presented in
            if !presented { path = [] }
        }
    }

    private func launch(_ config: SessionConfig) {
        launcher.start(config)
    }

    // MARK: - Sections

    private var summaryRow: some View {
        HStack(spacing: Metric.spaceS) {
            StatTile(label: "Sessions", value: "\(store.stats.totalGames)",
                     glyph: .grid, palette: palette)
            StatTile(label: "Best score", value: "\(store.stats.bestScore)",
                     glyph: .star, tint: palette.warning, palette: palette)
            StatTile(label: "Streak", value: "\(store.stats.winStreak)",
                     glyph: .spark, tint: palette.accent, palette: palette)
        }
    }

    private var dailyCard: some View {
        let challenge = daily
        let done = store.isDailyDone(challenge.dateKey)
        return Card(palette: palette) {
            VStack(alignment: .leading, spacing: Metric.spaceS) {
                HStack(spacing: Metric.spaceS) {
                    GlyphIcon(glyph: .calendar, size: 18, color: palette.accent, weight: 2)
                    Text("DAILY CHALLENGE")
                        .font(AppFont.captionBold)
                        .tracking(1.1)
                        .foregroundColor(palette.accent)
                    Spacer()
                    if done {
                        Text("DONE")
                            .font(AppFont.captionBold)
                            .foregroundColor(palette.accent)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(palette.accent.opacity(0.16)))
                    }
                }
                Text(challenge.title)
                    .font(AppFont.heading)
                    .foregroundColor(palette.text)
                Text("Generated from today's date on this device — \(challenge.dateKey). Same puzzle every time you open it today.")
                    .font(AppFont.caption)
                    .foregroundColor(palette.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton(title: done ? "Replay today's challenge" : "Play daily challenge",
                              glyph: .play, palette: palette, tint: palette.accent) {
                    launch(SessionConfig(mode: challenge.mode,
                                         difficulty: challenge.difficulty,
                                         size: challenge.size,
                                         layoutID: challenge.layout.id,
                                         isDaily: true,
                                         fixedSeed: challenge.seed))
                }
            }
        }
    }

    private var startCard: some View {
        Card(palette: palette) {
            VStack(alignment: .leading, spacing: Metric.spaceS) {
                Text("Free session")
                    .font(AppFont.heading)
                    .foregroundColor(palette.text)
                Text("Pick one of 20 modes, a difficulty from 1 to 7 and a board from 3x3 up to 10x10.")
                    .font(AppFont.caption)
                    .foregroundColor(palette.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    path.append(.setup)
                } label: {
                    HStack(spacing: Metric.spaceS) {
                        GlyphIcon(glyph: .play, size: 20, color: .white, weight: 2.1)
                        Text("Configure session").font(AppFont.bodyBold).foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: Metric.cornerS).fill(palette.primary))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quickModes: some View {
        VStack(alignment: .leading, spacing: Metric.spaceS) {
            SectionHeader(title: "Quick start", trailing: "default settings", palette: palette)
            let modes = quickModeList
            ForEach(modes, id: \.rawValue) { mode in
                Button {
                    let size = preferredSize(for: store.settings.defaultDifficulty)
                    let layouts = LayoutCatalog.layouts(for: size)
                    let layout = layouts.randomElement() ?? LayoutCatalog.all[0]
                    launch(SessionConfig(mode: mode,
                                         difficulty: store.settings.defaultDifficulty,
                                         size: size,
                                         layoutID: layout.id))
                } label: {
                    HStack(spacing: Metric.spaceM) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Metric.cornerS)
                                .fill(palette.primary.opacity(0.12))
                            SymbolSwatch(symbol: modeSymbol(mode), color: palette.primary, side: 22)
                        }
                        .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.title).font(AppFont.body).foregroundColor(palette.text)
                            Text(mode.brief).font(AppFont.caption).foregroundColor(palette.textSoft)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        GlyphIcon(glyph: .play, size: 14, color: palette.primary, weight: 2)
                    }
                    .padding(Metric.spaceM)
                    .background(RoundedRectangle(cornerRadius: Metric.cornerM).fill(palette.surface))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quickModeList: [GameModeType] {
        var out: [GameModeType] = []
        if let last = store.history.first?.mode { out.append(last) }
        for mode in [GameModeType.objects, .sequence, .route, .fading] where !out.contains(mode) {
            out.append(mode)
        }
        return Array(out.prefix(4))
    }

    private func preferredSize(for difficulty: Int) -> BoardSize {
        let wanted = BoardSize.forDifficulty(difficulty)
        if store.isUnlocked(wanted) { return wanted }
        return BoardSize.allCases.last { store.isUnlocked($0) } ?? .x3
    }

    private var recentRow: some View {
        VStack(alignment: .leading, spacing: Metric.spaceS) {
            SectionHeader(title: "Recent sessions",
                          trailing: store.history.isEmpty ? "nothing yet" : "\(store.history.count) saved",
                          palette: palette)
            if store.history.isEmpty {
                BannerMessage(text: "Finish a session and it is saved on this device straight away.",
                              palette: palette, tint: palette.primary)
            } else {
                ForEach(Array(store.history.prefix(4))) { result in
                    HistoryRow(result: result, palette: palette)
                }
            }
        }
    }

    private func modeSymbol(_ mode: GameModeType) -> SymbolType {
        SymbolType.allCases[mode.rawValue % SymbolType.allCases.count]
    }
}

struct HistoryRow: View {
    let result: GameResult
    let palette: Palette

    private static let formatter = AppCalendar.formatter(date: .short, time: .short)

    var body: some View {
        HStack(spacing: Metric.spaceM) {
            ZStack {
                Circle().fill((result.won ? palette.accent : palette.warning).opacity(0.16))
                GlyphIcon(glyph: result.won ? .check : .close,
                          size: 14,
                          color: result.won ? palette.accent : palette.warning,
                          weight: 2.2)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(result.mode.title).font(AppFont.body).foregroundColor(palette.text)
                Text("\(result.boardDimension)x\(result.boardDimension) · d\(result.difficulty) · \(HistoryRow.formatter.string(from: result.date))")
                    .font(AppFont.caption)
                    .foregroundColor(palette.textSoft)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(result.score)")
                    .font(AppFont.bodyBold)
                    .foregroundColor(palette.primary)
                Text("\(Int(round(result.accuracy * 100)))%")
                    .font(AppFont.caption)
                    .foregroundColor(palette.textSoft)
            }
        }
        .padding(Metric.spaceM)
        .background(RoundedRectangle(cornerRadius: Metric.cornerM).fill(palette.surface))
    }
}
