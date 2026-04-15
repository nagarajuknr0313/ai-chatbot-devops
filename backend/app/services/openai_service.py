"""
OpenAI integration for AI chatbot
Handles communication with OpenAI GPT models
"""

import logging
from typing import Optional
from app.config import settings

logger = logging.getLogger(__name__)

try:
    from openai import OpenAI, APIError, RateLimitError
    import httpx
    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False
    logger.warning("OpenAI SDK not installed. Install with: pip install openai")

# Initialize OpenAI client
client: Optional[OpenAI] = None

def init_openai():
    """Initialize OpenAI client if API key is available"""
    global client
    
    if not settings.openai_api_key:
        logger.info("OpenAI API key not configured - using mock responses")
        return False
    
    if not OPENAI_AVAILABLE:
        logger.warning("OpenAI SDK not available")
        return False
    
    try:
        logger.info(f"Initializing OpenAI client with API key: {settings.openai_api_key[:20]}...")
        # Initialize with custom httpx client to avoid proxy parameter issues
        http_client = httpx.Client(
            verify=True,
            limits=httpx.Limits(max_connections=100, max_keepalive_connections=20)
        )
        client = OpenAI(api_key=settings.openai_api_key, http_client=http_client)
        logger.info("OpenAI client initialized successfully")
        return True
    except Exception as e:
        logger.error(f"Failed to initialize OpenAI client: {type(e).__name__}: {e}")
        logger.warning("Falling back to mock AI responses")
        return False


async def get_ai_response(user_message: str, conversation_context: Optional[list] = None) -> dict:
    """
    Get AI response from OpenAI GPT model
    
    Args:
        user_message: The user's message
        conversation_context: Optional conversation history for context
    
    Returns:
        Dictionary with response text and metadata
    """
    
    # Use mock response if configured or OpenAI is not available
    if settings.use_mock_ai or not client or not OPENAI_AVAILABLE:
        return {
            "content": "Mock AI response (OpenAI not configured). Configure OPENAI_API_KEY to enable real AI responses.",
            "model": "mock",
            "usage": {
                "prompt_tokens": 0,
                "completion_tokens": 0,
                "total_tokens": 0
            }
        }
    
    try:
        # Build message history
        messages = []
        
        # Add system message
        messages.append({
            "role": "system",
            "content": "You are a helpful AI assistant. Provide concise, clear, and accurate responses."
        })
        
        # Add conversation context if provided
        if conversation_context:
            messages.extend(conversation_context)
        
        # Add current user message
        messages.append({
            "role": "user",
            "content": user_message
        })
        
        # Call OpenAI API
        logger.info(f"Calling OpenAI API with message: {user_message[:50]}...")
        
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",  # or "gpt-4" for better quality
            messages=messages,
            temperature=0.7,
            max_tokens=500,
            top_p=0.9
        )
        
        # Extract response
        ai_content = response.choices[0].message.content
        
        logger.info(f"OpenAI response received: {ai_content[:50]}...")
        
        return {
            "content": ai_content,
            "model": response.model,
            "usage": {
                "prompt_tokens": response.usage.prompt_tokens,
                "completion_tokens": response.usage.completion_tokens,
                "total_tokens": response.usage.total_tokens
            }
        }
    
    except RateLimitError as e:
        logger.warning(f"OpenAI rate limit exceeded: {e}")
        error_msg = str(e)
        
        # Check for quota errors
        if "insufficient_quota" in error_msg or "quota" in error_msg or "billing" in error_msg:
            return {
                "content": "⚠️ Service temporarily unavailable. The Open API account has reached its usage limit. Please check your billing details.",
                "model": "gpt-3.5-turbo",
                "error": "quota_exceeded"
            }
        
        return {
            "content": "⏳ Service is busy right now. Please try again in a moment.",
            "model": "gpt-3.5-turbo",
            "error": "rate_limit"
        }
    
    except APIError as e:
        logger.error(f"OpenAI API error: {type(e).__name__}: {e}")
        error_msg = str(e)
        
        # Handle specific error scenarios
        if "invalid_api_key" in error_msg or "authentication" in error_msg:
            return {
                "content": "❌ Authentication error. The API credentials are invalid.",
                "model": "gpt-3.5-turbo",
                "error": "auth_error"
            }
        elif "invalid_request" in error_msg:
            return {
                "content": "❌ Request error. Please try rephrasing your question.",
                "model": "gpt-3.5-turbo",
                "error": "invalid_request"
            }
        elif "server_error" in error_msg or "500" in error_msg:
            return {
                "content": "❌ OpenAI service is currently experiencing issues. Please try again later.",
                "model": "gpt-3.5-turbo",
                "error": "server_error"
            }
        elif "insufficient_quota" in error_msg or "quota" in error_msg or "billing" in error_msg:
            return {
                "content": "⚠️ Service temporarily unavailable. The API account has reached its usage limit. Please check your billing details.",
                "model": "gpt-3.5-turbo",
                "error": "quota_exceeded"
            }
        
        return {
            "content": "❌ An error occurred while processing your request. Please try again.",
            "model": "gpt-3.5-turbo",
            "error": "api_error"
        }
    
    except Exception as e:
        logger.error(f"Unexpected error calling OpenAI: {type(e).__name__}: {e}")
        return {
            "content": "❌ An unexpected error occurred. Please try again.",
            "model": "unknown",
            "error": "unexpected_error"
        }


async def generate_conversation_title(messages: list) -> str:
    """
    Generate a title for a conversation based on initial messages
    
    Args:
        messages: List of messages in conversation
    
    Returns:
        Generated title string
    """
    
    if not client or not OPENAI_AVAILABLE or len(messages) == 0:
        return "New Conversation"
    
    try:
        first_message = messages[0].get("content", "")[:100]
        
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {
                    "role": "system",
                    "content": "Generate a short, concise title (max 5 words) for a conversation based on the first message. Return only the title, nothing else."
                },
                {
                    "role": "user",
                    "content": first_message
                }
            ],
            temperature=0.5,
            max_tokens=20
        )
        
        return response.choices[0].message.content.strip()
    
    except Exception as e:
        logger.warning(f"Failed to generate title: {e}")
        return "New Conversation"
