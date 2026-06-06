from decimal import Decimal
from uuid import UUID

from sqlalchemy import Boolean, Enum, ForeignKey, Numeric, String, Text
from sqlalchemy.dialects.postgresql import ARRAY, UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.enums import FinancingType, UserRole
from app.models.mixins import TimestampMixin, UUIDPrimaryKeyMixin


class User(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(String(320), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), default=UserRole.retail_user, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    profile: Mapped["UserProfile | None"] = relationship(back_populates="user", cascade="all, delete-orphan")
    interests: Mapped[list["UserInterest"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class UserProfile(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "user_profiles"

    user_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"), unique=True)
    display_name: Mapped[str] = mapped_column(String(100), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(40))
    bio: Mapped[str | None] = mapped_column(Text)
    preferred_districts: Mapped[list[str]] = mapped_column(ARRAY(String), default=list)
    investment_min_amount: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    investment_max_amount: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    preferred_financing_types: Mapped[list[FinancingType]] = mapped_column(
        ARRAY(Enum(FinancingType)), default=list
    )

    user: Mapped[User] = relationship(back_populates="profile")


class UserInterest(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "user_interests"

    user_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"), index=True)
    category: Mapped[str] = mapped_column(String(80), nullable=False)
    weight: Mapped[int] = mapped_column(default=1, nullable=False)

    user: Mapped[User] = relationship(back_populates="interests")
