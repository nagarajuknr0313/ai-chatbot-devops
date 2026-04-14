"""
Configuration module for FastAPI application
Loads settings from environment variables using Pydantic Settings
"""

from typing import List
from pathlib import Path
from pydantic_settings import BaseSettings
from pydantic import Field

# Get the path to the .env file (in project root, one level up from backend)
ENV_FILE = Path(__file__).parent.parent.parent / ".env"


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
    allowed_hosts_str: str = Field("localhost,127.0.0.1", alias="ALLOWED_HOSTS")
    
    # CORS
    cors_origins_str: str = Field(
        "http://localhost:3000,http://localhost:5173",
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
        env_file = str(ENV_FILE)
        case_sensitive = False
        extra = "ignore"  # Ignore extra environment variables
    
    @property
    def allowed_hosts(self) -> list:
        """Parse allowed hosts from comma-separated string"""
        return [h.strip() for h in self.allowed_hosts_str.split(",")]
    
    @property
    def cors_origins(self) -> list:
        """Parse CORS origins from comma-separated string"""
        return [o.strip() for o in self.cors_origins_str.split(",")]


# Create global settings instance


# Create global settings instance
settings = Settings()
