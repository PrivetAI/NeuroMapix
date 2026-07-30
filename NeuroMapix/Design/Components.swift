import SwiftUI

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var glyph: Glyph? = nil
    var palette: Palette
    var tint: Color? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: Metric.spaceS) {
                if let glyph {
                    GlyphIcon(glyph: glyph, size: 20, color: .white, weight: 2.1)
                }
                Text(title)
                    .font(AppFont.bodyBold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: Metric.cornerS)
                    .fill((tint ?? palette.primary).opacity(enabled ? 1 : 0.35))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct SecondaryButton: View {
    let title: String
    var glyph: Glyph? = nil
    var palette: Palette
    var tint: Color? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: Metric.spaceS) {
                if let glyph {
                    GlyphIcon(glyph: glyph, size: 18, color: tint ?? palette.primary, weight: 2)
                }
                Text(title)
                    .font(AppFont.bodyBold)
                    .foregroundColor(tint ?? palette.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: Metric.cornerS)
                    .stroke((tint ?? palette.primary).opacity(enabled ? 0.55 : 0.2), lineWidth: 1.4)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// A glyph-only button. The sized label always gets `.contentShape(Rectangle())`,
/// otherwise the Canvas drawing alone is not hit-testable.
struct GlyphButton: View {
    let glyph: Glyph
    var size: CGFloat = 40
    var iconSize: CGFloat = 20
    var color: Color
    var background: Color? = nil
    var weight: CGFloat = 2
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if let background {
                    RoundedRectangle(cornerRadius: Metric.cornerS).fill(background)
                }
                GlyphIcon(glyph: glyph, size: iconSize, color: color, weight: weight)
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Containers

struct Card<Content: View>: View {
    var palette: Palette
    var padding: CGFloat = Metric.spaceM
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Metric.cornerM).fill(palette.surface)
            )
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var palette: Palette

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(AppFont.captionBold)
                .tracking(1.1)
                .foregroundColor(palette.textSoft)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(AppFont.caption)
                    .foregroundColor(palette.textFaint)
            }
        }
    }
}

/// Every screen uses this: hidden system nav bar, custom header, scrolling body.
struct ScreenScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var palette: Palette
    var showsBack: Bool = false
    var trailing: AnyView? = nil
    var scrolls: Bool = true
    var bottomInset: CGFloat = Metric.spaceL
    @ViewBuilder var content: () -> Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: Metric.spaceS) {
                if showsBack {
                    GlyphButton(glyph: .back, size: 38, iconSize: 18, color: palette.text) {
                        dismiss()
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.title)
                        .foregroundColor(palette.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppFont.caption)
                            .foregroundColor(palette.textSoft)
                    }
                }
                Spacer(minLength: 0)
                if let trailing { trailing }
            }
            .padding(.horizontal, Metric.spaceM)
            .padding(.top, Metric.spaceS)
            .padding(.bottom, Metric.spaceM)

            if scrolls {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Metric.spaceM) {
                        content()
                    }
                    .padding(.horizontal, Metric.spaceM)
                    .padding(.bottom, bottomInset)
                }
            } else {
                VStack(alignment: .leading, spacing: Metric.spaceM) {
                    content()
                }
                .padding(.horizontal, Metric.spaceM)
                .padding(.bottom, bottomInset)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Small pieces

struct StatTile: View {
    let label: String
    let value: String
    var glyph: Glyph? = nil
    var tint: Color? = nil
    var palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let glyph {
                    GlyphIcon(glyph: glyph, size: 14, color: tint ?? palette.primary, weight: 1.8)
                }
                Text(label.uppercased())
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .foregroundColor(palette.textSoft)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(Metric.spaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metric.cornerM).fill(palette.surface))
    }
}

struct Chip: View {
    let title: String
    var selected: Bool = false
    var palette: Palette
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.captionBold)
                .foregroundColor(selected ? .white : (tint ?? palette.text).opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(selected ? (tint ?? palette.primary) : palette.surface)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 8
    var color: Color
    var track: Color
    var side: CGFloat = 84
    var centerText: String
    var caption: String?
    var textColor: Color

    var body: some View {
        ZStack {
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
                context.stroke(Path(ellipseIn: rect), with: .color(track),
                               style: StrokeStyle(lineWidth: lineWidth))
                var arc = Path()
                arc.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                           radius: rect.width / 2,
                           startAngle: .degrees(-90),
                           endAngle: .degrees(-90 + 360 * max(0, min(1, progress))),
                           clockwise: false)
                context.stroke(arc, with: .color(color),
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
            VStack(spacing: 0) {
                Text(centerText)
                    .font(.system(size: side * 0.28, weight: .bold, design: .rounded))
                    .foregroundColor(textColor)
                if let caption {
                    Text(caption)
                        .font(.system(size: side * 0.13, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.6))
                }
            }
        }
        .frame(width: side, height: side)
    }
}

struct RowLink<Trailing: View>: View {
    let title: String
    var detail: String? = nil
    var glyph: Glyph
    var palette: Palette
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Metric.spaceM) {
            ZStack {
                RoundedRectangle(cornerRadius: Metric.cornerS)
                    .fill(palette.primary.opacity(0.12))
                GlyphIcon(glyph: glyph, size: 20, color: palette.primary, weight: 2)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.body).foregroundColor(palette.text)
                if let detail {
                    Text(detail).font(AppFont.caption).foregroundColor(palette.textSoft)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(Metric.spaceM)
        .background(RoundedRectangle(cornerRadius: Metric.cornerM).fill(palette.surface))
    }
}

extension RowLink where Trailing == AnyView {
    init(title: String, detail: String? = nil, glyph: Glyph, palette: Palette) {
        self.init(title: title, detail: detail, glyph: glyph, palette: palette) {
            AnyView(GlyphIcon(glyph: .forward, size: 16, color: palette.textFaint, weight: 2))
        }
    }
}

struct BannerMessage: View {
    let text: String
    var palette: Palette
    var tint: Color

    var body: some View {
        HStack(spacing: Metric.spaceS) {
            GlyphIcon(glyph: .info, size: 16, color: tint, weight: 1.8)
            Text(text).font(AppFont.caption).foregroundColor(palette.text)
            Spacer(minLength: 0)
        }
        .padding(Metric.spaceS + 2)
        .background(RoundedRectangle(cornerRadius: Metric.cornerS).fill(tint.opacity(0.14)))
    }
}
