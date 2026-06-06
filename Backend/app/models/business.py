from decimal import Decimal
from uuid import UUID

from sqlalchemy import Boolean, Enum, ForeignKey, Integer, Numeric, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import ARRAY, UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.enums import DealStage, FinancingType
from app.models.mixins import TimestampMixin, UUIDPrimaryKeyMixin


class Business(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "businesses"

    owner_user_id: Mapped[UUID | None] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"))
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    slug: Mapped[str] = mapped_column(String(180), unique=True, index=True, nullable=False)
    category: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    district: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    address: Mapped[str | None] = mapped_column(Text)
    latitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    longitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    short_description: Mapped[str] = mapped_column(String(500), nullable=False)
    status: Mapped[DealStage] = mapped_column(Enum(DealStage), default=DealStage.draft, nullable=False)
    financing_types: Mapped[list[FinancingType]] = mapped_column(ARRAY(Enum(FinancingType)), default=list)
    urgency_score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    popularity_score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    owner_retirement_risk: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    story: Mapped["BusinessStory | None"] = relationship(back_populates="business")
    financial_snapshot: Mapped["BusinessFinancialSnapshot | None"] = relationship(
        back_populates="business"
    )


class BusinessStory(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "business_stories"

    business_id: Mapped[UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("businesses.id"), unique=True
    )
    founder_story: Mapped[str | None] = mapped_column(Text)
    family_legacy: Mapped[str | None] = mapped_column(Text)
    cultural_relevance: Mapped[str | None] = mapped_column(Text)
    neighbourhood_importance: Mapped[str | None] = mapped_column(Text)

    business: Mapped[Business] = relationship(back_populates="story")


class BusinessFinancialSnapshot(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "business_financial_snapshots"

    business_id: Mapped[UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("businesses.id"), unique=True
    )
    monthly_revenue_min: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    monthly_revenue_max: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    monthly_profit_min: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    monthly_profit_max: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    monthly_rent: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    employee_count: Mapped[int | None] = mapped_column(Integer)
    assets_summary: Mapped[str | None] = mapped_column(Text)
    debts_summary: Mapped[str | None] = mapped_column(Text)
    years_operating: Mapped[int | None] = mapped_column(Integer)
    funding_needed: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    asking_price: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    currency: Mapped[str] = mapped_column(String(3), default="HKD", nullable=False)

    business: Mapped[Business] = relationship(back_populates="financial_snapshot")


class BusinessImage(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "business_images"

    business_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("businesses.id"))
    url: Mapped[str] = mapped_column(Text, nullable=False)
    alt_text: Mapped[str | None] = mapped_column(String(200))
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)


class SupportFollow(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "support_follows"
    __table_args__ = (UniqueConstraint("user_id", "business_id", name="uq_support_follow_user_business"),)

    user_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"), index=True)
    business_id: Mapped[UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("businesses.id"), index=True
    )


class CommunityMemory(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "community_memories"

    user_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"))
    business_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("businesses.id"))
    body: Mapped[str] = mapped_column(Text, nullable=False)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class BusinessQuestion(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "business_questions"

    business_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("businesses.id"))
    user_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"))
    question: Mapped[str] = mapped_column(Text, nullable=False)


class BusinessAnswer(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "business_answers"

    question_id: Mapped[UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("business_questions.id"), unique=True
    )
    answered_by_user_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"))
    answer: Mapped[str] = mapped_column(Text, nullable=False)
