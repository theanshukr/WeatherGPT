import logging
import base64
from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from pydantic import BaseModel
from app.services.voice.sarvam_voice_service import sarvam_voice_service
from app.services.llm.service_factory import get_llm_service
from app.schemas.chat import ChatMessageRequest, ChatMessageResponse

logger = logging.getLogger(__name__)
router = APIRouter()


class TTSRequest(BaseModel):
    text: str
    language_code: Optional[str] = "hi-IN"
    # Left unset by default on purpose: sarvam_voice_service.text_to_speech
    # resolves the real default (DEFAULT_SPEAKER) itself. Only pass a value
    # here if the caller genuinely wants to override the assistant's voice.
    speaker: Optional[str] = None


class STTResponse(BaseModel):
    transcript: str
    language_code: str
    confidence: Optional[float] = 1.0
    status: str
    message: Optional[str] = None


class VoiceChatResponse(BaseModel):
    transcript: str
    response_text: str
    audio_base64: Optional[str] = None
    weather_data: Optional[dict] = None
    travel_assessment: Optional[dict] = None
    farming_advisory: Optional[dict] = None
    risk_level: Optional[str] = None
    suggestions: list[str] = []


@router.post("/stt", response_model=STTResponse)
async def speech_to_text_endpoint(
    file: UploadFile = File(...),
    language_code: str = Form("hi-IN"),
):
    """
    Speech-to-Text: Convert user's spoken audio (WAV, MP3, WEBM)
    into transcribed text (Hindi, Hinglish, Indic languages).
    """
    audio_bytes = await file.read()
    res = await sarvam_voice_service.speech_to_text(
        audio_bytes=audio_bytes,
        filename=file.filename or "audio.wav",
        language_code=language_code,
    )
    return STTResponse(**res)


@router.post("/tts")
async def text_to_speech_endpoint(req: TTSRequest):
    """
    Text-to-Speech: Synthesize natural conversational speech audio from response text.
    """
    res = await sarvam_voice_service.text_to_speech(
        text=req.text,
        target_language_code=req.language_code or "hi-IN",
        speaker=req.speaker,  # None -> service applies the single default voice
    )
    return res


@router.post("/chat", response_model=VoiceChatResponse)
async def voice_chat_pipeline(
    file: UploadFile = File(...),
    session_id: str = Form(...),
    user_id: str = Form(...),
    persona: str = Form("general"),
    language_code: str = Form("hi-IN"),
):
    """
    End-to-End Voice Assistant Pipeline:
    1. User Audio -> Speech-to-Text
    2. Transcribed Query -> WeatherGPT AI (Meteorological Tools + Gemini)
    3. AI Response Text -> Text-to-Speech
    4. Returns Audio + Text + Meteorological Cards
    """
    audio_bytes = await file.read()
    
    # 1. Speech-to-Text
    stt_res = await sarvam_voice_service.speech_to_text(
        audio_bytes=audio_bytes,
        filename=file.filename or "audio.wav",
        language_code=language_code,
    )
    transcript = stt_res.get("transcript", "").strip()

    if not transcript:
        # Fallback if audio transcription failed or no key
        return VoiceChatResponse(
            transcript="",
            response_text="माफ कीजिए, आपकी आवाज़ स्पष्ट रूप से सुनाई नहीं दी। कृपया दोबारा बोलें या टेक्स्ट में लिखें।",
            audio_base64=None,
            suggestions=["Delhi weather today", "Kal baarish hogi kya?"]
        )

    # 2. Process query with WeatherGPT LLM + live weather tools
    chat_req = ChatMessageRequest(
        message=transcript,
        session_id=session_id,
        user_id=user_id,
        persona=persona,
        language="hi" if "hi" in language_code else "en",
    )

    llm_service = get_llm_service()
    chat_resp: ChatMessageResponse = await llm_service.process_chat(chat_req)

    # 3. Text-to-Speech
    tts_res = await sarvam_voice_service.text_to_speech(
        text=chat_resp.response,
        target_language_code=language_code,
    )

    return VoiceChatResponse(
        transcript=transcript,
        response_text=chat_resp.response,
        audio_base64=tts_res.get("audio_base64"),
        weather_data=chat_resp.weather_data.model_dump() if chat_resp.weather_data else None,
        travel_assessment=chat_resp.travel_assessment.model_dump() if chat_resp.travel_assessment else None,
        farming_advisory=chat_resp.farming_advisory.model_dump() if chat_resp.farming_advisory else None,
        risk_level=chat_resp.risk_level,
        suggestions=chat_resp.suggestions,
    )
