from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from pydantic import BaseModel


class PersonaConfirmationSuggestion(BaseModel):
    persona: str
    confidence: float
    title: str
    message: str
    action_chips: List[Dict[str, str]]


class ConfirmationManager:
    """
    Manages persona confirmation suggestions, user consent lifecycles,
    and non-intrusive prompt cooldowns.
    """

    CONFIRMATION_THRESHOLD = 0.65
    DECLINE_COOLDOWN_DAYS = 30
    DEFER_COOLDOWN_DAYS = 3

    PERSONA_PROMPTS = {
        "farmer": {
            "title": "🌾 Enable Farmer Intelligence?",
            "message": "It looks like you often ask about crop and farming weather. Would you like me to personalize weather updates for agriculture and field care?",
        },
        "traveler": {
            "title": "✈️ Enable Traveler Mode?",
            "message": "I noticed you frequently plan trips and travel. Would you like proactive travel weather safety, road conditions, and packing advisories?",
        },
        "daily_commuter": {
            "title": "🛵 Enable Daily Commuter Mode?",
            "message": "It looks like you check daily commute weather. Would you like focus on peak morning and evening travel hours with rain alerts?",
        },
        "student": {
            "title": "🎒 Enable Student Weather Mode?",
            "message": "Would you like personalized morning school/college weather timings and afternoon outdoor sports forecasts?",
        },
        "outdoor_worker": {
            "title": "👷 Enable Outdoor Worker Protection?",
            "message": "Would you like specialized outdoor heat index alerts, UV protection advice, and rapid rain storm warnings for field work?",
        },
    }

    def evaluate_confirmation_eligibility(
        self,
        inferred_personas: Dict[str, float],
        confirmed_personas: List[str],
        confirmation_status: Dict[str, str],
        prompt_cooldowns: Dict[str, str],
        now: datetime = None,
    ) -> Optional[PersonaConfirmationSuggestion]:
        if now is None:
            now = datetime.utcnow()

        # Sort personas by confidence descending
        sorted_personas = sorted(inferred_personas.items(), key=lambda x: x[1], reverse=True)

        for persona, conf in sorted_personas:
            if conf < self.CONFIRMATION_THRESHOLD:
                continue

            # Check if already confirmed
            if persona in confirmed_personas:
                continue

            # Check if declined permanently or status is declined
            status = confirmation_status.get(persona, "unprompted")
            if status == "declined":
                continue

            # Check cooldown
            cooldown_str = prompt_cooldowns.get(persona)
            if cooldown_str:
                try:
                    cooldown_dt = datetime.fromisoformat(cooldown_str)
                    if now < cooldown_dt:
                        continue
                except Exception:
                    pass

            # Eligible! Return confirmation suggestion
            prompt_info = self.PERSONA_PROMPTS.get(persona, {
                "title": f"Enable {persona.title()} Mode?",
                "message": f"Would you like tailored insights for {persona.replace('_', ' ')}?",
            })

            return PersonaConfirmationSuggestion(
                persona=persona,
                confidence=conf,
                title=prompt_info["title"],
                message=prompt_info["message"],
                action_chips=[
                    {"label": f"✅ Yes, personalize for {persona.title()}", "action": f"confirm_persona:{persona}"},
                    {"label": "⏳ Not now", "action": f"defer_persona:{persona}"},
                    {"label": "❌ No thanks", "action": f"decline_persona:{persona}"},
                ],
            )

        return None

    def get_decline_cooldown_expiry(self) -> str:
        return (datetime.utcnow() + timedelta(days=self.DECLINE_COOLDOWN_DAYS)).isoformat()

    def get_defer_cooldown_expiry(self) -> str:
        return (datetime.utcnow() + timedelta(days=self.DEFER_COOLDOWN_DAYS)).isoformat()


confirmation_manager = ConfirmationManager()
