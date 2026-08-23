import logging
from typing import Optional
from fastapi import APIRouter, Header, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.core.supabase import supabase_client
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter()


class SyncProfileRequest(BaseModel):
    preferred_language: Optional[str] = "en"
    inferred_persona: Optional[str] = "general"
    saved_locations: Optional[list] = []


@router.get("/me", tags=["Supabase Auth"])
async def get_current_authenticated_user(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
):
    """Verify Supabase Auth JWT token and retrieve corresponding user profile."""
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing Authorization Header")

    supabase_user = await supabase_client.verify_token_and_get_user(authorization)
    if not supabase_user:
        raise HTTPException(status_code=401, detail="Invalid or expired Supabase token")

    user_id = supabase_user.get("id")
    email = supabase_user.get("email")

    user_record = None
    if db:
        stmt = select(User).where(User.id == user_id)
        res = await db.execute(stmt)
        user_record = res.scalar_one_or_none()

        if not user_record:
            # Auto-create user in database synced with Supabase Auth ID
            user_record = User(
                id=user_id,
                preferred_language="en",
                inferred_persona="general",
                preferences={"email": email},
            )
            db.add(user_record)
            await db.commit()
            await db.refresh(user_record)

    return {
        "user_id": user_id,
        "email": email,
        "preferred_language": user_record.preferred_language if user_record else "en",
        "inferred_persona": user_record.inferred_persona if user_record else "general",
        "saved_locations": user_record.saved_locations if user_record else [],
        "authenticated_via": "supabase_auth",
    }


@router.post("/sync-profile", tags=["Supabase Auth"])
async def sync_supabase_user_profile(
    payload: SyncProfileRequest,
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
):
    """Sync mobile user preferences with Supabase Auth account."""
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing Authorization Header")

    supabase_user = await supabase_client.verify_token_and_get_user(authorization)
    if not supabase_user:
        raise HTTPException(status_code=401, detail="Invalid or expired Supabase token")

    user_id = supabase_user.get("id")
    if db:
        stmt = select(User).where(User.id == user_id)
        res = await db.execute(stmt)
        user = res.scalar_one_or_none()
        if user:
            if payload.preferred_language:
                user.preferred_language = payload.preferred_language
            if payload.inferred_persona:
                user.inferred_persona = payload.inferred_persona
            if payload.saved_locations is not None:
                user.saved_locations = payload.saved_locations
            await db.commit()

    return {"status": "success", "user_id": user_id, "updated": True}
