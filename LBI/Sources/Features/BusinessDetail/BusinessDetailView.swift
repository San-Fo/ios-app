import SwiftUI

/// Full editorial business detail page with all sections and actions.
struct BusinessDetailView: View {
    let businessId: String

    @Environment(AppEnvironment.self) private var environment
    @Environment(ProfileStore.self) private var profileStore

    @State private var detail: BusinessDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showInvest = false
    @State private var showTakeover = false
    @State private var showAskQuestion = false
    @State private var showProfessionalBid = false
    @State private var showRetailPurchase = false
    @State private var showEdit = false
    @State private var showAddMemory = false
    @State private var openedDeal: DealConversation?
    @State private var galleryIndex: String?

    var body: some View {
        Group {
            if let detail {
                content(detail)
            } else if isLoading {
                ProgressView().tint(Theme.Palette.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Palette.paper)
            } else {
                errorState
            }
        }
        .background(Theme.Palette.paper)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: Content

    private func content(_ detail: BusinessDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                hero(detail)

                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    titleBlock(detail)
                    socialProof(detail)
                    if detail.summary.status.showsFundingProgress {
                        fundingBlock(detail)
                    }
                    // Section ordering is role-dependent:
                    // - Commercial investors get a data-first layout (snapshot
                    //   + deal/financials first, story afterwards).
                    // - Public users get a story-first layout (founder story
                    //   first, deal info last).
                    if isInstitutionalView {
                        snapshot(detail.snapshot)
                        institutionalSections(detail)
                        founderStory(detail)
                        whyItMatters(detail)
                    } else {
                        founderStory(detail)
                        whyItMatters(detail)
                        snapshot(detail.snapshot)
                        publicRevenueShareNotice(detail)
                        professionalSaleSection(detail)
                    }
                    if let ownership = detail.partialOwnership {
                        partialOwnership(ownership)
                    }
                    if let acquisition = detail.fullAcquisition {
                        fullAcquisition(acquisition)
                    }
                    if !detail.shareRewards.isEmpty {
                        ShareRewardsCard(rewards: detail.shareRewards, ownedCards: ownedCards(for: detail))
                    }
                    memoriesSection(detail)
                    Color.clear.frame(height: 80)
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom) { actionBar(detail) }
        .sheet(isPresented: $showInvest) {
            InvestFlowView(detail: detail)
        }
        .sheet(isPresented: $showAskQuestion) {
            AskQuestionView(businessName: detail.summary.name)
        }
        .sheet(isPresented: $showProfessionalBid) {
            if let sale = detail.professionalSale {
                ProfessionalBidSheet(sale: sale) { amount, message in
                    try await placeProfessionalBid(saleId: sale.id, amount: amount, message: message)
                }
            }
        }
        .sheet(isPresented: $showRetailPurchase) {
            if let sale = detail.professionalSale, let offer = sale.retailFallbackOffer {
                RetailPurchaseSheet(businessName: detail.summary.name, offer: offer) { buyerName in
                    await acceptRetailPurchase(saleId: sale.id, buyerName: buyerName)
                }
            }
        }
        .navigationDestination(isPresented: $showTakeover) {
            TakeoverGroupView(businessId: detail.id, businessName: detail.summary.name)
        }
        // Pushed after the owner/buyer accepts an offer — opens the deal chat.
        .navigationDestination(item: $openedDeal) { conversation in
            DealChatView(conversationId: conversation.id, conversation: conversation)
        }
        .sheet(isPresented: $showEdit) {
            EditBusinessSheet(businessId: detail.id, currentDescription: detail.summary.storyHeadline) { updated in
                self.detail = updated
            }
        }
        .sheet(isPresented: $showAddMemory) {
            AddMemorySheet(businessId: detail.id, businessName: detail.summary.name) { memory in
                self.detail?.communityMemories.insert(memory, at: 0)
            }
        }
    }

    /// Whether the viewer is an approved commercial investor.
    private var isInstitutionalView: Bool {
        profileStore.profile?.isInstitutionalInvestor ?? false
    }

    /// Whether the signed-in user owns *this* business (can edit it; cannot
    /// buy/bid/invest in it).
    private func isMyBusiness(_ detail: BusinessDetail) -> Bool {
        profileStore.isMyBusiness(detail)
    }

    @ViewBuilder
    private func institutionalSections(_ detail: BusinessDetail) -> some View {
        professionalSaleSection(detail)
        if let terms = detail.revenueShareTerms {
            RevenueShareCard(terms: terms, isInstitutionalView: true)
        }
    }

