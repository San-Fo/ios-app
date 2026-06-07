import Foundation

/// The three verification programmes on the platform.
enum VerificationKind: String, Codable, CaseIterable, Identifiable {
    /// Know Your Customer — identity verification for any user.
    case kyc
    /// Know Your Business — business existence + ownership, required before
    /// a business can be listed for sale / loan.
    case kyb
    /// Accredited / professional commercial-investor verification, required to
    /// upgrade from a normal user to a pro investor.
    case proInvestor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kyc: return "Identity verification"
        case .kyb: return "Business verification"
        case .proInvestor: return "Commercial investor verification"
        }
    }

    var shortTitle: String {
        switch self {
        case .kyc: return "Identity (KYC)"
        case .kyb: return "Business (KYB)"
        case .proInvestor: return "Investor accreditation"
        }
    }

    var subtitle: String {
        switch self {
        case .kyc:
            return "Confirm who you are so we can keep the community safe."
        case .kyb:
            return "Prove the business exists and that you own it before listing it for sale or financing."
        case .proInvestor:
            return "Provide documents to be approved as a commercial investor and unlock bidding and loan products."
        }
    }
}

/// Where a verification submission currently sits.
enum VerificationStatus: String, Codable, Equatable {
    /// No submission yet.
    case notStarted
    /// User chose to skip (demo / defer). Treated as unverified.
    case skipped
    /// Submitted, awaiting backend review.
    case pending
    /// Approved by the backend.
    case approved
    /// Rejected; the user may resubmit.
    case rejected

    var displayName: String {
        switch self {
        case .notStarted: return "Not started"
        case .skipped: return "Skipped"
        case .pending: return "Under review"
        case .approved: return "Verified"
        case .rejected: return "Rejected"
        }
    }

    var isApproved: Bool { self == .approved }
    /// Whether the user still needs to act (start or resubmit).
    var needsAction: Bool { self == .notStarted || self == .skipped || self == .rejected }
}

/// A single uploaded/attached document reference in a submission (mock holds
/// only metadata; the backend will store the actual file).
struct VerificationDocument: Identifiable, Equatable, Hashable {
    let id: String
    var label: String
    /// Filename or capture reference; nil until "attached".
    var reference: String?

    init(id: String = UUID().uuidString, label: String, reference: String? = nil) {
        self.id = id
        self.label = label
        self.reference = reference
    }

    var isAttached: Bool { reference != nil }
}

/// The verification state for a single programme.
struct VerificationRecord: Equatable {
    var kind: VerificationKind
    var status: VerificationStatus
    /// Optional reviewer note (e.g. rejection reason).
    var note: String?
    var submittedAt: Date?

    init(kind: VerificationKind, status: VerificationStatus = .notStarted, note: String? = nil, submittedAt: Date? = nil) {
        self.kind = kind
        self.status = status
        self.note = note
        self.submittedAt = submittedAt
    }
}

/// The server's response after a verification submission or override-skip.
///
/// Role assignment is a **server decision**: the backend returns the updated
/// verification record together with the role it has granted (if any). The
/// client never promotes itself — it applies whatever the server returns. This
/// keeps the source of truth for access on the server, where it can be enforced.
struct VerificationOutcome: Equatable {
    /// The updated verification record for the programme.
    var record: VerificationRecord
    /// The role the server granted as a result, if it changed. `nil` means the
    /// role is unchanged (e.g. still pending review, or KYC which grants no
    /// elevated role).
    var grantedRole: AccountRole?
}

/// Required documents per programme (mock checklist; backend will define real ones).
extension VerificationKind {
    var requiredDocuments: [VerificationDocument] {
        switch self {
        case .kyc:
            return [
                VerificationDocument(label: "Government-issued ID (front)"),
                VerificationDocument(label: "Selfie / liveness check"),
            ]
        case .kyb:
            return [
                VerificationDocument(label: "Business Registration certificate"),
                VerificationDocument(label: "Proof of ownership / directorship"),
                VerificationDocument(label: "Recent business address proof"),
            ]
        case .proInvestor:
            return [
                VerificationDocument(label: "Government-issued ID"),
                VerificationDocument(label: "Proof of accredited-investor status"),
                VerificationDocument(label: "Source-of-funds declaration"),
            ]
        }
    }
}
