from uuid import UUID

from pydantic import BaseModel

from app.models.enums import DealStage


class DealStageUpdateRequest(BaseModel):
    stage: DealStage


class AdminActionResponse(BaseModel):
    business_id: UUID
    status: DealStage
