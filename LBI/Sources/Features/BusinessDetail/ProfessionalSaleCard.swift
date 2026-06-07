import SwiftUI

/// Professional-first business sale card. Confidential financials are shown
/// only to verified professional accounts, unless the owner opens the sale.
struct ProfessionalSaleCard: View {
    let sale: ProfessionalSale
    /// Viewer is an approved commercial investor (sees AI memo + can bid).
    let isProfessional: Bool
    /// Viewer is the business owner (sees decision controls + group offers).
    let isOwner: Bool
    /// Investor taps "Place commercial bid".
    let onPlaceBid: () -> Void
    /// Owner accepts a specific commercial bid.
    let onAcceptBid: (SaleBid) -> Void
    /// Owner accepts a takeover-group offer (may be below ask).
    let onAcceptGroupOffer: (GroupBuyOffer) -> Void
    /// Owner declines all commercial bids and opens a retail fallback
    /// (price, allow-outright, allow-group-takeover).
    let onDeclineToRetail: (Decimal, Bool, Bool) -> Void
    /// Public buyer starts the outright purchase flow.
    let onRetailPurchase: () -> Void
    /// Public user starts/joins a takeover group.
    let onGroupTakeover: () -> Void

    // Local state for the owner's "decline to retail" sheet.
    @State private var showDeclineSheet = false
    @State private var retailPriceText = ""
    @State private var allowOutrightPurchase = true
    @State private var allowGroupTakeover = true

    /// Confidential financials are visible to investors, the owner, or — once
    /// the owner opens a public fallback — to everyone (retail-visible stages).
    private var canViewFinancials: Bool {
        isProfessional || isOwner || sale.stage.isVisibleToRetail
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header

                lifecycle

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                    StatPill(label: sale.stage == .openToRetail ? "Commercial ask" : "Guide price", value: Money.hkd(sale.askingPrice, abbreviated: true), icon: "tag.fill")
                    if let bid = sale.highestBid {
                        StatPill(label: "Highest bid", value: Money.hkd(bid.amount, abbreviated: true), icon: "arrow.up.forward.circle.fill")
                    } else {
                        StatPill(label: "Bids", value: "None yet", icon: "tray.fill")
                    }
                    if isProfessional, let evaluation = sale.aiEvaluation {
                        StatPill(label: "AI score", value: "\(evaluation.score)/100", icon: "sparkles")
                    }
                    if let end = sale.commercialBiddingEndsAt, sale.stage == .commercialBidding {
                        StatPill(label: "Bidding closes", value: end.formatted(.relative(presentation: .named)), icon: "clock.fill")
                    }
                }

