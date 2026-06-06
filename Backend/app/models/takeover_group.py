from datetime import datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import DateTime, Enum, ForeignKey, Numeric, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.enums import GroupMemberRole
from app.models.mixins import TimestampMixin, UUIDPrimaryKeyMixin


class TakeoverGroup(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "takeover_groups"

    business_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("businesses.id"))
    organizer_user_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"))
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    goal_summary: Mapped[str | None] = mapped_column(Text)
    target_offer_amount: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    submitted_offer_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class TakeoverGroupMember(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "takeover_group_members"
    __table_args__ = (UniqueConstraint("group_id", "user_id", name="uq_takeover_group_member"),)

    group_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("takeover_groups.id"))
    user_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"))
    role: Mapped[GroupMemberRole] = mapped_column(
        Enum(GroupMemberRole), default=GroupMemberRole.supporter
    )


class TakeoverGroupMessage(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "takeover_group_messages"

    group_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("takeover_groups.id"))
    user_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"))
    body: Mapped[str] = mapped_column(Text, nullable=False)
    is_moderated: Mapped[bool] = mapped_column(default=False, nullable=False)
