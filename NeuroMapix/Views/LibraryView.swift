import SwiftUI

enum LibraryRoute: Hashable {
    case themes, favorites, daily
}

struct LibraryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var path: [LibraryRoute] = []

    private var palette: Palette { store.palette }

    var body: some View {
        NavigationStack(path: $path) {
            ScreenScaffold(title: "Library",
                           subtitle: "Themes, favourites and the daily board",
                           palette: palette) {
                Button { path.append(.themes) } label: {
                    RowLink(title: "Visual themes",
                            detail: "\(ThemeCatalog.all.count) palettes · using \(store.theme.name)",
                            glyph: .palette, palette: palette)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { path.append(.favorites) } label: {
                    RowLink(title: "Favourite layouts",
                            detail: store.favorites.isEmpty ? "No layouts saved yet" : "\(store.favorites.count) saved",
                            glyph: .heart, palette: palette)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { path.append(.daily) } label: {
                    RowLink(title: "Daily challenge",
                            detail: "Generated from the device date",
                            glyph: .calendar, palette: palette)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Card(palette: palette) {
                    VStack(alignment: .leading, spacing: Metric.spaceS) {
                        SectionHeader(title: "Built-in content", palette: palette)
                        infoRow("Layouts", "\(LayoutCatalog.all.count)")
                        infoRow("Modes", "\(GameModeType.allCases.count)")
                        infoRow("Board sizes", "\(BoardSize.allCases.count) (3x3 to 10x10)")
                        infoRow("Object sets", "\(ObjectTheme.allCases.count)")
                        infoRow("Symbols", "\(SymbolType.allCases.count) hand-drawn")
                        infoRow("Achievements", "\(AchievementCatalog.all.count)")
                        Text("All of it ships inside the app. Nothing is downloaded.")
                            .font(AppFont.caption)
                            .foregroundColor(palette.textFaint)
                    }
                }

                objectSets
            }
            .navigationDestination(for: LibraryRoute.self) { route in
                switch route {
                case .themes: ThemesView()
                case .favorites: FavoritesView()
                case .daily: DailyView()
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(AppFont.body).foregroundColor(palette.text)
            Spacer()
            Text(value).font(AppFont.bodyBold).foregroundColor(palette.primary)
        }
    }

    private var objectSets: some View {
        VStack(alignment: .leading, spacing: Metric.spaceS) {
            SectionHeader(title: "Object sets", palette: palette)
            ForEach(ObjectTheme.allCases) { theme in
                HStack(spacing: Metric.spaceM) {
                    HStack(spacing: 2) {
                        ForEach(theme.symbols, id: \.rawValue) { symbol in
                            SymbolSwatch(symbol: symbol,
                                         color: palette.color(for: theme.colors[0]),
                                         side: 18)
                        }
                    }
                    .frame(width: 78, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(theme.title).font(AppFont.body).foregroundColor(palette.text)
                        Text(theme.summary).font(AppFont.caption).foregroundColor(palette.textSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(Metric.spaceM)
                .background(RoundedRectangle(cornerRadius: Metric.cornerM).fill(palette.surface))
            }
        }
    }
}

// MARK: - Themes

struct ThemesView: View {
    @EnvironmentObject private var store: AppStore
    private var palette: Palette { store.palette }

    var body: some View {
        ScreenScaffold(title: "Visual themes",
                       subtitle: "Applies to every screen",
                       palette: palette,
                       showsBack: true) {
            Card(palette: palette) {
                VStack(alignment: .leading, spacing: Metric.spaceS) {
                    SectionHeader(title: "Appearance", trailing: store.settings.darkMode ? "Dark" : "Light",
                                  palette: palette)
                    HStack(spacing: Metric.spaceS) {
                        appearanceButton(title: "Light", dark: false)
                        appearanceButton(title: "Dark", dark: true)
                    }
                    Text("The app never follows the device setting — this picker is the only switch.")
                        .font(AppFont.caption)
                        .foregroundColor(palette.textFaint)
                }
            }
            ForEach(ThemeCatalog.all) { theme in
                themeCard(theme)
            }
        }
    }

    private func appearanceButton(title: String, dark: Bool) -> some View {
        Button {
            store.setDarkMode(dark)
            Feedback.shared.tap()
        } label: {
            Text(title)
                .font(AppFont.bodyBold)
                .foregroundColor(store.settings.darkMode == dark ? .white : palette.text)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: Metric.cornerS)
                    .fill(store.settings.darkMode == dark ? palette.primary : palette.background))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func themeCard(_ theme: VisualTheme) -> some View {
        let selected = store.settings.themeID == theme.id
        let preview = Palette(theme: theme, isDark: store.settings.darkMode)
        return Button {
            store.selectTheme(theme.id)
            Feedback.shared.confirm()
        } label: {
            HStack(spacing: Metric.spaceM) {
                ZStack {
                    RoundedRectangle(cornerRadius: Metric.cornerS).fill(preview.background)
                    RoundedRectangle(cornerRadius: Metric.cornerS)
                        .stroke(preview.gridLine, lineWidth: 1)
                    VStack(spacing: 3) {
                        HStack(spacing: 3) {
                            swatch(preview.primary)
                            swatch(preview.accent)
                        }
                        HStack(spacing: 3) {
                            swatch(preview.warning)
                            swatch(preview.error)
                        }
                    }
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name).font(AppFont.body).foregroundColor(palette.text)
                    Text(theme.note).font(AppFont.caption).foregroundColor(palette.textSoft)
                }
                Spacer(minLength: 0)
                if selected {
                    GlyphIcon(glyph: .check, size: 18, color: palette.accent, weight: 2.4)
                }
            }
            .padding(Metric.spaceM)
            .background(RoundedRectangle(cornerRadius: Metric.cornerM)
                .fill(palette.surface))
            .overlay(
                RoundedRectangle(cornerRadius: Metric.cornerM)
                    .stroke(selected ? palette.primary : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func swatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 18, height: 18)
    }
}

// MARK: - Favorites

struct FavoritesView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var launcher: SessionLauncher
    @State private var browseSize: BoardSize = .x4

    private var palette: Palette { store.palette }

    var body: some View {
        ScreenScaffold(title: "Favourites",
                       subtitle: "\(store.favorites.count) saved layouts",
                       palette: palette,
                       showsBack: true) {
            if store.favorites.isEmpty {
                BannerMessage(text: "Tap the heart on any layout to keep it here.",
                              palette: palette, tint: palette.primary)
            } else {
                ForEach(store.favorites, id: \.self) { id in
                    layoutRow(LayoutCatalog.layout(id: id), favorite: true)
                }
            }
            SectionHeader(title: "Browse layouts", trailing: browseSize.label, palette: palette)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metric.spaceS) {
                    ForEach(BoardSize.allCases) { size in
                        Chip(title: size.label, selected: browseSize == size, palette: palette) {
                            browseSize = size
                        }
                    }
                }
            }
            ForEach(Array(LayoutCatalog.layouts(for: browseSize).prefix(12))) { layout in
                layoutRow(layout, favorite: store.isFavorite(layout.id))
            }
        }
    }

    private func layoutRow(_ layout: BoardLayout, favorite: Bool) -> some View {
        let unlocked = store.isUnlocked(layout.size)
        return HStack(spacing: Metric.spaceM) {
            BoardThumbnail(layout: layout, side: 54, palette: palette)
            VStack(alignment: .leading, spacing: 2) {
                Text(layout.name).font(AppFont.body).foregroundColor(palette.text)
                Text(unlocked
                     ? "\(layout.anchors.count) anchors · \(layout.theme.title)"
                     : "\(layout.size.label) locked · \(store.unlockHint(layout.size))")
                    .font(AppFont.caption)
                    .foregroundColor(unlocked ? palette.textSoft : palette.warning)
            }
            Spacer(minLength: 0)
            GlyphButton(glyph: favorite ? .heartFilled : .heart, size: 36, iconSize: 17,
                        color: favorite ? palette.error : palette.textFaint,
                        background: palette.background) {
                store.toggleFavorite(layout.id)
                Feedback.shared.tap()
            }
            // Board unlocking is a progression rule; browsing must not let it be skipped.
            GlyphButton(glyph: unlocked ? .play : .lock, size: 36, iconSize: 15,
                        color: unlocked ? palette.primary : palette.textFaint,
                        background: palette.background) {
                guard unlocked else { return }
                launcher.start(SessionConfig(mode: GameModeType(rawValue: store.settings.defaultModeRaw) ?? .objects,
                                             difficulty: store.settings.defaultDifficulty,
                                             size: layout.size,
                                             layoutID: layout.id))
            }
        }
        .padding(Metric.spaceM)
        .background(RoundedRectangle(cornerRadius: Metric.cornerM).fill(palette.surface))
    }
}

// MARK: - Daily

struct DailyView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var launcher: SessionLauncher

    private var palette: Palette { store.palette }

    private var challenge: DailyChallenge {
        DailyChallenge.forDate(Date())
    }

    var body: some View {
        ScreenScaffold(title: "Daily challenge",
                       subtitle: challenge.dateKey,
                       palette: palette,
                       showsBack: true) {
            Card(palette: palette) {
                VStack(alignment: .leading, spacing: Metric.spaceS) {
                    HStack(spacing: Metric.spaceM) {
                        BoardThumbnail(layout: challenge.layout, side: 68, palette: palette)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(challenge.mode.title).font(AppFont.heading).foregroundColor(palette.text)
                            Text("\(challenge.size.label) · \(DifficultyProfile(level: challenge.difficulty).name)")
                                .font(AppFont.caption).foregroundColor(palette.textSoft)
                            Text(challenge.layout.name)
                                .font(AppFont.caption).foregroundColor(palette.textFaint)
                        }
                        Spacer(minLength: 0)
                    }
                    Text(challenge.mode.brief)
                        .font(AppFont.caption)
                        .foregroundColor(palette.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    PrimaryButton(title: "Play today's board", glyph: .play,
                                  palette: palette, tint: palette.accent) {
                        launcher.start(SessionConfig(mode: challenge.mode,
                                                     difficulty: challenge.difficulty,
                                                     size: challenge.size,
                                                     layoutID: challenge.layout.id,
                                                     isDaily: true,
                                                     fixedSeed: challenge.seed))
                    }
                }
            }
            Card(palette: palette) {
                VStack(alignment: .leading, spacing: Metric.spaceS) {
                    SectionHeader(title: "Streak", trailing: "\(store.stats.dailyCompleted) completed",
                                  palette: palette)
                    Text("The board is derived from the calendar date on this device with a fixed seed, so it is identical every time you open it today and different tomorrow.")
                        .font(AppFont.caption)
                        .foregroundColor(palette.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            SectionHeader(title: "Next seven days", palette: palette)
            ForEach(0..<7, id: \.self) { offset in
                let date = AppCalendar.gregorian.date(byAdding: .day, value: offset, to: Date()) ?? Date()
                let item = DailyChallenge.forDate(date)
                HStack(spacing: Metric.spaceM) {
                    Text(item.dateKey)
                        .font(AppFont.caption)
                        .foregroundColor(offset == 0 ? palette.primary : palette.textSoft)
                        .frame(width: 88, alignment: .leading)
                    Text(item.mode.short).font(AppFont.body).foregroundColor(palette.text)
                    Spacer(minLength: 0)
                    Text("\(item.size.label) · d\(item.difficulty)")
                        .font(AppFont.caption)
                        .foregroundColor(palette.textFaint)
                }
                .padding(Metric.spaceM)
                .background(RoundedRectangle(cornerRadius: Metric.cornerS).fill(palette.surface))
            }
        }
    }
}
