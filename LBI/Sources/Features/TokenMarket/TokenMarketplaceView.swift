import SwiftUI

/// ⚠️ STUB — example tokenized marketplace for **verified commercial investors
/// only**. Small/medium businesses are tokenized and traded as on-chain shares
/// (Web3). There is no server, wallet or chain behind this; all data is sample
/// data. See MOCKING.md section 6 / gap #10.
///
/// Gating is enforced by `MainTabView` (the tab only appears for
/// `isInstitutionalInvestor`); the inner guard is defence-in-depth.
struct TokenMarketplaceView: View {
    @Environment(ProfileStore.self) private var profileStore

    @State private var listings: [BusinessToken] = []
    @State private var holdings: [TokenHolding] = []
    @State private var tradeTarget: BusinessToken?

    private var isVerifiedInvestor: Bool {
        profileStore.profile?.isInstitutionalInvestor ?? false
    }

    var body: some View {
        NavigationStack {
            Group {
                if isVerifiedInvestor {
                    marketplace
                } else {
                    accessGate
                }
            }
            .background(Theme.Palette.paper)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            listings = TokenMarketSampleData.listings
            holdings = TokenMarketSampleData.holdings
        }
        .sheet(item: $tradeTarget) { token in
            TokenTradeSheet(token: token)
        }
    }

    // MARK: - Marketplace

    private var marketplace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                portfolioSummary
                listingsSection
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Token Market")
                .font(.lbiHero)
                .inkStyle()
            Text("Trade tokenized shares of verified Hong Kong businesses on Web3 infrastructure, settled on-chain.")
                .font(.lbiBody)
                .inkSecondaryStyle()
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Palette.jade)
                Text("Web3 · ERC-20 equity tokens")
                    .font(.lbiLabel)
                    .inkSecondaryStyle()
            }
        }
    }

    private var portfolioSummary: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Your positions", subtitle: "Tokenized holdings in your linked Web3 wallet")
            if holdings.isEmpty {
                CardContainer { Text("No token positions yet.").font(.lbiBody).inkSecondaryStyle() }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                    StatPill(label: "Portfolio value", value: Money.hkd(totalValue, abbreviated: true), icon: "wallet.bedside.fill")
                    StatPill(label: "Unrealised P/L", value: signedPercent(totalReturn), icon: "chart.line.uptrend.xyaxis")
                }
                ForEach(holdings) { holding in
                    TokenHoldingRow(holding: holding)
                }
            }
        }
    }

    private var listingsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Listed tokens", subtitle: "Verified businesses with an on-chain order book")
            ForEach(listings) { token in
                Button { tradeTarget = token } label: {
                    TokenListingRow(token: token)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Access gate (defence-in-depth)

    private var accessGate: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Palette.red)
            Text("Verified commercial investors only")
                .font(.lbiHeadline)
                .inkStyle()
            Text("The token market is restricted to approved commercial investors.")
                .font(.lbiBody)
                .inkSecondaryStyle()
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Derived

    private var totalValue: Decimal {
        holdings.reduce(0) { $0 + $1.marketValue }
    }

    private var totalReturn: Double {
        let cost = holdings.reduce(Decimal(0)) { $0 + $1.costBasis }
        let value = totalValue
        let costD = NSDecimalNumber(decimal: cost).doubleValue
        guard costD > 0 else { return 0 }
        return (NSDecimalNumber(decimal: value).doubleValue - costD) / costD
    }
}

/// Signed percentage string, e.g. "+4.2%" / "-1.3%".
private func signedPercent(_ fraction: Double) -> String {
    let pct = fraction * 100
    return String(format: "%+.1f%%", pct)
}

// MARK: - Rows

private struct TokenListingRow: View {
    let token: BusinessToken

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(token.symbol).font(.lbiMonoSmall).inkStyle()
                            TagChip(text: token.district.displayName, style: .neutral)
                        }
                        Text(token.businessName).font(.lbiHeadline).inkStyle()
                        HStack(spacing: 4) {
                            Image(systemName: "cube.fill").font(.system(size: 8))
                            Text(token.contractAddress).font(.lbiLabel)
                        }
                        .foregroundStyle(Theme.Palette.inkSecondary.opacity(0.7))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Money.hkd(token.lastPrice)).font(.lbiSubtitle).inkStyle()
                        Text(signedPercent(token.change24h))
                            .font(.lbiMonoSmall)
                            .foregroundStyle(token.change24h >= 0 ? Theme.Palette.jade : Theme.Palette.red)
                    }
                }
                Sparkline(points: token.priceHistory, isPositive: token.change24h >= 0)
                    .frame(height: 32)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                    StatPill(label: "Market cap", value: Money.hkd(token.marketCap, abbreviated: true), icon: "building.2.fill")
                    StatPill(label: "24h volume", value: Money.hkd(token.volume24h, abbreviated: true), icon: "arrow.left.arrow.right")
                    StatPill(label: "Float", value: "\(Int(token.floatPercent * 100))%", icon: "chart.pie.fill")
                    StatPill(label: "Supply", value: "\(token.totalSupply)", icon: "number")
                }
            }
        }
    }
}

