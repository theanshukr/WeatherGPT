import logging
import asyncio
from datetime import datetime
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import httpx
from app.core.config import settings
from app.core.database import init_db
from app.core.redis import redis_manager
from app.api.v1.api import api_router
from app.api.v1.endpoints.voice_websocket import manager as ws_manager
from app.services.alerts.alert_poller import alert_poller

# Configure logging
logging.basicConfig(
    level=logging.INFO if not settings.DEBUG else logging.DEBUG,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

keep_alive_task = None


async def _self_keep_alive_loop():
    """Background keep-alive loop to prevent Render free-tier 15-minute sleep."""
    await asyncio.sleep(60)  # Initial delay
    while True:
        try:
            # Ping internal health endpoint every 9 minutes (540 seconds)
            async with httpx.AsyncClient(timeout=10.0) as client:
                await client.get(f"http://127.0.0.1:{settings.PORT}/health")
                logger.debug("Keep-alive self-ping sent successfully.")
        except Exception:
            pass
        await asyncio.sleep(540)


@asynccontextmanager
async def lifespan(app: FastAPI):
    global keep_alive_task
    # Startup
    logger.info(f"Starting {settings.PROJECT_NAME}...")
    await init_db()
    await redis_manager.connect()
    alert_poller.start(ws_manager.broadcast)
    keep_alive_task = asyncio.create_task(_self_keep_alive_loop())
    yield
    # Shutdown
    logger.info(f"Shutting down {settings.PROJECT_NAME}...")
    if keep_alive_task:
        keep_alive_task.cancel()
    alert_poller.stop()
    await redis_manager.close()


app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan,
)

# Open CORS for Web, Mobile App & Production Cloud
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API Router
app.include_router(api_router, prefix=settings.API_V1_STR)


@app.api_route("/", methods=["GET", "HEAD"])
def root():
    return {
        "message": "Welcome to WeatherGPT API",
        "docs": "/docs",
        "health": "/health",
        "api_health": f"{settings.API_V1_STR}/health",
    }


@app.api_route("/health", methods=["GET", "HEAD"], tags=["System"])
@app.api_route("/ping", methods=["GET", "HEAD"], tags=["System"])
async def health_ping():
    """Ultra-lightweight ping endpoint for 24/7 keep-alive monitors (UptimeRobot, Render Health Check)."""
    return {
        "status": "healthy",
        "alive": True,
        "service": settings.PROJECT_NAME,
        "database": "connected",
        "timestamp": datetime.utcnow().isoformat(),
    }
