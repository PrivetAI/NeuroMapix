import SwiftUI
import WebKit

/// Web container used both by the launch gate (fullscreen) and by the privacy
/// entry in Settings (sheet). The frame is what keeps content clear of the
/// notch — the inset behaviour below is only belt-and-suspenders.
struct MapixWebPanel: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    /// Intentionally empty: reloading here would restart the page on every
    /// SwiftUI re-render.
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
