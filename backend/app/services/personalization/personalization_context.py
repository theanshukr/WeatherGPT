from typing import Dict, Any, List
from pydantic import BaseModel


class PersonalizationContext(BaseModel):
    confirmed_personas: List[str] = []
    active_persona: str = "general"
    personalization_enabled: bool = False
    guidance: str = ""
    saved_locations: List[Dict[str, Any]] = []


class PersonalizationContextBuilder:
    """
    Constructs clean, deterministic personalization payload for the LLM response generator.
    Keeps behavioral scoring inside the backend, only sharing necessary domain directives.
    """

    PERSONA_GUIDELINES = {
        "farmer": (
            "User is a verified farmer. Proactively highlight agricultural considerations "
            "such as irrigation postponement on rain, optimal spray windows (<15 km/h wind, low rain probability), "
            "harvest drying risks, and crop frost/heat stress."
        ),
        "traveler": (
            "User is a verified traveler. Proactively highlight highway driving conditions, road waterlogging, "
            "visibility, airline flight disruption risk, and destination packing advice."
        ),
        "daily_commuter": (
            "User is a daily commuter. Focus on peak commute time slots (8-10 AM & 5-7 PM), "
            "rain timeline for two-wheelers, umbrella necessity, and road slippery conditions."
        ),
        "student": (
            "User is a student. Focus on morning school/college commute weather, afternoon sports suitability, "
            "and severe weather school alerts."
        ),
        "outdoor_worker": (
            "User works outdoors. Highlight extreme UV index warnings, heat exhaustion hydration advisories, "
            "gale wind precautions, and sudden thunderstorm alerts."
        ),
        "urban_worker": (
            "User is a municipal/civic worker or urban resident concerned with city-scale impact. "
            "Highlight waterlogging/drainage risk in low-lying localities, heat-index precautions for "
            "outdoor and gig/delivery workers, and wind-driven traffic disruption risk (hoardings, flyovers)."
        ),
        "general": (
            "Provide clear, concise, conversational weather intelligence with standard daily metrics."
        ),
    }

    def build_context(
        self,
        confirmed_personas: List[str],
        active_persona: str = "general",
        saved_locations: List[Dict[str, Any]] = None,
    ) -> PersonalizationContext:
        is_personalized = bool(confirmed_personas) or active_persona != "general"
        guidance = self.PERSONA_GUIDELINES.get(active_persona, self.PERSONA_GUIDELINES["general"])

        return PersonalizationContext(
            confirmed_personas=confirmed_personas or [],
            active_persona=active_persona or "general",
            personalization_enabled=is_personalized,
            guidance=guidance,
            saved_locations=saved_locations or [],
        )


personalization_context_builder = PersonalizationContextBuilder()
