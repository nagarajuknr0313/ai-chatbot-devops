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
        client = OpenAI(api_key=settings.openai_api_key)
        logger.info("OpenAI client initialized successfully")
        return True
    except Exception as e:
        logger.error(f"Failed to initialize OpenAI client: {e}")
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
    
    # Use mock response if OpenAI is not available or API key not set
    if not client or not OPENAI_AVAILABLE:
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
        return {
            "content": "I'm temporarily rate limited. Please try again in a moment.",
            "model": "gpt-3.5-turbo",
            "error": "rate_limit"
        }
    
    except APIError as e:
        logger.error(f"OpenAI API error: {e}")
        return {
            "content": f"API Error: {str(e)}",
            "model": "gpt-3.5-turbo",
            "error": "api_error"
        }
    
    except Exception as e:
        logger.error(f"Unexpected error calling OpenAI: {e}")
        return {
            "content": "An unexpected error occurred. Please try again.",
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
