from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.permissions import get_current_user
from app.models.enums import DealStage, GroupMemberRole, UserRole
from app.models.takeover_group import TakeoverGroup, TakeoverGroupMember, TakeoverGroupMessage
from app.models.user import User
from app.schemas.takeover_group import (
    TakeoverGroupCreateRequest,
    TakeoverGroupMessageCreateRequest,
    TakeoverGroupResponse,
)
from app.services.audit_service import write_audit_log
from app.services.business_service import get_business_or_404

router = APIRouter(tags=["takeover_groups"])


@router.post(
    "/businesses/{business_id}/takeover-groups",
    response_model=TakeoverGroupResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_takeover_group(
    business_id: UUID,
    payload: TakeoverGroupCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> TakeoverGroup:
    get_business_or_404(db, business_id)
    group = TakeoverGroup(business_id=business_id, organizer_user_id=current_user.id, **payload.model_dump())
    db.add(group)
    db.flush()
    db.add(TakeoverGroupMember(group_id=group.id, user_id=current_user.id, role=GroupMemberRole.operator))
    write_audit_log(
        db,
        action="takeover_group.create",
        entity_type="takeover_group",
        actor_user_id=current_user.id,
        entity_id=group.id,
    )
    db.commit()
    db.refresh(group)
    return group


@router.get("/businesses/{business_id}/takeover-groups", response_model=list[TakeoverGroupResponse])
def list_takeover_groups(business_id: UUID, db: Session = Depends(get_db)) -> list[TakeoverGroup]:
    get_business_or_404(db, business_id)
    return list(db.scalars(select(TakeoverGroup).where(TakeoverGroup.business_id == business_id)).all())


@router.post("/takeover-groups/{group_id}/join", status_code=status.HTTP_201_CREATED)
def join_takeover_group(
    group_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, UUID]:
    group = db.get(TakeoverGroup, group_id)
    if group is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Takeover group not found")
    member = TakeoverGroupMember(group_id=group_id, user_id=current_user.id, role=GroupMemberRole.supporter)
    db.add(member)
    db.commit()
    return {"id": member.id}


@router.post("/takeover-groups/{group_id}/messages", status_code=status.HTTP_201_CREATED)
def post_group_message(
    group_id: UUID,
    payload: TakeoverGroupMessageCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, UUID]:
    if db.get(TakeoverGroup, group_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Takeover group not found")
    message = TakeoverGroupMessage(group_id=group_id, user_id=current_user.id, body=payload.body)
    db.add(message)
    db.commit()
    return {"id": message.id}


@router.post("/takeover-groups/{group_id}/submit-offer", response_model=TakeoverGroupResponse)
def submit_collective_offer(
    group_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> TakeoverGroup:
    group = db.get(TakeoverGroup, group_id)
    if group is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Takeover group not found")
    if current_user.role != UserRole.admin and group.organizer_user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer or admin can submit")
    group.submitted_offer_at = datetime.now(UTC)
    business = get_business_or_404(db, group.business_id)
    business.status = DealStage.offer_submitted
    write_audit_log(
        db,
        action="takeover_group.submit_offer",
        entity_type="takeover_group",
        actor_user_id=current_user.id,
        entity_id=group.id,
    )
    db.commit()
    db.refresh(group)
    return group
