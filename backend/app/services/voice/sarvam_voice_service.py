import logging
import httpx
import base64
from typing import Optional, Dict, Any
from app.core.config import settings

logger = logging.getLogger(__name__)


class SarvamVoiceService:
    """
    Sarvam AI Voice Integration for Indic Speech-to-Text (saaras:v1)
    and Text-to-Speech (bulbul:v1).
    """

    # SINGLE SOURCE OF TRUTH for the assistant's voice. Every caller in this
    # codebase (chat auto-TTS, the /voice/tts endpoint, the voice pipeline)
    # must resolve down to this constant unless the user has explicitly
    # picked a different speaker. This prevents the male/female voice from
    # flip-flopping between requests because of mismatched hardcoded
    # defaults scattered across files.
    # NOTE: speakers are NOT interchangeable between bulbul model versions.
    # "anushka" is valid for bulbul:v2 (used below). If DEFAULT_TTS_MODEL is
    # ever changed to bulbul:v3/v3-beta, this must change too (v3 default is
    # "shubh" for male / "ritu" for female — anushka does not exist on v3).
    DEFAULT_TTS_MODEL = "bulbul:v2"
    DEFAULT_SPEAKER = "anushka"
    DEFAULT_PITCH = 0.35  # Sweet, cheerful, youthful girl voice tone
    DEFAULT_PACE = 1.04   # Lively, friendly conversational rhythm
    DEFAULT_LOUDNESS = 1.6

    def __init__(self):
        self.api_key = settings.SARVAM_API_KEY
        self.base_url = "https://api.sarvam.ai"

    async def speech_to_text(
        self,
        audio_bytes: bytes,
        filename: str = "audio.wav",
        language_code: str = "hi-IN",
        model: str = "saaras:v1",
    ) -> Dict[str, Any]:
        """Convert spoken audio bytes to text using Sarvam STT API."""
        if not self.api_key:
            logger.warning("SARVAM_API_KEY not configured for STT.")
            return {
                "transcript": "",
                "language_code": language_code,
                "confidence": 0.0,
                "status": "api_key_missing",
                "message": "Sarvam API Key not set in backend .env",
            }

        headers = {
            "api-subscription-key": self.api_key,
        }

        files = {
            "file": (filename, audio_bytes, "audio/wav"),
        }
        data = {
            "model": model,
            "language_code": language_code,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.base_url}/speech-to-text",
                    headers=headers,
                    files=files,
                    data=data,
                )
                if response.status_code == 200:
                    result = response.json()
                    transcript = result.get("transcript", "")
                    detected_lang = result.get("language_code", language_code)
                    return {
                        "transcript": transcript,
                        "language_code": detected_lang,
                        "confidence": result.get("confidence", 0.95),
                        "status": "success",
                    }
                else:
                    logger.error(f"Sarvam STT Error {response.status_code}: {response.text}")
                    return {
                        "transcript": "",
                        "language_code": language_code,
                        "status": "error",
                        "error": f"STT API returned {response.status_code}",
                    }
        except Exception as e:
            logger.error(f"Sarvam STT Exception: {e}")
            return {
                "transcript": "",
                "language_code": language_code,
                "status": "error",
                "error": str(e),
            }

    async def text_to_speech(
        self,
        text: str,
        target_language_code: str = "hi-IN",
        speaker: Optional[str] = None,
        pitch: Optional[float] = None,
        pace: Optional[float] = None,
        loudness: Optional[float] = None,
        model: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Convert response text to natural sweet young girl voice audio using Sarvam TTS API."""
        resolved_model = model or self.DEFAULT_TTS_MODEL
        resolved_speaker = speaker or self.DEFAULT_SPEAKER
        resolved_pitch = pitch if pitch is not None else self.DEFAULT_PITCH
        resolved_pace = pace if pace is not None else self.DEFAULT_PACE
        resolved_loudness = loudness if loudness is not None else self.DEFAULT_LOUDNESS

        if not self.api_key:
            logger.warning("SARVAM_API_KEY not configured for TTS.")
            return {
                "audio_base64": None,
                "language_code": target_language_code,
                "status": "api_key_missing",
                "message": "Sarvam API Key not set in backend .env",
            }

        headers = {
            "api-subscription-key": self.api_key,
            "Content-Type": "application/json",
        }

        # Remove asterisks / markdown formatting before sending to TTS for clean speech
        clean_text = text.replace("**", "").replace("*", "").replace("#", "").replace("•", "").strip()

        # Split into natural sentence chunks under 500 chars to avoid truncation
        import re
        inputs = []
        if len(clean_text) <= 500:
            inputs = [clean_text]
        else:
            sentences = re.split(r'([।!?.\n]+)', clean_text)
            cur = ""
            for i in range(0, len(sentences), 2):
                s = sentences[i]
                delim = sentences[i + 1] if i + 1 < len(sentences) else ""
                part = (s + delim).strip()
                if not part:
                    continue
                if len(cur) + len(part) + 1 <= 480:
                    cur = f"{cur} {part}".strip()
                else:
                    if cur:
                        inputs.append(cur)
                    cur = part
            if cur:
                inputs.append(cur)
            if not inputs:
                inputs = [clean_text[:500]]

        payload = {
            "inputs": inputs,
            "target_language_code": target_language_code,
            "speaker": resolved_speaker,
            "pitch": pitch,
            "pace": pace,
            "loudness": loudness,
            "speech_sample_rate": 22050,
            "enable_preprocessing": True,
            "model": resolved_model,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.base_url}/text-to-speech",
                    headers=headers,
                    json=payload,
                )
                if response.status_code == 200:
                    result = response.json()
                    audios = result.get("audios", [])
                    audio_b64 = audios[0] if len(audios) == 1 else None
                    return {
                        "audio_base64": audio_b64,
                        "audio_chunks": audios,
                        "language_code": target_language_code,
                        "speaker": resolved_speaker,
                        "status": "success",
                    }
                else:
                    logger.error(f"Sarvam TTS Error {response.status_code}: {response.text}")
                    return {
                        "audio_base64": None,
                        "language_code": target_language_code,
                        "status": "error",
                        "error": f"TTS API returned {response.status_code}",
                    }
        except Exception as e:
            logger.error(f"Sarvam TTS Exception: {e}")
            return {
                "audio_base64": None,
                "language_code": target_language_code,
                "status": "error",
                "error": str(e),
            }


sarvam_voice_service = SarvamVoiceService()
