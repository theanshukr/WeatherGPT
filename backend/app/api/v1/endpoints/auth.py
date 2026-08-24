import logging
import uuid
import json
from typing import Optional
from fastapi import APIRouter, Header, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, text
from app.core.database import get_db
from app.core.supabase import supabase_client
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter()


class RegisterRequest(BaseModel):
    email: str
    password: str
    full_name: Optional[str] = "WeatherGPT User"
    persona: Optional[str] = "general"
    preferred_language: Optional[str] = "en"


class SyncProfileRequest(BaseModel):
    preferred_language: Optional[str] = "en"
    inferred_persona: Optional[str] = "general"
    saved_locations: Optional[list] = []


@router.post("/register", tags=["Supabase Auth"])
async def register_user_direct(
    payload: RegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    """Directly register user into Supabase Auth with pre-confirmed email.
    
    This bypasses Supabase free-tier SMTP email rate limits ('over_email_send_rate_limit')
    and creates both auth.users, auth.identities, and public.users records.
    The user can immediately log in with their credentials.
    """
    email = payload.email.strip().lower()
    password = payload.password.strip()

    if not email or "@" not in email:
        raise HTTPException(status_code=400, detail="A valid email address is required")
    if len(password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    if not db:
        raise HTTPException(status_code=500, detail="Database connection is unavailable")

    try:
        # 1. Check if user already exists
        check_stmt = text("SELECT id FROM auth.users WHERE email = :email")
        res = await db.execute(check_stmt, {"email": email})
        existing = res.scalar_one_or_none()
        if existing:
            return {
                "status": "success",
                "user_id": str(existing),
                "email": email,
                "message": "User already registered, proceed to login",
                "already_exists": True
            }

        # 2. Generate UUID
        new_uid = str(uuid.uuid4())
        meta_json = json.dumps({
            "full_name": payload.full_name,
            "persona": payload.persona,
            "preferred_language": payload.preferred_language
        })

        # 3. Insert into auth.users (with empty string tokens so GoTrue doesn't error)
        insert_auth_user = text("""
            INSERT INTO auth.users (
                instance_id,
                id,
                aud,
                role,
                email,
                encrypted_password,
                email_confirmed_at,
                raw_app_meta_data,
                raw_user_meta_data,
                confirmation_token,
                recovery_token,
                email_change_token_new,
                email_change,
                phone_change,
                phone_change_token,
                email_change_token_current,
                reauthentication_token,
                created_at,
                updated_at
            ) VALUES (
                '00000000-0000-0000-0000-000000000000',
                CAST(:id AS uuid),
                'authenticated',
                'authenticated',
                :email,
                extensions.crypt(:password, extensions.gen_salt('bf')),
                NOW(),
                '{"provider": "email", "providers": ["email"]}'::jsonb,
                CAST(:raw_user_meta_data AS jsonb),
                '', '', '', '', '', '', '', '',
                NOW(),
                NOW()
            );
        """)
        await db.execute(insert_auth_user, {
            "id": new_uid,
            "email": email,
            "password": password,
            "raw_user_meta_data": meta_json
        })

        # 4. Insert into auth.identities
        identity_json = json.dumps({
            "sub": new_uid,
            "email": email,
            "email_verified": True,
            "phone_verified": False
        })
        insert_identity = text("""
            INSERT INTO auth.identities (
                id,
                provider_id,
                user_id,
                identity_data,
                provider,
                created_at,
                updated_at
            ) VALUES (
                CAST(:id AS uuid),
                :provider_id,
                CAST(:id AS uuid),
                CAST(:identity_data AS jsonb),
                'email',
                NOW(),
                NOW()
            )
            ON CONFLICT (provider_id, provider) DO UPDATE SET
                identity_data = EXCLUDED.identity_data,
                updated_at = NOW();
        """)
        await db.execute(insert_identity, {
            "id": new_uid,
            "provider_id": new_uid,
            "identity_data": identity_json
        })

        # 5. Insert into public.users
        insert_public_user = text("""
            INSERT INTO public.users (
                id,
                preferred_language,
                inferred_persona,
                persona_confidence,
                preferences,
                saved_locations,
                created_at,
                updated_at
            ) VALUES (
                :id,
                :preferred_language,
                :inferred_persona,
                1.0,
                '{"notifications": true}'::json,
                '[]'::json,
                NOW(),
                NOW()
            )
            ON CONFLICT (id) DO UPDATE SET
                preferred_language = EXCLUDED.preferred_language,
                inferred_persona = EXCLUDED.inferred_persona,
                updated_at = NOW();
        """)
        await db.execute(insert_public_user, {
            "id": new_uid,
            "preferred_language": payload.preferred_language or "en",
            "inferred_persona": payload.persona or "general"
        })

        await db.commit()

        logger.info(f"Registered new verified user: {email} ({new_uid})")
        return {
            "status": "success",
            "user_id": new_uid,
            "email": email,
            "message": "User registered and email verified instantly!",
            "already_exists": False
        }

    except Exception as e:
        await db.rollback()
        logger.error(f"Error registering user direct: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")


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
