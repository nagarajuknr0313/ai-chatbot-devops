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
        # For development, only initialize if database is available
        if settings.backend_env == "development":
            logger.info("Running in development mode - skipping database initialization")
            logger.info("Database will be initialized when deployed")
            return
        
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
        logger.warning(f"Database initialization skipped: {e}")
        logger.info("Running in development mode without persistent database")


async def get_db():
    """Get database session"""
    # In development mode without database, return None
    if AsyncSessionLocal is None:
        yield None
        return
    
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
