from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import DealStage, FinancingType


class FinancingProposalCreateRequest(BaseModel):
    financing_type: FinancingType
    target_amount: Decimal | None = Field(default=None, gt=0)
    minimum_investment_amount: Decimal | None = Field(default=None, gt=0)


class FinancingProposalResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    business_id: UUID
    financing_type: FinancingType
    target_amount: Decimal | None
    minimum_investment_amount: Decimal | None
    current_amount_raised: Decimal
    deal_stage: DealStage
