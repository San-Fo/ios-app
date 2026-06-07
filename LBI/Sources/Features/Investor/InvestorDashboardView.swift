import SwiftUI

/// Commercial-investor home: data and active deal workflow first, not stories.
struct InvestorDashboardView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var sales: [ProfessionalSale] = []
    @State private var businesses: [BusinessDetail] = []
    @State private var isLoading = true

    private var activeSales: [ProfessionalSale] {
        sales.filter { [.commercialBidding, .ownerDecision].contains($0.stage) }
    }

    private var activeBids: [SaleBid] {
        sales.flatMap(\.bids).filter { $0.status == .submitted }.sorted { $0.amount > $1.amount }
    }

    private var loanDeals: [BusinessDetail] {
        businesses.filter { $0.revenueShareTerms != nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header
                    overviewGrid
                    activeBidsSection
                    aiMemosSection
                    loanSearchesSection
                    acquisitionPipelineSection
                    publicMarketSection
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.paper)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Commercial Desk")
                .font(.lbiHero)
                .inkStyle()
            Text("AI-screened acquisitions, live bids, and revenue-share loan searches.")
                .font(.lbiBody)
                .inkSecondaryStyle()
        }
    }

    private var overviewGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
            StatPill(label: "Active sales", value: "\(activeSales.count)", icon: "briefcase.fill")
            StatPill(label: "Live bids", value: "\(activeBids.count)", icon: "hammer.fill")
            StatPill(label: "Loan searches", value: "\(loanDeals.count)", icon: "percent")
            StatPill(label: "Avg AI score", value: averageAIScore, icon: "sparkles")
        }
    }

    private var activeBidsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Active bids", subtitle: "Commercial offers currently in play")
            if activeBids.isEmpty {
                emptyCard("No active bids yet.")
            } else {
                ForEach(activeSales.filter { !$0.bids.isEmpty }) { sale in
                    NavigationLink {
                        BusinessDetailView(businessId: sale.businessId)
                    } label: {
                        InvestorSaleRow(sale: sale)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var ratedSales: [ProfessionalSale] {
        sales
            .filter { $0.aiEvaluation != nil }
            .sorted { ($0.aiEvaluation?.score ?? 0) > ($1.aiEvaluation?.score ?? 0) }
    }

    private var aiMemosSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "AI investment memos", subtitle: "Backend screening for approved commercial investors")
            if ratedSales.isEmpty {
                emptyCard("No AI memos available yet.")
            } else {
                ForEach(ratedSales) { sale in
                    if let evaluation = sale.aiEvaluation {
                        NavigationLink {
                            BusinessDetailView(businessId: sale.businessId)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(sale.businessName)
                                    .font(.lbiSubtitle)
                                    .inkStyle()
                                AIMemoCard(evaluation: evaluation)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var loanSearchesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Revenue-share loan searches", subtitle: "Terms available only to approved commercial investors")
            ForEach(loanDeals) { detail in
                NavigationLink {
                    BusinessDetailView(businessId: detail.id)
                } label: {
                    InvestorLoanRow(detail: detail)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var acquisitionPipelineSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "AI-screened acquisition pipeline", subtitle: "Commercial-first business sales")
            ForEach(sales) { sale in
                NavigationLink {
                    BusinessDetailView(businessId: sale.businessId)
                } label: {
                    InvestorSaleRow(sale: sale)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var publicMarketSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Public fallback market", subtitle: "Declined commercial bids now open to retail or groups")
            let fallbackSales = sales.filter { $0.stage == .openToRetail }
            if fallbackSales.isEmpty {
                emptyCard("No public fallback sales currently open.")
            } else {
                ForEach(fallbackSales) { sale in
                    NavigationLink {
                        BusinessDetailView(businessId: sale.businessId)
                    } label: {
                        InvestorSaleRow(sale: sale)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var averageAIScore: String {
        let scores = sales.compactMap(\.aiEvaluation?.score)
        guard !scores.isEmpty else { return "-" }
        return "\(scores.reduce(0, +) / scores.count)"
    }

    private func emptyCard(_ text: String) -> some View {
        CardContainer { Text(text).font(.lbiBody).inkSecondaryStyle() }
    }

    private func load() async {
        isLoading = true
        sales = (try? await environment.saleRepository.sales()) ?? []
        let summaries = (try? await environment.businessRepository.list(query: BusinessQuery())) ?? []
        businesses = await summaries.asyncCompactMap { try? await environment.businessRepository.detail(id: $0.id) }
        isLoading = false
    }
}

struct InvestorOpportunitiesView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var sales: [ProfessionalSale] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    SectionHeader(title: "Deal Pipeline", subtitle: "Commercial acquisition opportunities first")
                    ForEach(sales) { sale in
                        NavigationLink {
                            BusinessDetailView(businessId: sale.businessId)
                        } label: {
                            InvestorSaleRow(sale: sale)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.paper)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { sales = (try? await environment.saleRepository.sales()) ?? [] }
    }
}

struct InvestorSearchView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var searchText = ""
    @State private var filters = InvestorDealFilters()
    @State private var sales: [ProfessionalSale] = []
    @State private var businesses: [BusinessDetail] = []
    @State private var isLoading = true
    @State private var showFilters = false

    private var deals: [InvestorDeal] {
        InvestorDealSearchLogic.filtered(sales: sales, businesses: businesses, text: searchText, filters: filters)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header
                    activeFilters

                    if isLoading {
                        ProgressView().tint(Theme.Palette.red)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Spacing.xl)
                    } else if deals.isEmpty {
                        emptyState
                    } else {
                        Text("\(deals.count) deal\(deals.count == 1 ? "" : "s")")
                            .font(.lbiCaption)
                            .inkSecondaryStyle()
                        ForEach(deals) { deal in
                            NavigationLink {
                                BusinessDetailView(businessId: deal.businessId)
                            } label: {
                                InvestorDealRow(deal: deal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.paper)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFilters = true } label: {
                        Image(systemName: filters.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(Theme.Palette.red)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Deal, owner, district, terms...")
            .sheet(isPresented: $showFilters) {
                InvestorDealFiltersView(filters: $filters)
            }
        }
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Deal Search")
                .font(.lbiHero)
                .inkStyle()
            Text("Search the full commercial deal universe. Public onboarding interests and districts are ignored here.")
                .font(.lbiBody)
                .inkSecondaryStyle()
        }
    }

    @ViewBuilder
    private var activeFilters: some View {
        if !filters.isEmpty {
            FlowLayout(spacing: 8) {
                if let amount = filters.minimumLoanAmount {
                    TagChip(text: "Loan >= \(Money.hkd(amount, abbreviated: true))", systemImage: "percent", style: .gold)
                }
                if let amount = filters.minimumAskingPrice {
                    TagChip(text: "Ask >= \(Money.hkd(amount, abbreviated: true))", systemImage: "tag.fill", style: .red)
                }
                if let score = filters.minimumAIScore {
                    TagChip(text: "AI >= \(score)", systemImage: "sparkles", style: .jade)
                }
                ForEach(Array(filters.stages), id: \.self) { stage in
                    TagChip(text: stage.displayName, style: .outline)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.Palette.inkSecondary.opacity(0.4))
            Text("No deals match").font(.lbiHeadline).inkStyle()
            Text("Try lowering the financial thresholds or clearing stage filters.")
                .font(.lbiBody)
                .inkSecondaryStyle()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.xl)
    }

    private func load() async {
        isLoading = true
        sales = (try? await environment.saleRepository.sales()) ?? []
        let summaries = (try? await environment.businessRepository.list(query: BusinessQuery())) ?? []
        businesses = await summaries.asyncCompactMap { try? await environment.businessRepository.detail(id: $0.id) }
        isLoading = false
    }
}

/// Investor-entered deal filters. These are deliberately separate from the
/// public onboarding preferences — investor search must never be influenced by
/// a user's interests/districts. Text fields are kept as strings so partial
/// input parses leniently (empty/invalid = no constraint).
struct InvestorDealFilters: Equatable {
    var includeAcquisitions = true
    var includeLoans = true
    var minimumLoanAmountText = ""
    var minimumAskingPriceText = ""
    var minimumAIScoreText = ""
    var stages: Set<SaleStage> = []

    var minimumLoanAmount: Decimal? { Decimal(string: minimumLoanAmountText) }
    var minimumAskingPrice: Decimal? { Decimal(string: minimumAskingPriceText) }
    var minimumAIScore: Int? { Int(minimumAIScoreText) }

    /// True when no constraints are applied (both deal types on, no thresholds).
    var isEmpty: Bool {
        includeAcquisitions && includeLoans
            && minimumLoanAmountText.isEmpty
            && minimumAskingPriceText.isEmpty
            && minimumAIScoreText.isEmpty
            && stages.isEmpty
    }
}

/// A unified row in investor deal search: either a business sale or a
/// revenue-share loan opportunity.
enum InvestorDeal: Identifiable, Equatable {
    case sale(ProfessionalSale)
    case loan(BusinessDetail)

    /// Prefixed so sale and loan rows for the same business stay distinct.
    var id: String {
        switch self {
        case let .sale(sale): return "sale-\(sale.id)"
        case let .loan(detail): return "loan-\(detail.id)"
        }
    }

    /// The underlying business id (for navigation to the detail screen).
    var businessId: String {
        switch self {
        case let .sale(sale): return sale.businessId
        case let .loan(detail): return detail.id
        }
    }
}

/// Pure, testable filtering for investor deal search. Kept free of view state
/// so it can be unit-tested directly (see `InvestorDealSearch*` tests).
enum InvestorDealSearchLogic {
    /// Combines acquisition sales and revenue-share loans, applying only the
    /// investor's explicit filters and free-text query.
    static func filtered(sales: [ProfessionalSale], businesses: [BusinessDetail], text: String, filters: InvestorDealFilters) -> [InvestorDeal] {
        var deals: [InvestorDeal] = []

        if filters.includeAcquisitions {
            deals += sales
                .filter { sale in matches(sale, text: text, filters: filters) }
                .map(InvestorDeal.sale)
        }

        if filters.includeLoans {
            // Only businesses that actually offer a revenue-share loan.
            deals += businesses
                .filter { $0.revenueShareTerms != nil }
                .filter { detail in matchesLoan(detail, text: text, filters: filters) }
                .map(InvestorDeal.loan)
        }

        return deals
    }

    /// Whether a sale passes the financial thresholds, stage filter and text query.
    private static func matches(_ sale: ProfessionalSale, text: String, filters: InvestorDealFilters) -> Bool {
        if let minimum = filters.minimumAskingPrice, sale.askingPrice < minimum { return false }
        if let score = filters.minimumAIScore, (sale.aiEvaluation?.score ?? 0) < score { return false }
        if !filters.stages.isEmpty, !filters.stages.contains(sale.stage) { return false }
        guard !text.isEmpty else { return true }
        return sale.businessName.localizedCaseInsensitiveContains(text)
            || sale.stage.displayName.localizedCaseInsensitiveContains(text)
            || sale.includes.contains { $0.localizedCaseInsensitiveContains(text) }
    }

    /// Whether a loan opportunity passes the minimum-amount filter and text query.
    private static func matchesLoan(_ detail: BusinessDetail, text: String, filters: InvestorDealFilters) -> Bool {
        guard let terms = detail.revenueShareTerms else { return false }
        if let minimum = filters.minimumLoanAmount, terms.fundingTarget < minimum { return false }
        guard !text.isEmpty else { return true }
        return detail.summary.name.localizedCaseInsensitiveContains(text)
            || detail.summary.district.displayName.localizedCaseInsensitiveContains(text)
            || terms.useOfFunds.localizedCaseInsensitiveContains(text)
    }
}

private struct InvestorDealRow: View {
    let deal: InvestorDeal

    var body: some View {
        switch deal {
        case let .sale(sale):
            InvestorSaleRow(sale: sale)
        case let .loan(detail):
            InvestorLoanRow(detail: detail)
        }
    }
}

private struct InvestorDealFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: InvestorDealFilters
    @State private var draft = InvestorDealFilters()

    var body: some View {
        NavigationStack {
            Form {
                Section("Deal types") {
                    Toggle("Acquisition offers", isOn: $draft.includeAcquisitions)
                    Toggle("Revenue-share loans", isOn: $draft.includeLoans)
                }

                Section("Financial thresholds") {
                    TextField("Minimum loan amount", text: $draft.minimumLoanAmountText)
                        .keyboardType(.numberPad)
                    TextField("Minimum acquisition ask", text: $draft.minimumAskingPriceText)
                        .keyboardType(.numberPad)
                    TextField("Minimum AI score", text: $draft.minimumAIScoreText)
                        .keyboardType(.numberPad)
                }

                Section("Sale stages") {
                    ForEach(SaleStage.allCases, id: \.self) { stage in
                        Toggle(stage.displayName, isOn: stageBinding(stage))
                    }
                }
            }
            .navigationTitle("Deal Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") { draft = InvestorDealFilters() }
                        .foregroundStyle(Theme.Palette.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        filters = draft
                        dismiss()
                    }
                    .foregroundStyle(Theme.Palette.red)
                }
            }
        }
        .onAppear { draft = filters }
    }

    private func stageBinding(_ stage: SaleStage) -> Binding<Bool> {
        Binding(
            get: { draft.stages.contains(stage) },
            set: { enabled in
                if enabled { draft.stages.insert(stage) }
                else { draft.stages.remove(stage) }
            }
        )
    }
}

private struct InvestorSaleRow: View {
    let sale: ProfessionalSale

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sale.businessName).font(.lbiHeadline).inkStyle()
                        Text(sale.stage.displayName).font(.lbiCaption).foregroundStyle(Theme.Palette.red)
                    }
                    Spacer()
                    if let score = sale.aiEvaluation?.score {
                        Text("AI \(score)")
                            .font(.lbiMonoSmall)
                            .foregroundStyle(Theme.Palette.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Theme.Palette.gold.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                    StatPill(label: "Guide", value: Money.hkd(sale.askingPrice, abbreviated: true), icon: "tag.fill")
                    StatPill(label: "Highest bid", value: sale.highestBid.map { Money.hkd($0.amount, abbreviated: true) } ?? "-", icon: "hammer.fill")
                    StatPill(label: "Annual profit", value: Money.hkd(sale.financials.annualProfit, abbreviated: true), icon: "chart.line.uptrend.xyaxis")
                    if let fallback = sale.retailFallbackOffer {
                        StatPill(label: "Public price", value: Money.hkd(fallback.askingPrice, abbreviated: true), icon: "person.3.fill")
                    }
                }
            }
        }
    }
}

private struct InvestorLoanRow: View {
    let detail: BusinessDetail

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(detail.summary.name).font(.lbiHeadline).inkStyle()
                if let terms = detail.revenueShareTerms {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                        StatPill(label: "Target", value: Money.hkd(terms.fundingTarget, abbreviated: true), icon: "target")
                        StatPill(label: "Revenue share", value: "\(Int(terms.revenueSharePercent))%", icon: "percent")
                        StatPill(label: "Return", value: "\(terms.targetMultiple)x", icon: "arrow.up.right")
                        StatPill(label: "Period", value: "\(terms.estimatedMonths) mo", icon: "calendar")
                    }
                }
            }
        }
    }
}

private extension Sequence {
    /// Sequentially `compactMap`s with an async transform (awaits each element
    /// in order). Used to hydrate business details from their summaries.
    func asyncCompactMap<T>(_ transform: (Element) async -> T?) async -> [T] {
        var values: [T] = []
        for element in self {
            if let value = await transform(element) { values.append(value) }
        }
        return values
    }
}

#Preview {
    InvestorDashboardView()
        .environment(AppEnvironment.preview)
}
