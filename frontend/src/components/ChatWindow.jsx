import { useState, useRef, useEffect } from 'react'
import axios from 'axios'
import MessageList from './MessageList'
import MessageInput from './MessageInput'

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000'

export default function ChatWindow() {
  const [messages, setMessages] = useState([
    {
      id: 1,
      content: 'Hello! I\'m your AI assistant. How can I help you today?',
      role: 'assistant',
      timestamp: new Date()
    }
  ])
  const [conversationId, setConversationId] = useState(null)
  const [loading, setLoading] = useState(false)
  const messagesEndRef = useRef(null)

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  useEffect(() => {
    scrollToBottom()
  }, [messages])

  const handleSendMessage = async (content) => {
    if (!content.trim()) return

    // Add user message to chat
    const userMessage = {
      id: messages.length + 1,
      content,
      role: 'user',
      timestamp: new Date()
    }

    setMessages(prev => [...prev, userMessage])
    setLoading(true)

    try {
      // Send to API
      const response = await axios.post(`${API_URL}/api/chat/message`, {
        content,
        conversation_id: conversationId
      })

      // Add assistant response
      const assistantMessage = {
        id: messages.length + 2,
        content: response.data.content,
        role: 'assistant',
        timestamp: new Date(response.data.timestamp)
      }

      setMessages(prev => [...prev, assistantMessage])

      if (!conversationId && response.data.conversation_id) {
        setConversationId(response.data.conversation_id)
      }
    } catch (error) {
      console.error('Error sending message:', error)
      
      // Add error message
      const errorMessage = {
        id: messages.length + 2,
        content: 'Sorry, I encountered an error. Please try again.',
        role: 'assistant',
        timestamp: new Date()
      }
      setMessages(prev => [...prev, errorMessage])
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="chat-container">
      <div className="bg-white border-b border-gray-200 p-4 shadow-sm">
        <h1 className="text-2xl font-bold text-gray-800">AI Chatbot</h1>
        <p className="text-gray-600 text-sm">Chat with your AI assistant</p>
      </div>
      
      <MessageList messages={messages} messagesEndRef={messagesEndRef} />
      
      <MessageInput 
        onSendMessage={handleSendMessage} 
        disabled={loading} 
      />
    </div>
  )
}
