import logging
import asyncio
import json
from typing import List
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from app.services.llm.service_factory import get_llm_service
from app.schemas.chat import ChatMessageRequest

logger = logging.getLogger(__name__)
router = APIRouter()


class ConnectionManager:
    """Manages active WebSocket connections for live alert broadcasting."""
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"WebSocket client connected. Active connections: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
            logger.info(f"WebSocket client disconnected. Active connections: {len(self.active_connections)}")

    async def broadcast(self, message: dict):
        """Broadcast real-time emergency disaster warning to all connected clients."""
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except Exception as e:
                logger.error(f"Error broadcasting to client: {e}")


manager = ConnectionManager()


@router.websocket("/live")
async def websocket_live_chat(websocket: WebSocket):
    """
    WebSocket endpoint for real-time bi-directional chat, 
    live weather updates, and instant extreme weather warnings.
    """
    await manager.connect(websocket)
    try:
        # Send initial connected handshake
        await websocket.send_json({
            "type": "connection_established",
            "message": "Connected to WeatherGPT Real-Time WebSocket Gateway"
        })

        while True:
            data_text = await websocket.receive_text()
            try:
                data = json.loads(data_text)
                msg_type = data.get("type", "chat")

                if msg_type == "chat":
                    user_message = data.get("message", "")
                    session_id = data.get("session_id", "ws_session")
                    user_id = data.get("user_id", "ws_user")
                    persona = data.get("persona", "general")
                    language = data.get("language", "hi")

                    # Process through WeatherGPT LLM Engine
                    chat_req = ChatMessageRequest(
                        message=user_message,
                        session_id=session_id,
                        user_id=user_id,
                        persona=persona,
                        language=language
                    )
                    llm_service = get_llm_service()
                    chat_resp = await llm_service.process_chat(chat_req)

                    # Send back real-time response packet
                    await websocket.send_json({
                        "type": "chat_response",
                        "response": chat_resp.response,
                        "weather_data": chat_resp.weather_data.model_dump() if chat_resp.weather_data else None,
                        "travel_assessment": chat_resp.travel_assessment.model_dump() if chat_resp.travel_assessment else None,
                        "farming_advisory": chat_resp.farming_advisory.model_dump() if chat_resp.farming_advisory else None,
                        "risk_level": chat_resp.risk_level,
                        "suggestions": chat_resp.suggestions
                    })

                elif msg_type == "ping":
                    await websocket.send_json({"type": "pong"})

            except json.JSONDecodeError:
                await websocket.send_json({"type": "error", "message": "Invalid JSON format"})

    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        manager.disconnect(websocket)
