from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.permissions import get_current_user, require_roles
from app.models.business import Business, BusinessFinancialSnapshot, BusinessStory, CommunityMemory
from app.models.enums import DealStage, FinancingType, UserRole
from app.models.financing import FinancingProposal
from app.models.user import User
from app.schemas.business import (
    BusinessCreateRequest,
    BusinessDetailResponse,
    BusinessStoryResponse,
    BusinessStoryUpsertRequest,
    BusinessSummaryResponse,
    BusinessUpdateRequest,
    CommunityMemoryCreateRequest,
    FinancialSnapshotResponse,
    FinancialSnapshotUpsertRequest,
)
from app.schemas.financing import FinancingProposalCreateRequest, FinancingProposalResponse
from app.services.audit_service import write_audit_log
from app.services.business_service import assert_can_manage_business, get_business_or_404, unique_slug

router = APIRouter(prefix="/businesses", tags=["businesses"])


@router.post("", response_model=BusinessSummaryResponse, status_code=status.HTTP_201_CREATED)
def create_business(
    payload: BusinessCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(UserRole.business_owner, UserRole.admin)),
) -> Business:
    business = Business(
        owner_user_id=current_user.id,
        slug=unique_slug(db, payload.name),
        **payload.model_dump(),
    )
    db.add(business)
    db.flush()
    write_audit_log(
        db,
        action="business.create",
        entity_type="business",
        actor_user_id=current_user.id,
        entity_id=business.id,
    )
    db.commit()
    db.refresh(business)
    return business


@router.get("", response_model=list[BusinessSummaryResponse])
def search_businesses(
    q: str | None = None,
    district: str | None = None,
    category: str | None = None,
    financing_type: FinancingType | None = None,
    include_unlisted: bool = False,
    limit: int = Query(default=20, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[Business]:
    statement = select(Business)
    if not include_unlisted:
        statement = statement.where(Business.status.in_([DealStage.listed, DealStage.funding_open]))
    if q:
        statement = statement.where(Business.name.ilike(f"%{q}%"))
    if district:
        statement = statement.where(Business.district == district)
    if category:
        statement = statement.where(Business.category == category)
    if financing_type:
        statement = statement.where(Business.financing_types.any(financing_type))
    return list(db.scalars(statement.offset(offset).limit(limit)).all())


@router.get("/{business_id}", response_model=BusinessDetailResponse)
def get_business(business_id: UUID, db: Session = Depends(get_db)) -> Business:
    return get_business_or_404(db, business_id)


@router.patch("/{business_id}", response_model=BusinessSummaryResponse)
def update_business(
    business_id: UUID,
    payload: BusinessUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Business:
    business = get_business_or_404(db, business_id)
    assert_can_manage_business(current_user, business)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(business, key, value)
    write_audit_log(
        db,
        action="business.update",
        entity_type="business",
        actor_user_id=current_user.id,
        entity_id=business.id,
    )
    db.commit()
    db.refresh(business)
    return business


@router.post("/{business_id}/submit", response_model=BusinessSummaryResponse)
def submit_business(
    business_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Business:
    business = get_business_or_404(db, business_id)
    assert_can_manage_business(current_user, business)
    business.status = DealStage.submitted
    write_audit_log(
        db,
        action="business.submit",
        entity_type="business",
        actor_user_id=current_user.id,
        entity_id=business.id,
    )
    db.commit()
    db.refresh(business)
    return business


@router.put("/{business_id}/story", response_model=BusinessStoryResponse)
def upsert_story(
    business_id: UUID,
    payload: BusinessStoryUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> BusinessStory:
    business = get_business_or_404(db, business_id)
    assert_can_manage_business(current_user, business)
    story = db.scalar(select(BusinessStory).where(BusinessStory.business_id == business_id))
    if story is None:
        story = BusinessStory(business_id=business_id)
        db.add(story)
    for key, value in payload.model_dump().items():
        setattr(story, key, value)
    db.commit()
    db.refresh(story)
    return story


@router.put("/{business_id}/financial-snapshot", response_model=FinancialSnapshotResponse)
def upsert_financial_snapshot(
    business_id: UUID,
    payload: FinancialSnapshotUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> BusinessFinancialSnapshot:
    business = get_business_or_404(db, business_id)
    assert_can_manage_business(current_user, business)
    snapshot = db.scalar(
        select(BusinessFinancialSnapshot).where(BusinessFinancialSnapshot.business_id == business_id)
    )
    if snapshot is None:
        snapshot = BusinessFinancialSnapshot(business_id=business_id)
        db.add(snapshot)
    for key, value in payload.model_dump().items():
        setattr(snapshot, key, value)
    write_audit_log(
        db,
        action="business.financial_snapshot.upsert",
        entity_type="business",
        actor_user_id=current_user.id,
        entity_id=business.id,
    )
    db.commit()
    db.refresh(snapshot)
    return snapshot


@router.post("/{business_id}/financing-proposals", response_model=FinancingProposalResponse)
def create_financing_proposal(
    business_id: UUID,
    payload: FinancingProposalCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> FinancingProposal:
    business = get_business_or_404(db, business_id)
    assert_can_manage_business(current_user, business)
    proposal = FinancingProposal(business_id=business_id, **payload.model_dump())
    db.add(proposal)
    write_audit_log(
        db,
        action="financing_proposal.create",
        entity_type="business",
        actor_user_id=current_user.id,
        entity_id=business.id,
    )
    db.commit()
    db.refresh(proposal)
    return proposal


@router.get("/{business_id}/financing-proposals", response_model=list[FinancingProposalResponse])
def list_financing_proposals(business_id: UUID, db: Session = Depends(get_db)) -> list[FinancingProposal]:
    get_business_or_404(db, business_id)
    return list(
        db.scalars(select(FinancingProposal).where(FinancingProposal.business_id == business_id)).all()
    )


@router.post("/{business_id}/memories", status_code=status.HTTP_201_CREATED)
def create_memory(
    business_id: UUID,
    payload: CommunityMemoryCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, UUID]:
    get_business_or_404(db, business_id)
    memory = CommunityMemory(user_id=current_user.id, business_id=business_id, body=payload.body)
    db.add(memory)
    db.commit()
    return {"id": memory.id}
