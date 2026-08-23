import re
from datetime import datetime
from typing import List, Dict, Any
from pydantic import BaseModel


class PersonaSignal(BaseModel):
    persona: str  # farmer, traveler, daily_commuter, student, outdoor_worker
    weight: float
    trigger_keyword: str
    timestamp: str = None

    def __init__(self, **data):
        super().__init__(**data)
        if not self.timestamp:
            self.timestamp = datetime.utcnow().isoformat()


class SignalExtractor:
    """
    Extracts multi-persona behavioral signals from user messages.
    Supports Farmer, Traveler, Daily Commuter, Student, and Outdoor Worker.
    """

    FARMER_SIGNALS = {
        "irrigation": 0.25,
        "sinchai": 0.25,
        "tubewell": 0.20,
        "spraying": 0.25,
        "pesticide": 0.25,
        "insecticide": 0.25,
        "fungicide": 0.25,
        "chhidkaw": 0.25,
        "urea": 0.20,
        "fertilizer": 0.20,
        "harvest": 0.25,
        "harvesting": 0.25,
        "katai": 0.25,
        "mandi": 0.20,
        "kheti": 0.20,
        "fasal": 0.20,
        "crop": 0.15,
        "crops": 0.15,
        "wheat": 0.15,
        "gehu": 0.15,
        "paddy": 0.15,
        "rice": 0.15,
        "dhan": 0.15,
        "mustard": 0.15,
        "sarson": 0.15,
        "cotton": 0.15,
        "kapas": 0.15,
        "sugarcane": 0.15,
        "ganna": 0.15,
    }

    TRAVELER_SIGNALS = {
        "flight": 0.25,
        "flights": 0.25,
        "hotel": 0.20,
        "hotels": 0.20,
        "resort": 0.20,
        "road trip": 0.25,
        "highway": 0.20,
        "travelling": 0.20,
        "traveling": 0.20,
        "travel": 0.15,
        "trip": 0.15,
        "vacation": 0.20,
        "holiday": 0.15,
        "packing": 0.20,
        "pack": 0.15,
        "luggage": 0.20,
        "visiting": 0.15,
        "visit": 0.15,
        "ghoomne": 0.20,
        "safar": 0.20,
        "airport": 0.25,
        "destination": 0.15,
    }

    COMMUTER_SIGNALS = {
        "commute": 0.25,
        "commuter": 0.25,
        "office": 0.20,
        "workplace": 0.20,
        "bike": 0.20,
        "biking": 0.20,
        "scooter": 0.20,
        "two wheeler": 0.25,
        "motorcycle": 0.20,
        "metro": 0.20,
        "bus": 0.15,
        "traffic": 0.15,
        "reach office": 0.25,
        "morning commute": 0.25,
        "evening commute": 0.25,
        "flyover": 0.15,
    }

    STUDENT_SIGNALS = {
        "school": 0.25,
        "college": 0.25,
        "university": 0.25,
        "tuition": 0.20,
        "coaching": 0.20,
        "exam": 0.25,
        "exams": 0.25,
        "campus": 0.20,
        "class": 0.15,
        "classes": 0.15,
        "sports practice": 0.20,
        "cricket match": 0.20,
        "football": 0.15,
    }

    OUTDOOR_WORKER_SIGNALS = {
        "construction": 0.25,
        "delivery": 0.25,
        "courier": 0.25,
        "site work": 0.25,
        "labor": 0.20,
        "labour": 0.20,
        "field work": 0.20,
        "outdoor event": 0.20,
        "shift": 0.15,
        "direct sun": 0.20,
        "roofing": 0.25,
    }

    URBAN_WORKER_SIGNALS = {
        "waterlogging": 0.25,
        "drainage": 0.25,
        "municipal": 0.25,
        "nagar nigam": 0.25,
        "civic body": 0.20,
        "underpass": 0.20,
        "traffic advisory": 0.20,
        "city administration": 0.20,
        "gig worker": 0.20,
        "delivery rider": 0.20,
        "hoarding": 0.15,
        "streetlight": 0.15,
        "manhole": 0.20,
        "pothole": 0.15,
    }

    def extract_signals(self, message: str) -> List[PersonaSignal]:
        msg_lower = message.lower()
        extracted: List[PersonaSignal] = []

        all_categories = [
            ("farmer", self.FARMER_SIGNALS),
            ("traveler", self.TRAVELER_SIGNALS),
            ("daily_commuter", self.COMMUTER_SIGNALS),
            ("student", self.STUDENT_SIGNALS),
            ("outdoor_worker", self.OUTDOOR_WORKER_SIGNALS),
            ("urban_worker", self.URBAN_WORKER_SIGNALS),
        ]

        for persona_name, signal_dict in all_categories:
            for kw, weight in signal_dict.items():
                pattern = rf"\b{re.escape(kw)}\b"
                if re.search(pattern, msg_lower):
                    extracted.append(
                        PersonaSignal(
                            persona=persona_name,
                            weight=weight,
                            trigger_keyword=kw,
                            timestamp=datetime.utcnow().isoformat(),
                        )
                    )

        return extracted


signal_extractor = SignalExtractor()
