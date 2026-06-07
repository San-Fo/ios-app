import SwiftUI

/// Owner preview: submitted listings, commercial bids, and fallback status.
struct OwnerDashboardView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var sales: [ProfessionalSale] = []
    @State private var selectedFallbackSale: ProfessionalSale?
    @State private var openedDeal: DealConversation?

    private var pendingDecisionSales: [ProfessionalSale] {
        sales.filter { [.commercialBidding, .ownerDecision].contains($0.stage) && !$0.bids.isEmpty }
    }

    private var groupOfferSales: [ProfessionalSale] {
        sales.filter { $0.stage == .openToRetail && $0.groupOffers.contains { $0.status == .submitted } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header
                    overviewGrid
                    decisionsSection
                    groupOffersSection
                    fallbackSection
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.paper)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $openedDeal) { conversation in
                DealChatView(conversationId: conversation.id, conversation: conversation)
            }
        }
        .task { await load() }
        .sheet(item: $selectedFallbackSale) { sale in
            OwnerFallbackSheet(sale: sale) { updated in
                replace(updated)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Owner Desk")
                .font(.lbiHero)
                .inkStyle()
            Text("Review commercial bids and public fallback settings for your submitted businesses.")
                .font(.lbiBody)
                .inkSecondaryStyle()
        }
    }

    private var overviewGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
            StatPill(label: "Listings", value: "\(sales.count)", icon: "storefront.fill")
            StatPill(label: "Need decision", value: "\(pendingDecisionSales.count)", icon: "exclamationmark.circle.fill")
            StatPill(label: "Live bids", value: "\(sales.flatMap(\.bids).filter { $0.status == .submitted }.count)", icon: "hammer.fill")
            StatPill(label: "Retail fallback", value: "\(sales.filter { $0.stage == .openToRetail }.count)", icon: "person.3.fill")
        }
    }

    private var decisionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Owner decisions", subtitle: "Accept a commercial bid or open a public fallback path")
            if pendingDecisionSales.isEmpty {
                emptyCard("No commercial bids currently need a decision.")
            } else {
                ForEach(pendingDecisionSales) { sale in
                    OwnerSaleCard(sale: sale) { bid in
                        await accept(bid, in: sale)
                    } decline: {
                        selectedFallbackSale = sale
                    }
                }
            }
        }
    }

    private var groupOffersSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if !groupOfferSales.isEmpty {
                SectionHeader(title: "Group takeover offers", subtitle: "You may accept a group's offer even if it is below your public price")
                ForEach(groupOfferSales) { sale in
                    ForEach(sale.groupOffers.filter { $0.status == .submitted }) { offer in
                        OwnerGroupOfferCard(sale: sale, offer: offer) {
                            await acceptGroup(offer, in: sale)
                        }
                    }
                }
            }
        }
    }

    private var fallbackSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Public fallback", subtitle: "Retail purchase and takeover group availability")
            let fallbackSales = sales.filter { $0.stage == .openToRetail }
            if fallbackSales.isEmpty {
                emptyCard("No submitted businesses are open to public fallback yet.")
            } else {
                ForEach(fallbackSales) { sale in
                    OwnerFallbackStatusCard(sale: sale)
                }
            }
        }
    }

    private func emptyCard(_ text: String) -> some View {
        CardContainer { Text(text).font(.lbiBody).inkSecondaryStyle() }
    }

    private func load() async {
        sales = (try? await environment.saleRepository.sales()) ?? []
    }

    private func accept(_ bid: SaleBid, in sale: ProfessionalSale) async {
        guard let result = try? await environment.saleRepository.acceptBid(saleId: sale.id, bidId: bid.id) else { return }
        replace(result.sale)
        openedDeal = result.conversation
    }

    private func acceptGroup(_ offer: GroupBuyOffer, in sale: ProfessionalSale) async {
        guard let result = try? await environment.saleRepository.acceptGroupOffer(saleId: sale.id, offerId: offer.id) else { return }
        replace(result.sale)
        openedDeal = result.conversation
    }

    private func replace(_ updated: ProfessionalSale) {
        if let index = sales.firstIndex(where: { $0.id == updated.id }) {
            sales[index] = updated
        }
    }
}

