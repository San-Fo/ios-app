import Testing
@testable import LBI
import Foundation

/// Unit tests for the app's domain logic and DTO mapping, exercised against the
/// in-memory mock repositories (no network). Grouped loosely by area:
/// recommendations/search, DTO decoding, sample-data integrity, the
/// professional-sale + deal-chat flow, investor deal search, and verification.
struct LBITests {

    @Test func recommendationRanksByInterestAndDistrict() async throws {
        let repo = MockBusinessRepository()
        var profile = UserProfile.empty(id: "u", displayName: "Test", email: nil)
        profile.interests = [.bookstore]
        profile.districts = [.wanChai]

        let results = try await repo.recommended(for: profile)
        #expect(results.first?.category == .bookstore)
    }

    @Test func recommendationsKeepAllBusinessesVisible() async throws {
        let repo = MockBusinessRepository()
        var profile = UserProfile.empty(id: "u", displayName: "Test", email: nil)
        profile.interests = [.bookstore]
        profile.districts = [.wanChai]

        let results = try await repo.recommended(for: profile)

        #expect(results.count == SampleData.summaries.count)
        #expect(Set(results.map(\.id)) == Set(SampleData.summaries.map(\.id)))
    }

    @Test func recommendationsMoveLessRelevantBusinessesLowerInsteadOfRemoving() async throws {
        let repo = MockBusinessRepository()
        var profile = UserProfile.empty(id: "u", displayName: "Test", email: nil)
        profile.interests = [.bookstore]
        profile.districts = [.wanChai]

        let results = try await repo.recommended(for: profile)
        let matchedIndex = try #require(results.firstIndex { $0.category == .bookstore && $0.district == .wanChai })
        let lessRelevantIndex = try #require(results.firstIndex { $0.category != .bookstore && $0.district != .wanChai })

        #expect(matchedIndex < lessRelevantIndex)
    }

    @Test func searchFiltersByCategory() async throws {
        let repo = MockBusinessRepository()
        var query = BusinessQuery()
        query.categories = [.gym]

        let results = try await repo.list(query: query)
        #expect(results.allSatisfy { $0.category == .gym })
        #expect(!results.isEmpty)
    }

    @Test func searchFiltersByText() async throws {
        let repo = MockBusinessRepository()
        var query = BusinessQuery()
        query.text = "Peak Bookstore"

        let results = try await repo.list(query: query)
        #expect(results.count == 1)
        #expect(results.first?.id == "biz-003")
    }

    @Test func businessDTOMapsToDomain() {
        let dto = BusinessDTO(
            id: "x",
            name: "Test Shop",
            category: "bakery",
            district: "wanChai",
            storyHeadline: "A headline",
            heroImageURL: nil,
            status: "raising",
            fundingGoal: 100,
            fundingRaised: 50,
            fundingOptions: ["revenueShare", "unknownKind"],
            yearEstablished: 1980,
            deadline: nil,
            savedCount: 12,
            viewCount: 99
        )
        let business = dto.toDomain()
        #expect(business.category == .bakery)
        #expect(business.district == .wanChai)
        #expect(business.fundingProgress == 0.5)
        #expect(business.fundingOptions == [.revenueShare])
        #expect(business.yearEstablished == 1980)
        #expect(business.savedCount == 12)
    }

    @Test func fundingProgressClampsToOne() {
        var business = SampleData.summaries[0]
        business.fundingRaised = business.fundingGoal * 2
        #expect(business.fundingProgress == 1)
    }

    @Test func tokenStoreSavesAndClears() {
        let store = InMemoryTokenStore()
        #expect(store.currentToken() == nil)
        store.save(token: "abc")
        #expect(store.currentToken() == "abc")
        store.clear()
        #expect(store.currentToken() == nil)
    }

    // MARK: Merged-feature coverage

    @Test func sampleDataHasSixBusinesses() {
        #expect(SampleData.businesses.count == 6)
        // Every business detail has a non-empty story and a snapshot address.
        for detail in SampleData.businesses {
            #expect(!detail.founderStory.isEmpty)
            #expect(!detail.whyItMatters.isEmpty)
            #expect(detail.snapshot.foundedYear > 0)
        }
    }

    @Test func urgentBusinessHasDeadline() {
        let urgent = SampleData.summaries.first { $0.status == .urgentRisk }
        #expect(urgent != nil)
        #expect(urgent?.daysRemaining != nil)
    }

