import SwiftUI

/// Typography scale. Serif display for editorial headlines and story headers;
/// system text for UI and body to keep it legible and Dynamic Type friendly.
extension Font {
    static func lbiDisplay(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Large hero/story headline.
    static let lbiHero = Font.system(size: 34, weight: .bold, design: .serif)
    /// Section / screen titles.
    static let lbiTitle = Font.system(size: 26, weight: .bold, design: .serif)
    /// Medium serif display (between hero and title).
    static let lbiDisplayMedium = Font.system(size: 28, weight: .semibold, design: .serif)
    /// Card headlines.
    static let lbiHeadline = Font.system(size: 20, weight: .semibold, design: .serif)
    /// Emphasis subtitle.
    static let lbiSubtitle = Font.system(size: 17, weight: .semibold, design: .rounded)
    /// Body text.
    static let lbiBody = Font.system(size: 16, weight: .regular)
    /// Secondary/caption text.
    static let lbiCaption = Font.system(size: 13, weight: .medium, design: .rounded)
    /// Small labels / tags.
    static let lbiLabel = Font.system(size: 12, weight: .semibold, design: .rounded)

    // MARK: Monospaced — for figures, amounts, percentages, countdowns
    static let lbiMono = Font.system(size: 16, weight: .medium, design: .monospaced)
    static let lbiMonoLarge = Font.system(size: 22, weight: .bold, design: .monospaced)
    static let lbiMonoSmall = Font.system(size: 13, weight: .medium, design: .monospaced)
}

extension View {
    /// Applies the standard ink colour.
    func inkStyle() -> some View { foregroundStyle(Theme.Palette.ink) }
    func inkSecondaryStyle() -> some View { foregroundStyle(Theme.Palette.inkSecondary) }
}
