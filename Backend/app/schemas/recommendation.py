from pydantic import BaseModel

from app.schemas.business import BusinessSummaryResponse


class RecommendationItemResponse(BaseModel):
    business: BusinessSummaryResponse
    score: float
    reasons: list[str]
