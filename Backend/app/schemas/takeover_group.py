from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import GroupMemberRole


class TakeoverGroupCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    goal_summary: str | None = Field(default=None, max_length=1000)
    target_offer_amount: Decimal | None = Field(default=None, gt=0)


class TakeoverGroupMessageCreateRequest(BaseModel):
    body: str = Field(min_length=1, max_length=4000)


class TakeoverGroupResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    business_id: UUID
    organizer_user_id: UUID
    name: str
    goal_summary: str | None
    target_offer_amount: Decimal | None


class TakeoverGroupMemberResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    group_id: UUID
    user_id: UUID
    role: GroupMemberRole
