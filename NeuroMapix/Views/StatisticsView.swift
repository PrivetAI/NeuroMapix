import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAllHistory = false

    private var palette: Palette { store.palette }

    var body: some View {
        NavigationStack {
            ScreenScaffold(title: "Statistics",
                           subtitle: "Everything is stored on this device",
                           palette: palette) {
                tiles
                scoreTrend
                modeAccuracy
                difficultySpread
                historyList
            }
        }
    }

    private var tiles: some View {
        VStack(spacing: Metric.spaceS) {
            HStack(spacing: Metric.spaceS) {
                StatTile(label: "Sessions", value: "\(store.stats.totalGames)", glyph: .grid, palette: palette)
                StatTile(label: "Best score", value: "\(store.stats.bestScore)",
                         glyph: .star, tint: palette.warning, palette: palette)
            }
            HStack(spacing: Metric.spaceS) {
                StatTile(label: "Win streak", value: "\(store.stats.winStreak)",
                         glyph: .spark, tint: palette.accent, palette: palette)
                StatTile(label: "Best streak", value: "\(store.stats.bestStreak)",
                         glyph: .trophy, tint: palette.accent, palette: palette)
            }
            HStack(spacing: Metric.spaceS) {
                StatTile(label: "Perfect rounds", value: "\(store.stats.perfectRounds)",
                         glyph: .target, palette: palette)
                StatTile(label: "Training time", value: timeText, glyph: .clock, palette: palette)
            }
        }
    }

    private var timeText: String {
        let minutes = store.stats.totalMinutes
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private var scoreTrend: some View {
        Card(palette: palette) {
            VStack(alignment: .leading, spacing: Metric.spaceS) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionHeader(title: "Score trend", palette: palette)
                        Text("Newest on the right")
                            .font(AppFont.caption)
                            .foregroundColor(palette.textFaint)
                    }
                    Spacer()
                    AccuracyDial(value: store.stats.averageAccuracy, palette: palette, side: 76)
                }
                TrendChart(values: trendValues, palette: palette, tint: palette.primary)
            }
        }
    }

    private var trendValues: [Double] {
        Array(store.history.prefix(20).reversed()).map { Double($0.score) }
    }

    private var modeAccuracy: some View {
        Card(palette: palette) {
            VStack(alignment: .leading, spacing: Metric.spaceS) {
                SectionHeader(title: "Accuracy by mode",
                              trailing: "\(store.stats.modesTried) of 20 played",
                              palette: palette)
                let rows = GameModeType.allCases.compactMap { mode -> (String, Double, String)? in
                    guard let accuracy = store.averageAccuracy(for: mode) else { return nil }
                    return (mode.short, accuracy, "\(Int(round(accuracy * 100)))%")
                }
                .sorted { $0.1 > $1.1 }
                if rows.isEmpty {
                    Text("Play a few modes to fill this in.")
                        .font(AppFont.caption)
                        .foregroundColor(palette.textFaint)
                } else {
                    RankedBarChart(items: rows.prefix(10).map { (label: $0.0, value: $0.1, caption: $0.2) },
                                   palette: palette, tint: palette.accent)
                }
            }
        }
    }

    private var difficultySpread: some View {
        Card(palette: palette) {
            VStack(alignment: .leading, spacing: Metric.spaceS) {
                SectionHeader(title: "Sessions by difficulty", palette: palette)
                let counts = store.countByDifficulty()
                ColumnChart(items: (1...DifficultyProfile.maxLevel).map {
                    (label: "d\($0)", value: Double(counts[$0] ?? 0))
                }, palette: palette, tint: palette.primary)
                SectionHeader(title: "Boards cleared", palette: palette)
                HStack(spacing: 6) {
                    ForEach(BoardSize.allCases) { size in
                        let cleared = store.stats.sizesCleared.contains(size.dimension)
                        VStack(spacing: 2) {
                            Text(size.label)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(cleared ? .white : palette.textFaint)
                            GlyphIcon(glyph: cleared ? .check : .lock, size: 11,
                                      color: cleared ? .white : palette.textFaint, weight: 1.8)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(cleared ? palette.accent : palette.gridLine.opacity(0.5)))
                    }
                }
            }
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: Metric.spaceS) {
            SectionHeader(title: "History",
                          trailing: "\(store.history.count) sessions",
                          palette: palette)
            if store.history.isEmpty {
                BannerMessage(text: "Session history appears here and survives app restarts.",
                              palette: palette, tint: palette.primary)
            } else {
                ForEach(showAllHistory ? Array(store.history.prefix(60)) : Array(store.history.prefix(8))) { result in
                    HistoryRow(result: result, palette: palette)
                }
                if store.history.count > 8 {
                    SecondaryButton(title: showAllHistory ? "Show less" : "Show more",
                                    glyph: showAllHistory ? .minus : .plus,
                                    palette: palette) {
                        showAllHistory.toggle()
                    }
                }
            }
        }
    }
}
