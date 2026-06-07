import Foundation

/// API endpoints for verification.
///
/// Backend shape (differs from the app's per-programme abstraction):
/// - `POST /me/verify { claimedInvestorType }` → updated `User`.
///   Sets identity to verified and investorStatus to retail/institutional.
/// - `POST /businesses/{id}/verify` → updated `Business` (business proof, KYB).
///
/// The app's KYC + pro-investor programmes both map to `POST /me/verify`
/// (identity is always verified there; the claimed type controls investor
/// status). The KYB programme maps to the per-business verify endpoint.
enum VerificationEndpoints {
    /// Combined identity + investor verification.
    /// - Parameter institutional: when true, requests institutional status;
    ///   otherwise retail.
    static func verifyMe(institutional: Bool) throws -> Endpoint<UserProfileDTO> {
        try .json(
            path: "me/verify",
            method: .post,
            body: VerifyMeBody(claimedInvestorType: institutional ? "institutional" : "retail")
        )
    }

    /// Business proof submission (KYB); marks the listing verified.
    static func verifyBusiness(id: String) throws -> Endpoint<BusinessDTO> {
        try .json(
            path: "businesses/\(id)/verify",
            method: .post,
            body: VerifyBusinessBody()
        )
    }

    private struct VerifyMeBody: Encodable {
        let claimedInvestorType: String
    }

    private struct VerifyBusinessBody: Encodable {
        // Proof references are accepted by the backend but ignored in the mock.
        let businessRegistrationReference: String? = nil
        let documentReference: String? = nil
    }
}
