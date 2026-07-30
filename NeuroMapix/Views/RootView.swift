import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var launcher = SessionLauncher()
    @State private var tab = 0

    private var palette: Palette { store.palette }

    private let tabs: [(Glyph, String)] = [
        (.home, "Home"),
        (.chart, "Stats"),
        (.trophy, "Awards"),
        (.book, "Library"),
        (.gear, "Settings")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch tab {
                case 0: HomeView()
                case 1: StatisticsView()
                case 2: AchievementsView()
                case 3: LibraryView()
                default: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background(palette.background.ignoresSafeArea())
        .environmentObject(launcher)
        .fullScreenCover(isPresented: $launcher.isPresented) {
            if let config = launcher.config {
                GameView(config: config,
                         onExit: { launcher.close() },
                         onReplay: { launcher.replay() })
                    .id(launcher.token)
                    .environmentObject(store)
                    .environmentObject(launcher)
            }
        }
    }

    /// Custom tab bar: an HStack of Buttons plus a switch on the selected index.
    /// SwiftUI's TabView cannot render Canvas-drawn icons.
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { pair in
                let index = pair.offset
                let item = pair.element
                Button {
                    if tab != index {
                        tab = index
                        Feedback.shared.tap()
                    }
                } label: {
                    VStack(spacing: 3) {
                        GlyphIcon(glyph: item.0,
                                  size: 22,
                                  color: tab == index ? palette.primary : palette.text.opacity(0.42),
                                  weight: tab == index ? 2.3 : 1.9)
                        Text(item.1)
                            .font(.system(size: 10, weight: tab == index ? .semibold : .regular))
                            .foregroundColor(tab == index ? palette.primary : palette.text.opacity(0.42))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Metric.tabBarHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            palette.surface
                .overlay(Rectangle().fill(palette.gridLine).frame(height: 0.7), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct SplashView: View {
    let palette: Palette
    @State private var pulse = false

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            VStack(spacing: Metric.spaceL) {
                ZStack {
                    Circle()
                        .stroke(palette.primary.opacity(0.16), lineWidth: 10)
                        .frame(width: 148, height: 148)
                    Circle()
                        .trim(from: 0, to: pulse ? 1 : 0.08)
                        .stroke(palette.primary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 148, height: 148)
                        .rotationEffect(.degrees(-90))
                    GlyphIcon(glyph: .rings, size: 66, color: palette.primary, weight: 4)
                }
                VStack(spacing: 6) {
                    Text("NeuroMapix")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(palette.text)
                    Text("Offline memory training")
                        .font(AppFont.body)
                        .foregroundColor(palette.textSoft)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1)) { pulse = true }
        }
    }
}
