"""
Database configuration and session management
"""

from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
import logging

from app.config import settings

logger = logging.getLogger(__name__)

# Create base class for models
Base = declarative_base()

# Database engine
engine = None
AsyncSessionLocal = None


async def init_db():
    """Initialize database connection"""
    global engine, AsyncSessionLocal
    
    try:
        # Create async engine
        engine = create_async_engine(
            settings.database_url.replace("postgresql://", "postgresql+asyncpg://"),
            echo=settings.debug,
            future=True
        )
        
        # Create session factory
        AsyncSessionLocal = sessionmaker(
            engine,
            class_=AsyncSession,
            expire_on_commit=False
        )
        
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")
        raise


async def get_db():
    """Get database session"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
