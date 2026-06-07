import SwiftUI

/// Commercial-investor revenue-share loan terms.
struct RevenueShareCard: View {
    let terms: RevenueShareTerms
    var isInstitutionalView = false

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "percent")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Theme.Palette.red)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                    Text(isInstitutionalView ? "Commercial investor revenue-share loan" : "Revenue-share financing").font(.lbiHeadline).inkStyle()
                }

                Text(isInstitutionalView ? "Loan-level terms for approved commercial investors, with repayment tied to the business's future revenue until the target multiple is reached." : "You help fund this business and receive a small share of future revenue until the agreed target is reached.")
                    .font(.lbiBody)
                    .inkSecondaryStyle()
                    .fixedSize(horizontal: false, vertical: true)

                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                    StatPill(label: "Funding target", value: Money.hkd(terms.fundingTarget, abbreviated: true), icon: "target")
                    StatPill(label: "Revenue share", value: "\(formatted(terms.revenueSharePercent))%", icon: "percent")
                    StatPill(label: "Target return", value: "\(formatted(terms.targetMultiple))x", icon: "arrow.up.right")
                    StatPill(label: "Est. period", value: "\(terms.estimatedMonths) mo", icon: "calendar")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Use of funds").font(.lbiLabel).inkSecondaryStyle()
                    if terms.useOfFundsBreakdown.isEmpty {
                        Text(terms.useOfFunds).font(.lbiBody).inkStyle()
                    } else {
                        ForEach(terms.useOfFundsBreakdown) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(item.label).font(.lbiCaption).inkStyle()
                                    Spacer()
                                    Text("\(formatted(item.percentage))%").font(.lbiMonoSmall).inkSecondaryStyle()
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Theme.Palette.paperDeep)
                                        Capsule().fill(Theme.Palette.gold)
                                            .frame(width: geo.size.width * item.percentage / 100)
                                    }
                                }
                                .frame(height: 6)
                            }
                        }
                    }
                }

                if let minimum = terms.minimumInvestment {
                    let maxText = terms.maximumInvestment.map { " – \(Money.hkd($0, abbreviated: true))" } ?? ""
                    Text("Investment from \(Money.hkd(minimum, abbreviated: true))\(maxText)")
                        .font(.lbiCaption).inkSecondaryStyle()
                }
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}

struct RevenueShareAccessCard: View {
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Theme.Palette.red)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                    Text("Commercial investor loan access")
                        .font(.lbiHeadline)
                        .inkStyle()
                }

                Text("Revenue-share loans are available only to approved commercial investors. Public supporters can still collect support cards, save businesses, and join takeover groups when available.")
                    .font(.lbiBody)
                    .inkSecondaryStyle()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    RevenueShareCard(terms: SampleData.wongNoodleShop.revenueShareTerms!, isInstitutionalView: true)
        .padding()
        .background(Theme.Palette.paper)
}
