import SwiftUI

/// Shown while the launch check resolves, before either the trainer or the web
/// panel takes over. Colours are pinned to the reference palette so this screen
/// never depends on stored settings or on the device appearance.
struct MapixLoadingScreen: View {
    @State private var spin = false

    private let backdrop = Color(rgb: 0xFFFFFF)
    private let primary = Color(rgb: 0x3454D1)
    private let label = Color(rgb: 0x1A1A1A)
    private let labelSoft = Color(rgb: 0x5A5F66)

    var body: some View {
        ZStack {
            backdrop.ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(primary.opacity(0.14), lineWidth: 8)
                        .frame(width: 104, height: 104)
                    Circle()
                        .trim(from: 0, to: 0.22)
                        .stroke(primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 104, height: 104)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                    GlyphIcon(glyph: .rings, size: 44, color: primary, weight: 3)
                }
                VStack(spacing: 6) {
                    Text("NeuroMapix")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(label)
                    Text("Preparing your session")
                        .font(.system(size: 14))
                        .foregroundColor(labelSoft)
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
    }
}
