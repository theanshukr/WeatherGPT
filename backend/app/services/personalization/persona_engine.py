import json
import logging
from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel
from app.services.personalization.signal_extractor import signal_extractor, PersonaSignal
from app.services.personalization.confidence_calculator import confidence_calculator
from app.services.personalization.confirmation_manager import (
    confirmation_manager,
    PersonaConfirmationSuggestion,
)
from app.services.personalization.personalization_context import (
    personalization_context_builder,
    PersonalizationContext,
)
from app.core.redis import redis_manager

logger = logging.getLogger(__name__)


class UserProfileState(BaseModel):
    user_id: str
    confirmed_personas: List[str] = []
    inferred_personas: Dict[str, float] = {
        "farmer": 0.0,
        "traveler": 0.0,
        "daily_commuter": 0.0,
        "student": 0.0,
        "outdoor_worker": 0.0,
    }
    active_persona: str = "general"
    persona_confirmation_status: Dict[str, str] = {}
    persona_prompt_cooldown: Dict[str, str] = {}
    behavioral_signals: List[Dict[str, Any]] = []
    saved_locations: List[Dict[str, Any]] = []
    updated_at: str = None

    def __init__(self, **data):
        super().__init__(**data)
        if not self.updated_at:
            self.updated_at = datetime.utcnow().isoformat()


class PersonaEngine:
    """
    Main User Intelligence & Personalization Orchestrator.
    Manages multi-persona signal tracking, time-decayed confidence calculations,
    non-intrusive confirmation suggestions, and profile state persistence.
    """

    def __init__(self):
        self._local_profiles: Dict[str, UserProfileState] = {}

    def _redis_key(self, user_id: str) -> str:
        return f"weathergpt:profile:{user_id}"

    async def get_profile(self, user_id: str) -> UserProfileState:
        """Fetch user profile state from Redis, local memory, or initialize fresh."""
        # 1. Try Redis
        try:
            cached = await redis_manager.get(self._redis_key(user_id))
            if cached:
                data = json.loads(cached)
                profile = UserProfileState(**data)
                self._local_profiles[user_id] = profile
                return profile
        except Exception as e:
            logger.debug(f"Redis get_profile error: {e}")

        # 2. Try Local Cache
        if user_id in self._local_profiles:
            return self._local_profiles[user_id]

        # 3. Create fresh profile
        new_profile = UserProfileState(user_id=user_id)
        self._local_profiles[user_id] = new_profile
        return new_profile

    async def save_profile(self, profile: UserProfileState):
        """Persist profile state to Redis and local cache."""
        profile.updated_at = datetime.utcnow().isoformat()
        self._local_profiles[profile.user_id] = profile
        try:
            payload = profile.model_dump_json()
            await redis_manager.set(self._redis_key(profile.user_id), payload, expire=2592000)  # 30 days
        except Exception as e:
            logger.debug(f"Redis save_profile error: {e}")

    async def process_turn(
        self,
        user_id: str,
        message: str,
        explicit_session_persona: Optional[str] = None,
    ) -> tuple[PersonalizationContext, Optional[PersonaConfirmationSuggestion]]:
        """
        Process incoming user turn:
        1. Extract domain behavioral signals.
        2. Recalculate time-decayed rolling confidence scores.
        3. Determine active persona (Explicit > Confirmed > Inferred top > General).
        4. Check for gentle confirmation suggestion eligibility.
        5. Build clean personalization context for LLM.
        """
        profile = await self.get_profile(user_id)

        # 1. Extract Signals
        new_signals = signal_extractor.extract_signals(message)
        if new_signals:
            for s in new_signals:
                profile.behavioral_signals.append(s.model_dump())
            # Keep max 50 recent signals
            if len(profile.behavioral_signals) > 50:
                profile.behavioral_signals = profile.behavioral_signals[-50:]

        # 2. Recalculate Confidence Scores with time decay
        scores = confidence_calculator.calculate_scores(profile.behavioral_signals)
        profile.inferred_personas = scores

        # 3. Determine Active Persona Automatically (Query signals > Recent History > Confirmed > General)
        active_p = "general"
        if explicit_session_persona and explicit_session_persona.lower() != "general":
            active_p = explicit_session_persona.lower()
        else:
            # Check current turn signals immediately
            if new_signals:
                recent_top = max(new_signals, key=lambda s: s.confidence)
                if recent_top.confidence >= 0.50:
                    active_p = recent_top.persona
            
            # If still general, check cumulative rolling scores
            if active_p == "general" and profile.inferred_personas:
                top_p, top_score = max(profile.inferred_personas.items(), key=lambda x: x[1])
                if top_score >= 0.35:
                    active_p = top_p
            elif profile.confirmed_personas:
                active_p = profile.confirmed_personas[0]

        profile.active_persona = active_p

        # 4. Do NOT prompt or interrupt user with manual confirmation suggestions
        suggestion = None

        # 5. Build Personalization Context for LLM
        personalization_ctx = personalization_context_builder.build_context(
            confirmed_personas=profile.confirmed_personas,
            active_persona=active_p,
            saved_locations=profile.saved_locations,
        )

        # Save updated profile
        await self.save_profile(profile)

        return personalization_ctx, suggestion

    async def confirm_persona(self, user_id: str, persona: str) -> UserProfileState:
        """User confirms a persona choice."""
        profile = await self.get_profile(user_id)
        if persona not in profile.confirmed_personas:
            profile.confirmed_personas.append(persona)
        profile.active_persona = persona
        profile.persona_confirmation_status[persona] = "confirmed"
        await self.save_profile(profile)
        return profile

    async def decline_persona(self, user_id: str, persona: str) -> UserProfileState:
        """User declines a persona suggestion (sets 30-day cooldown)."""
        profile = await self.get_profile(user_id)
        profile.persona_confirmation_status[persona] = "declined"
        profile.persona_prompt_cooldown[persona] = confirmation_manager.get_decline_cooldown_expiry()
        await self.save_profile(profile)
        return profile

    async def defer_persona(self, user_id: str, persona: str) -> UserProfileState:
        """User defers a persona suggestion (sets 3-day cooldown)."""
        profile = await self.get_profile(user_id)
        profile.persona_confirmation_status[persona] = "dismissed"
        profile.persona_prompt_cooldown[persona] = confirmation_manager.get_defer_cooldown_expiry()
        await self.save_profile(profile)
        return profile


persona_engine = PersonaEngine()