    @ViewBuilder
    private func professionalSaleSection(_ detail: BusinessDetail) -> some View {
        if let sale = detail.professionalSale {
            ProfessionalSaleCard(sale: sale, isProfessional: isInstitutionalView, isOwner: isMyBusiness(detail)) {
                showProfessionalBid = true
            } onAcceptBid: { bid in
                Task { await acceptCommercialBid(saleId: sale.id, bidId: bid.id) }
            } onAcceptGroupOffer: { offer in
                Task { await acceptGroupOffer(saleId: sale.id, offerId: offer.id) }
            } onDeclineToRetail: { price, allowOutright, allowGroup in
                Task { await declineCommercialBids(saleId: sale.id, retailAskingPrice: price, allowOutrightPurchase: allowOutright, allowGroupTakeover: allowGroup) }
            } onRetailPurchase: {
                showRetailPurchase = true
            } onGroupTakeover: {
                showTakeover = true
            }
        }
    }

    @ViewBuilder
    private func publicRevenueShareNotice(_ detail: BusinessDetail) -> some View {
        if detail.revenueShareTerms != nil {
            RevenueShareAccessCard()
        }
    }

    /// Image URLs for the hero gallery (gallery if present, else the hero).
    private func galleryURLs(_ detail: BusinessDetail) -> [URL] {
        detail.galleryImageURLs.isEmpty
            ? [detail.summary.heroImageURL].compactMap { $0 }
            : detail.galleryImageURLs
    }

