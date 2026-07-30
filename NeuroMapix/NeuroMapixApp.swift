import SwiftUI

@main
struct NeuroMapixApp: App {
    @StateObject private var store = AppStore()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView(palette: store.palette)
                        .transition(.opacity)
                } else {
                    RootView()
                        .environmentObject(store)
                        .transition(.opacity)
                }
            }
            .environmentObject(store)
            // Always explicit, so the app never follows the device appearance.
            .preferredColorScheme(store.settings.darkMode ? .dark : .light)
            .onAppear {
                Feedback.shared.soundEnabled = store.settings.soundOn
                Feedback.shared.hapticsEnabled = store.settings.hapticsOn
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.35)) { showSplash = false }
                }
            }
        }
    }
}
