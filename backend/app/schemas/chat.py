from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


class ChatMessageRequest(BaseModel):
    message: str = Field(..., description="User query or weather question")
    session_id: Optional[str] = Field(None, description="Optional chat session ID for multi-turn context")
    user_id: Optional[str] = Field(None, description="Optional user ID")
    location: Optional[str] = Field(None, description="Current location if available")
    latitude: Optional[float] = Field(None, description="Current latitude")
    longitude: Optional[float] = Field(None, description="Current longitude")
    persona: Optional[str] = Field("general", description="Farmer, Traveller, Commuter, Student, Outdoor Worker, or General")
    language: Optional[str] = Field("en", description="Preferred language (en, hi, etc.)")


class WeatherCardData(BaseModel):
    location: str
    temperature: float
    condition: str
    weather_code: int
    humidity: Optional[float] = None
    wind_speed: Optional[float] = None
    precipitation: Optional[float] = None


class TravelAssessmentData(BaseModel):
    travel_risk: str  # LOW, MODERATE, HIGH, SEVERE
    destination: str
    time_frame: str
    activity: str
    verdict: str
    reasons: List[str] = []
    guidelines: List[str] = []
    weather_facts: Dict[str, Any] = {}


class FarmingAdvisoryData(BaseModel):
    crop: str
    location: str
    time_frame: str
    activity: str
    recommendation: str  # DELAY_IRRIGATION, AVOID_SPRAYING, OPTIMAL_SPRAY_WINDOW, etc.
    advisory_headline: str
    reasons: List[str] = []
    actionable_steps: List[str] = []
    weather_facts: Dict[str, Any] = {}


class UrbanAdvisoryData(BaseModel):
    location: str
    time_frame: str
    activity: str
    risk_level: str  # LOW, MODERATE, HIGH, SEVERE
    advisory_headline: str
    verdict: str
    reasons: List[str] = []
    actionable_steps: List[str] = []
    weather_facts: Dict[str, Any] = {}


class ClimateTrendData(BaseModel):
    location: str
    month: str
    years_covered: List[int] = []
    avg_total_rainfall_mm: Optional[float] = None
    max_total_rainfall_mm: Optional[float] = None
    min_total_rainfall_mm: Optional[float] = None
    avg_temp_max: Optional[float] = None
    avg_temp_min: Optional[float] = None
    typical_condition: str
    rainfall_trend: str  # increasing, decreasing, stable
    summary: str


class PersonaConfirmationDTO(BaseModel):
    persona: str
    confidence: float
    title: str
    message: str
    action_chips: List[Dict[str, str]] = []


class ChatMessageResponse(BaseModel):
    session_id: str
    response: str
    language: str = "en"
    primary_intent: str = "CURRENT_WEATHER"
    secondary_intents: List[str] = []
    intent: Optional[str] = None  # Backward compatibility
    persona_applied: Optional[str] = None
    weather_data: Optional[WeatherCardData] = None
    travel_assessment: Optional[TravelAssessmentData] = None
    farming_advisory: Optional[FarmingAdvisoryData] = None
    urban_advisory: Optional[UrbanAdvisoryData] = None
    climate_trend: Optional[ClimateTrendData] = None
    risk_level: str = "LOW"
    tools_called: List[str] = []
    suggestions: List[str] = []
    audio_base64: Optional[str] = None
    audio_chunks: Optional[List[str]] = None
    persona_confirmation: Optional[PersonaConfirmationDTO] = None
    inferred_personas: Optional[Dict[str, float]] = None


class SessionContextResponse(BaseModel):
    session_id: str
    active_location: Optional[Dict[str, Any]] = None
    persona: str = "general"
    language: str = "en"
    recent_intent: Optional[str] = None
    secondary_intents: List[str] = []
    recent_time_reference: str = "current"
    conversation_summary: Optional[str] = None
    history_count: int = 0
    updated_at: str
