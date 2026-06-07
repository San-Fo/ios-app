import Foundation

/// API endpoints for owner listings and supporter investments.
/// TODO(API): confirm paths and payloads with the backend team.
enum ListingEndpoints {
    static func submit(_ draft: ListingDraft) throws -> Endpoint<EmptyResponse> {
        try .json(path: "listings", method: .post, body: ListingSubmissionDTO(draft))
    }

    static func invest(businessId: String, kind: FundingKind, amount: Decimal) throws -> Endpoint<InvestmentDTO> {
        try .json(
            path: "businesses/\(businessId)/investments",
            method: .post,
            body: InvestmentBody(kind: kind.rawValue, amount: amount)
        )
    }

    private struct InvestmentBody: Encodable {
        let kind: String
        let amount: Decimal
    }
}
