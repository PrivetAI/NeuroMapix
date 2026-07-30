import SwiftUI

struct GameSetupView: View {
    @EnvironmentObject private var store: AppStore
    let onStart: (SessionConfig) -> Void

    @State private var mode: GameModeType = .objects
    @State private var difficulty: Int = 2
    @State private var size: BoardSize = .x4
    @State private var layoutID: Int = 0
    @State private var loaded = false

    private var palette: Palette { store.palette }
    private var profile: DifficultyProfile { DifficultyProfile(level: difficulty) }
    private var layout: BoardLayout { LayoutCatalog.layout(id: layoutID) }

    var body: some View {
        ScreenScaffold(title: "Session setup",
                       subtitle: "\(LayoutCatalog.all.count) built-in layouts · 20 modes",
                       palette: palette,
                       showsBack: true) {
            modeSection
            difficultySection
            boardSection
            layoutSection
            PrimaryButton(title: "Begin session", glyph: .play, palette: palette) {
                store.settings.defaultModeRaw = mode.rawValue
                store.settings.defaultDifficulty = difficulty
                store.settings.defaultSizeRaw = size.rawValue
                store.saveSettings()
                onStart(SessionConfig(mode: mode, difficulty: difficulty,
                                      size: size, layoutID: layoutID))
            }
            .padding(.top, Metric.spaceS)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            mode = GameModeType(rawValue: store.settings.defaultModeRaw) ?? .objects
            difficulty = min(max(store.settings.defaultDifficulty, 1), DifficultyProfile.maxLevel)
            let stored = BoardSize(rawValue: store.settings.defaultSizeRaw) ?? .x4
            size = store.isUnlocked(stored) ? stored : (BoardSize.allCases.last { store.isUnlocked($0) } ?? .x3)
            pickLayout()
        }
    }

    private func pickLayout() {
        let candidates = LayoutCatalog.layouts(for: size)
        let favourite = candidates.first { store.isFavorite($0.id) }
        layoutID = (favourite ?? candidates.randomElement() ?? LayoutCatalog.all[0]).id
    }

