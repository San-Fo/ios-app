from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.permissions import get_current_user, require_roles
from app.models.deal_room import DealRoom, DealRoomMember, Document
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.deal_room import DealRoomCreateRequest, DealRoomMemberAddRequest, DealRoomResponse
from app.services.audit_service import write_audit_log
from app.services.business_service import assert_can_manage_business, get_business_or_404

router = APIRouter(tags=["deal_rooms"])


@router.post(
    "/businesses/{business_id}/deal-rooms",
    response_model=DealRoomResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_deal_room(
    business_id: UUID,
    payload: DealRoomCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> DealRoom:
    business = get_business_or_404(db, business_id)
    assert_can_manage_business(current_user, business)
    room = DealRoom(business_id=business_id, created_by_user_id=current_user.id, name=payload.name)
    db.add(room)
    db.flush()
    db.add(DealRoomMember(deal_room_id=room.id, user_id=current_user.id, role="owner"))
    write_audit_log(
        db,
        action="deal_room.create",
        entity_type="deal_room",
        actor_user_id=current_user.id,
        entity_id=room.id,
    )
    db.commit()
    db.refresh(room)
    return room


@router.get("/deal-rooms/{deal_room_id}", response_model=DealRoomResponse)
def get_deal_room(
    deal_room_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> DealRoom:
    room = db.get(DealRoom, deal_room_id)
    if room is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Deal room not found")
    if current_user.role == UserRole.admin:
        return room
    is_member = db.scalar(
        select(DealRoomMember.id).where(
            DealRoomMember.deal_room_id == deal_room_id,
            DealRoomMember.user_id == current_user.id,
        )
    )
    if is_member is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a deal room member")
    return room


@router.post("/deal-rooms/{deal_room_id}/members", status_code=status.HTTP_201_CREATED)
def add_deal_room_member(
    deal_room_id: UUID,
    payload: DealRoomMemberAddRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(UserRole.admin)),
) -> dict[str, UUID]:
    if db.get(DealRoom, deal_room_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Deal room not found")
    member = DealRoomMember(deal_room_id=deal_room_id, user_id=payload.user_id, role=payload.role)
    db.add(member)
    db.flush()
    write_audit_log(
        db,
        action="deal_room.member.add",
        entity_type="deal_room",
        actor_user_id=current_user.id,
        entity_id=deal_room_id,
        metadata={"member_user_id": str(payload.user_id)},
    )
    db.commit()
    return {"id": member.id}


@router.get("/deal-rooms/{deal_room_id}/documents")
def list_deal_room_documents(
    deal_room_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[dict]:
    get_deal_room(deal_room_id, db, current_user)
    docs = db.scalars(select(Document).where(Document.deal_room_id == deal_room_id)).all()
    return [
        {
            "id": doc.id,
            "file_name": doc.file_name,
            "content_type": doc.content_type,
            "size_bytes": doc.size_bytes,
            "created_at": doc.created_at,
        }
        for doc in docs
    ]
