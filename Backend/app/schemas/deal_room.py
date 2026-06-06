from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class DealRoomCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=160)


class DealRoomMemberAddRequest(BaseModel):
    user_id: UUID
    role: str = Field(default="viewer", max_length=40)


class DealRoomResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    business_id: UUID
    name: str
    created_by_user_id: UUID