    // MARK: - Mode

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: Metric.spaceS) {
            SectionHeader(title: "Mode", trailing: mode.title, palette: palette)
            Card(palette: palette) {
                Text(mode.brief)
                    .font(AppFont.caption)
                    .foregroundColor(palette.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Metric.spaceS), count: 2),
                      spacing: Metric.spaceS) {
                ForEach(GameModeType.allCases) { item in
                    Button {
                        mode = item
                        Feedback.shared.tap()
                    } label: {
                        HStack(spacing: 8) {
                            SymbolSwatch(symbol: SymbolType.allCases[item.rawValue % SymbolType.allCases.count],
                                         color: mode == item ? .white : palette.primary,
                                         side: 20)
                            Text(item.short)
                                .font(AppFont.captionBold)
                                .foregroundColor(mode == item ? .white : palette.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: Metric.cornerS)
                            .fill(mode == item ? palette.primary : palette.surface))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Difficulty

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: Metric.spaceS) {
            SectionHeader(title: "Difficulty", trailing: "\(difficulty) · \(profile.name)", palette: palette)
            Card(palette: palette) {
                VStack(alignment: .leading, spacing: Metric.spaceS) {
                    HStack(spacing: Metric.spaceS) {
                        GlyphButton(glyph: .minus, size: 40, iconSize: 18,
                                    color: palette.text, background: palette.background) {
                            difficulty = max(DifficultyProfile.minLevel, difficulty - 1)
                            syncSize()
                        }
                        HStack(spacing: 4) {
                            ForEach(1...DifficultyProfile.maxLevel, id: \.self) { level in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(level <= difficulty ? palette.primary : palette.primary.opacity(0.15))
                                    .frame(height: 12)
                            }
                        }
                        GlyphButton(glyph: .plus, size: 40, iconSize: 18,
                                    color: palette.text, background: palette.background) {
                            difficulty = min(DifficultyProfile.maxLevel, difficulty + 1)
                            syncSize()
                        }
                    }
                    HStack(spacing: Metric.spaceM) {
                        detail("Objects", "\(profile.objectCount)")
                        detail("Preview", String(format: "%.1fs", profile.previewSeconds))
                        detail("Decoys", "\(profile.decoyCount)")
                        detail("Recall", String(format: "%.0fs", profile.timeLimit))
                    }
                    Text("Difficulty scales the board, object count, preview time, animation speed, stage count, decoys, mirroring, rotation and moving elements together.")
                        .font(AppFont.caption)
                        .foregroundColor(palette.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(palette.textFaint)
            Text(value).font(AppFont.captionBold).foregroundColor(palette.text)
        }
    }

    private func syncSize() {
        let recommended = profile.boardSize
        if store.isUnlocked(recommended) { size = recommended }
        pickLayout()
    }

    // MARK: - Board

    private var boardSection: some View {
        VStack(alignment: .leading, spacing: Metric.spaceS) {
            SectionHeader(title: "Board", trailing: size.label, palette: palette)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metric.spaceS) {
                    ForEach(BoardSize.allCases) { item in
                        let unlocked = store.isUnlocked(item)
                        Button {
                            guard unlocked else { return }
                            size = item
                            pickLayout()
                            Feedback.shared.tap()
                        } label: {
                            VStack(spacing: 3) {
                                if unlocked {
                                    Text(item.label)
                                        .font(AppFont.captionBold)
                                        .foregroundColor(size == item ? .white : palette.text)
                                } else {
                                    GlyphIcon(glyph: .lock, size: 16, color: palette.textFaint, weight: 1.8)
                                }
                                Text(unlocked
                                     ? "\(item.cellCount) cells"
                                     : "+\(max(0, item.unlockGames - store.stats.totalGames)) plays")
                                    .font(.system(size: 9))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .foregroundColor(size == item ? .white.opacity(0.8) : palette.textFaint)
                            }
                            .frame(width: 74, height: 50)
                            .background(RoundedRectangle(cornerRadius: Metric.cornerS)
                                .fill(size == item ? palette.primary : palette.surface))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!unlocked)
                    }
                }
            }
            if !store.isUnlocked(.x10) {
                Text("Bigger boards unlock as you finish sessions.")
                    .font(AppFont.caption)
                    .foregroundColor(palette.textFaint)
            }
        }
    }

    // MARK: - Layout

    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: Metric.spaceS) {
            SectionHeader(title: "Layout", trailing: layout.name, palette: palette)
            Card(palette: palette) {
                HStack(spacing: Metric.spaceM) {
                    BoardThumbnail(layout: layout, side: 68, palette: palette)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(layout.pattern.title)
                            .font(AppFont.bodyBold)
                            .foregroundColor(palette.text)
                        Text("\(layout.anchors.count) anchor cells · \(layout.theme.title) set")
                            .font(AppFont.caption)
                            .foregroundColor(palette.textSoft)
                        Text("Layout #\(layout.id + 1) of \(LayoutCatalog.all.count)")
                            .font(AppFont.caption)
                            .foregroundColor(palette.textFaint)
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: Metric.spaceS) {
                        GlyphButton(glyph: .shuffle, size: 38, iconSize: 18,
                                    color: palette.primary, background: palette.background) {
                            let candidates = LayoutCatalog.layouts(for: size).filter { $0.id != layoutID }
                            layoutID = (candidates.randomElement() ?? layout).id
                            Feedback.shared.tap()
                        }
                        GlyphButton(glyph: store.isFavorite(layoutID) ? .heartFilled : .heart,
                                    size: 38, iconSize: 18,
                                    color: store.isFavorite(layoutID) ? palette.error : palette.textSoft,
                                    background: palette.background) {
                            store.toggleFavorite(layoutID)
                            Feedback.shared.tap()
                        }
                    }
                }
            }
        }
    }
}
