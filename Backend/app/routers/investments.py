from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.permissions import get_current_user, require_roles
from app.models.enums import InvestmentStatus, UserRole
from app.models.investment import Investment, InvestmentIntent
from app.models.user import User
from app.schemas.investment import (
    InvestmentCreateRequest,
    InvestmentIntentCreateRequest,
    InvestmentResponse,
)
from app.services.audit_service import write_audit_log
from app.services.business_service import get_business_or_404

router = APIRouter(tags=["investments"])


@router.post("/investments", response_model=InvestmentResponse, status_code=status.HTTP_201_CREATED)
def create_investment(
    payload: InvestmentCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Investment:
    get_business_or_404(db, payload.business_id)
    investment = Investment(user_id=current_user.id, status=InvestmentStatus.pending_review, **payload.model_dump())
    db.add(investment)
    db.flush()
    write_audit_log(
        db,
        action="investment.create",
        entity_type="investment",
        actor_user_id=current_user.id,
        entity_id=investment.id,
    )
    db.commit()
    db.refresh(investment)
    return investment


@router.get("/investments/me", response_model=list[InvestmentResponse])
def list_my_investments(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[Investment]:
    return list(db.scalars(select(Investment).where(Investment.user_id == current_user.id)).all())


@router.post("/investment-intents", status_code=status.HTTP_201_CREATED)
def create_investment_intent(
    payload: InvestmentIntentCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, UUID]:
    get_business_or_404(db, payload.business_id)
    intent = InvestmentIntent(user_id=current_user.id, **payload.model_dump())
    db.add(intent)
    db.commit()
    return {"id": intent.id}


@router.post("/investments/{investment_id}/confirm", response_model=InvestmentResponse)
def confirm_investment(
    investment_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(UserRole.admin)),
) -> Investment:
    investment = db.get(Investment, investment_id)
    if investment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Investment not found")
    investment.status = InvestmentStatus.confirmed
    investment.confirmed_at = datetime.now(UTC)
    write_audit_log(
        db,
        action="investment.confirm",
        entity_type="investment",
        actor_user_id=current_user.id,
        entity_id=investment.id,
    )
    db.commit()
    db.refresh(investment)
    return investment