    @Test func takeoverGroupsResolveByBusiness() {
        let group = SampleData.group(forBusiness: "biz-002")
        #expect(group != nil)
        #expect(group?.status == .negotiating)
        #expect(group?.roles.contains { !$0.isFilled } == true)
    }

    @Test func shareRewardsAreSortedByThreshold() {
        let rewards = SampleData.wongNoodleShop.shareRewards
        #expect(!rewards.isEmpty)
        // BusinessDetail sorts rewards ascending by cardsRequired.
        #expect(rewards == rewards.sorted())
        #expect(rewards.first?.cardsRequired == 1)
    }

    @Test func shareRewardDTOMapsToDomain() {
        let dto = ShareRewardDTO(id: "r1", cardsRequired: 5, title: "Free coffee", detail: "Monthly")
        let reward = dto.toDomain()
        #expect(reward.cardsRequired == 5)
        #expect(reward.title == "Free coffee")
        #expect(reward.detail == "Monthly")
    }

    @Test func revenueShareBreakdownSumsTo約100() {
        let terms = SampleData.wongNoodleShop.revenueShareTerms!
        let total = terms.useOfFundsBreakdown.reduce(0) { $0 + $1.percentage }
        #expect(abs(total - 100) < 1.0)
    }

    @Test func businessDetailDTOMapsRichFields() {
        let dto = BusinessDetailDTO(
            id: "x",
            summary: BusinessDTO(
                id: "x", name: "T", category: "gym", district: "eastern",
                storyHeadline: "h", heroImageURL: nil, status: "seekingBuyer",
                fundingGoal: 0, fundingRaised: 0, fundingOptions: ["fullAcquisition"],
                yearEstablished: 1990, deadline: nil, savedCount: nil, viewCount: nil
            ),
            tagline: "tag",
            founderName: "F",
            founderStory: "s",
            whyItMatters: "w",
            communityMemories: [CommunityMemoryDTO(id: "m", author: "A", text: "t", yearsAgo: 3, authorInitials: nil, relationship: "Regular")],
            snapshot: BusinessSnapshotDTO(foundedYear: 1990, employees: 2, monthlyRevenue: 1000, address: "addr", highlights: ["x"]),
            useOfFunds: "u",
            revenueShareTerms: nil,
            partialOwnership: nil,
            fullAcquisition: FullAcquisitionDTO(askingPrice: 500, openToGroupOffer: true, includes: ["a"], includesProperty: nil, leaseYearsRemaining: 5, monthlyRevenue: 1000, staffCount: 2, ownerWillingToStay: true, handoverMonths: 6),
            hasTakeoverGroup: false,
            galleryImageURLs: ["https://example.com/a.jpg"],
            shareRewards: [ShareRewardDTO(id: "r", cardsRequired: 3, title: "Perk", detail: nil)],
            professionalSale: nil
        )
        let detail = dto.toDomain()
        #expect(detail.tagline == "tag")
        #expect(detail.communityMemories.first?.relationship == "Regular")
        #expect(detail.fullAcquisition?.ownerWillingToStay == true)
        #expect(detail.galleryImageURLs.count == 1)
        #expect(detail.shareRewards.first?.cardsRequired == 3)
    }

    @Test func sampleBusinessDetailIncludesProfessionalSale() {
        let detail = SampleData.detail(for: "biz-002")
        #expect(detail?.professionalSale?.stage == .commercialBidding)
        #expect(detail?.professionalSale?.aiEvaluation?.verdict == .recommendedForCommercialBidding)
        #expect(detail?.professionalSale?.ownerWillingToStay == true)
        #expect(detail?.professionalSale?.bids.count == 2)
    }

