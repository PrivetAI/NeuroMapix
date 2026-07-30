import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var group: String? = nil
    @State private var showLockedOnly = false

    private var palette: Palette { store.palette }

    private var filtered: [Achievement] {
        store.achievements.filter { item in
            (group == nil || item.group == group) && (!showLockedOnly || !item.unlocked)
        }
    }

    var body: some View {
        NavigationStack {
            ScreenScaffold(title: "Achievements",
                           subtitle: "\(store.unlockedCount) of \(store.achievements.count) unlocked",
                           palette: palette) {
                progressCard
                filters
                ForEach(filtered) { item in
                    row(item)
                }
                if filtered.isEmpty {
                    BannerMessage(text: "Nothing matches this filter.", palette: palette, tint: palette.primary)
                }
            }
        }
    }

    private var progressCard: some View {
        Card(palette: palette) {
            HStack(spacing: Metric.spaceL) {
                ProgressRing(progress: store.achievements.isEmpty ? 0
                             : Double(store.unlockedCount) / Double(store.achievements.count),
                             lineWidth: 9,
                             color: palette.warning,
                             track: palette.warning.opacity(0.14),
                             side: 92,
                             centerText: "\(store.unlockedCount)",
                             caption: "UNLOCKED",
                             textColor: palette.text)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(store.achievements.count) local achievements")
                        .font(AppFont.bodyBold)
                        .foregroundColor(palette.text)
                    Text("Every condition is checked against your own saved statistics. Nothing is fetched from a server.")
                        .font(AppFont.caption)
                        .foregroundColor(palette.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: Metric.spaceS) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metric.spaceS) {
                    Chip(title: "All", selected: group == nil, palette: palette) { group = nil }
                    ForEach(AchievementCatalog.groups, id: \.self) { name in
                        Chip(title: name, selected: group == name, palette: palette) { group = name }
                    }
                }
            }
            Chip(title: showLockedOnly ? "Showing locked only" : "Showing everything",
                 selected: showLockedOnly, palette: palette, tint: palette.warning) {
                showLockedOnly.toggle()
            }
        }
    }

    private func row(_ item: Achievement) -> some View {
        HStack(spacing: Metric.spaceM) {
            ZStack {
                RoundedRectangle(cornerRadius: Metric.cornerS)
                    .fill((item.unlocked ? palette.warning : palette.textFaint).opacity(0.14))
                GlyphIcon(glyph: item.unlocked ? .trophy : .lock,
                          size: 18,
                          color: item.unlocked ? palette.warning : palette.textFaint,
                          weight: 2)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(AppFont.body)
                    .foregroundColor(item.unlocked ? palette.text : palette.textSoft)
                Text(item.detail)
                    .font(AppFont.caption)
                    .foregroundColor(palette.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text(item.group)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(palette.textFaint)
        }
        .padding(Metric.spaceM)
        .background(RoundedRectangle(cornerRadius: Metric.cornerM).fill(palette.surface))
    }
}
