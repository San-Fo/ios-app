import SwiftUI

/// App language. English-first, with Traditional Chinese planned.
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .traditionalChinese: return "繁體中文"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .english: return true
        case .traditionalChinese: return false // Coming soon.
        }
    }

    /// Backend language enum value (`en` / `zhHant`).
    var serverValue: String {
        switch self {
        case .english: return "en"
        case .traditionalChinese: return "zhHant"
        }
    }
}

/// Business categories users can express interest in.
enum BusinessCategory: String, CaseIterable, Identifiable, Codable {
    case restaurant
    case cafe
    case teaHouse
    case bakery
    case sports
    case gym
    case bookstore
    case repairShop
    case tailoring
    case herbalist
    case familyBusiness
    case traditionalShop
    case wellness
    case culture
    case service

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .restaurant: return "Restaurants"
        case .cafe: return "Cafés"
        case .teaHouse: return "Tea Houses"
        case .bakery: return "Bakeries"
        case .sports: return "Sports"
        case .gym: return "Gyms"
        case .bookstore: return "Bookstores"
        case .repairShop: return "Repair Shops"
        case .tailoring: return "Tailoring"
        case .herbalist: return "Herbalists"
        case .familyBusiness: return "Family Businesses"
        case .traditionalShop: return "Traditional Shops"
        case .wellness: return "Wellness"
        case .culture: return "Culture"
        case .service: return "Services"
        }
    }

    var systemImage: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer.fill"
        case .teaHouse: return "mug.fill"
        case .bakery: return "birthday.cake.fill"
        case .sports: return "figure.run"
        case .gym: return "dumbbell.fill"
        case .bookstore: return "books.vertical.fill"
        case .repairShop: return "wrench.and.screwdriver.fill"
        case .tailoring: return "scissors"
        case .herbalist: return "leaf.circle.fill"
        case .familyBusiness: return "house.fill"
        case .traditionalShop: return "storefront.fill"
        case .wellness: return "leaf.fill"
        case .culture: return "theatermasks.fill"
        case .service: return "hand.raised.fill"
        }
    }
}

/// Hong Kong districts.
enum District: String, CaseIterable, Identifiable, Codable {
    case central
    case centralWestern
    case wanChai
    case causewayBay
    case eastern
    case shamShuiPo
    case mongKok
    case yauMaTei
    case yauTsimMong
    case tsimShaTsui
    case kowloonCity
    case kwunTong
    case shauKeiWan
    case tinHau
    case saiYingPun
    case taiPo
    case shaTin
    case tuenMun

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .central: return "Central"
        case .centralWestern: return "Central & Western"
        case .wanChai: return "Wan Chai"
        case .causewayBay: return "Causeway Bay"
        case .eastern: return "Eastern"
        case .shamShuiPo: return "Sham Shui Po"
        case .mongKok: return "Mong Kok"
        case .yauMaTei: return "Yau Ma Tei"
        case .yauTsimMong: return "Yau Tsim Mong"
        case .tsimShaTsui: return "Tsim Sha Tsui"
        case .kowloonCity: return "Kowloon City"
        case .kwunTong: return "Kwun Tong"
        case .shauKeiWan: return "Shau Kei Wan"
        case .tinHau: return "Tin Hau"
        case .saiYingPun: return "Sai Ying Pun"
        case .taiPo: return "Tai Po"
        case .shaTin: return "Sha Tin"
        case .tuenMun: return "Tuen Mun"
        }
    }
}

/// What a user wants to do on the platform.
enum UserIntent: String, CaseIterable, Identifiable, Codable {
    case support
    case revenueShare
    case buyBusiness
    case joinTakeover

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .support: return "Support local shops"
        case .revenueShare: return "Revenue-share financing"
        case .buyBusiness: return "Buy a business"
        case .joinTakeover: return "Join a takeover group"
        }
    }

    var detail: String {
        switch self {
        case .support: return "Discover and champion businesses you love."
        case .revenueShare: return "Fund a business and share in future revenue."
        case .buyBusiness: return "Explore full acquisition opportunities."
        case .joinTakeover: return "Team up with others to take over a business."
        }
    }

    var systemImage: String {
        switch self {
        case .support: return "heart.fill"
        case .revenueShare: return "percent"
        case .buyBusiness: return "key.fill"
        case .joinTakeover: return "person.3.fill"
        }
    }
}

/// Listing lifecycle status.
enum BusinessStatus: String, Codable, CaseIterable {
    case raising
    case fullyFunded
    case seekingBuyer
    case inNegotiation
    case urgentRisk
    case underOffer
    case preserved

    var displayName: String {
        switch self {
        case .raising: return "Raising"
        case .fullyFunded: return "Fully Funded"
        case .seekingBuyer: return "Seeking Buyer"
        case .inNegotiation: return "In Negotiation"
        case .urgentRisk: return "Urgent"
        case .underOffer: return "Under Offer"
        case .preserved: return "Preserved"
        }
    }

    /// Whether a funding goal / progress bar is relevant for this status.
    var showsFundingProgress: Bool {
        switch self {
        case .raising, .urgentRisk: return true
        case .fullyFunded, .seekingBuyer, .inNegotiation, .underOffer, .preserved: return false
        }
    }

    /// Whether this status should be surfaced as urgent.
    var isUrgent: Bool { self == .urgentRisk }
}

/// Desired outcome chosen by a business owner when listing.
enum ListingOutcome: String, CaseIterable, Identifiable, Codable {
    case raiseCapital
    case revenueShare
    case sellPartial
    case sellWhole
    case findSuccessor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .raiseCapital: return "Raise capital"
        case .revenueShare: return "Revenue-share financing"
        case .sellPartial: return "Sell partial ownership"
        case .sellWhole: return "Sell the whole business"
        case .findSuccessor: return "Find a successor"
        }
    }

    var systemImage: String {
        switch self {
        case .raiseCapital: return "banknote.fill"
        case .revenueShare: return "percent"
        case .sellPartial: return "chart.pie.fill"
        case .sellWhole: return "key.fill"
        case .findSuccessor: return "figure.2.arms.open"
        }
    }
}
