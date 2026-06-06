from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import FinancingType, InvestmentStatus


class InvestmentCreateRequest(BaseModel):
    business_id: UUID
    proposal_id: UUID | None = None
    financing_type: FinancingType
    amount: Decimal = Field(gt=0)


class InvestmentIntentCreateRequest(BaseModel):
    business_id: UUID
    financing_type: FinancingType
    amount_min: Decimal | None = Field(default=None, gt=0)
    amount_max: Decimal | None = Field(default=None, gt=0)
    note: str | None = Field(default=None, max_length=1000)


class InvestmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    business_id: UUID
    proposal_id: UUID | None
    financing_type: FinancingType
    amount: Decimal
    status: InvestmentStatus
