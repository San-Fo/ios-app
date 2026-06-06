import re
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.business import Business
from app.models.enums import UserRole
from app.models.user import User


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug or "business"


def unique_slug(db: Session, name: str) -> str:
    base = slugify(name)
    candidate = base
    index = 2
    while db.scalar(select(Business.id).where(Business.slug == candidate)) is not None:
        candidate = f"{base}-{index}"
        index += 1
    return candidate


def assert_can_manage_business(user: User, business: Business) -> None:
    if user.role == UserRole.admin:
        return
    if business.owner_user_id == user.id:
        return
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot manage this business")


def get_business_or_404(db: Session, business_id: UUID) -> Business:
    business = db.get(Business, business_id)
    if business is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business not found")
    return business
