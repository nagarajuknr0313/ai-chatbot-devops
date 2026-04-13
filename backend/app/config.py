"""
Configuration module for FastAPI application
Loads settings from environment variables using Pydantic Settings
"""

from typing import List
from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""
    
    # Backend Configuration
    backend_host: str = Field("0.0.0.0", alias="BACKEND_HOST")
    backend_port: int = Field(8000, alias="BACKEND_PORT")
    backend_env: str = Field("development", alias="BACKEND_ENV")
    
    # Database Configuration
    database_url: str = Field("postgresql://localhost/chatbot", alias="DATABASE_URL")
    
    # Security
    secret_key: str = Field("dev-secret-key", alias="SECRET_KEY")
    debug: bool = Field(False, alias="DEBUG")
    allowed_hosts: List[str] = Field(["localhost", "127.0.0.1"], alias="ALLOWED_HOSTS")
    
    # CORS
    cors_origins: List[str] = Field(
        ["http://localhost:3000", "http://localhost:5173"],
        alias="CORS_ORIGINS"
    )
    
    # API Configuration
    openai_api_key: str = Field("", alias="OPENAI_API_KEY")
    use_mock_ai: bool = Field(True, alias="USE_MOCK_AI")
    
    # Rate Limiting
    rate_limit: str = Field("100/minute", alias="RATE_LIMIT")
    
    # JWT Configuration
    jwt_algorithm: str = Field("HS256", alias="JWT_ALGORITHM")
    jwt_expiration_hours: int = Field(24, alias="JWT_EXPIRATION_HOURS")
    
    # Logging
    log_level: str = Field("INFO", alias="LOG_LEVEL")
    log_format: str = Field("json", alias="LOG_FORMAT")
    
    class Config:
        env_file = ".env"
        case_sensitive = False


# Create global settings instance
settings = Settings()
