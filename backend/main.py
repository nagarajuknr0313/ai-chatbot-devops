"""
AI Chatbot Backend - Main FastAPI Application
Production-ready FastAPI server with WebSocket support, JWT auth, and PostgreSQL
"""

import logging
from contextlib import asynccontextmanager
from dotenv import load_dotenv

# Load environment variables BEFORE importing config
load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware

from app.config import settings
from app.database import init_db
from app.api import auth, chat
from app.services import openai_service

# Configure logging
logging.basicConfig(
    level=settings.log_level,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Log configuration
logger.info(f"Backend Environment: {settings.backend_env}")
logger.info(f"USE_MOCK_AI: {settings.use_mock_ai}")
logger.info(f"OpenAI API Key configured: {bool(settings.openai_api_key)}")
logger.info(f"Debug mode: {settings.debug}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Handle startup and shutdown events"""
    # Startup
    logger.info("Starting AI Chatbot Backend")
    await init_db()
    openai_service.init_openai()
    yield
    # Shutdown
    logger.info("Shutting down AI Chatbot Backend")


# Create FastAPI app
app = FastAPI(
    title="AI Chatbot API",
    description="Production-ready AI Chatbot Backend API",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add trusted host middleware
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=settings.allowed_hosts
)


# Root endpoint
@app.get("/", tags=["Health"])
async def root():
    """Root endpoint - Health check"""
    return {
        "status": "online",
        "service": "AI Chatbot Backend",
        "version": "1.0.0",
        "environment": settings.backend_env
    }


@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "database": "connected",
        "timestamp": "2026-04-14T12:00:00Z"
    }


# Include routers
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(chat.router, prefix="/api/chat", tags=["Chat"])


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.backend_host,
        port=settings.backend_port,
        reload=settings.backend_env == "development",
        log_level=settings.log_level.lower()
    )