private struct TokenHoldingRow: View {
    let holding: TokenHolding

    var body: some View {
        CardContainer {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.symbol).font(.lbiMonoSmall).inkStyle()
                    Text("\(holding.quantity) tokens").font(.lbiCaption).inkSecondaryStyle()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Money.hkd(holding.marketValue, abbreviated: true)).font(.lbiSubtitle).inkStyle()
                    Text(signedPercent(holding.returnPercent))
                        .font(.lbiMonoSmall)
                        .foregroundStyle(holding.returnPercent >= 0 ? Theme.Palette.jade : Theme.Palette.red)
                }
            }
        }
    }
}

/// Minimal inline sparkline for the token price series.
private struct Sparkline: View {
    let points: [Double]
    let isPositive: Bool

    var body: some View {
        GeometryReader { geo in
            let values = points
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let span = max(maxV - minV, 0.0001)
            Path { path in
                for (index, value) in values.enumerated() {
                    let x = values.count > 1
                        ? geo.size.width * CGFloat(index) / CGFloat(values.count - 1)
                        : 0
                    let y = geo.size.height * (1 - CGFloat((value - minV) / span))
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(isPositive ? Theme.Palette.jade : Theme.Palette.red,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Trade sheet (stub)

/// ⚠️ STUB — buy/sell UI that records nothing. Confirming shows a notice that no
/// order was placed (no chain/wallet behind it).
private struct TokenTradeSheet: View {
    let token: BusinessToken

    @Environment(\.dismiss) private var dismiss
    @State private var side: Side = .buy
    @State private var quantityText = ""
    @State private var showStubNotice = false

    enum Side: String, CaseIterable, Identifiable {
        case buy, sell
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    private var quantity: Int { Int(quantityText) ?? 0 }
    private var estimatedTotal: Decimal { token.lastPrice * Decimal(quantity) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(token.symbol).font(.lbiMonoSmall).inkSecondaryStyle()
                        Text(token.businessName).font(.lbiTitle).inkStyle()
                        Text("\(Money.hkd(token.lastPrice)) / token").font(.lbiBody).foregroundStyle(Theme.Palette.red)
                        HStack(spacing: 4) {
                            Image(systemName: "cube.fill").font(.system(size: 8))
                            Text("ERC-20 · \(token.contractAddress)").font(.lbiLabel)
                        }
                        .foregroundStyle(Theme.Palette.inkSecondary.opacity(0.7))
                    }

                    Picker("Side", selection: $side) {
                        ForEach(Side.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        SectionHeader(title: "Quantity")
                        TextField("0", text: $quantityText)
                            .keyboardType(.numberPad)
                            .font(.lbiHero)
                            .inkStyle()
                            .padding(Theme.Spacing.md)
                            .background(Theme.Palette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))
                    }

                    HStack {
                        Text("Estimated total").font(.lbiBody).inkSecondaryStyle()
                        Spacer()
                        Text(Money.hkd(estimatedTotal)).font(.lbiSubtitle).inkStyle()
                    }

                    if showStubNotice {
                        Text("Concept preview: no order was broadcast. On-chain settlement via the Web3 smart contract is not yet connected.")
                            .font(.lbiCaption)
                            .foregroundStyle(Theme.Palette.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.paper)
            .navigationTitle("\(side.label) \(token.symbol)")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton("Review \(side.label) order", isEnabled: quantity > 0) {
                    // STUB: no order is placed; surface a notice instead.
                    MockMarker.hit(.mock, "TokenTradeSheet.placeOrder", "Web3 marketplace stub; order discarded")
                    withAnimation { showStubNotice = true }
                }
                .padding(Theme.Spacing.lg)
                .background(Theme.Palette.paper)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
        }
    }
}

#Preview {
    TokenMarketplaceView()
        .environment(AppEnvironment.preview)
        .environment(ProfileStore(repository: MockProfileRepository(), businessRepository: MockBusinessRepository()))
}
