import Foundation

/// Manages KYC / KYB / pro-investor verification submissions and status.
///
/// Role assignment is performed **server-side**: both `submit` and the
/// demo-only `skipWithOverride` return a `VerificationOutcome` containing the
/// role the server granted. The client applies that role and never elevates
/// itself locally.
protocol VerificationRepository: Sendable {
    /// Current status for every programme.
    func records() async throws -> [VerificationRecord]
    /// Submit a programme's documents for review. The server returns the
    /// updated record and any role it granted as a result.
    func submit(kind: VerificationKind, documentLabels: [String]) async throws -> VerificationOutcome
    /// Demo/admin override: ask the server to grant the role for a programme
    /// without completing verification (records the status as `skipped`).
    /// In production this is an authorised override; here it lets demos proceed.
    func skipWithOverride(kind: VerificationKind) async throws -> VerificationOutcome
}

// MARK: - Live

final class LiveVerificationRepository: VerificationRepository, @unchecked Sendable {
    private let client: APIClient
    private let fallbackUser: AuthenticatedUser?

    init(client: APIClient, fallbackUser: AuthenticatedUser? = nil) {
        self.client = client
        self.fallbackUser = fallbackUser
    }

    /// The backend has no "list verification records" endpoint; status is read
    /// from the user (`GET /me`) and per-business documents. We surface the
    /// user-level programmes derived from the current profile.
    func records() async throws -> [VerificationRecord] {
        let profile = try await client.send(ProfileEndpoints.me())
            .toDomain(fallback: fallbackUser ?? AuthenticatedUser(id: "", displayName: nil, email: nil))
        return VerificationKind.allCases.map {
            VerificationRecord(kind: $0, status: profile.verificationStatus($0))
        }
    }

    func submit(kind: VerificationKind, documentLabels: [String]) async throws -> VerificationOutcome {
        switch kind {
        case .kyc, .proInvestor:
            // Both map to POST /me/verify. Pro-investor requests institutional
            // status; KYC alone requests retail (identity) verification.
            let institutional = (kind == .proInvestor)
            let dto = try await client.send(try VerificationEndpoints.verifyMe(institutional: institutional))
            return outcome(for: kind, from: dto)
        case .kyb:
            // NO_BACKEND (generic flow): KYB is per-business on the backend
            // (POST /businesses/{id}/verify) and cannot be completed without a
            // business id. Surfaced as pending until done from a listing screen.
            // TODO(API): drive KYB from the owner's listing screen with a business id.
            MockMarker.hit(.noBackend, "Live.verifyKYB.generic", "KYB needs a businessId; use listing screen")
            return VerificationOutcome(
                record: VerificationRecord(kind: .kyb, status: .pending, submittedAt: Date()),
                grantedRole: nil
            )
        }
    }

    func skipWithOverride(kind: VerificationKind) async throws -> VerificationOutcome {
        // NO_BACKEND: there is no skip/override endpoint; a demo skip is treated
        // as a standard submission (which the mock backend auto-approves).
        MockMarker.hit(.noBackend, "Live.verifySkipOverride", "no skip endpoint; falls back to submit")
        return try await submit(kind: kind, documentLabels: [])
    }

    /// Builds an outcome from the User returned by `POST /me/verify`.
    private func outcome(for kind: VerificationKind, from dto: UserProfileDTO) -> VerificationOutcome {
        let profile = dto.toDomain(fallback: fallbackUser ?? AuthenticatedUser(id: dto.id, displayName: dto.displayName, email: dto.email))
        return VerificationOutcome(
            record: VerificationRecord(kind: kind, status: profile.verificationStatus(kind), submittedAt: Date()),
            grantedRole: profile.isProInvestorVerified ? .professional : nil
        )
    }
}

// MARK: - Mock

/// In-memory mock standing in for the backend. It both records the verification
/// status AND decides the role grant, mirroring how the real server behaves:
/// passing/overriding KYB grants the owner role, pro-investor grants the
/// professional role, and KYC grants no elevated role.
/// ⚠️ MOCK — auto-approves every submission instantly; stores no documents.
/// Active only when `APIConfiguration.useMockData == true`.
final class MockVerificationRepository: VerificationRepository, @unchecked Sendable {
    private let mutex = Mutex()
    private var records: [VerificationKind: VerificationRecord] = [:]

    func records() async throws -> [VerificationRecord] {
        MockMarker.hit(.mock, "MockVerificationRepository.records")
        return mutex.withLock {
            VerificationKind.allCases.map { records[$0] ?? VerificationRecord(kind: $0) }
        }
    }

    func submit(kind: VerificationKind, documentLabels: [String]) async throws -> VerificationOutcome {
        MockMarker.hit(.mock, "MockVerificationRepository.submit", "auto-approves; no document review")
        return mutex.withLock {
            // Demo backend auto-approves a complete submission.
            let record = VerificationRecord(kind: kind, status: .approved, submittedAt: Date())
            records[kind] = record
            return VerificationOutcome(record: record, grantedRole: Self.roleGrant(for: kind))
        }
    }

    func skipWithOverride(kind: VerificationKind) async throws -> VerificationOutcome {
        MockMarker.hit(.mock, "MockVerificationRepository.skipWithOverride", "grants role despite skip")
        return mutex.withLock {
            // Override path: the server grants the role despite a skipped check.
            let record = VerificationRecord(kind: kind, status: .skipped, submittedAt: Date())
            records[kind] = record
            return VerificationOutcome(record: record, grantedRole: Self.roleGrant(for: kind))
        }
    }

    /// The role the server grants when a programme passes/is overridden.
    private static func roleGrant(for kind: VerificationKind) -> AccountRole? {
        switch kind {
        case .kyb: return .owner
        case .proInvestor: return .professional
        case .kyc: return nil // Identity check unlocks features, not a role.
        }
    }
}
