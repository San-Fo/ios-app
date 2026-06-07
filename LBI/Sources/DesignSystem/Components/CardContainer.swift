import SwiftUI

/// A soft, warm surface used to group content into cards.
struct CardContainer<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.md
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.Palette.hairline, lineWidth: 1)
            )
            .shadow(color: Theme.Shadow.card, radius: 10, x: 0, y: 4)
    }
}

/// A titled section header with optional accent rule.
struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var accent: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                if accent {
                    Rectangle()
                        .fill(Theme.Palette.red)
                        .frame(width: 4, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                Text(title).font(.lbiTitle).inkStyle()
            }
            if let subtitle {
                Text(subtitle).font(.lbiCaption).inkSecondaryStyle()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        SectionHeader(title: "Near You", subtitle: "Shops in Sham Shui Po")
        CardContainer {
            Text("A neighbourhood worth keeping.").font(.lbiBody).inkStyle()
        }
    }
    .padding()
    .background(Theme.Palette.paper)
}
