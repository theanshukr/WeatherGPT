from fastapi import APIRouter
from app.api.v1.endpoints import health, chat, weather, user, voice, ws, auth

api_router = APIRouter()

api_router.include_router(health.router, prefix="", tags=["System"])
api_router.include_router(auth.router, prefix="/auth", tags=["Supabase Auth"])
api_router.include_router(chat.router, prefix="/chat", tags=["Chat"])
api_router.include_router(weather.router, prefix="/weather", tags=["Weather"])
api_router.include_router(user.router, prefix="/user", tags=["User Intelligence & Personalization"])
api_router.include_router(voice.router, prefix="/voice", tags=["Voice Assistant"])
api_router.include_router(ws.router, prefix="/ws", tags=["WebSocket Real-Time Gateway"])
