from enum import StrEnum


class UserRole(StrEnum):
    retail_user = "retail_user"
    business_owner = "business_owner"
    group_organizer = "group_organizer"
    admin = "admin"


class FinancingType(StrEnum):
    support_only = "support_only"
    revenue_share = "revenue_share"
    partial_ownership = "partial_ownership"
    full_acquisition = "full_acquisition"
    loan = "loan"
    collective_takeover = "collective_takeover"


class DealStage(StrEnum):
    draft = "draft"
    submitted = "submitted"
    approved = "approved"
    listed = "listed"
    funding_open = "funding_open"
    negotiation = "negotiation"
    due_diligence = "due_diligence"
    offer_submitted = "offer_submitted"
    funded = "funded"
    acquired = "acquired"
    closed = "closed"


class InvestmentStatus(StrEnum):
    intent = "intent"
    pending_review = "pending_review"
    confirmed = "confirmed"
    cancelled = "cancelled"
    refunded = "refunded"


class GroupMemberRole(StrEnum):
    investor = "investor"
    operator = "operator"
    accountant = "accountant"
    marketing = "marketing"
    legal = "legal"
    supporter = "supporter"


class AdminReviewStatus(StrEnum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"
    changes_requested = "changes_requested"
