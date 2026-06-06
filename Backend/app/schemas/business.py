from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import DealStage, FinancingType


class BusinessCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    category: str = Field(min_length=1, max_length=80)
    district: str = Field(min_length=1, max_length=80)
    address: str | None = None
    short_description: str = Field(min_length=20, max_length=500)
    financing_types: list[FinancingType] = []
    urgency_score: int = Field(default=0, ge=0, le=10)
    owner_retirement_risk: bool = False


class BusinessUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    category: str | None = Field(default=None, min_length=1, max_length=80)
    district: str | None = Field(default=None, min_length=1, max_length=80)
    address: str | None = None
    short_description: str | None = Field(default=None, min_length=20, max_length=500)
    financing_types: list[FinancingType] | None = None
    urgency_score: int | None = Field(default=None, ge=0, le=10)
    owner_retirement_risk: bool | None = None


class BusinessStoryUpsertRequest(BaseModel):
    founder_story: str | None = None
    family_legacy: str | None = None
    cultural_relevance: str | None = None
    neighbourhood_importance: str | None = None


class FinancialSnapshotUpsertRequest(BaseModel):
    monthly_revenue_min: Decimal | None = None
    monthly_revenue_max: Decimal | None = None
    monthly_profit_min: Decimal | None = None
    monthly_profit_max: Decimal | None = None
    monthly_rent: Decimal | None = None
    employee_count: int | None = Field(default=None, ge=0)
    assets_summary: str | None = None
    debts_summary: str | None = None
    years_operating: int | None = Field(default=None, ge=0)
    funding_needed: Decimal | None = None
    asking_price: Decimal | None = None


class CommunityMemoryCreateRequest(BaseModel):
    body: str = Field(min_length=1, max_length=4000)


class BusinessQuestionCreateRequest(BaseModel):
    question: str = Field(min_length=1, max_length=2000)


class BusinessAnswerCreateRequest(BaseModel):
    answer: str = Field(min_length=1, max_length=4000)


class BusinessSummaryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    slug: str
    category: str
    district: str
    short_description: str
    status: DealStage
    financing_types: list[FinancingType]
    urgency_score: int
    popularity_score: int
    owner_retirement_risk: bool


class BusinessStoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    business_id: UUID
    founder_story: str | None
    family_legacy: str | None
    cultural_relevance: str | None
    neighbourhood_importance: str | None


class FinancialSnapshotResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    business_id: UUID
    monthly_revenue_min: Decimal | None
    monthly_revenue_max: Decimal | None
    monthly_profit_min: Decimal | None
    monthly_profit_max: Decimal | None
    monthly_rent: Decimal | None
    employee_count: int | None
    assets_summary: str | None
    debts_summary: str | None
    years_operating: int | None
    funding_needed: Decimal | None
    asking_price: Decimal | None
    currency: str


class BusinessDetailResponse(BusinessSummaryResponse):
    story: BusinessStoryResponse | None = None
    financial_snapshot: FinancialSnapshotResponse | None = None
