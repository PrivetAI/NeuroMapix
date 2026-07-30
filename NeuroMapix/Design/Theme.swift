import SwiftUI

extension Color {
    init(rgb: UInt32) {
        self.init(.sRGB,
                  red: Double((rgb >> 16) & 0xFF) / 255.0,
                  green: Double((rgb >> 8) & 0xFF) / 255.0,
                  blue: Double(rgb & 0xFF) / 255.0,
                  opacity: 1.0)
    }
}

struct VisualTheme: Identifiable, Hashable {
    let id: Int
    let name: String
    let note: String
    let primary: UInt32
    let accent: UInt32
    let warning: UInt32
    let error: UInt32
    let lightBackground: UInt32
    let lightSurface: UInt32
    let lightText: UInt32
    let darkBackground: UInt32
    let darkSurface: UInt32
    let darkText: UInt32
}

enum ThemeCatalog {
    /// Theme 0 is the specification palette, untouched. The other eleven keep the same
    /// structure and swap the hues.
    static let all: [VisualTheme] = [
        VisualTheme(id: 0, name: "Cobalt Base", note: "The reference palette",
                    primary: 0x3454D1, accent: 0x38B66B, warning: 0xF9A825, error: 0xD32F2F,
                    lightBackground: 0xFFFFFF, lightSurface: 0xF2F4FA, lightText: 0x1A1A1A,
                    darkBackground: 0x121212, darkSurface: 0x1E2129, darkText: 0xF5F5F5),
        VisualTheme(id: 1, name: "Slate Ink", note: "Low contrast, quiet",
                    primary: 0x4A5A78, accent: 0x5FA88A, warning: 0xE0A33A, error: 0xC0483F,
                    lightBackground: 0xFBFBFC, lightSurface: 0xEDEFF3, lightText: 0x1C2027,
                    darkBackground: 0x131519, darkSurface: 0x1F242C, darkText: 0xEFF1F4),
        VisualTheme(id: 2, name: "Forest Line", note: "Green primary",
                    primary: 0x2E7D5B, accent: 0x8CC152, warning: 0xE8A33D, error: 0xC94F4F,
                    lightBackground: 0xFCFDFB, lightSurface: 0xEBF2ED, lightText: 0x172019,
                    darkBackground: 0x101512, darkSurface: 0x1B241E, darkText: 0xF0F5F1),
        VisualTheme(id: 3, name: "Amber Draft", note: "Warm, high energy",
                    primary: 0xC77A16, accent: 0x3E9E7C, warning: 0xF3C13A, error: 0xC24338,
                    lightBackground: 0xFFFDF8, lightSurface: 0xF6EEDE, lightText: 0x231A0C,
                    darkBackground: 0x161210, darkSurface: 0x241C15, darkText: 0xF7F1E6),
        VisualTheme(id: 4, name: "Crimson Grid", note: "Bold and direct",
                    primary: 0xB03246, accent: 0x3F9B8E, warning: 0xE8A32F, error: 0xD32F2F,
                    lightBackground: 0xFFFBFC, lightSurface: 0xF6E9EC, lightText: 0x210F13,
                    darkBackground: 0x161011, darkSurface: 0x241819, darkText: 0xF7ECEE),
        VisualTheme(id: 5, name: "Violet Field", note: "Cool and deep",
                    primary: 0x6C46C4, accent: 0x4FBFA0, warning: 0xEFB13B, error: 0xC9445A,
                    lightBackground: 0xFDFCFF, lightSurface: 0xEFEBF9, lightText: 0x1A1526,
                    darkBackground: 0x121017, darkSurface: 0x1E1A29, darkText: 0xF2EFFA),
        VisualTheme(id: 6, name: "Teal Chart", note: "Clean and analytic",
                    primary: 0x11737C, accent: 0x62B23F, warning: 0xE7A82C, error: 0xC2493D,
                    lightBackground: 0xFAFEFE, lightSurface: 0xE6F2F3, lightText: 0x0F1D1F,
                    darkBackground: 0x0F1415, darkSurface: 0x182224, darkText: 0xEAF5F6),
        VisualTheme(id: 7, name: "Copper Plate", note: "Muted metal",
                    primary: 0x9C5B33, accent: 0x6D9E52, warning: 0xDFA33C, error: 0xB84438,
                    lightBackground: 0xFFFCFA, lightSurface: 0xF3EAE3, lightText: 0x211711,
                    darkBackground: 0x15110F, darkSurface: 0x231B16, darkText: 0xF5EDE6),
        VisualTheme(id: 8, name: "Indigo Night", note: "Built for dark mode",
                    primary: 0x3D4CB8, accent: 0x3FB0C4, warning: 0xE9B94A, error: 0xCB4A5C,
                    lightBackground: 0xFBFCFF, lightSurface: 0xE9ECF7, lightText: 0x141726,
                    darkBackground: 0x0E1018, darkSurface: 0x181C2A, darkText: 0xEEF1FA),
        VisualTheme(id: 9, name: "Moss Stone", note: "Earthy and calm",
                    primary: 0x5C7346, accent: 0xA3B85C, warning: 0xD9A845, error: 0xB6544A,
                    lightBackground: 0xFCFDF9, lightSurface: 0xEEF1E5, lightText: 0x1B2015,
                    darkBackground: 0x121410, darkSurface: 0x1E221A, darkText: 0xF1F4EB),
        VisualTheme(id: 10, name: "Rose Quartz", note: "Soft and light",
                    primary: 0xA84C79, accent: 0x54A9A0, warning: 0xE8AE49, error: 0xC44B57,
                    lightBackground: 0xFFFBFD, lightSurface: 0xF6E9F0, lightText: 0x221118,
                    darkBackground: 0x161014, darkSurface: 0x24181F, darkText: 0xF8ECF2),
        VisualTheme(id: 11, name: "Graphite", note: "Neutral monochrome",
                    primary: 0x565C66, accent: 0x8A9099, warning: 0xB89A5C, error: 0xA65450,
                    lightBackground: 0xFFFFFF, lightSurface: 0xEFEFF1, lightText: 0x1A1A1A,
                    darkBackground: 0x121212, darkSurface: 0x1F1F21, darkText: 0xF5F5F5)
    ]

