import math
from datetime import datetime
from typing import List, Dict, Any


class ConfidenceCalculator:
    """
    Calculates rolling time-decayed confidence scores for user personas.
    Applies half-life exponential decay to past signals so old behaviors
    gradually fade without permanent lock-in.
    """

    def __init__(self, half_life_days: float = 14.0):
        self.half_life_days = half_life_days
        # Decay constant lambda = ln(2) / half_life
        self.decay_lambda = math.log(2) / (self.half_life_days * 86400.0)

    def calculate_scores(self, signals: List[Dict[str, Any]], now: datetime = None) -> Dict[str, float]:
        if now is None:
            now = datetime.utcnow()

        persona_weighted_sums: Dict[str, float] = {
            "farmer": 0.0,
            "traveler": 0.0,
            "daily_commuter": 0.0,
            "student": 0.0,
            "outdoor_worker": 0.0,
            "urban_worker": 0.0,
        }

        for sig in signals:
            persona = sig.get("persona")
            weight = float(sig.get("weight", 0.15))
            ts_str = sig.get("timestamp")

            if not persona or persona not in persona_weighted_sums:
                continue

            decay_multiplier = 1.0
            if ts_str:
                try:
                    sig_time = datetime.fromisoformat(ts_str)
                    delta_seconds = max(0.0, (now - sig_time).total_seconds())
                    decay_multiplier = math.exp(-self.decay_lambda * delta_seconds)
                except Exception:
                    decay_multiplier = 1.0

            persona_weighted_sums[persona] += weight * decay_multiplier

        # Convert weighted sum into normalized confidence [0.0, 1.0]
        # Formula: Confidence = 1 - exp(-k * sum) where k=1.5
        # Example: sum=0.25 -> 0.31; sum=0.50 -> 0.52; sum=0.70 -> 0.65; sum=1.0 -> 0.77
        confidence_scores: Dict[str, float] = {}
        for p, s in persona_weighted_sums.items():
            conf = 1.0 - math.exp(-1.5 * s)
            confidence_scores[p] = round(min(1.0, max(0.0, conf)), 2)

        return confidence_scores


confidence_calculator = ConfidenceCalculator()
