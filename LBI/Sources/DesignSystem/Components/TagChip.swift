import SwiftUI

/// Small rounded label used for categories, districts and availability flags.
struct TagChip: View {
    enum Style {
        case neutral
        case red
        case jade
        case gold
        case outline
    }

    let text: String
    var systemImage: String?
    var style: Style = .neutral

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 10, weight: .bold)) }
            Text(text).font(.lbiLabel).lineLimit(1).fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 5)
        .foregroundStyle(foreground)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                .stroke(borderColor, lineWidth: style == .outline ? 1 : 0)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous))
    }

    private var foreground: Color {
        switch style {
        case .neutral: return Theme.Palette.inkSecondary
        case .red: return .white
        case .jade: return .white
        case .gold: return Theme.Palette.ink
        case .outline: return Theme.Palette.ink
        }
    }

    private var background: Color {
        switch style {
        case .neutral: return Theme.Palette.paperDeep
        case .red: return Theme.Palette.red
        case .jade: return Theme.Palette.jade
        case .gold: return Theme.Palette.gold
        case .outline: return .clear
        }
    }

    private var borderColor: Color {
        style == .outline ? Theme.Palette.ink.opacity(0.25) : .clear
    }
}

#Preview {
    HStack {
        TagChip(text: "Cha Chaan Teng", style: .neutral)
        TagChip(text: "Revenue Share", systemImage: "percent", style: .red)
        TagChip(text: "Takeover", style: .jade)
    }
    .padding()
    .background(Theme.Palette.paper)
}