    static func theme(id: Int) -> VisualTheme {
        all.first { $0.id == id } ?? all[0]
    }
}

struct Palette {
    let theme: VisualTheme
    let isDark: Bool

    var primary: Color { Color(rgb: theme.primary) }
    var accent: Color { Color(rgb: theme.accent) }
    var warning: Color { Color(rgb: theme.warning) }
    var error: Color { Color(rgb: theme.error) }
    var background: Color { Color(rgb: isDark ? theme.darkBackground : theme.lightBackground) }
    var surface: Color { Color(rgb: isDark ? theme.darkSurface : theme.lightSurface) }
    var text: Color { Color(rgb: isDark ? theme.darkText : theme.lightText) }
    var textSoft: Color { text.opacity(0.62) }
    var textFaint: Color { text.opacity(0.38) }
    var gridLine: Color { text.opacity(isDark ? 0.16 : 0.12) }
    var boardBase: Color { isDark ? Color(rgb: theme.darkSurface) : Color(rgb: theme.lightSurface) }
    var cellFill: Color { isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.02) }

    func color(for type: ColorType) -> Color {
        switch type {
        case .blue: return primary
        case .green: return accent
        case .amber: return warning
        case .red: return error
        default: return Color(rgb: type.hex)
        }
    }
}

enum Metric {
    static let cornerS: CGFloat = 10
    static let cornerM: CGFloat = 16
    static let cornerL: CGFloat = 24
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 16
    static let spaceL: CGFloat = 24
    static let tabBarHeight: CGFloat = 58
}

enum AppFont {
    static let title = Font.system(size: 24, weight: .bold)
    static let heading = Font.system(size: 18, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
    static let bodyBold = Font.system(size: 16, weight: .semibold)
    static let caption = Font.system(size: 12, weight: .regular)
    static let captionBold = Font.system(size: 12, weight: .semibold)
    static let numeric = Font.system(size: 34, weight: .bold, design: .rounded)
}
