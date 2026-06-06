from datetime import datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import DateTime, Enum, ForeignKey, Numeric, Text
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.enums import FinancingType, InvestmentStatus
from app.models.mixins import TimestampMixin, UUIDPrimaryKeyMixin


class Investment(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "investments"

    user_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"), index=True)
    business_id: Mapped[UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("businesses.id"), index=True
    )
    proposal_id: Mapped[UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("financing_proposals.id")
    )
    financing_type: Mapped[FinancingType] = mapped_column(Enum(FinancingType), nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    status: Mapped[InvestmentStatus] = mapped_column(
        Enum(InvestmentStatus), default=InvestmentStatus.intent
    )
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class InvestmentIntent(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "investment_intents"

    user_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"), index=True)
    business_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("businesses.id"))
    financing_type: Mapped[FinancingType] = mapped_column(Enum(FinancingType), nullable=False)
    amount_min: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    amount_max: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    note: Mapped[str | None] = mapped_column(Text)