private struct OwnerGroupOfferCard: View {
    let sale: ProfessionalSale
    let offer: GroupBuyOffer
    let accept: () async -> Void

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sale.businessName).font(.lbiCaption).foregroundStyle(Theme.Palette.red)
                        Text(offer.groupName).font(.lbiHeadline).inkStyle()
                        Text("\(offer.memberCount) members").font(.lbiCaption).inkSecondaryStyle()
                    }
                    Spacer()
                    Text(Money.hkd(offer.amount, abbreviated: true))
                        .font(.lbiSubtitle)
                        .foregroundStyle(Theme.Palette.red)
                }
                if let message = offer.message {
                    Text(message)
                        .font(.lbiBody)
                        .inkSecondaryStyle()
                        .fixedSize(horizontal: false, vertical: true)
                }
                if offer.amount < sale.askingPrice {
                    TagChip(text: "Below asking price", systemImage: "arrow.down", style: .outline)
                }
                PrimaryButton("Accept group offer", systemImage: "checkmark.seal.fill") {
                    Task { await accept() }
                }
            }
        }
    }
}

private struct OwnerSaleCard: View {
    let sale: ProfessionalSale
    let accept: (SaleBid) async -> Void
    let decline: () -> Void

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sale.businessName).font(.lbiHeadline).inkStyle()
                        Text(sale.stage.displayName).font(.lbiCaption).foregroundStyle(Theme.Palette.red)
                    }
                    Spacer()
                    if let bid = sale.highestBid {
                        Text(Money.hkd(bid.amount, abbreviated: true))
                            .font(.lbiSubtitle)
                            .foregroundStyle(Theme.Palette.red)
                    }
                }

                if let bid = sale.highestBid {
                    Text("Highest bid from \(bid.bidderName): \(bid.message ?? bid.bidderCredential ?? "No note provided")")
                        .font(.lbiBody)
                        .inkSecondaryStyle()
                        .fixedSize(horizontal: false, vertical: true)

                    PrimaryButton("Accept highest bid", systemImage: "checkmark.seal.fill") {
                        Task { await accept(bid) }
                    }
                }

                SecondaryButton("Decline and set retail fallback", systemImage: "person.3.fill", action: decline)
            }
        }
    }
}

private struct OwnerFallbackStatusCard: View {
    let sale: ProfessionalSale

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(sale.businessName).font(.lbiHeadline).inkStyle()
                if let fallback = sale.retailFallbackOffer {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                        StatPill(label: "Public price", value: Money.hkd(fallback.askingPrice, abbreviated: true), icon: "tag.fill")
                        StatPill(label: "Outright", value: fallback.allowOutrightPurchase ? "Open" : "Closed", icon: "person.fill")
                        StatPill(label: "Group", value: fallback.allowGroupTakeover ? "Open" : "Closed", icon: "person.3.fill")
                    }
                    Text(fallback.ownerNote)
                        .font(.lbiCaption)
                        .inkSecondaryStyle()
                }
            }
        }
    }
}

private struct OwnerFallbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment

    let sale: ProfessionalSale
    let onUpdated: (ProfessionalSale) -> Void

    @State private var askingPrice = ""
    @State private var allowOutrightPurchase = true
    @State private var allowGroupTakeover = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Retail fallback price") {
                    TextField("HKD", text: $askingPrice)
                        .keyboardType(.numberPad)
                }

                Section("Allowed public paths") {
                    Toggle("Outright retail purchase", isOn: $allowOutrightPurchase)
                    Toggle("Group takeover", isOn: $allowGroupTakeover)
                }
            }
            .navigationTitle("Set Fallback")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Open") { Task { await openFallback() } }
                        .disabled(price == nil)
                }
            }
        }
        .onAppear { askingPrice = decimalString(sale.retailFallbackOffer?.askingPrice ?? sale.askingPrice) }
    }

    private var price: Decimal? { Decimal(string: askingPrice) }

    private func openFallback() async {
        guard let price else { return }
        guard let updated = try? await environment.saleRepository.declineCommercialBids(
            saleId: sale.id,
            retailAskingPrice: price,
            allowOutrightPurchase: allowOutrightPurchase,
            allowGroupTakeover: allowGroupTakeover
        ) else { return }
        onUpdated(updated)
        dismiss()
    }

    private func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}

#Preview {
    OwnerDashboardView()
        .environment(AppEnvironment.preview)
}
