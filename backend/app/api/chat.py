"""
Chat API endpoints
Handles message streaming, WebSocket connections, and conversation management
"""

from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, WebSocket, status
from pydantic import BaseModel
import logging
import asyncio

from app.config import settings
from app.database import get_db
from app.services import openai_service

logger = logging.getLogger(__name__)

router = APIRouter()


# Pydantic Models
class MessageRequest(BaseModel):
    """Chat message request"""
    content: str
    conversation_id: Optional[int] = None
    
    class Config:
        json_schema_extra = {
            "example": {
                "content": "Hello, how can you help me?",
                "conversation_id": 1
            }
        }


class MessageResponse(BaseModel):
    """Chat message response"""
    id: int
    content: str
    role: str  # "user" or "assistant"
    timestamp: datetime
    conversation_id: int
    
    class Config:
        json_schema_extra = {
            "example": {
                "id": 1,
                "content": "I'm an AI chatbot here to help you...",
                "role": "assistant",
                "timestamp": "2026-04-14T12:00:00Z",
                "conversation_id": 1
            }
        }
        from_attributes = True


class ConversationResponse(BaseModel):
    """Conversation response"""
    id: int
    title: str
    created_at: datetime
    updated_at: datetime
    message_count: int
    
    class Config:
        from_attributes = True


# Chat endpoints
@router.post("/message", response_model=MessageResponse)
async def send_message(message: MessageRequest, db = Depends(get_db)):
    """
    Send a chat message and get AI response
    
    **Request body:**
    - `content`: Message content
    - `conversation_id`: Optional conversation ID
    
    **Returns:** AI response message
    """
    logger.info(f"Message received: {message.content[:50]}...")
    
    try:
        # Get AI response using OpenAI service
        ai_response = await openai_service.get_ai_response(message.content)
        
        response = {
            "id": 1,
            "content": ai_response.get("content"),
            "role": "assistant",
            "timestamp": datetime.utcnow(),
            "conversation_id": message.conversation_id or 1
        }
        
        logger.info(f"AI response generated: {ai_response.get('model', 'unknown')}")
        return response
        
    except Exception as e:
        logger.error(f"Error generating AI response: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error generating response: {str(e)}"
        )


@router.get("/conversations", response_model=List[ConversationResponse])
async def list_conversations(db = Depends(get_db)):
    """
    List all conversations for current user
    
    **Returns:** List of conversations
    """
    logger.info("Fetching conversations")
    
    # TODO: Implement database query
    return [
        {
            "id": 1,
            "title": "First Conversation",
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
            "message_count": 5
        }
    ]


@router.get("/conversations/{conversation_id}", response_model=List[MessageResponse])
async def get_conversation(conversation_id: int, db = Depends(get_db)):
    """
    Get all messages in a conversation
    
    **Path parameters:**
    - `conversation_id`: Conversation ID
    
    **Returns:** List of messages
    """
    logger.info(f"Fetching conversation {conversation_id}")
    
    # TODO: Implement database query
    return [
        {
            "id": 1,
            "content": "User message",
            "role": "user",
            "timestamp": datetime.utcnow(),
            "conversation_id": conversation_id
        }
    ]


@router.post("/conversations", response_model=ConversationResponse, status_code=status.HTTP_201_CREATED)
async def create_conversation(title: str = None, db = Depends(get_db)):
    """
    Create a new conversation
    
    **Query parameters:**
    - `title`: Optional conversation title
    
    **Returns:** Created conversation
    """
    logger.info(f"Creating new conversation: {title}")
    
    # TODO: Implement database insert
    return {
        "id": 1,
        "title": title or "New Conversation",
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
        "message_count": 0
    }


@router.delete("/conversations/{conversation_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_conversation(conversation_id: int, db = Depends(get_db)):
    """
    Delete a conversation
    
    **Path parameters:**
    - `conversation_id`: Conversation ID
    """
    logger.info(f"Deleting conversation {conversation_id}")
    
    # TODO: Implement database delete
    return None


# WebSocket endpoint
@router.websocket("/ws/{conversation_id}")
async def websocket_endpoint(websocket: WebSocket, conversation_id: int):
    """
    WebSocket endpoint for real-time chat streaming
    
    **Path parameters:**
    - `conversation_id`: Conversation ID
    
    Supports streaming responses from AI
    """
    await websocket.accept()
    logger.info(f"WebSocket connection established for conversation {conversation_id}")
    
    try:
        while True:
            # Receive message from client
            data = await websocket.receive_text()
            logger.info(f"WebSocket message: {data[:30]}...")
            
            # TODO: Process message and stream response
            # For now, send mock response
            response = f"Echo: {data}"
            
            # Send response
            await websocket.send_text(response)
            
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        await websocket.close()
        logger.info(f"WebSocket connection closed for conversation {conversation_id}")