                if canViewFinancials {
                    financials
                    includes
                    // AI memo is investor-only (never shown to owner/public).
                    if isProfessional { aiEvaluation }
                    if let offer = sale.retailFallbackOffer { retailFallback(offer) }
                    if !sale.bids.isEmpty { bids }
                    // Investors can bid only while commercial bidding is open.
                    if isProfessional && sale.stage == .commercialBidding {
                        PrimaryButton("Place Commercial Bid", systemImage: "hammer.fill", action: onPlaceBid)
                    }
                    // Owner-only: accept/decline bids and review group offers.
                    if isOwner { ownerDecisionControls }
                    if isOwner { ownerGroupOffers }
                    // Public outright-buy / group-takeover actions (retail fallback).
                    retailActions
                } else {
                    // Public users before fallback is open: confidentiality notice.
                    gatedNotice
                }
            }
        }
        .sheet(isPresented: $showDeclineSheet) {
            declineSheet
        }
        .onAppear {
            if retailPriceText.isEmpty {
                retailPriceText = "\(NSDecimalNumber(decimal: sale.retailFallbackOffer?.askingPrice ?? sale.askingPrice).intValue)"
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Label(isProfessional ? "AI-screened sale" : "Business sale", systemImage: isProfessional ? "sparkles" : "building.2.fill")
                    .font(.lbiHeadline)
                    .inkStyle()
                Spacer()
                TagChip(text: sale.stage.displayName, systemImage: sale.stage == .openToRetail ? "person.3.fill" : "lock.shield.fill", style: sale.stage == .openToRetail ? .jade : .gold)
            }
            Text(isProfessional
                ? "Submitted sale listings are evaluated by backend AI. Strong businesses are offered to commercial investors first; if the owner declines those bids, they can set a public price and try retail buyers or a group takeover."
                : "Strong businesses are offered to commercial investors first. If the owner declines those bids, they can set a public price and try retail buyers or a group takeover.")
                .font(.lbiBody)
                .inkSecondaryStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var lifecycle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sale path")
                .font(.lbiLabel)
                .inkSecondaryStyle()
            HStack(spacing: 6) {
                processStep(isProfessional ? "AI review" : "Review", isActive: sale.stage == .aiReview, isDone: sale.stage != .aiReview)
                processStep("Commercial bids", isActive: sale.stage == .commercialBidding, isDone: [.ownerDecision, .openToRetail, .accepted, .sold].contains(sale.stage))
                processStep("Owner decision", isActive: sale.stage == .ownerDecision, isDone: [.openToRetail, .accepted, .sold].contains(sale.stage))
                processStep("Retail fallback", isActive: sale.stage == .openToRetail, isDone: sale.stage == .sold)
            }
        }
    }

    private func processStep(_ title: String, isActive: Bool, isDone: Bool) -> some View {
        Text(title)
            .font(.lbiLabel)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(isActive || isDone ? Theme.Palette.ink : Theme.Palette.inkSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isActive ? Theme.Palette.gold.opacity(0.35) : (isDone ? Theme.Palette.paperDeep : Theme.Palette.surface))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    @ViewBuilder
    private var aiEvaluation: some View {
        if let evaluation = sale.aiEvaluation {
            AIMemoCard(evaluation: evaluation)
        }
    }

    private func retailFallback(_ offer: RetailFallbackOffer) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Retail fallback")
                .font(.lbiLabel)
                .inkSecondaryStyle()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                StatPill(label: "Public price", value: Money.hkd(offer.askingPrice, abbreviated: true), icon: "tag.fill")
                StatPill(label: "Outright buy", value: offer.allowOutrightPurchase ? "Allowed" : "Closed", icon: "cart.fill")
                StatPill(label: "Group takeover", value: offer.allowGroupTakeover ? "Allowed" : "Closed", icon: "person.3.fill")
            }
            if !offer.ownerNote.isEmpty {
                Text(offer.ownerNote)
                    .font(.lbiCaption)
                    .inkSecondaryStyle()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.paperDeep)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }

    @ViewBuilder
    private var ownerDecisionControls: some View {
        if let bid = sale.highestBid, [.commercialBidding, .ownerDecision].contains(sale.stage) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Owner decision demo")
                    .font(.lbiLabel)
                    .inkSecondaryStyle()
                Text("When commercial bidding closes, the owner can accept the best bid or decline all commercial offers and set a public fallback price.")
                    .font(.lbiCaption)
                    .inkSecondaryStyle()
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Spacing.sm) {
                    PrimaryButton("Accept \(Money.hkd(bid.amount, abbreviated: true))", systemImage: "checkmark.seal.fill") {
                        onAcceptBid(bid)
                    }
                    SecondaryButton("Decline", systemImage: "arrow.uturn.forward") {
                        showDeclineSheet = true
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
    }

    @ViewBuilder
    private var ownerGroupOffers: some View {
        let pending = sale.groupOffers.filter { $0.status == .submitted }
        if sale.stage == .openToRetail, !pending.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Group takeover offers")
                    .font(.lbiLabel)
                    .inkSecondaryStyle()
                Text("You can accept a group's offer even if it is below your public price.")
                    .font(.lbiCaption)
                    .inkSecondaryStyle()
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(pending) { offer in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(offer.groupName).font(.lbiSubtitle).inkStyle()
                                Text("\(offer.memberCount) members").font(.lbiCaption).inkSecondaryStyle()
                            }
                            Spacer()
                            Text(Money.hkd(offer.amount, abbreviated: true))
                                .font(.lbiSubtitle)
                                .foregroundStyle(Theme.Palette.red)
                        }
                        if let message = offer.message {
                            Text(message)
                                .font(.lbiCaption)
                                .inkSecondaryStyle()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if offer.amount < sale.askingPrice {
                            TagChip(text: "Below public price", systemImage: "arrow.down", style: .outline)
                        }
                        PrimaryButton("Accept \(Money.hkd(offer.amount, abbreviated: true)) offer", systemImage: "checkmark.seal.fill") {
                            onAcceptGroupOffer(offer)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Palette.paperDeep)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var retailActions: some View {
        if sale.stage == .openToRetail, let offer = sale.retailFallbackOffer {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Public fallback actions")
                    .font(.lbiLabel)
                    .inkSecondaryStyle()
                if offer.allowOutrightPurchase {
                    PrimaryButton("Buy Outright for \(Money.hkd(offer.askingPrice, abbreviated: true))", systemImage: "cart.fill", action: onRetailPurchase)
                }
                // Group takeover is a public/community route — hidden for commercial investors.
                if offer.allowGroupTakeover && !isProfessional {
                    SecondaryButton("Start / Join Group Takeover", systemImage: "person.3.fill", action: onGroupTakeover)
                }
            }
        }
    }

    private var declineSheet: some View {
        NavigationStack {
            Form {
                Section("Retail fallback") {
                    TextField("Public asking price in HKD", text: $retailPriceText)
                        .keyboardType(.numberPad)
                    Toggle("Allow outright retail purchase", isOn: $allowOutrightPurchase)
                    Toggle("Allow group takeover", isOn: $allowGroupTakeover)
                }
                Section {
                    Text("Declining commercial bids marks all submitted bids as declined and opens the listing to civilian buyers at the public price you set.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Decline Bids")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDeclineSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Open Public") {
                        if let price = Decimal(string: retailPriceText) {
                            onDeclineToRetail(price, allowOutrightPurchase, allowGroupTakeover)
                            showDeclineSheet = false
                        }
                    }
                    .disabled(Decimal(string: retailPriceText) == nil)
                }
            }
        }
    }

    private var financials: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Confidential financials")
                .font(.lbiLabel)
                .inkSecondaryStyle()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                StatPill(label: "Annual revenue", value: Money.hkd(sale.financials.annualRevenue, abbreviated: true), icon: "chart.bar.fill")
                StatPill(label: "Annual profit", value: Money.hkd(sale.financials.annualProfit, abbreviated: true), icon: "chart.line.uptrend.xyaxis")
                if let rent = sale.financials.monthlyRent {
                    StatPill(label: "Monthly rent", value: Money.hkd(rent, abbreviated: true), icon: "building.2.fill")
                }
                StatPill(label: "Staff", value: "\(sale.financials.staffCount)", icon: "person.2.fill")
            }

            if !sale.financials.notes.isEmpty {
                Text(sale.financials.notes)
                    .font(.lbiCaption)
                    .inkSecondaryStyle()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var includes: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sale includes")
                .font(.lbiLabel)
                .inkSecondaryStyle()
            ForEach(sale.includes, id: \.self) { item in
                Label(item, systemImage: "checkmark.seal.fill")
                    .font(.lbiBody)
                    .inkStyle()
            }
            if sale.ownerWillingToStay, let months = sale.handoverMonths {
                Label("Owner will stay for a \(months)-month handover", systemImage: "figure.2.arms.open")
                    .font(.lbiCaption)
                    .foregroundStyle(Theme.Palette.jade)
            }
        }
    }

    private var bids: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Commercial bids")
                .font(.lbiLabel)
                .inkSecondaryStyle()

            ForEach(sale.bids.sorted { $0.amount > $1.amount }) { bid in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(Money.hkd(bid.amount, abbreviated: true))
                            .font(.lbiHeadline)
                            .foregroundStyle(Theme.Palette.red)
                        Spacer()
                        Text(bid.status.displayName)
                            .font(.lbiLabel)
                            .inkSecondaryStyle()
                    }
                    Text(bid.bidderName)
                        .font(.lbiBody)
                        .inkStyle()
                    if let credential = bid.bidderCredential {
                        Text(credential)
                            .font(.lbiCaption)
                            .inkSecondaryStyle()
                    }
                    if let message = bid.message, !message.isEmpty {
                        Text("“\(message)”")
                            .font(.lbiCaption)
                            .inkSecondaryStyle()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.Palette.paperDeep)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            }
        }
    }

    private var gatedNotice: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("Financials and bidding are private", systemImage: "lock.fill")
                .font(.lbiHeadline)
                .inkStyle()
            Text("Commercial investors can review the full financial snapshot and bid during the private window. If the owner declines those bids, they may set a public price and open this to retail buyers or a group takeover.")
                .font(.lbiBody)
                .inkSecondaryStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.paperDeep)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }
}

struct ProfessionalBidSheet: View {
    let sale: ProfessionalSale
    let onSubmit: (Decimal, String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Offer") {
                    TextField("Amount in HKD", text: $amountText)
                        .keyboardType(.numberPad)
                    TextField("Message to owner", text: $message, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Context") {
                    LabeledContent("Asking price", value: Money.hkd(sale.askingPrice))
                    if let bid = sale.highestBid {
                        LabeledContent("Highest bid", value: Money.hkd(bid.amount))
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Theme.Palette.red)
                    }
                }
            }
            .navigationTitle("Place Bid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Sending..." : "Submit") { submit() }
                        .disabled(parsedAmount == nil || isSubmitting)
                }
            }
        }
    }

    private func submit() {
        guard let amount = parsedAmount else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                try await onSubmit(amount, message.isEmpty ? nil : message)
                dismiss()
            } catch let error as APIError {
                errorMessage = error.userMessage
            } catch {
                errorMessage = "Could not submit this bid."
            }
            isSubmitting = false
        }
    }
}