    private func hero(_ detail: BusinessDetail) -> some View {
        let urls = galleryURLs(detail)
        return ZStack(alignment: .bottomLeading) {
            // Native paging gallery — avoids TabView gesture conflicts in scroll.
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(urls, id: \.absoluteString) { url in
                        RemoteImage(url: url, contentMode: .fill)
                            .containerRelativeFrame(.horizontal)
                            .frame(height: 340)
                            .clipped()
                            .id(url.absoluteString)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $galleryIndex)
            .frame(height: 340)

            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                .frame(height: 340)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                FlowLayout(spacing: 6) {
                    TagChip(text: detail.summary.category.displayName, systemImage: detail.summary.category.systemImage, style: .red)
                    TagChip(text: detail.summary.district.displayName, style: .gold)
                    if detail.summary.status.isUrgent {
                        TagChip(text: detail.summary.status.displayName, systemImage: "exclamationmark.triangle.fill", style: .red)
                    }
                }
                Text(detail.summary.storyHeadline)
                    .font(.lbiHero)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if urls.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(urls, id: \.absoluteString) { url in
                            Circle()
                                .fill(.white.opacity(galleryIndex == url.absoluteString || (galleryIndex == nil && url == urls.first) ? 1 : 0.4))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private func titleBlock(_ detail: BusinessDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(detail.summary.name).font(.lbiTitle).inkStyle()
            if !detail.tagline.isEmpty {
                Text(detail.tagline).font(.lbiBody).inkSecondaryStyle()
                    .fixedSize(horizontal: false, vertical: true)
            }
            FlowLayout(spacing: 6) {
                if let year = detail.summary.yearEstablished {
                    let age = Calendar.current.component(.year, from: Date()) - year
                    TagChip(text: "Est. \(year) · \(age) yrs", systemImage: "seal.fill", style: .gold)
                }
                TagChip(text: detail.summary.district.displayName, systemImage: "mappin.and.ellipse", style: .outline)
            }
        }
    }

    private func socialProof(_ detail: BusinessDetail) -> some View {
        HStack(spacing: Theme.Spacing.lg) {
            Label("\(detail.summary.savedCount.formatted()) saved", systemImage: "bookmark.fill")
            Label("\(detail.summary.viewCount.formatted()) views", systemImage: "eye.fill")
        }
        .font(.lbiCaption)
        .inkSecondaryStyle()
    }

    private func fundingBlock(_ detail: BusinessDetail) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let days = detail.summary.daysRemaining {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(detail.summary.status.isUrgent ? Theme.Palette.red : Theme.Palette.gold)
                        Text("\(days) day\(days == 1 ? "" : "s") left")
                            .font(.lbiMono)
                            .foregroundStyle(detail.summary.status.isUrgent ? Theme.Palette.red : Theme.Palette.ink)
                        Spacer()
                        Text(detail.summary.status.displayName)
                            .font(.lbiLabel)
                            .inkSecondaryStyle()
                    }
                }
                ProgressGoalBar(
                    progress: detail.summary.fundingProgress,
                    raisedLabel: "\(Money.hkd(detail.summary.fundingRaised)) raised",
                    goalLabel: "Goal \(Money.hkd(detail.summary.fundingGoal))",
                    tint: detail.summary.status.isUrgent ? Theme.Palette.red : Theme.Palette.red
                )
                Text("\(Int(detail.summary.fundingProgress * 100))% funded")
                    .font(.lbiCaption).inkSecondaryStyle()
            }
        }
    }

    private func founderStory(_ detail: BusinessDetail) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "The founder", subtitle: detail.founderName)
            Text(detail.founderStory).font(.lbiBody).inkStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func whyItMatters(_ detail: BusinessDetail) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Why this matters")
            Text(detail.whyItMatters).font(.lbiBody).inkStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func snapshot(_ snapshot: BusinessSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Business snapshot")
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                StatPill(label: "Founded", value: String(snapshot.foundedYear), icon: "calendar")
                StatPill(label: "Team", value: "\(snapshot.employees) people", icon: "person.2.fill")
                if let revenue = snapshot.monthlyRevenue {
                    StatPill(label: "Monthly revenue", value: Money.hkd(revenue, abbreviated: true), icon: "chart.bar.fill")
                }
            }
            if !snapshot.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(snapshot.highlights, id: \.self) { highlight in
                        Label(highlight, systemImage: "checkmark.seal.fill")
                            .font(.lbiBody).inkStyle()
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
    }

    private func partialOwnership(_ option: PartialOwnershipOption) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Label("Partial ownership", systemImage: "chart.pie.fill")
                    .font(.lbiHeadline).inkStyle()
                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                    StatPill(label: "Equity offered", value: "\(Int(option.equityOfferedPercent))%", icon: "chart.pie")
                    StatPill(label: "Valuation", value: Money.hkd(option.valuation, abbreviated: true), icon: "building.columns")
                    StatPill(label: "Minimum", value: Money.hkd(option.minimumInvestment, abbreviated: true), icon: "banknote")
                }
            }
        }
    }

    private func fullAcquisition(_ option: FullAcquisitionOption) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Label("Full acquisition", systemImage: "key.fill")
                    .font(.lbiHeadline).inkStyle()

                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                    StatPill(label: "Asking price", value: Money.hkd(option.askingPrice, abbreviated: true), icon: "tag.fill")
                    if let revenue = option.monthlyRevenue {
                        StatPill(label: "Monthly revenue", value: Money.hkd(revenue, abbreviated: true), icon: "chart.bar.fill")
                    }
                    if let staff = option.staffCount {
                        StatPill(label: "Staff", value: "\(staff)", icon: "person.2.fill")
                    }
                    if let lease = option.leaseYearsRemaining {
                        StatPill(label: "Lease left", value: "\(lease) yrs", icon: "calendar")
                    }
                }

                if option.ownerWillingToStay, let months = option.handoverMonths {
                    Label("Owner will stay for a \(months)-month handover", systemImage: "figure.2.arms.open")
                        .font(.lbiCaption).foregroundStyle(Theme.Palette.jade)
                }
                if option.openToGroupOffer {
                    TagChip(text: "Open to group offers", systemImage: "person.3.fill", style: .jade)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Includes").font(.lbiLabel).inkSecondaryStyle()
                    ForEach(option.includes, id: \.self) { item in
                        Label(item, systemImage: "checkmark").font(.lbiBody).inkStyle()
                    }
                }
            }
        }
    }

    /// Community memories with an "Add a memory" CTA. Any signed-in user (not
    /// the owner of this business) can contribute a memory.
    @ViewBuilder
    private func memoriesSection(_ detail: BusinessDetail) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if !detail.communityMemories.isEmpty {
                memories(detail.communityMemories)
            }
            if !isMyBusiness(detail) {
                SecondaryButton("Add a memory", systemImage: "text.bubble") { showAddMemory = true }
            }
        }
    }

    private func memories(_ memories: [CommunityMemory]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Community memories")
            ForEach(memories) { memory in
                CardContainer {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("“\(memory.text)”").font(.lbiBody).inkStyle()
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: Theme.Spacing.sm) {
                            Circle()
                                .fill(Theme.Palette.paperDeep)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Text(memory.authorInitials ?? String(memory.author.prefix(1)))
                                        .font(.lbiLabel).inkStyle()
                                )
                            VStack(alignment: .leading, spacing: 1) {
                                Text(memory.author).font(.lbiCaption).foregroundStyle(Theme.Palette.red)
                                if let relationship = memory.relationship {
                                    Text(relationship).font(.lbiLabel).inkSecondaryStyle()
                                }
                            }
                            Spacer()
                            if let years = memory.yearsAgo {
                                Text("\(years)y ago").font(.lbiLabel).inkSecondaryStyle()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Action bar

    private func actionBar(_ detail: BusinessDetail) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                Task { await profileStore.toggleSaved(detail.id) }
            } label: {
                Image(systemName: profileStore.isSaved(detail.id) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(profileStore.isSaved(detail.id) ? Theme.Palette.gold : Theme.Palette.ink)
                    .frame(width: 52, height: 52)
                    .background(Theme.Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                showAskQuestion = true
            } label: {
                Image(systemName: "bubble.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink)
                    .frame(width: 52, height: 52)
                    .background(Theme.Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if isMyBusiness(detail) {
                // You can't buy/bid/invest in your own business — you manage it.
                PrimaryButton("Edit business", systemImage: "square.and.pencil") { showEdit = true }
            } else if isInstitutionalView {
                // Commercial investors act via the deal card (bid / terms),
                // not consumer support or takeover-group actions.
                if detail.professionalSale == nil {
                    PrimaryButton(primaryActionTitle(detail), systemImage: "heart.fill") { showInvest = true }
                } else {
                    Spacer(minLength: 0)
                }
            } else if detail.hasTakeoverGroup {
                PrimaryButton("Join Takeover Group", systemImage: "person.3.fill") { showTakeover = true }
            } else {
                PrimaryButton(primaryActionTitle(detail), systemImage: "heart.fill") { showInvest = true }
            }
        }
        .padding(Theme.Spacing.md)
        .background(.ultraThinMaterial)
    }

    private func primaryActionTitle(_ detail: BusinessDetail) -> String {
        switch detail.summary.status {
        case .preserved: return "Support"
        case .seekingBuyer, .inNegotiation, .underOffer: return "Express Interest"
        case .raising, .urgentRisk, .fullyFunded: return "Support"
        }
    }

    private var errorState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Couldn't load this business").font(.lbiHeadline).inkStyle()
            if let errorMessage { Text(errorMessage).font(.lbiBody).inkSecondaryStyle() }
            SecondaryButton("Try again") { Task { await load() } }.frame(width: 160)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    /// How many support cards the current supporter has collected for this business.
    /// (Mock: derived from their recorded support for this business.)
    private func ownedCards(for detail: BusinessDetail) -> Int {
        (profileStore.profile?.investments ?? [])
            .filter { $0.businessId == detail.id }
            .reduce(0) { $0 + $1.supportCards }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await environment.businessRepository.detail(id: businessId)
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Something went wrong."
        }
        isLoading = false
    }

    @MainActor
    private func placeProfessionalBid(saleId: String, amount: Decimal, message: String?) async throws {
        let bid = try await environment.saleRepository.placeBid(saleId: saleId, amount: amount, message: message)
        detail?.professionalSale?.bids.append(bid)
    }

    @MainActor
    private func acceptCommercialBid(saleId: String, bidId: String) async {
        guard let result = try? await environment.saleRepository.acceptBid(saleId: saleId, bidId: bidId) else { return }
        detail?.professionalSale = result.sale
        openedDeal = result.conversation
    }

    @MainActor
    private func acceptGroupOffer(saleId: String, offerId: String) async {
        guard let result = try? await environment.saleRepository.acceptGroupOffer(saleId: saleId, offerId: offerId) else { return }
        detail?.professionalSale = result.sale
        openedDeal = result.conversation
    }

    @MainActor
    private func acceptRetailPurchase(saleId: String, buyerName: String) async -> Bool {
        guard let result = try? await environment.saleRepository.acceptRetailPurchase(saleId: saleId, buyerName: buyerName) else { return false }
        detail?.professionalSale = result.sale
        openedDeal = result.conversation
        return true
    }

    @MainActor
    private func declineCommercialBids(saleId: String, retailAskingPrice: Decimal, allowOutrightPurchase: Bool, allowGroupTakeover: Bool) async {
        detail?.professionalSale = try? await environment.saleRepository.declineCommercialBids(
            saleId: saleId,
            retailAskingPrice: retailAskingPrice,
            allowOutrightPurchase: allowOutrightPurchase,
            allowGroupTakeover: allowGroupTakeover
        )
    }
}

#Preview {
    NavigationStack {
        BusinessDetailView(businessId: "biz-002")
            .environment(AppEnvironment.preview)
            .environment(previewProfileStore())
    }
}
