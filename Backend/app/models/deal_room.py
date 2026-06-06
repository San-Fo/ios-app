from uuid import UUID

from sqlalchemy import BigInteger, ForeignKey, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.mixins import TimestampMixin, UUIDPrimaryKeyMixin


class DealRoom(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "deal_rooms"

    business_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("businesses.id"))
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    created_by_user_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"))


class DealRoomMember(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "deal_room_members"
    __table_args__ = (UniqueConstraint("deal_room_id", "user_id", name="uq_deal_room_member"),)

    deal_room_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("deal_rooms.id"))
    user_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"))
    role: Mapped[str] = mapped_column(String(40), default="viewer", nullable=False)


class Document(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "documents"

    deal_room_id: Mapped[UUID | None] = mapped_column(PgUUID(as_uuid=True), ForeignKey("deal_rooms.id"))
    business_id: Mapped[UUID | None] = mapped_column(PgUUID(as_uuid=True), ForeignKey("businesses.id"))
    uploaded_by_user_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("users.id"))
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    content_type: Mapped[str] = mapped_column(String(120), nullable=False)
    storage_key: Mapped[str] = mapped_column(Text, nullable=False)
    size_bytes: Mapped[int] = mapped_column(BigInteger, nullable=False)
    checksum_sha256: Mapped[str] = mapped_column(String(64), nullable=False)
