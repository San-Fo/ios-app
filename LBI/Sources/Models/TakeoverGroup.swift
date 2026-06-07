import Foundation

/// A collective group working to take over a business.
struct TakeoverGroup: Identifiable, Equatable {
    let id: String
    var businessId: String
    var businessName: String
    var memberCount: Int
    var targetMembers: Int
    var pooledCommitment: Decimal
    var members: [GroupMember]
    var channels: [GroupChannel]
    var founderQAndA: [FounderQA]
    /// Lifecycle status of the group.
    var status: TakeoverStatus
    /// Defined roles the group needs filled.
    var roles: [TakeoverRole]
    /// Collective offer amount, if one has been agreed.
    var collectiveOfferAmount: Decimal?

    init(
        id: String,
        businessId: String,
        businessName: String,
        memberCount: Int,
        targetMembers: Int,
        pooledCommitment: Decimal,
        members: [GroupMember],
        channels: [GroupChannel],
        founderQAndA: [FounderQA],
        status: TakeoverStatus = .forming,
        roles: [TakeoverRole] = [],
        collectiveOfferAmount: Decimal? = nil
    ) {
        self.id = id
        self.businessId = businessId
        self.businessName = businessName
        self.memberCount = memberCount
        self.targetMembers = targetMembers
        self.pooledCommitment = pooledCommitment
        self.members = members
        self.channels = channels
        self.founderQAndA = founderQAndA
        self.status = status
        self.roles = roles
        self.collectiveOfferAmount = collectiveOfferAmount
    }
}

/// Lifecycle status of a takeover group.
enum TakeoverStatus: String, Codable {
    case forming
    case negotiating
    case dueDiligence
    case completed
    case failed

    var displayName: String {
        switch self {
        case .forming: return "Forming"
        case .negotiating: return "Negotiating"
        case .dueDiligence: return "Due Diligence"
        case .completed: return "Completed"
        case .failed: return "Closed"
        }
    }
}

/// A role the takeover group is looking to fill.
struct TakeoverRole: Identifiable, Equatable {
    let id: String
    var title: String
    var detail: String
    var isFilled: Bool
    var occupantName: String?

    init(id: String = UUID().uuidString, title: String, detail: String, isFilled: Bool = false, occupantName: String? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isFilled = isFilled
        self.occupantName = occupantName
    }
}

/// Role of a member within a takeover group.
enum GroupRole: String, Codable {
    case lead
    case contributor
    case advisor
    case member

    var displayName: String {
        switch self {
        case .lead: return "Lead"
        case .contributor: return "Contributor"
        case .advisor: return "Advisor"
        case .member: return "Member"
        }
    }
}

struct GroupMember: Identifiable, Equatable {
    let id: String
    var name: String
    var role: GroupRole
    var committedAmount: Decimal?
}

/// A discussion channel within a group.
struct GroupChannel: Identifiable, Equatable {
    let id: String
    var name: String
    var topic: String
    var messages: [GroupMessage]
}

struct GroupMessage: Identifiable, Equatable {
    let id: String
    var authorName: String
    var text: String
    var sentAt: Date
    var isCurrentUser: Bool
}

/// A founder question + answer entry.
struct FounderQA: Identifiable, Equatable {
    let id: String
    var question: String
    var answer: String?
    var askedBy: String
}
