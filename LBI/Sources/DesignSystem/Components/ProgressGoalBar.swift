import SwiftUI

/// A funding-progress bar with a current/target caption.
struct ProgressGoalBar: View {
    /// Value between 0 and 1.
    let progress: Double
    var raisedLabel: String
    var goalLabel: String
    var tint: Color = Theme.Palette.red

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.paperDeep)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(0, min(1, progress)) * geo.size.width)
                }
            }
            .frame(height: 10)

            HStack {
                Text(raisedLabel).font(.lbiCaption).foregroundStyle(tint)
                Spacer()
                Text(goalLabel).font(.lbiCaption).inkSecondaryStyle()
            }
        }
    }
}

/// A compact stat display (label + value).
struct StatPill: View {
    let label: String
    let value: String
    var icon: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.Palette.red) }
                Text(label).font(.lbiLabel).inkSecondaryStyle().lineLimit(1)
            }
            Text(value).font(.lbiSubtitle).inkStyle()
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(Theme.Palette.paperDeep)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 16) {
        ProgressGoalBar(progress: 0.62, raisedLabel: "HK$310,000 raised", goalLabel: "Goal HK$500,000")
        HStack {
            StatPill(label: "Revenue Share", value: "8%", icon: "percent")
            StatPill(label: "Target", value: "1.5x", icon: "target")
        }
    }
    .padding()
    .background(Theme.Palette.paper)
}
