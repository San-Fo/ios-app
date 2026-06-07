import Foundation

/// Wire model for a backend `Action` (a recorded financing action).
///
/// `kind` is externally tagged and serializes per variant:
/// `"purchase"`, `{ "donation": { amount, tier } }`,
/// `{ "revenueShareLoan": { amount } }`.
struct ActionDTO: Decodable {
    let id: String
    let userId: String
    let businessId: String
    let kind: ActionKind
    let createdAt: BSONDate?

    enum ActionKind: Decodable {
        case purchase
        case donation(amount: Decimal, tier: String?)
        case revenueShareLoan(amount: Decimal)

        private enum CodingKeys: String, CodingKey { case donation, revenueShareLoan }
        private struct DonationPayload: Decodable { let amount: Decimal; let tier: String? }
        private struct LoanPayload: Decodable { let amount: Decimal }

        init(from decoder: Decoder) throws {
            // Unit variant: a bare string "purchase".
            if let single = try? decoder.singleValueContainer(), let raw = try? single.decode(String.self) {
                if raw == "purchase" { self = .purchase; return }
            }
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let d = try? c.decode(DonationPayload.self, forKey: .donation) {
                self = .donation(amount: d.amount, tier: d.tier)
            } else if let l = try? c.decode(LoanPayload.self, forKey: .revenueShareLoan) {
                self = .revenueShareLoan(amount: l.amount)
            } else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Unknown action kind")
                )
            }
        }
    }

    func toDomain(businessName: String) -> InvestmentRecord {
        let fundingKind: FundingKind
        let amount: Decimal
        switch kind {
        case .purchase:
            fundingKind = .fullAcquisition
            amount = 0
        case let .donation(donationAmount, _):
            fundingKind = .fullAcquisition
            amount = donationAmount
        case let .revenueShareLoan(loanAmount):
            fundingKind = .revenueShare
            amount = loanAmount
        }
        return InvestmentRecord(
            id: id,
            businessId: businessId,
            businessName: businessName,
            kind: fundingKind,
            amount: amount,
            date: createdAt?.date ?? Date()
        )
    }
}
