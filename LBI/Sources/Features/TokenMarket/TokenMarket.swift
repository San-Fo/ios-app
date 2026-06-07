import Foundation

/// ⚠️ STUB — example data model for a future Web3 tokenized marketplace where
/// small/medium businesses are tokenized and traded as on-chain shares.
///
/// There is **no backend, wallet or chain** behind any of this. Every value is
/// in-memory sample data and every access fires a `MockMarker` MOCK marker.
/// See MOCKING.md section 6 and gap #10 for the real-backend requirements.
struct BusinessToken: Identifiable, Equatable {
    let id: String
    /// Ticker symbol, e.g. "WONG".
    let symbol: String
    let businessName: String
    let district: District
    /// Last traded price per token, in HK$.
    let lastPrice: Decimal
    /// 24h price change, as a fraction (e.g. 0.042 = +4.2%).
    let change24h: Double
    /// Total token supply issued for the business.
    let totalSupply: Int
    /// Fraction of supply currently offered on the order book (0...1).
    let floatPercent: Double
    /// 24h traded volume in HK$.
    let volume24h: Decimal
    /// Short recent price series for the sparkline (oldest → newest).
    let priceHistory: [Double]

    /// Implied market capitalisation: price × supply.
    var marketCap: Decimal {
        lastPrice * Decimal(totalSupply)
    }
}

/// A single user position in the tokenized marketplace (stub).
struct TokenHolding: Identifiable, Equatable {
    let id: String
    let symbol: String
    let businessName: String
    let quantity: Int
    /// Average acquisition price per token, HK$.
    let avgCost: Decimal
    /// Current price per token, HK$.
    let currentPrice: Decimal

    var marketValue: Decimal { currentPrice * Decimal(quantity) }
    var costBasis: Decimal { avgCost * Decimal(quantity) }
    /// Unrealised P/L as a fraction of cost basis.
    var returnPercent: Double {
        let cost = NSDecimalNumber(decimal: costBasis).doubleValue
        guard cost > 0 else { return 0 }
        return (NSDecimalNumber(decimal: marketValue).doubleValue - cost) / cost
    }
}

/// ⚠️ STUB data source for the tokenized marketplace. No network, no chain.
enum TokenMarketSampleData {
    static var listings: [BusinessToken] {
        MockMarker.hit(.mock, "TokenMarketSampleData.listings", "Web3 marketplace stub; no chain")
        return [
            BusinessToken(
                id: "tok-wong",
                symbol: "WONG",
                businessName: "Wong's Noodle Shop",
                district: .shamShuiPo,
                lastPrice: 12.40,
                change24h: 0.042,
                totalSupply: 100_000,
                floatPercent: 0.18,
                volume24h: 84_200,
                priceHistory: [11.2, 11.6, 11.4, 12.0, 12.1, 11.9, 12.4]
            ),
            BusinessToken(
                id: "tok-leung",
                symbol: "LEUNG",
                businessName: "Leung's Master Tailoring",
                district: .central,
                lastPrice: 48.75,
                change24h: -0.013,
                totalSupply: 50_000,
                floatPercent: 0.09,
                volume24h: 152_000,
                priceHistory: [49.8, 49.1, 49.4, 48.2, 48.9, 49.0, 48.75]
            ),
            BusinessToken(
                id: "tok-peak",
                symbol: "PEAK",
                businessName: "Peak Bookstore",
                district: .wanChai,
                lastPrice: 6.20,
                change24h: 0.118,
                totalSupply: 200_000,
                floatPercent: 0.27,
                volume24h: 61_500,
                priceHistory: [5.4, 5.6, 5.5, 5.9, 6.0, 6.1, 6.2]
            ),
            BusinessToken(
                id: "tok-herb",
                symbol: "HERB",
                businessName: "Tin Hau Herbal Hall",
                district: .tinHau,
                lastPrice: 21.05,
                change24h: 0.006,
                totalSupply: 75_000,
                floatPercent: 0.14,
                volume24h: 33_900,
                priceHistory: [20.9, 21.1, 20.8, 21.0, 21.2, 21.0, 21.05]
            )
        ]
    }

    static var holdings: [TokenHolding] {
        MockMarker.hit(.mock, "TokenMarketSampleData.holdings", "Web3 marketplace stub; no wallet")
        return [
            TokenHolding(id: "h-wong", symbol: "WONG", businessName: "Wong's Noodle Shop", quantity: 1_200, avgCost: 10.80, currentPrice: 12.40),
            TokenHolding(id: "h-peak", symbol: "PEAK", businessName: "Peak Bookstore", quantity: 5_000, avgCost: 6.50, currentPrice: 6.20)
        ]
    }
}
