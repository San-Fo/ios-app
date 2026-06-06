from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.permissions import require_roles
from app.models.audit import AuditLog
from app.models.business import Business
from app.models.enums import DealStage, UserRole
from app.models.investment import Investment
from app.models.user import User
from app.schemas.admin import AdminActionResponse, DealStageUpdateRequest
from app.schemas.business import BusinessSummaryResponse
from app.schemas.investment import InvestmentResponse
from app.services.audit_service import write_audit_log
from app.services.business_service import get_business_or_404

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/businesses/submitted", response_model=list[BusinessSummaryResponse])
def list_submitted_businesses(
    db: Session = Depends(get_db),
    _: User = Depends(require_roles(UserRole.admin)),
) -> list[Business]:
    return list(db.scalars(select(Business).where(Business.status == DealStage.submitted)).all())


@router.post("/businesses/{business_id}/approve", response_model=AdminActionResponse)
def approve_business(
    business_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(UserRole.admin)),
) -> AdminActionResponse:
    business = get_business_or_404(db, business_id)
    business.status = DealStage.approved
    write_audit_log(
        db,
        action="admin.business.approve",
        entity_type="business",
        actor_user_id=current_user.id,
        entity_id=business.id,
    )
    db.commit()
    return AdminActionResponse(business_id=business.id, status=business.status)


@router.post("/businesses/{business_id}/publish", response_model=AdminActionResponse)
def publish_business(
    business_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(UserRole.admin)),
) -> AdminActionResponse:
    business = get_business_or_404(db, business_id)
    business.status = DealStage.listed
    write_audit_log(
        db,
        action="admin.business.publish",
        entity_type="business",
        actor_user_id=current_user.id,
        entity_id=business.id,
    )
    db.commit()
    return AdminActionResponse(business_id=business.id, status=business.status)


@router.patch("/businesses/{business_id}/deal-stage", response_model=AdminActionResponse)
def update_deal_stage(
    business_id: UUID,
    payload: DealStageUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(UserRole.admin)),
) -> AdminActionResponse:
    business = get_business_or_404(db, business_id)
    business.status = payload.stage
    write_audit_log(
        db,
        action="admin.business.deal_stage.update",
        entity_type="business",
        actor_user_id=current_user.id,
        entity_id=business.id,
        metadata={"stage": payload.stage.value},
    )
    db.commit()
    return AdminActionResponse(business_id=business.id, status=business.status)


@router.get("/investments", response_model=list[InvestmentResponse])
def list_investments(
    db: Session = Depends(get_db),
    _: User = Depends(require_roles(UserRole.admin)),
) -> list[Investment]:
    return list(db.scalars(select(Investment)).all())


@router.get("/audit-logs")
def list_audit_logs(
    limit: int = 100,
    db: Session = Depends(get_db),
    _: User = Depends(require_roles(UserRole.admin)),
) -> list[dict]:
    logs = db.scalars(select(AuditLog).order_by(AuditLog.id.desc()).limit(limit)).all()
    return [
        {
            "id": log.id,
            "actor_user_id": log.actor_user_id,
            "action": log.action,
            "entity_type": log.entity_type,
            "entity_id": log.entity_id,
            "metadata": log.extra,
        }
        for log in logs
    ]
