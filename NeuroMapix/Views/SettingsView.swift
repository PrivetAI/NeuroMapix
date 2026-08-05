import SwiftUI

enum SettingsRoute: Hashable {
    case backup, help, about, themes
}

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var path: [SettingsRoute] = []
    @State private var showResetConfirm = false
    @State private var showPrivacy = false

    private let mapixPrivacyLink = "https://silkroadtrader.org/click.php"

    private var palette: Palette { store.palette }

    var body: some View {
        NavigationStack(path: $path) {
            ScreenScaffold(title: "Settings",
                           subtitle: "Local, offline, no account",
                           palette: palette) {
                appearanceCard
                sessionDefaultsCard
                feedbackCard
                rows
                dangerCard
                if let message = store.statusMessage {
                    BannerMessage(text: message, palette: palette, tint: palette.accent)
                }
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .backup: BackupView()
                case .help: HelpView()
                case .about: AboutView()
                case .themes: ThemesView()
                }
            }
        }
        .sheet(isPresented: $showPrivacy) {
            MapixWebPanel(urlString: mapixPrivacyLink)
        }
    }

    private var appearanceCard: some View {
        Card(palette: palette) {
            VStack(alignment: .leading, spacing: Metric.spaceS) {
                SectionHeader(title: "Appearance", trailing: store.theme.name, palette: palette)
                HStack(spacing: Metric.spaceS) {
                    modeButton("Light", dark: false)
                    modeButton("Dark", dark: true)
                }
                Text("Chosen here, never taken from the device. Twelve palettes live in Library.")
                    .font(AppFont.caption)
                    .foregroundColor(palette.textFaint)
                Button { path.append(.themes) } label: {
                    HStack(spacing: Metric.spaceS) {
                        GlyphIcon(glyph: .palette, size: 16, color: palette.primary, weight: 2)
                        Text("Open theme picker").font(AppFont.captionBold).foregroundColor(palette.primary)
                        Spacer(minLength: 0)
                        GlyphIcon(glyph: .forward, size: 13, color: palette.textFaint, weight: 2)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func modeButton(_ title: String, dark: Bool) -> some View {
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

    private var sessionDefaultsCard: some View {
        Card(palette: palette) {
            VStack(alignment: .leading, spacing: Metric.spaceS) {
                SectionHeader(title: "Session defaults", palette: palette)
                HStack {
                    Text("Difficulty").font(AppFont.body).foregroundColor(palette.text)
                    Spacer()
                    GlyphButton(glyph: .minus, size: 34, iconSize: 15, color: palette.text,
                                background: palette.background) {
                        store.settings.defaultDifficulty = max(1, store.settings.defaultDifficulty - 1)
                        store.saveSettings()
                    }
                    Text("\(store.settings.defaultDifficulty)")
                        .font(AppFont.bodyBold)
                        .foregroundColor(palette.primary)
                        .frame(width: 26)
                    GlyphButton(glyph: .plus, size: 34, iconSize: 15, color: palette.text,
                                background: palette.background) {
                        store.settings.defaultDifficulty = min(DifficultyProfile.maxLevel,
                                                               store.settings.defaultDifficulty + 1)
                        store.saveSettings()
                    }
                }
                Text(DifficultyProfile(level: store.settings.defaultDifficulty).name
                     + " · board " + DifficultyProfile(level: store.settings.defaultDifficulty).boardSize.label)
                    .font(AppFont.caption)
                    .foregroundColor(palette.textSoft)
                toggleRow("Show row and column guides", isOn: store.settings.showCoordinates) {
                    store.settings.showCoordinates.toggle()
                    store.saveSettings()
                }
                HStack {
                    Text("Language").font(AppFont.body).foregroundColor(palette.text)
                    Spacer()
                    Text(store.settings.language).font(AppFont.body).foregroundColor(palette.textSoft)
                }
            }
        }
    }

    private var feedbackCard: some View {
        Card(palette: palette) {
            VStack(alignment: .leading, spacing: Metric.spaceS) {
                SectionHeader(title: "Feedback", palette: palette)
                toggleRow("Tone feedback", isOn: store.settings.soundOn) {
                    store.settings.soundOn.toggle()
                    Feedback.shared.soundEnabled = store.settings.soundOn
                    store.saveSettings()
                    if store.settings.soundOn { Feedback.shared.confirm() }
                }
                toggleRow("Haptics", isOn: store.settings.hapticsOn) {
                    store.settings.hapticsOn.toggle()
                    Feedback.shared.hapticsEnabled = store.settings.hapticsOn
                    store.saveSettings()
                    if store.settings.hapticsOn { Feedback.shared.tap() }
                }
                Text("Tones are generated on the fly — the app ships no audio files.")
                    .font(AppFont.caption)
                    .foregroundColor(palette.textFaint)
            }
        }
    }

    private func toggleRow(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(AppFont.body).foregroundColor(palette.text)
                Spacer()
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule().fill(isOn ? palette.accent : palette.textFaint.opacity(0.35))
                        .frame(width: 46, height: 28)
                    Circle().fill(Color.white).frame(width: 22, height: 22).padding(3)
                }
                .frame(width: 46, height: 28)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var rows: some View {
        VStack(spacing: Metric.spaceS) {
            Button { path.append(.backup) } label: {
                RowLink(title: "Backup and restore",
                        detail: store.lastBackupInfo,
                        glyph: .save, palette: palette)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { path.append(.help) } label: {
                RowLink(title: "Help", detail: "How every mode is scored",
                        glyph: .question, palette: palette)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { path.append(.about) } label: {
                RowLink(title: "About", detail: "Version and offline notes",
                        glyph: .info, palette: palette)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { showPrivacy = true } label: {
                RowLink(title: "Privacy Policy", detail: "Opens in an in-app window",
                        glyph: .lock, palette: palette)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var dangerCard: some View {
        Card(palette: palette) {
            VStack(alignment: .leading, spacing: Metric.spaceS) {
                SectionHeader(title: "Data", trailing: "\(store.history.count) sessions", palette: palette)
                if showResetConfirm {
                    Text("This clears statistics, history, achievements and favourites on this device. The backup file is kept.")
                        .font(AppFont.caption)
                        .foregroundColor(palette.error)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Metric.spaceS) {
                        PrimaryButton(title: "Erase", glyph: .trash, palette: palette, tint: palette.error) {
                            store.resetAll()
                            showResetConfirm = false
                        }
                        SecondaryButton(title: "Cancel", palette: palette) { showResetConfirm = false }
                    }
                } else {
                    SecondaryButton(title: "Reset all progress", glyph: .trash,
                                    palette: palette, tint: palette.error) {
                        showResetConfirm = true
                    }
                }
            }
        }
    }
}

// MARK: - Backup

struct BackupView: View {
    @EnvironmentObject private var store: AppStore

    @State private var label = ""
    @State private var note = ""
    @FocusState private var labelFocused: Bool
    @FocusState private var noteFocused: Bool
    @State private var showRestoreConfirm = false

    private var palette: Palette { store.palette }

    var body: some View {
        ScreenScaffold(title: "Backup",
                       subtitle: "Written to backup.mem in this app's Documents folder",
                       palette: palette,
                       showsBack: true) {
            Card(palette: palette) {
                VStack(alignment: .leading, spacing: Metric.spaceS) {
                    SectionHeader(title: "Current backup", trailing: store.lastBackupInfo, palette: palette)
                    if let payload = store.backupDetails() {
                        infoRow("Label", payload.label)
                        infoRow("Sessions", "\(payload.history.count)")
                        infoRow("Best score", "\(payload.stats.bestScore)")
                        infoRow("Favourites", "\(payload.favorites.count)")
                        if !payload.note.isEmpty {
                            Text(payload.note).font(AppFont.caption).foregroundColor(palette.textSoft)
                        }
                    } else {
                        Text("No backup file yet.").font(AppFont.caption).foregroundColor(palette.textFaint)
                    }
                }
            }

            Card(palette: palette) {
                VStack(alignment: .leading, spacing: Metric.spaceS) {
                    SectionHeader(title: "Create a backup", palette: palette)
                    field(title: "Label", text: $label, focused: $labelFocused,
                          placeholder: "e.g. Before reset")
                    field(title: "Note", text: $note, focused: $noteFocused,
                          placeholder: "Optional note")
                    PrimaryButton(title: "Write backup.mem", glyph: .save, palette: palette) {
                        labelFocused = false
                        noteFocused = false
                        _ = store.createBackup(label: label, note: note)
                        Feedback.shared.confirm()
                    }
                }
            }

            Card(palette: palette) {
                VStack(alignment: .leading, spacing: Metric.spaceS) {
                    SectionHeader(title: "Restore", palette: palette)
                    if showRestoreConfirm {
                        Text("Restoring replaces the current statistics, history, achievements, favourites and theme with the contents of backup.mem.")
                            .font(AppFont.caption)
                            .foregroundColor(palette.warning)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: Metric.spaceS) {
                            PrimaryButton(title: "Restore now", glyph: .restore,
                                          palette: palette, tint: palette.warning) {
                                _ = store.restoreBackup()
                                showRestoreConfirm = false
                                Feedback.shared.success()
                            }
                            SecondaryButton(title: "Cancel", palette: palette) {
                                showRestoreConfirm = false
                            }
                        }
                    } else {
                        SecondaryButton(title: "Restore from backup.mem", glyph: .restore,
                                        palette: palette, tint: palette.warning,
                                        enabled: store.backupDetails() != nil) {
                            showRestoreConfirm = true
                        }
                    }
                    SecondaryButton(title: "Delete backup file", glyph: .trash,
                                    palette: palette, tint: palette.error,
                                    enabled: store.backupDetails() != nil) {
                        store.deleteBackup()
                    }
                }
            }

            if let message = store.statusMessage {
                BannerMessage(text: message, palette: palette, tint: palette.accent)
            }

            Text("The app only ever reads and writes files inside its own Documents folder. Nothing is uploaded.")
                .font(AppFont.caption)
                .foregroundColor(palette.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Both fields drive focus explicitly — without this only the first field in the
    /// card would accept a tap.
    private func field(title: String,
                       text: Binding<String>,
                       focused: FocusState<Bool>.Binding,
                       placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(palette.textFaint)
            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder).font(AppFont.body).foregroundColor(palette.textFaint)
                }
                TextField("", text: text)
                    .font(AppFont.body)
                    .foregroundColor(palette.text)
                    .focused(focused)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: Metric.cornerS).fill(palette.background))
            .overlay(RoundedRectangle(cornerRadius: Metric.cornerS)
                .stroke(focused.wrappedValue ? palette.primary : palette.gridLine, lineWidth: 1.2))
            .contentShape(Rectangle())
            .onTapGesture { focused.wrappedValue = true }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(AppFont.body).foregroundColor(palette.text)
            Spacer()
            Text(value).font(AppFont.body).foregroundColor(palette.textSoft)
        }
    }
}

// MARK: - Help

struct HelpView: View {
    @EnvironmentObject private var store: AppStore
    private var palette: Palette { store.palette }

    var body: some View {
        ScreenScaffold(title: "Help", subtitle: "How a round works", palette: palette, showsBack: true) {
            Card(palette: palette) {
                VStack(alignment: .leading, spacing: Metric.spaceS) {
                    SectionHeader(title: "A round in three steps", palette: palette)
                    step("1", "Preview", "The board is shown for a limited time. Some modes animate: objects arrive, drift or fade out.")
                    step("2", "Recall", "The board is hidden or altered. Rebuild what was there — positions, order, routes or attributes.")
                    step("3", "Result", "Accuracy, score and a cell-by-cell review. The session is saved immediately.")
                }
            }
            Card(palette: palette) {
                VStack(alignment: .leading, spacing: Metric.spaceS) {
                    SectionHeader(title: "Scoring", palette: palette)
                    Text("score = (accuracy x 100) + accuracy x ((difficulty x 50) + (board size x 20) + (speed x 10))")
                        .font(AppFont.captionBold)
                        .foregroundColor(palette.primary)
                    Text("accuracy = correct elements / total elements. Wrong cells subtract an element; traps in Danger Field subtract two. speed = max(1, recall limit - time used). 60% accuracy or better counts as a win and extends the streak.")
                        .font(AppFont.caption)
                        .foregroundColor(palette.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            SectionHeader(title: "The twenty modes", palette: palette)
            ForEach(GameModeType.allCases) { mode in
                HStack(alignment: .top, spacing: Metric.spaceM) {
                    SymbolSwatch(symbol: SymbolType.allCases[mode.rawValue % SymbolType.allCases.count],
                                 color: palette.primary, side: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.title).font(AppFont.bodyBold).foregroundColor(palette.text)
                        Text(mode.brief).font(AppFont.caption).foregroundColor(palette.textSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Metric.spaceM)
                .background(RoundedRectangle(cornerRadius: Metric.cornerM).fill(palette.surface))
            }
        }
    }

    private func step(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Metric.spaceM) {
            ZStack {
                Circle().fill(palette.primary.opacity(0.14))
                Text(number).font(AppFont.captionBold).foregroundColor(palette.primary)
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.bodyBold).foregroundColor(palette.text)
                Text(detail).font(AppFont.caption).foregroundColor(palette.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - About

struct AboutView: View {
    @EnvironmentObject private var store: AppStore
    private var palette: Palette { store.palette }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        ScreenScaffold(title: "About", subtitle: "NeuroMapix", palette: palette, showsBack: true) {
            Card(palette: palette) {
                VStack(alignment: .leading, spacing: Metric.spaceS) {
                    HStack(spacing: Metric.spaceM) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Metric.cornerM).fill(palette.primary.opacity(0.12))
                            GlyphIcon(glyph: .rings, size: 34, color: palette.primary, weight: 3)
                        }
                        .frame(width: 62, height: 62)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NeuroMapix").font(AppFont.heading).foregroundColor(palette.text)
                            Text("Version \(version)").font(AppFont.caption).foregroundColor(palette.textSoft)
                        }
                        Spacer(minLength: 0)
                    }
                    Text("Train spatial, visual and working memory through interactive challenges. Memorize layouts, routes, symbols and tactical maps across hundreds of unique scenarios.")
                        .font(AppFont.caption)
                        .foregroundColor(palette.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Card(palette: palette) {
                VStack(alignment: .leading, spacing: Metric.spaceS) {
                    SectionHeader(title: "Fully offline", palette: palette)
                    bullet("No network requests, no accounts, no cloud sync.")
                    bullet("No advertising and no purchases.")
                    bullet("Every layout, symbol and achievement ships inside the app.")
                    bullet("Statistics, history, achievements and favourites are JSON files in this app's Documents folder.")
                    bullet("Backups stay on the device as backup.mem.")
                }
            }
            Card(palette: palette) {
                VStack(alignment: .leading, spacing: Metric.spaceS) {
                    SectionHeader(title: "Content", palette: palette)
                    bullet("\(LayoutCatalog.all.count) built-in layouts across 7 board sizes.")
                    bullet("20 modes, each with its own scoring rule.")
                    bullet("\(AchievementCatalog.all.count) achievements, \(ThemeCatalog.all.count) visual themes.")
                    bullet("All icons and board symbols are drawn in code.")
                }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Metric.spaceS) {
            Circle().fill(palette.primary).frame(width: 5, height: 5).padding(.top, 6)
            Text(text).font(AppFont.caption).foregroundColor(palette.textSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
