import SwiftUI
import UIKit

/// Central design tokens for the LBI app.
///
/// Visual identity: imperial-era traditional Hong Kong — aged parchment and
/// lacquered ink, cinnabar-seal red, and imperial gold leaf. Colours are
/// semantic and resolve per `ColorScheme`, rendering a warm parchment look in
/// light mode and a deep lacquer-black look in dark mode.
enum Theme {
    enum Palette {
        // MARK: Surfaces / backgrounds

        /// App background. Light: refined warm ivory. Dark: deep lacquer black.
        static let paper = dynamic(light: 0xF3EDE2, dark: 0x14100C)
        /// Deeper background for grouped areas / progress tracks / neutral chips.
        static let paperDeep = dynamic(light: 0xE7DECF, dark: 0x211A12)
        /// Card / surface colour.
        static let surface = dynamic(light: 0xFBF7EF, dark: 0x221A11)
        /// Elevated surface (raised cards, sheets).
        static let surfaceRaised = dynamic(light: 0xFFFDF8, dark: 0x2C2317)

        // MARK: Text

        /// Primary text. Light: near-black lacquer ink. Dark: warm ivory.
        static let ink = dynamic(light: 0x1C1813, dark: 0xF3E9D2)
        /// Secondary / supporting text.
        static let inkSecondary = dynamic(light: 0x5E564A, dark: 0xB6A37E)
        /// Tertiary / placeholder text.
        static let inkTertiary = dynamic(light: 0x8C8475, dark: 0x6E5F45)

        // MARK: Brand (shared across light & dark)

        /// Cinnabar / imperial seal red — the primary accent.
        static let red = Color(hex6: 0xA8201A)
        /// Darker oxblood red for pressed states.
        static let redDeep = Color(hex6: 0x7A1410)
        /// Imperial jade — sparing supporting accent.
        static let jade = Color(hex6: 0x1E6F5C)
        /// Imperial gold leaf — sparing supporting accent.
        static let gold = Color(hex6: 0xBE9B33)
        /// Antique bronze gold for secondary accents.
        static let goldMuted = Color(hex6: 0x8F7320)

        // MARK: Semantic status

        static let success = Color(hex6: 0x2E7D54)
        static let warning = Color(hex6: 0xB67A12)
        static let destructive = Color(hex6: 0xA8201A)

        // MARK: Lines

        /// Hairline separators / borders.
        static let hairline = dynamic(light: 0x2E2920, dark: 0xF3E9D2, lightAlpha: 0.12, darkAlpha: 0.12)

        // MARK: - Helpers

        /// A colour that resolves to a different value per interface style.
        static func dynamic(
            light: UInt32,
            dark: UInt32,
            lightAlpha: CGFloat = 1,
            darkAlpha: CGFloat = 1
        ) -> Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(hex6: dark, alpha: darkAlpha)
                    : UIColor(hex6: light, alpha: lightAlpha)
            })
        }
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 22
        static let pill: CGFloat = 999
    }

    enum Shadow {
        /// Card shadow. Subtle in light; effectively invisible on ink in dark.
        static let card = Color.black.opacity(0.08)
    }
}

// MARK: - Hex colour initialisers

extension Color {
    /// Creates an opaque colour from a 6-digit hex value (0xRRGGBB).
    init(hex6 value: UInt32) {
        self.init(uiColor: UIColor(hex6: value, alpha: 1))
    }
}

extension UIColor {
    convenience init(hex6 value: UInt32, alpha: CGFloat) {
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
