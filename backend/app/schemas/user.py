from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


class SavedLocationSchema(BaseModel):
    name: str = Field(..., description="Custom label e.g. Home, Work, Farm, Vineyard")
    city: str
    latitude: float
    longitude: float


class UpdatePersonaRequest(BaseModel):
    action: str = Field("confirm", description="confirm, decline, or defer")
    persona: str = Field(..., description="farmer, traveler, daily_commuter, student, outdoor_worker, general")


class UserProfileResponse(BaseModel):
    user_id: str
    confirmed_personas: List[str] = []
    inferred_personas: Dict[str, float] = {}
    active_persona: str = "general"
    persona_confirmation_status: Dict[str, str] = {}
    persona_prompt_cooldown: Dict[str, str] = {}
    saved_locations: List[Dict[str, Any]] = []
    updated_at: str
