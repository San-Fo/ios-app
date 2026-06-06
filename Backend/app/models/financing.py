from decimal import Decimal
from uuid import UUID

from sqlalchemy import Boolean, Enum, ForeignKey, Integer, Numeric, Text
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.enums import DealStage, FinancingType
from app.models.mixins import TimestampMixin, UUIDPrimaryKeyMixin


class FinancingProposal(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "financing_proposals"

    business_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("businesses.id"))
    financing_type: Mapped[FinancingType] = mapped_column(Enum(FinancingType), nullable=False)
    target_amount: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    minimum_investment_amount: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    current_amount_raised: Mapped[Decimal] = mapped_column(Numeric(14, 2), default=0, nullable=False)
    deal_stage: Mapped[DealStage] = mapped_column(Enum(DealStage), default=DealStage.draft)


class RevenueShareTerms(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "revenue_share_terms"

    proposal_id: Mapped[UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("financing_proposals.id"), unique=True
    )
    revenue_share_percent: Mapped[Decimal] = mapped_column(Numeric(5, 2), nullable=False)
    repayment_cap_multiplier: Mapped[Decimal | None] = mapped_column(Numeric(5, 2))
    expected_term_months: Mapped[int | None] = mapped_column(Integer)


class OwnershipTerms(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "ownership_terms"

    proposal_id: Mapped[UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("financing_proposals.id"), unique=True
    )
    equity_percent_offered: Mapped[Decimal] = mapped_column(Numeric(5, 2), nullable=False)
    investor_rights_summary: Mapped[str | None] = mapped_column(Text)


class AcquisitionTerms(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "acquisition_terms"

    proposal_id: Mapped[UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("financing_proposals.id"), unique=True
    )
    asking_price: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    includes_assets: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    handover_support_months: Mapped[int | None] = mapped_column(Integer)


class LoanTerms(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "loan_terms"

    proposal_id: Mapped[UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("financing_proposals.id"), unique=True
    )
    principal_amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    interest_rate_percent: Mapped[Decimal | None] = mapped_column(Numeric(5, 2))
    term_months: Mapped[int | None] = mapped_column(Integer)
