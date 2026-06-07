import SwiftUI

/// A toggleable chip used in onboarding and filters.
struct SelectableChip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 13, weight: .semibold))
                }
                Text(title).font(.lbiCaption)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? .white : Theme.Palette.ink)
            .background(isSelected ? Theme.Palette.red : Theme.Palette.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                    .stroke(isSelected ? .clear : Theme.Palette.ink.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A flowing, wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                totalHeight += rowHeight + spacing
                currentWidth = 0
                rowHeight = 0
            }
            rows[rows.count - 1].append(subview)
            currentWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? currentWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