    @Test func professionalSaleDTOMapsToDomain() {
        let dto = ProfessionalSaleDTO(
            id: "sale-x",
            businessId: "biz-x",
            businessName: "Shop",
            stage: "openToRetail",
            askingPrice: 1_000_000,
            aiEvaluation: SaleEvaluationDTO(score: 88, verdict: "recommendedForCommercialBidding", strengths: ["Profit"], risks: ["Lease"], summary: "Strong", recommendedAction: "Bid now", confidence: 0.9),
            commercialBiddingEndsAt: Date(),
            financials: SaleFinancialsDTO(
                annualRevenue: 800_000,
                annualProfit: 160_000,
                monthlyRent: 20_000,
                leaseYearsRemaining: 3,
                staffCount: 2,
                inventoryValue: 50_000,
                notes: "Stable"
            ),
            includes: ["Brand"],
            ownerWillingToStay: true,
            handoverMonths: 6,
            retailFallbackOffer: RetailFallbackOfferDTO(askingPrice: 1_200_000, allowOutrightPurchase: true, allowGroupTakeover: true, ownerNote: "Public fallback"),
            bids: [
                SaleBidDTO(id: "bid-x", bidderName: "Buyer", bidderCredential: "Operator", amount: 900_000, message: "Keep staff", date: Date(), status: "submitted")
            ],
            groupOffers: nil
        )

        let sale = dto.toDomain()
        #expect(sale.stage == .openToRetail)
        #expect(sale.aiEvaluation?.score == 88)
        #expect(sale.aiEvaluation?.recommendedAction == "Bid now")
        #expect(sale.aiEvaluation?.confidencePercent == 90)
        #expect(sale.aiEvaluation?.rating == .strong)
        #expect(sale.retailFallbackOffer?.askingPrice == 1_200_000)
        #expect(sale.financials.staffCount == 2)
        #expect(sale.includes == ["Brand"])
        #expect(sale.bids.first?.amount == 900_000)
    }

    @Test func evaluationRatingBucketsByScore() {
        func rating(_ score: Int) -> EvaluationRating {
            SaleEvaluation(score: score, verdict: .needsManualReview, strengths: [], risks: [], summary: "").rating
        }
        #expect(rating(90) == .strong)
        #expect(rating(78) == .promising)
        #expect(rating(60) == .cautious)
        #expect(rating(40) == .weak)
    }

    @Test func mockSaleRepositorySubmitsBid() async throws {
        let repo = MockSaleRepository()
        let before = try await repo.sale(forBusiness: "biz-002")
        let bid = try await repo.placeBid(saleId: "sale-002", amount: 2_100_000, message: "Professional handover plan")
        let after = try await repo.sale(forBusiness: "biz-002")

        #expect(before?.bids.count == 2)
        #expect(bid.isCurrentUser)
        #expect(after?.bids.count == 3)
        #expect(after?.highestBid?.amount == 2_100_000)
    }

    @Test func mockSaleRepositoryAcceptsCommercialBid() async throws {
        let repo = MockSaleRepository()
        let accepted = try await repo.acceptBid(saleId: "sale-002", bidId: "bid-2")

        #expect(accepted.sale.stage == .accepted)
        #expect(accepted.sale.acceptedBid?.id == "bid-2")
        #expect(accepted.sale.bids.first { $0.id == "bid-1" }?.status == .rejected)
        #expect(accepted.conversation.dealKind == .commercialBid)
        #expect(accepted.conversation.agreedAmount == 2_050_000)
    }

    @Test func mockSaleRepositoryAcceptsGroupOfferBelowAsk() async throws {
        let repo = MockSaleRepository()
        let before = try await repo.sale(forBusiness: "biz-004")
        #expect(before?.groupOffers.first?.amount == 1_620_000)
        // The group offer is below the owner's public fallback price.
        #expect((before?.retailFallbackOffer?.askingPrice ?? 0) > (before?.groupOffers.first?.amount ?? 0))

        let accepted = try await repo.acceptGroupOffer(saleId: "sale-004", offerId: "go-1")
        #expect(accepted.sale.stage == .accepted)
        #expect(accepted.conversation.dealKind == .groupTakeover)
        #expect(accepted.conversation.agreedAmount == 1_620_000)
    }

    @Test func acceptingOfferOpensDealChatConversation() async throws {
        let chat = MockDealChatRepository()
        let repo = MockSaleRepository(dealChat: chat)
        let accepted = try await repo.acceptBid(saleId: "sale-002", bidId: "bid-2")

        let fetched = try await chat.conversation(id: accepted.conversation.id)
        #expect(fetched != nil)

        let sent = try await chat.sendMessage(conversationId: accepted.conversation.id, text: "When can we discuss payment?")
        #expect(sent.isCurrentUser)
        let convo = try await chat.conversation(id: accepted.conversation.id)
        // System seed + our message + auto reply.
        #expect((convo?.messages.count ?? 0) >= 3)
    }

