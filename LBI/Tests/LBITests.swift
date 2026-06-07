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

    private func decodeBusiness(_ json: String) throws -> BusinessDTO {
        try JSONDecoder.lbiDefault.decode(BusinessDTO.self, from: Data(json.utf8))
    }

    @Test func businessDTODecodesAndMapsSummary() throws {
        // Server-shaped Business: revenue-share-loan intent + stats.
        let dto = try decodeBusiness("""
        {
          "id": "x",
          "ownerUserId": "owner-1",
          "name": "Test Shop",
          "description": "A beloved corner bakery.",
          "foundingYear": 1980,
          "categories": ["cafe"],
          "district": "wanChai",
          "verificationStatus": "verified",
          "financialIntent": { "revenueShareLoan": { "targetAmount": 50000, "totalInterestPercentage": 8, "totalRevenueCutPercentage": 5 } },
          "galleryImageUrls": ["https://example.com/a.jpg"],
          "listingStatistics": { "viewCount": 99, "likeCount": 12 }
        }
        """)
        let business = dto.toSummary()
        #expect(business.name == "Test Shop")
        #expect(business.district == .wanChai)
        #expect(business.storyHeadline == "A beloved corner bakery.")
        #expect(business.fundingOptions.contains(.revenueShare))
        #expect(business.yearEstablished == 1980)
        #expect(business.savedCount == 12)
        #expect(business.viewCount == 99)
        #expect(business.heroImageURL != nil)
    }

    @Test func businessDTOMapsOwnerToFounderAndDerivesEditorial() throws {
        let dto = try decodeBusiness("""
        {
          "id": "x",
          "ownerUserId": "owner-1",
          "name": "Leung's",
          "description": "Bespoke tailoring since 1979.",
          "foundingYear": 1979,
          "categories": ["services"],
          "district": "central",
          "financialIntent": { "sale": { "targetAmount": 2200000 } },
          "owner": { "id": "owner-1", "name": "Leung Po-Wah", "biography": "Master tailor." }
        }
        """)
        let detail = dto.toDetail()
        #expect(detail.founderName == "Leung Po-Wah")
        #expect(detail.founderStory == "Master tailor.")
        #expect(detail.tagline == "Bespoke tailoring since 1979.")
        #expect(detail.summary.fundingOptions.contains(.fullAcquisition))
    }

    @Test func businessSaleDTODecodesFoldedSale() throws {
        let dto = try decodeBusiness("""
        {
          "id": "biz-x",
          "ownerUserId": "owner-1",
          "name": "Shop",
          "description": "desc",
          "categories": ["retail"],
          "district": "mongKok",
          "financialIntent": { "sale": { "targetAmount": 1000000 } },
          "sale": {
            "stage": "openToRetail",
            "askingPrice": 1000000,
            "financials": { "annualRevenue": 800000, "annualProfit": 160000, "staffCount": 2 },
            "aiEvaluation": { "score": 88, "verdict": "recommendedForCommercialBidding", "strengths": ["Profit"], "risks": ["Lease"], "summary": "Strong" },
            "retailFallback": { "askingPrice": 1200000, "allowOutrightPurchase": true, "allowGroupTakeover": true, "ownerNote": "Public" },
            "bids": [
              { "id": "bid-x", "bidderUserId": "u-1", "bidderName": "Buyer", "amount": 900000, "message": "Keep staff", "status": "submitted" },
              { "id": "bid-g", "bidderUserId": "u-2", "bidderName": "Heritage Circle", "bidderGroupId": "grp-1", "amount": 950000, "status": "submitted" }
            ]
          }
        }
        """)
        let sale = dto.toDetail().professionalSale
        #expect(sale?.stage == .openToRetail)
        #expect(sale?.aiEvaluation?.score == 88)
        #expect(sale?.aiEvaluation?.rating == .strong)
        #expect(sale?.retailFallbackOffer?.askingPrice == 1200000)
        #expect(sale?.financials.staffCount == 2)
        #expect(sale?.bids.count == 2)
        // The group-tagged bid surfaces as a group offer.
        #expect(sale?.groupOffers.count == 1)
        #expect(sale?.groupOffers.first?.groupId == "grp-1")
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

    @Test func revenueShareBreakdownSumsTo約100() {
        let terms = SampleData.wongNoodleShop.revenueShareTerms!
        let total = terms.useOfFundsBreakdown.reduce(0) { $0 + $1.percentage }
        #expect(abs(total - 100) < 1.0)
    }

    @Test func sampleBusinessDetailIncludesProfessionalSale() {
        let detail = SampleData.detail(for: "biz-002")
        #expect(detail?.professionalSale?.stage == .commercialBidding)
        #expect(detail?.professionalSale?.aiEvaluation?.verdict == .recommendedForCommercialBidding)
        #expect(detail?.professionalSale?.ownerWillingToStay == true)
        #expect(detail?.professionalSale?.bids.count == 2)
    }

    @Test func saleEvaluationMapsVerdictToRecommendedAction() {
        let eval = SaleEvaluationDTO(
            score: 88,
            verdict: "recommendedForCommercialBidding",
            strengths: ["Profit"],
            risks: ["Lease"],
            summary: "Strong"
        ).toDomain()
        #expect(eval.score == 88)
        #expect(eval.rating == .strong)
        #expect(!eval.recommendedAction.isEmpty) // derived client-side from verdict
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

    @Test func authSessionResponseDecodesRealDevPayload() throws {
        // Verbatim shape returned by POST /auth/dev (note `_id`, BSON date).
        let json = """
        {"sessionToken":"e95ec036","user":{"_id":"57e1c1dd","appleUserId":"dev:client-test","verificationState":"unverified","investorStatus":"institutionalVerified","name":"Client Test","email":null,"birthDate":null,"location":null,"language":null,"followedCategories":[],"districts":[],"financialIntents":[],"savedBusinessIds":[],"hasCompletedOnboarding":false,"createdAt":{"$date":{"$numberLong":"1780808264339"}}}}
        """
        let resp = try JSONDecoder.lbiDefault.decode(AuthSessionResponse.self, from: Data(json.utf8))
        #expect(resp.sessionToken == "e95ec036")
        #expect(resp.user.id == "57e1c1dd") // mapped from `_id`
        let profile = resp.user.toDomain(fallback: AuthenticatedUser(id: "x", displayName: nil, email: nil))
        #expect(profile.isInstitutionalInvestor)
        #expect(profile.isProInvestorVerified)
        #expect(profile.role == .professional)
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
        // KYB grants no role — ownership is derived from owning a verified
        // business, not from an account-role change.
        #expect(try await repo.submit(kind: .kyb, documentLabels: ["BR"]).grantedRole == nil)
        // KYC unlocks features but grants no elevated role.
        #expect(try await repo.submit(kind: .kyc, documentLabels: ["ID"]).grantedRole == nil)
    }

    @Test func skipWithOverrideGrantsRoleButRecordsSkipped() async throws {
        let repo = MockVerificationRepository()
        let outcome = try await repo.skipWithOverride(kind: .proInvestor)
        #expect(outcome.record.status == .skipped)
        #expect(outcome.grantedRole == .professional)
    }

    @Test func verifyBusinessApprovesKYBWithoutRoleChange() async throws {
        // Per-business KYB: verifying a specific listing approves KYB. Ownership
        // is derived (the user now owns a verified business), so there is no
        // account-role grant.
        let repo = MockVerificationRepository()
        let outcome = try await repo.verifyBusiness(businessId: "biz-1")
        #expect(outcome.record.kind == .kyb)
        #expect(outcome.record.status == .approved)
        #expect(outcome.grantedRole == nil)
    }

    @Test func ownsBusinessDrivesOwnerState() async throws {
        // A user with at least one listing is treated as an owner; the mock
        // returns no businesses, so a fresh user is not an owner.
        let store = await ProfileStore(repository: MockProfileRepository(), businessRepository: MockBusinessRepository())
        await store.load(for: AuthenticatedUser(id: "u", displayName: "Demo", email: nil))
        await #expect(store.ownsBusiness == false)
    }

    @Test func listingSubmissionReturnsBusinessIdForKYB() async throws {
        // The listing flow needs the created business id to lock KYB to it.
        let repo = MockListingRepository()
        let id = try await repo.submitListing(ListingDraft())
        #expect(!id.isEmpty)
    }

    @Test func profileStoreAppliesServerGrantedRole() async throws {
        let profileRepo = MockProfileRepository()
        let store = await ProfileStore(repository: profileRepo, businessRepository: MockBusinessRepository())
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

    // MARK: Mock instrumentation

    @Test func mockReposFireMockMarker() async throws {
        // Exercising a mock repository must record a MOCK marker site, so the
        // "is this real data?" audit (no MOCK sites with useMockData=false) works.
        MockMarker.reset()
        let repo = MockBusinessRepository()
        _ = try await repo.list(query: BusinessQuery())
        #expect(MockMarker.firedSites.contains("MockBusinessRepository"))
        #expect(MockMarker.firedSites.contains("MockBusinessRepository.list"))
    }

    @Test func derivedEditorialFiresDerivedMarker() {
        // Deriving editorial content from the server Business records a DERIVED
        // marker (expected even on the real-data path).
        MockMarker.reset()
        let dto = try? JSONDecoder.lbiDefault.decode(BusinessDTO.self, from: Data("""
        { "id": "x", "ownerUserId": "o", "name": "N", "description": "d",
          "categories": ["retail"], "district": "central",
          "financialIntent": { "sale": { "targetAmount": 1 } } }
        """.utf8))
        _ = dto?.toDetail()
        #expect(MockMarker.firedSites.contains("BusinessDTO.toDetail.editorial"))
    }

    // MARK: Live-payload regression (verbatim JSON captured from lbi.proxied.zone)

    @Test func decodesRealVerifiedBusinessWithSale() throws {
        // Captured from GET /businesses/{id} (owner view) on the live backend.
        let json = """
        {"_id":"6f0729cf-317a-4fb3-9f73-196044e4ab8a","ownerUserId":"02b0f3d1","name":"Leung's Master Tailoring","description":"Bespoke suits since 1979.","foundingYear":1979,"categories":["services"],"district":"central","location":{"address":"Central, Hong Kong Island","geo":{"type":"Point","coordinates":[114.1578,22.2816]}},"financialIntent":{"sale":{"targetAmount":2200000}},"verificationStatus":"verified","sale":{"stage":"commercialBidding","askingPrice":2200000,"financials":{"annualRevenue":2220000,"annualProfit":540000,"monthlyRent":48000,"leaseYearsRemaining":4,"staffCount":3,"inventoryValue":180000,"notes":"Established clientele."},"aiEvaluation":{"score":78,"verdict":"recommendedForCommercialBidding","strengths":["Established local presence"],"risks":["Automated estimate; verify financials independently"],"summary":"Preliminary automated assessment."},"includes":["Client archive","Brand & goodwill","Equipment"],"ownerWillingToStay":true,"handoverMonths":12,"commercialBiddingEndsAt":null,"retailFallback":null,"bids":[{"id":"47de76f7","bidderUserId":"5a27e8a4","bidderName":"M. Cheng","bidderGroupId":null,"amount":2050000,"message":"Committed to the bespoke model.","status":"submitted","createdAt":{"$date":{"$numberLong":"1780810613121"}}}]},"galleryImageUrls":[],"listingStatistics":{"viewCount":0,"likeCount":0},"createdAt":{"$date":{"$numberLong":"1780810582397"}},"owner":{"id":"02b0f3d1","name":"Leung Po-Wah","biography":null,"profileImageUrl":null}}
        """
        let dto = try JSONDecoder.lbiDefault.decode(BusinessDTO.self, from: Data(json.utf8))
        #expect(dto.id == "6f0729cf-317a-4fb3-9f73-196044e4ab8a") // from `_id`
        let detail = dto.toDetail()
        #expect(detail.summary.name == "Leung's Master Tailoring")
        #expect(detail.founderName == "Leung Po-Wah") // from owner.id-keyed summary
        #expect(detail.summary.district == .central)
        let sale = detail.professionalSale
        #expect(sale?.stage == .commercialBidding)
        #expect(sale?.aiEvaluation?.score == 78)
        #expect(sale?.financials.staffCount == 3)
        #expect(sale?.bids.first?.bidderName == "M. Cheng")
        #expect(sale?.bids.first?.amount == 2_050_000)
    }

    @Test func decodesRealRedactedSaleForAnonViewer() throws {
        // Captured from GET /businesses/{id} unauthenticated: financials null.
        let json = """
        {"_id":"6f0729cf","ownerUserId":"02b0f3d1","name":"Leung's","description":"d","categories":["services"],"district":"central","financialIntent":{"sale":{"targetAmount":2200000}},"verificationStatus":"verified","sale":{"stage":"commercialBidding","askingPrice":2200000,"financials":null,"aiEvaluation":{"score":78,"verdict":"recommendedForCommercialBidding","strengths":["x"],"risks":["y"],"summary":"s"},"includes":[],"ownerWillingToStay":true,"handoverMonths":12,"commercialBiddingEndsAt":null,"retailFallback":null,"bids":[]}}
        """
        let dto = try JSONDecoder.lbiDefault.decode(BusinessDTO.self, from: Data(json.utf8))
        let sale = dto.toDetail().professionalSale
        #expect(sale != nil)
        // Redacted financials map to the zeroed placeholder.
        #expect(sale?.financials == .redacted)
        #expect(sale?.bids.isEmpty == true)
    }

    @Test func decodesRealConversationAndMessage() throws {
        let convJSON = """
        {"_id":"49896428","kind":"deal","businessId":"6f0729cf","participantIds":["02b0f3d1","5a27e8a4"],"createdAt":{"$date":{"$numberLong":"1780810613675"}}}
        """
        let conv = try JSONDecoder.lbiDefault.decode(ConversationDTO.self, from: Data(convJSON.utf8))
        #expect(conv.id == "49896428") // from `_id`
        #expect(conv.kind == "deal")
        #expect(conv.participantIds?.count == 2)

        let msgJSON = """
        {"_id":"8f209c71","conversationId":"49896428","senderUserId":"02b0f3d1","body":"Welcome.","createdAt":{"$date":{"$numberLong":"1780810626852"}}}
        """
        let msg = try JSONDecoder.lbiDefault.decode(ChatMessageDTO.self, from: Data(msgJSON.utf8))
        #expect(msg.id == "8f209c71")
        let mine = msg.toDomain(currentUserId: "02b0f3d1")
        #expect(mine.isCurrentUser)
        #expect(mine.text == "Welcome.")
    }

    // MARK: Request-body encoding (validated against the live server)

    private func encodeJSON<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder.lbiDefault.encode(value)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    @Test func actionBodyIsInternallyTaggedWithKind() throws {
        // The live server expects {"kind":"purchase"} etc., NOT a bare string
        // or an externally-tagged object. (Verified: bare string -> 422.)
        let purchase = try encodeJSON(ListingEndpoints.ActionBody.purchase)
        #expect(purchase["kind"] as? String == "purchase")
        #expect(purchase.count == 1)

        let donation = try encodeJSON(ListingEndpoints.ActionBody.donation(amount: 100, tier: "Gold"))
        #expect(donation["kind"] as? String == "donation")
        #expect((donation["amount"] as? NSNumber)?.intValue == 100)
        #expect(donation["tier"] as? String == "Gold")

        let loan = try encodeJSON(ListingEndpoints.ActionBody.revenueShareLoan(amount: 5000))
        #expect(loan["kind"] as? String == "revenueShareLoan")
        #expect((loan["amount"] as? NSNumber)?.intValue == 5000)
    }

    @Test func districtCentroidsAreReasonableHKCoordinates() {
        for district in District.allCases {
            let c = district.centroid
            #expect(c.latitude > 22.1 && c.latitude < 22.6)
            #expect(c.longitude > 113.8 && c.longitude < 114.4)
        }
    }

    @Test func kybRequiresFourYearFinancialStatements() {
        let labels = VerificationKind.kyb.requiredDocuments.map(\.label)
        #expect(labels.contains { $0.localizedCaseInsensitiveContains("financial statements") && $0.contains("4") })
    }
}
