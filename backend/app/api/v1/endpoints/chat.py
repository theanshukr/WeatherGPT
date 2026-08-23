import logging
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.schemas.chat import (
    ChatMessageRequest,
    ChatMessageResponse,
    SessionContextResponse,
)
from app.services.llm.service_factory import get_llm_service
from app.services.llm.context_manager import context_manager
from app.models.chat import ChatSession, ChatMessage

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("", response_model=ChatMessageResponse, tags=["Chat"])
@router.post("/", response_model=ChatMessageResponse, tags=["Chat"])
@router.post("/message", response_model=ChatMessageResponse, tags=["Chat"])
async def send_chat_message(
    payload: ChatMessageRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Process incoming user prompt using Hybrid Conversational Engine:
    1. Retrieve Session Context (Redis / Local)
    2. Multi-intent & Entity Understanding (Location, Time, Activity, Crop)
    3. Tool Orchestrator & Deterministic Advisory Engines (Travel / Farming / Risk)
    4. Grounded Multilingual Response Generation (Explain Only)
    5. Context & Memory Update
    """
    try:
        llm_service = get_llm_service()
        response = await llm_service.process_chat(payload)

        # Persist conversation to database if session & DB are available
        if db is not None:
            try:
                session = None
                if payload.session_id:
                    session = await db.get(ChatSession, payload.session_id)

                if not session:
                    session = ChatSession(
                        id=response.session_id,
                        user_id=payload.user_id,
                        title=payload.message[:30] + ("..." if len(payload.message) > 30 else ""),
                    )
                    db.add(session)
                    await db.flush()

                # Record user message
                user_msg = ChatMessage(
                    session_id=session.id,
                    sender="user",
                    text=payload.message,
                    language=payload.language or "en",
                )
                db.add(user_msg)

                # Record AI response
                ai_msg = ChatMessage(
                    session_id=session.id,
                    sender="ai",
                    text=response.response,
                    language=response.language,
                    intent=response.primary_intent,
                    persona_applied=response.persona_applied,
                    tools_called=response.tools_called,
                    weather_data_snapshot=response.weather_data.model_dump() if response.weather_data else None,
                )
                db.add(ai_msg)
                await db.commit()
            except Exception as dbe:
                logger.warning(f"Database save chat message failed: {dbe}")
                await db.rollback()

        return response
    except Exception as e:
        # Log the real error for debugging, but never surface a raw
        # exception/500 to the user — that's what makes the assistant feel
        # "technical" instead of like a friend when something upstream
        # (Gemini, weather API, etc.) hiccups. Respond in-character instead.
        logger.error(f"Chat processing error: {e}", exc_info=True)
        fallback_text = (
            "माफ़ कीजिए, अभी मुझे जवाब देने में थोड़ी दिक्कत हो रही है 🙏 "
            "कृपया थोड़ी देर बाद फिर से पूछें।"
            if (payload.language or "en").startswith("hi")
            else "Sorry, I'm having a little trouble answering right now 🙏 "
                 "Please try asking again in a moment."
        )
        return ChatMessageResponse(
            session_id=payload.session_id or "error_session",
            response=fallback_text,
            language=payload.language or "en",
            primary_intent="ERROR",
            persona_applied=payload.persona or "general",
            risk_level="LOW",
            tools_called=[],
            suggestions=["Delhi weather today", "Kal baarish hogi kya?"],
        )


@router.get("/sessions/{session_id}/context", response_model=SessionContextResponse, tags=["Chat"])
async def get_session_context(session_id: str):
    """Retrieve active session context (active location, persona, recent intent, time ref)."""
    ctx = await context_manager.get_context(session_id)
    return SessionContextResponse(
        session_id=ctx.session_id,
        active_location=ctx.active_location.model_dump() if ctx.active_location else None,
        persona=ctx.persona,
        language=ctx.language,
        recent_intent=ctx.recent_intent,
        secondary_intents=ctx.secondary_intents,
        recent_time_reference=ctx.recent_time_reference,
        conversation_summary=ctx.conversation_summary,
        history_count=len(ctx.history),
        updated_at=ctx.updated_at,
    )


@router.get("/sessions/{session_id}/history", tags=["Chat"])
async def get_session_history(
    session_id: str,
    limit: int = Query(20, description="Max messages to retrieve"),
    db: AsyncSession = Depends(get_db),
):
    """Retrieve persistent conversation history for the session from PostgreSQL or Context Memory."""
    if db is not None:
        try:
            stmt = (
                select(ChatMessage)
                .where(ChatMessage.session_id == session_id)
                .order_by(ChatMessage.created_at.asc())
                .limit(limit)
            )
            res = await db.execute(stmt)
            messages = res.scalars().all()
            if messages:
                return [
                    {
                        "id": m.id,
                        "sender": m.sender,
                        "text": m.text,
                        "language": m.language,
                        "intent": m.intent,
                        "created_at": m.created_at.isoformat() if m.created_at else None,
                    }
                    for m in messages
                ]
        except Exception as e:
            logger.warning(f"Failed to fetch history from DB: {e}")

    # Fallback to context manager rolling history
    ctx = await context_manager.get_context(session_id)
    return ctx.history


@router.delete("/sessions/{session_id}", tags=["Chat"])
async def clear_session_context(session_id: str):
    """Clear active session context and memory."""
    success = await context_manager.clear_context(session_id)
    return {"status": "success", "session_id": session_id, "cleared": success}
