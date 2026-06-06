from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.permissions import get_current_user
from app.models.business import Business
from app.models.enums import DealStage
from app.models.user import User
from app.schemas.recommendation import RecommendationItemResponse
from app.services.recommendation_service import score_business_for_user

router = APIRouter(prefix="/recommendations", tags=["recommendations"])


@router.get("/businesses", response_model=list[RecommendationItemResponse])
def recommend_businesses(
    limit: int = Query(default=20, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[RecommendationItemResponse]:
    businesses = db.scalars(
        select(Business).where(Business.status.in_([DealStage.listed, DealStage.funding_open]))
    ).all()
    ranked = []
    for business in businesses:
        score, reasons = score_business_for_user(current_user, business)
        ranked.append(RecommendationItemResponse(business=business, score=score, reasons=reasons))
    return sorted(ranked, key=lambda item: item.score, reverse=True)[:limit]
