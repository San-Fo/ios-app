import SwiftUI

/// Formats Hong Kong dollar amounts for display.
///
/// Shared across the app so currency rendering stays consistent.
enum Money {
    /// Formats `value` as HKD.
    /// - Parameter abbreviated: when true, large amounts are shortened to
    ///   `HK$2.2M` / `HK$95k` for compact stat pills; otherwise the full
    ///   grouped amount (`HK$2,200,000`) is returned.
    static func hkd(_ value: Decimal, abbreviated: Bool = false) -> String {
        let number = NSDecimalNumber(decimal: value)
        if abbreviated {
            let doubleValue = number.doubleValue
            if doubleValue >= 1_000_000 {
                return "HK$\(String(format: "%.1f", doubleValue / 1_000_000))M"
            } else if doubleValue >= 1_000 {
                return "HK$\(Int(doubleValue / 1_000))k"
            }
        }
        // Grouped decimal with no fraction digits, e.g. "HK$2,200,000".
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: number) ?? "0"
        return "HK$\(formatted)"
    }
}

/// An emotional business discovery card.
struct BusinessCard: View {
    let business: Business
    var isSaved: Bool = false
    var onSaveTapped: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: business.heroImageURL, contentMode: .fill)
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .topLeading) {
                    statusBadge
                        .padding(Theme.Spacing.sm)
                }
                .overlay(alignment: .topTrailing) {
                    if let onSaveTapped {
                        Button(action: onSaveTapped) {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(isSaved ? Theme.Palette.gold : .white)
                                .frame(width: 34, height: 34)
                                .background(.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(Theme.Spacing.sm)
                    }
                }
                .clipShape(
                    .rect(
                        topLeadingRadius: Theme.Radius.lg,
                        topTrailingRadius: Theme.Radius.lg
                    )
                )

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                FlowLayout(spacing: 6) {
                    TagChip(text: business.category.displayName, systemImage: business.category.systemImage)
                    TagChip(text: business.district.displayName, style: .outline)
                }

                Text(business.storyHeadline)
                    .font(.lbiHeadline)
                    .inkStyle()
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(business.name)
                    .font(.lbiCaption)
                    .inkSecondaryStyle()

                if business.status.showsFundingProgress {
                    ProgressGoalBar(
                        progress: business.fundingProgress,
                        raisedLabel: "\(Money.hkd(business.fundingRaised, abbreviated: true)) raised",
                        goalLabel: "Goal \(Money.hkd(business.fundingGoal, abbreviated: true))"
                    )
                }

                if let days = business.daysRemaining, business.status.isUrgent {
                    Label("\(days) day\(days == 1 ? "" : "s") left", systemImage: "clock.fill")
                        .font(.lbiLabel)
                        .foregroundStyle(Theme.Palette.red)
                }

                if !business.fundingOptions.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(Array(business.fundingOptions).sorted(by: { $0.rawValue < $1.rawValue })) { kind in
                            TagChip(text: kind.displayName, systemImage: kind.systemImage, style: .neutral)
                        }
                    }
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.Palette.hairline, lineWidth: 1)
        )
        .shadow(color: Theme.Shadow.card, radius: 10, x: 0, y: 4)
    }

    private var statusBadge: some View {
        TagChip(
            text: business.status.displayName,
            systemImage: business.status.isUrgent ? "exclamationmark.triangle.fill" : nil,
            style: business.status.chipStyle
        )
    }
}

extension BusinessStatus {
    /// Maps a status to a chip style for badges.
    var chipStyle: TagChip.Style {
        switch self {
        case .raising: return .red
        case .urgentRisk: return .red
        case .fullyFunded: return .jade
        case .preserved: return .jade
        case .seekingBuyer: return .gold
        case .inNegotiation: return .gold
        case .underOffer: return .gold
        }
    }
}

#Preview {
    ScrollView {
        BusinessCard(business: SampleData.summaries[0], isSaved: true, onSaveTapped: {})
            .padding()
    }
    .background(Theme.Palette.paper)
}