    @Test func mockSaleRepositoryDeclinesToRetailFallback() async throws {
        let repo = MockSaleRepository()
        let sale = try await repo.declineCommercialBids(
            saleId: "sale-002",
            retailAskingPrice: 2_600_000,
            allowOutrightPurchase: true,
            allowGroupTakeover: false
        )

        #expect(sale.stage == .openToRetail)
        #expect(sale.retailFallbackOffer?.askingPrice == 2_600_000)
        #expect(sale.retailFallbackOffer?.allowOutrightPurchase == true)
        #expect(sale.retailFallbackOffer?.allowGroupTakeover == false)
        #expect(sale.bids.allSatisfy { $0.status == .rejected })
    }

    @Test func investorDealSearchFiltersLoanAmountOnlyFromExplicitFilters() {
        var filters = InvestorDealFilters()
        filters.includeAcquisitions = false
        filters.minimumLoanAmountText = "400000"

        let deals = InvestorDealSearchLogic.filtered(
            sales: SampleData.professionalSales,
            businesses: SampleData.businesses,
            text: "",
            filters: filters
        )

        #expect(!deals.isEmpty)
        #expect(deals.allSatisfy {
            if case let .loan(detail) = $0, let target = detail.revenueShareTerms?.fundingTarget {
                return target >= 400_000
            }
            return false
        })
    }

    @Test func investorDealSearchFiltersAcquisitionCriteriaOnlyFromExplicitFilters() {
        var filters = InvestorDealFilters()
        filters.includeLoans = false
        filters.minimumAskingPriceText = "2000000"
        filters.minimumAIScoreText = "90"
        filters.stages = [.commercialBidding]

        let deals = InvestorDealSearchLogic.filtered(
            sales: SampleData.professionalSales,
            businesses: SampleData.businesses,
            text: "",
            filters: filters
        )

        #expect(deals == [.sale(SampleData.professionalSales.first { $0.id == "sale-002" }!)])
    }

    @Test func investorDealSearchHasNoProfilePreferenceInput() {
        let filters = InvestorDealFilters()
        let deals = InvestorDealSearchLogic.filtered(
            sales: SampleData.professionalSales,
            businesses: SampleData.businesses,
            text: "",
            filters: filters
        )
        let loanCount = SampleData.businesses.filter { $0.revenueShareTerms != nil }.count

        #expect(deals.count == SampleData.professionalSales.count + loanCount)
    }

    /// Decodes a `UserProfileDTO` from server-shaped JSON.
    private func decodeUser(_ json: String) throws -> UserProfileDTO {
        try JSONDecoder.lbiDefault.decode(UserProfileDTO.self, from: Data(json.utf8))
    }

    @Test func profileDTODefaultsToRetailFromServerUser() throws {
        let user = AuthenticatedUser(id: "u", displayName: "Demo", email: nil)
        let dto = try decodeUser("""
        { "id": "u", "verificationState": "unverified", "investorStatus": "unverified" }
        """)
        let profile = dto.toDomain(fallback: user)
        #expect(profile.role == .retail)
        #expect(!profile.isProInvestorVerified)
    }

    @Test func profileDTOMapsInstitutionalInvestorToProfessional() throws {
        let user = AuthenticatedUser(id: "u", displayName: "Demo", email: nil)
        let dto = try decodeUser("""
        { "id": "u", "verificationState": "verified", "investorStatus": "institutionalVerified" }
        """)
        let profile = dto.toDomain(fallback: user)
        #expect(profile.isInstitutionalInvestor)
        #expect(profile.isProInvestorVerified)
        #expect(profile.isIdentityVerified)
    }

    // MARK: Verification

    @Test func newUserHasNoVerificationsAndDefaults() {
        let profile = UserProfile.empty(id: "u", displayName: "Demo", email: nil)
        #expect(profile.verificationStatus(.kyc) == .notStarted)
        #expect(!profile.isBusinessVerified)
        #expect(!profile.isProInvestorVerified)
        #expect(profile.verificationStatus(.kyb).needsAction)
    }

    @Test func profileDTOMapsVerificationStateFromServer() throws {
        let user = AuthenticatedUser(id: "u", displayName: "Demo", email: nil)
        let dto = try decodeUser("""
        { "id": "u", "verificationState": "verified", "investorStatus": "pending" }
        """)
        let profile = dto.toDomain(fallback: user)
        #expect(profile.verificationStatus(.kyc) == .approved)
        #expect(profile.verificationStatus(.proInvestor) == .pending)
    }

    @Test func bsonDateDecodesCanonicalAndRelaxedForms() throws {
        struct Wrapper: Decodable { let createdAt: BSONDate }
        let canonical = try JSONDecoder.lbiDefault.decode(
            Wrapper.self,
            from: Data(#"{ "createdAt": { "$date": { "$numberLong": "1700000000000" } } }"#.utf8)
        )
        #expect(Int(canonical.createdAt.date.timeIntervalSince1970) == 1_700_000_000)

        let relaxed = try JSONDecoder.lbiDefault.decode(
            Wrapper.self,
            from: Data(#"{ "createdAt": { "$date": "2023-11-14T22:13:20Z" } }"#.utf8)
        )
        #expect(Int(relaxed.createdAt.date.timeIntervalSince1970) == 1_700_000_000)
    }

    @Test func bsonDateEncodesCanonicalMillis() throws {
        struct Wrapper: Encodable { let birthDate: BSONDate }
        let data = try JSONEncoder.lbiDefault.encode(
            Wrapper(birthDate: BSONDate(Date(timeIntervalSince1970: 1_700_000_000)))
        )
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("$numberLong"))
        #expect(json.contains("1700000000000"))
    }

    @Test func mockVerificationRepositoryApprovesAndGrantsRoleOnSubmit() async throws {
        let repo = MockVerificationRepository()
        let before = try await repo.records()
        #expect(before.allSatisfy { $0.status == .notStarted })

        // Submitting pro-investor docs returns approval AND the granted role.
        let outcome = try await repo.submit(kind: .proInvestor, documentLabels: ["ID", "Accreditation", "Funds"])
        #expect(outcome.record.status == .approved)
        #expect(outcome.grantedRole == .professional)

        let after = try await repo.records()
        #expect(after.first { $0.kind == .proInvestor }?.status == .approved)
    }

    @Test func verificationGrantsRolePerProgramme() async throws {
        let repo = MockVerificationRepository()
        // KYB grants the owner role.
        #expect(try await repo.submit(kind: .kyb, documentLabels: ["BR"]).grantedRole == .owner)
        // KYC unlocks features but grants no elevated role.
        #expect(try await repo.submit(kind: .kyc, documentLabels: ["ID"]).grantedRole == nil)
    }

    @Test func skipWithOverrideGrantsRoleButRecordsSkipped() async throws {
        let repo = MockVerificationRepository()
        let outcome = try await repo.skipWithOverride(kind: .proInvestor)
        #expect(outcome.record.status == .skipped)
        #expect(outcome.grantedRole == .professional)
    }

    @Test func profileStoreAppliesServerGrantedRole() async throws {
        let profileRepo = MockProfileRepository()
        let store = await ProfileStore(repository: profileRepo)
        await store.load(for: AuthenticatedUser(id: "u", displayName: "Demo", email: nil))

        // Server grants the professional role via the outcome.
        let outcome = VerificationOutcome(
            record: VerificationRecord(kind: .proInvestor, status: .approved),
            grantedRole: .professional
        )
        await store.applyVerificationOutcome(outcome)

        await #expect(store.profile?.role == .professional)
        await #expect(store.profile?.isProInvestorVerified == true)
        await #expect(store.profile?.tier == .verifiedInvestor)
    }

    @Test func verificationStatusActionFlags() {
        #expect(VerificationStatus.notStarted.needsAction)
        #expect(VerificationStatus.skipped.needsAction)
        #expect(VerificationStatus.rejected.needsAction)
        #expect(!VerificationStatus.pending.needsAction)
        #expect(VerificationStatus.approved.isApproved)
    }

    @Test func accountTierReflectsRoleAndVerification() {
        var profile = UserProfile.empty(id: "u", displayName: "Demo", email: nil)

        // Fresh retail user → unverified supporter.
        #expect(profile.tier == .unverifiedSupporter)
        #expect(!profile.tier.isVerified)

        // Switching to investor mode without verification is NOT verified.
        profile.role = .professional
        #expect(profile.tier == .unverifiedInvestor)
        #expect(!profile.tier.isVerified)

        // Approving pro-investor verification promotes to verified investor.
        profile.verifications[.proInvestor] = .approved
        #expect(profile.tier == .verifiedInvestor)
        #expect(profile.tier.isVerified)

        // Owner mode mirrors the same rule against KYB.
        profile.role = .owner
        #expect(profile.tier == .unverifiedOwner)
        profile.verifications[.kyb] = .approved
        #expect(profile.tier == .verifiedOwner)

        // Retail with KYC approved becomes a verified supporter.
        profile.role = .retail
        profile.verifications[.kyc] = .approved
        #expect(profile.tier == .verifiedSupporter)
    }
}
