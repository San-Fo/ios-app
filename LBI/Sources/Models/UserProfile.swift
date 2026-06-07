import Foundation

/// The signed-in user's profile and preferences.
struct UserProfile: Equatable {
    var id: String
    var displayName: String
    var email: String?
    var language: AppLanguage
    var interests: Set<BusinessCategory>
    var districts: Set<District>
    var intents: Set<UserIntent>
    var savedBusinessIds: Set<String>
    var joinedGroupIds: Set<String>
    var investments: [InvestmentRecord]
    var hasCompletedOnboarding: Bool
    /// Account role — retail supporter, vetted commercial buyer, or owner preview.
    var role: AccountRole
    /// Verification status per programme (KYC / KYB / pro-investor).
    var verifications: [VerificationKind: VerificationStatus]

    var isProfessional: Bool { role == .professional }
    var isInstitutionalInvestor: Bool { role == .professional }
    var isOwner: Bool { role == .owner }

    /// Status for a programme (defaults to `.notStarted`).
    func verificationStatus(_ kind: VerificationKind) -> VerificationStatus {
        verifications[kind] ?? .notStarted
    }

    func isVerified(_ kind: VerificationKind) -> Bool {
        verificationStatus(kind).isApproved
    }

    /// Identity verified (KYC approved).
    var isIdentityVerified: Bool { isVerified(.kyc) }
    /// Business verified — required before listing a business.
    var isBusinessVerified: Bool { isVerified(.kyb) }
    /// Approved as a commercial investor.
    var isProInvestorVerified: Bool { isVerified(.proInvestor) }

    /// The user's effective account tier, derived from `role` + verifications.
    ///
    /// This is the single, honest answer to "what kind of account is this".
    /// It combines the chosen role with whether the required verification has
    /// actually been approved, so the UI can distinguish a *verified* pro
    /// investor / owner from one who only switched mode in the demo picker.
    var tier: AccountTier {
        switch role {
        case .professional:
            return isProInvestorVerified ? .verifiedInvestor : .unverifiedInvestor
        case .owner:
            return isBusinessVerified ? .verifiedOwner : .unverifiedOwner
        case .retail:
            return isIdentityVerified ? .verifiedSupporter : .unverifiedSupporter
        }
    }

    static func empty(id: String, displayName: String, email: String?) -> UserProfile {
        UserProfile(
            id: id,
            displayName: displayName,
            email: email,
            language: .english,
            interests: [],
            districts: [],
            intents: [],
            savedBusinessIds: [],
            joinedGroupIds: [],
            investments: [],
            hasCompletedOnboarding: false,
            role: .retail,
            verifications: [:]
        )
    }

    // MARK: Portfolio stats

    var totalInvested: Decimal { investments.reduce(0) { $0 + $1.amount } }
    var totalReturned: Decimal { investments.reduce(0) { $0 + $1.returnedAmount } }
    var businessesSupported: Int { Set(investments.map(\.businessId)).count }
}

/// Lifecycle status of an investment.
enum InvestmentStatus: String, Codable {
    case active
    case repaying
    case completed
    case refunded

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .repaying: return "Repaying"
        case .completed: return "Completed"
        case .refunded: return "Refunded"
        }
    }
}

/// A record of a user's support / contribution action.
struct InvestmentRecord: Identifiable, Equatable {
    let id: String
    var businessId: String
    var businessName: String
    var kind: FundingKind
    var amount: Decimal
    var date: Date
    var status: InvestmentStatus
    var returnedAmount: Decimal
    var expectedReturn: Decimal?
    /// Number of collectible support cards this contribution earned.
    var supportCards: Int

    init(
        id: String,
        businessId: String,
        businessName: String,
        kind: FundingKind,
        amount: Decimal,
        date: Date,
        status: InvestmentStatus = .active,
        returnedAmount: Decimal = 0,
        expectedReturn: Decimal? = nil,
        supportCards: Int = 1
    ) {
        self.id = id
        self.businessId = businessId
        self.businessName = businessName
        self.kind = kind
        self.amount = amount
        self.date = date
        self.status = status
        self.returnedAmount = returnedAmount
        self.expectedReturn = expectedReturn
        self.supportCards = supportCards
    }

    /// Progress toward the expected return (0–1).
    var returnProgress: Double {
        guard let expectedReturn, expectedReturn > 0 else { return 0 }
        return min(1, NSDecimalNumber(decimal: returnedAmount).doubleValue
            / NSDecimalNumber(decimal: expectedReturn).doubleValue)
    }
}
