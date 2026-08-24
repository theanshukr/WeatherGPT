import re
from typing import Dict, Any, Optional, List
from pydantic import BaseModel
from app.services.llm.context_manager import SessionContext


class ParsedQuery(BaseModel):
    original_message: str
    primary_intent: str
    secondary_intents: List[str] = []
    location: Optional[str] = None
    time_range: str = "current"  # current, tomorrow, weekend, 7_days, hourly
    activity: Optional[str] = None  # driving, travel, spraying, irrigation, harvesting, outdoor
    crop: Optional[str] = None  # wheat, rice, mustard, cotton, potato, maize, vegetables, sugarcane
    metrics_requested: List[str] = []
    language_hint: str = "en"  # en, hi, hinglish
    target_month: Optional[int] = None  # 1-12, used for CLIMATE_TREND intent
    years_back: Optional[int] = None  # how many years of history to average, for CLIMATE_TREND


class QueryUnderstandingService:
    COMMON_CITIES = [
        "new delhi", "delhi", "mumbai", "bangalore", "bengaluru", "kolkata", "chennai", "hyderabad",
        "lucknow", "kanpur", "jaipur", "varanasi", "patna", "bhopal", "indore", "chandigarh",
        "shimla", "manali", "goa", "pune", "ahmedabad", "surat", "agra", "noida", "gurgaon",
        "gurugram", "amritsar", "dehradun", "rishikesh", "srinagar", "haridwar", "ayodhya",
        "ranchi", "guwahati", "nagpur", "kochi", "coimbatore", "mysore", "udaipur", "jodhpur",
        "london", "new york", "tokyo", "paris", "dubai", "singapore"
    ]

    MULTILINGUAL_INDIC_CITIES = {
        # Devanagari / Hindi / Marathi
        "दिल्ली": "Delhi", "नई दिल्ली": "New Delhi", "मुंबई": "Mumbai", "पुणे": "Pune", "नागपूर": "Nagpur",
        "लखनऊ": "Lucknow", "कानपुर": "Kanpur", "जयपुर": "Jaipur", "शिमला": "Shimla", "मनाली": "Manali",
        "वाराणसी": "Varanasi", "पटना": "Patna", "भोपाल": "Bhopal", "इंदौर": "Indore", "बेंगलुरु": "Bengaluru",
        "कोलकाता": "Kolkata", "चेन्नई": "Chennai", "गोवा": "Goa", "अहमदाबाद": "Ahmedabad", "सूरत": "Surat",
        # Bengali
        "কলকাতা": "Kolkata", "ঢাকা": "Dhaka", "শিলিগুড়ি": "Siliguri", "পাটনা": "Patna", "রাঁচি": "Ranchi",
        # Tamil
        "சென்னை": "Chennai", "மதுரை": "Madurai", "கோவை": "Coimbatore", "திருச்சி": "Trichy", "சேலம்": "Salem",
        # Telugu
        "హైదరాబాద్": "Hyderabad", "విశాఖపట్నం": "Visakhapatnam", "విజయవాడ": "Vijayawada", "తిరుపతి": "Tirupati",
        # Gujarati
        "અમદાવાદ": "Ahmedabad", "સુરત": "Surat", "વડોદરા": "Vadodara", "રાજકોટ": "Rajkot",
        # Kannada
        "ಬೆಂಗಳೂರು": "Bengaluru", "ಮೈಸೂರು": "Mysuru", "ಮಂಗಳೂರು": "Mangaluru",
        # Punjabi
        "ਅੰਮ੍ਰਿਤਸਰ": "Amritsar", "ਚੰਡੀਗੜ੍ਹ": "Chandigarh", "ਲੁਧਿਆਣਾ": "Ludhiana"
    }

    STOP_WORDS = {
        "the", "a", "an", "my", "today", "tomorrow", "this", "next", "weekend", "morning", "evening",
        "kheti", "liye", "kal", "aaj", "mausam", "kaisa", "hogi", "kya", "rain", "weather", "forecast",
        "there", "here", "city", "place", "safe", "trip", "drive", "travel", "road", "spray", "water",
        "about", "timing", "tell", "show", "status", "condition", "what", "how", "when", "is", "it",
        "crop", "crops", "field", "farm", "khet", "fasal", "kisan", "farmer", "pesticide", "spray",
        "spraying", "insecticide", "fungicide", "urea", "fertilizer", "chhidkaw", "sinchai", "tubewell",
        "wheat", "gehu", "rice", "dhan", "mustard", "sarson", "cotton", "kapas", "sugarcane", "ganna",
        "potato", "aloo", "corn", "makka", "vegetables", "sabzi", "car", "bike", "gadi", "safar", "tour",
        "hi", "hello", "hey", "megha", "namaste", "kaise", "ho", "haal", "kem", "cho", "pranam",
        "mujhe", "mujhko", "apne", "apna", "apni", "mere", "mera", "meri", "humare", "humara", "karna", "kar",
        "dalna", "dalne", "dal", "chahiye", "sakte", "sakta", "saktee", "h", "hai", "hain", "ghar",
        "dawa", "dawao", "dawai", "paani", "sadak", "office", "gaanv", "gao", "gaun", "village", "batao",
        "badal", "dhoop", "thand", "garmi", "havaye", "hawa", "toofan", "barish", "baarish"
    }

    CROPS_KEYWORDS = {
        "wheat": ["wheat", "gehu", "gehun"],
        "rice": ["rice", "paddy", "dhan", "chawal"],
        "mustard": ["mustard", "sarson", "rai"],
        "cotton": ["cotton", "kapas"],
        "sugarcane": ["sugarcane", "ganna"],
        "potato": ["potato", "aloo", "alu"],
        "maize": ["maize", "corn", "makka"],
        "vegetables": ["vegetables", "sabzi", "tamatar", "pyaz", "tomato", "onion"],
    }

    ACTIVITIES_KEYWORDS = {
        "driving": ["drive", "driving", "car", "road trip", "highway", "gadi"],
        "biking": ["bike", "biking", "two wheeler", "scooter", "motorcycle"],
        "travel": ["travel", "traveling", "travelling", "trip", "visit", "ghoomne", "safar", "flight", "train"],
        "spraying": ["spray", "spraying", "pesticide", "insecticide", "fungicide", "chhidkaw", "urea", "fertilizer", "kitnashak", "keetnashak", "dalne"],
        "irrigation": ["irrigate", "irrigation", "watering", "pani", "sinchai", "tubewell"],
        "harvesting": ["harvest", "harvesting", "katai", "threshing", "cutting"],
        "outdoor": ["event", "match", "picnic", "cricket", "walk", "jogging", "outdoor"],
    }

    def parse_query(self, message: str, context: Optional[SessionContext] = None) -> ParsedQuery:
        msg = message.strip()
        msg_lower = msg.lower()

        # 1. Detect Language Hint
        language_hint = "en"
        hindi_keywords = ["kaisa", "hogi", "kya", "aaj", "kal", "baarish", "mausam", "kheti", "pani", "chhatri", "namaste", "garmi", "thandi", "safar", "ghoomne", "batao", "chhidkaw", "fasal", "mujhe", "apne", "khet", "kitnashak", "dalne", "h"]
        has_devanagari = any('\u0900' <= char <= '\u097F' for char in msg)
        has_hindi_vocab = any(kw in msg_lower for kw in hindi_keywords)

        if has_devanagari:
            language_hint = "hi"
        elif has_hindi_vocab:
            language_hint = "hi"  # Hinglish / Romanized Hindi

        # 2. Extract Location
        extracted_location = None

        # Check Multilingual Indic cities first (matching Marathi, Bengali, Tamil, Telugu, Hindi, Gujarati, etc.)
        for indic_city, eng_city in self.MULTILINGUAL_INDIC_CITIES.items():
            if indic_city in msg:
                extracted_location = eng_city
                break

        # Check travel route destination first (e.g. "delhi se gurgaon", "to mumbai")
        route_dest = re.search(r'(?:se|from)\s+([a-z\s]+?)\s+(?:jana|jaana|travel|shift|reach)', msg_lower)
        if route_dest:
            cand = route_dest.group(1).strip()
            for city in self.COMMON_CITIES:
                if city in cand:
                    extracted_location = city.title()
                    break

        # Check English known cities
        if not extracted_location:
            for city in self.COMMON_CITIES:
                if re.search(rf'\b{city}\b', msg_lower):
                    extracted_location = city.title()
                    break

        # Fallback to preposition parsing if no known city matched
        if not extracted_location:
            match_en = re.search(r'\b(?:to|in|for|at|around)\s+([A-Za-z]+)', msg, re.IGNORECASE)
            match_hi = re.search(r'\b([A-Za-z]+)\s+(?:me|mein|mai|ka|ki|ke|jaana|ja sakte)\b', msg, re.IGNORECASE)

            if match_en and len(match_en.group(1)) > 2 and match_en.group(1).lower() not in self.STOP_WORDS:
                extracted_location = match_en.group(1).strip().capitalize()
            elif match_hi and len(match_hi.group(1)) > 2 and match_hi.group(1).lower() not in self.STOP_WORDS:
                extracted_location = match_hi.group(1).strip().capitalize()

        # Multi-Turn Context Resolution: Inherit from previous turns if user says "tomorrow?", "what about there?", "rain timing?", etc.
        if not extracted_location and context and context.active_location:
            extracted_location = context.active_location.name

        is_pure_greeting = (
            any(re.search(rf'\b{re.escape(g)}\b', msg_lower) for g in ["hi", "hello", "hey", "namaste", "namaskar", "kaise ho", "kya haal", "good morning", "good evening", "good afternoon", "kem cho", "vanakkam", "pranam", "नमस्ते", "प्रणाम", "नमस्कार"]) and
            not any(w in msg_lower for w in ["rain", "baarish", "barish", "travel", "trip", "spray", "crop", "fasal", "khet", "temp", "garmi", "thandi", "toofan", "barish", "बारिश"])
        )

        # 3. Detect Time Range
        time_range = "current"
        if "parso" in msg_lower or "day after tomorrow" in msg_lower or "agle se agla" in msg_lower or "परसों" in msg:
            time_range = "day_after_tomorrow"
        elif "tomorrow" in msg_lower or "kal" in msg_lower or "agle din" in msg_lower or "कल" in msg:
            time_range = "tomorrow"
        elif "shaam" in msg_lower or "evening" in msg_lower or "शाम" in msg:
            time_range = "evening"
        elif "subah" in msg_lower or "morning" in msg_lower or "सुबह" in msg:
            time_range = "morning"
        elif "raat" in msg_lower or "night" in msg_lower or "रात" in msg:
            time_range = "night"
        elif "dopahar" in msg_lower or "afternoon" in msg_lower:
            time_range = "afternoon"
        elif "aaj" in msg_lower or "today" in msg_lower or "आज" in msg:
            time_range = "today"
        elif "weekend" in msg_lower or "saturday" in msg_lower or "sunday" in msg_lower or "ravivar" in msg_lower:
            time_range = "weekend"
        elif "7 day" in msg_lower or "week" in msg_lower or "hafta" in msg_lower or "weekly" in msg_lower or "forecast" in msg_lower:
            time_range = "7_days"
        elif "hourly" in msg_lower or "timing" in msg_lower:
            time_range = "hourly"
        elif context and context.recent_time_reference != "current" and any(ref in msg_lower for ref in ["there", "it", "then", "also", "and"]):
            time_range = context.recent_time_reference

        # 4. Detect Activity (Word boundary matching)
        detected_activity = None
        for act, kws in self.ACTIVITIES_KEYWORDS.items():
            if any(re.search(rf'\b{re.escape(kw)}\b', msg_lower) for kw in kws):
                detected_activity = act
                break

        # 5. Detect Crop (Word boundary matching)
        detected_crop = None
        for crop_name, kws in self.CROPS_KEYWORDS.items():
            if any(re.search(rf'\b{re.escape(kw)}\b', msg_lower) for kw in kws):
                detected_crop = crop_name
                break

        # 6. Detect Metrics Requested
        metrics = []
        if any(w in msg_lower for w in ["rain", "baarish", "precipitation", "umbrella", "chhatri", "barsat", "wet", "barish", "बारिश"]):
            metrics.append("rain")
        if any(w in msg_lower for w in ["temp", "temperature", "garmi", "thandi", "hot", "cold", "heat", "तापमान"]):
            metrics.append("temperature")
        if any(w in msg_lower for w in ["wind", "hawa", "storm", "aandhi", "toofan", "cyclone", "gale", "हवा"]):
            metrics.append("wind")
        if any(w in msg_lower for w in ["humidity", "nami", "sweat", "moisture"]):
            metrics.append("humidity")
        if any(w in msg_lower for w in ["alert", "warning", "danger", "hazard", "risk", "khatra", "चेतावनी"]):
            metrics.append("alert")

        # 7. Multi-Intent Classification
        all_intents: List[str] = []

        is_rain_query = "rain" in metrics or any(w in msg_lower for w in ["rain", "baarish", "barish", "umbrella", "wet", "बारिश"])
        is_travel_query = (
            detected_activity in ["travel", "driving", "biking"] or
            any(w in msg_lower for w in ["travel", "trip", "road", "drive", "visit", "ghoomne", "safe to go", "can i go", "jaana", "jana", "safar", "nikalna", "route", "commute", "जाना", "सफर"]) or
            bool(re.search(r'\bse\b.*\b(jana|jaana|nikalna)\b', msg_lower))
        )
        is_farming_query = (
            detected_activity in ["spraying", "irrigation", "harvesting"] or
            detected_crop is not None or
            any(w in msg_lower for w in [
                "farming", "farmer", "kisan", "kheti", "crop", "fasal", "spray", "pesticide", "irrigation",
                "sinchai", "chhidkaw", "khet", "farm", "field", "फसल", "खेती", "खेत", "किसान", "कृषि",
                "बुवाई", "कटाई", "खाद", "जुताई", "कीटनाशक"
            ])
        )
        is_warning_query = "alert" in metrics or any(w in msg_lower for w in ["warning", "danger", "hazard", "storm", "cyclone", "flood", "disaster", "toofan", "चेतावनी"])
        is_temp_query = "temperature" in metrics

        # Climate trend / historical query detection: month name + a
        # history/average/trend/"last N years" style keyword. Kept
        # deliberately narrow so it doesn't fire on ordinary forecast
        # questions that happen to mention a month in passing.
        MONTH_NAMES = {
            "january": 1, "february": 2, "march": 3, "april": 4, "may": 5,
            "june": 6, "july": 7, "august": 8, "september": 9,
            "october": 10, "november": 11, "december": 12,
        }
        detected_month = None
        for name, num in MONTH_NAMES.items():
            if re.search(rf'\b{name}\b', msg_lower):
                detected_month = num
                break
        history_keywords = [
            "average", "historical", "history", "trend", "last 10 years",
            "past years", "usually", "typically", "over the years",
            "compared to", "climate", "पिछले", "औसत", "इतिहास"
        ]
        years_match = re.search(r'last\s+(\d{1,2})\s+years?', msg_lower)
        is_climate_trend_query = detected_month is not None and (
            any(w in msg_lower for w in history_keywords) or years_match is not None
        )
        detected_years_back = int(years_match.group(1)) if years_match else None

        if is_climate_trend_query:
            all_intents.append("CLIMATE_TREND")
        if is_pure_greeting and not is_rain_query and not is_travel_query and not is_farming_query and not is_temp_query and not is_climate_trend_query:
            all_intents.append("GREETING")
        if is_farming_query:
            all_intents.append("FARMER_ASSISTANCE")
        if is_travel_query:
            all_intents.append("TRAVEL_PLANNING")
        if is_rain_query and "TRAVEL_PLANNING" not in all_intents and "FARMER_ASSISTANCE" not in all_intents:
            all_intents.append("RAIN_CHECK")
        elif is_rain_query:
            all_intents.append("RAIN_CHECK")
        if is_temp_query:
            all_intents.append("TEMPERATURE_QUERY")

        if time_range == "day_after_tomorrow" and not all_intents:
            all_intents.append("DAY_AFTER_TOMORROW_FORECAST")
        elif time_range == "tomorrow" and not all_intents:
            all_intents.append("TOMORROW_FORECAST")
        elif time_range == "7_days" and not all_intents:
            all_intents.append("MULTI_DAY_FORECAST")
        elif time_range in ["hourly", "evening", "morning", "night", "afternoon", "today"] and not all_intents:
            all_intents.append("HOURLY_TIMELINE")

        if not all_intents:
            all_intents.append("CURRENT_WEATHER")

        primary_intent = all_intents[0]
        secondary_intents = all_intents[1:] if len(all_intents) > 1 else []

        return ParsedQuery(
            original_message=msg,
            primary_intent=primary_intent,
            secondary_intents=secondary_intents,
            location=extracted_location,
            time_range=time_range,
            activity=detected_activity,
            crop=detected_crop or "general",
            metrics_requested=metrics,
            language_hint=language_hint,
            target_month=detected_month if is_climate_trend_query else None,
            years_back=detected_years_back,
        )


query_parser = QueryUnderstandingService()
