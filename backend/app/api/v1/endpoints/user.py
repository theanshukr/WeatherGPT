import logging
from fastapi import APIRouter, HTTPException, Depends
from typing import List, Dict, Any
from app.services.personalization.persona_engine import persona_engine
from app.schemas.user import UserProfileResponse, UpdatePersonaRequest, SavedLocationSchema

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/profile/{user_id}", response_model=UserProfileResponse, tags=["User Intelligence & Personalization"])
async def get_user_profile(user_id: str):
    """Retrieve full user profile including confirmed personas, inferred scores, and confirmation status."""
    profile = await persona_engine.get_profile(user_id)
    return UserProfileResponse(
        user_id=profile.user_id,
        confirmed_personas=profile.confirmed_personas,
        inferred_personas=profile.inferred_personas,
        active_persona=profile.active_persona,
        persona_confirmation_status=profile.persona_confirmation_status,
        persona_prompt_cooldown=profile.persona_prompt_cooldown,
        saved_locations=profile.saved_locations,
        updated_at=profile.updated_at,
    )


@router.put("/profile/{user_id}/persona", response_model=UserProfileResponse, tags=["User Intelligence & Personalization"])
async def update_user_persona(user_id: str, payload: UpdatePersonaRequest):
    """
    Handle user confirmation response:
    - action='confirm': Confirms persona and locks it in.
    - action='decline': Sets 30-day cooldown on this persona prompt.
    - action='defer': Sets 3-day cooldown on this persona prompt.
    """
    action = payload.action.lower()
    persona = payload.persona.lower()

    if action == "confirm":
        profile = await persona_engine.confirm_persona(user_id, persona)
    elif action == "decline":
        profile = await persona_engine.decline_persona(user_id, persona)
    elif action == "defer":
        profile = await persona_engine.defer_persona(user_id, persona)
    else:
        raise HTTPException(status_code=400, detail=f"Invalid action '{action}'. Must be 'confirm', 'decline', or 'defer'.")

    return UserProfileResponse(
        user_id=profile.user_id,
        confirmed_personas=profile.confirmed_personas,
        inferred_personas=profile.inferred_personas,
        active_persona=profile.active_persona,
        persona_confirmation_status=profile.persona_confirmation_status,
        persona_prompt_cooldown=profile.persona_prompt_cooldown,
        saved_locations=profile.saved_locations,
        updated_at=profile.updated_at,
    )


@router.post("/profile/{user_id}/locations", tags=["User Intelligence & Personalization"])
async def add_saved_location(user_id: str, location: SavedLocationSchema):
    """Add a personalized saved location (e.g. Home, Work, Farm, Vineyard)."""
    profile = await persona_engine.get_profile(user_id)
    # Remove existing location with the same name if present
    profile.saved_locations = [loc for loc in profile.saved_locations if loc.get("name") != location.name]
    profile.saved_locations.append(location.model_dump())
    await persona_engine.save_profile(profile)
    return {"status": "success", "saved_locations": profile.saved_locations}


@router.delete("/profile/{user_id}/locations/{location_name}", tags=["User Intelligence & Personalization"])
async def delete_saved_location(user_id: str, location_name: str):
    """Delete a saved location."""
    profile = await persona_engine.get_profile(user_id)
    profile.saved_locations = [loc for loc in profile.saved_locations if loc.get("name") != location_name]
    await persona_engine.save_profile(profile)
    return {"status": "success", "saved_locations": profile.saved_locations}
