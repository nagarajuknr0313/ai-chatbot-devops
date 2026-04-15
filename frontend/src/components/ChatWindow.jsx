import { useState, useRef, useEffect } from 'react'
import axios from 'axios'
import MessageList from './MessageList'
import MessageInput from './MessageInput'

// Get API URL dynamically based on current environment
const getApiUrl = () => {
  if (typeof window === 'undefined') {
    return 'http://localhost:8000'
  }
  
  const { hostname, protocol } = window.location
  
  // Development: running on localhost
  if (hostname === 'localhost' || hostname === '127.0.0.1') {
    const url = `${protocol}//localhost:8000`
    console.log('[API] Running on localhost, using:', url)
    return url
  }
  
  // Production: running on k8s ALB
  if (hostname.includes('k8s-chatbot-frontend')) {
    // Use the actual backend ALB URL (different from frontend)
    const backendUrl = 'http://k8s-chatbot-backendn-28c871c98c-03a3caa79ecbc40c.elb.ap-southeast-2.amazonaws.com'
    console.log('[API] Detected frontend ALB, using backend ALB:', backendUrl)
    return backendUrl
  }
  
  // Fallback: explicit backend ALB URL
  const fallbackUrl = 'http://k8s-chatbot-backendn-28c871c98c-03a3caa79ecbc40c.elb.ap-southeast-2.amazonaws.com'
  console.log('[API] Using fallback backend URL:', fallbackUrl)
  return fallbackUrl
}

const API_URL = getApiUrl()

const SUGGESTED_QUESTIONS = [
  'What is Neural Networks?',
  'Explain machine learning',
  'What is AI?',
  'How does deep learning work?'
]

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
  const [showSuggestions, setShowSuggestions] = useState(true)
  const messagesEndRef = useRef(null)

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  useEffect(() => {
    scrollToBottom()
  }, [messages, loading])

  const handleSendMessage = async (content) => {
    if (!content.trim()) return

    setShowSuggestions(false)

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
    <>
      <header>
        <div className="header-content">
          <h1>AI Assistant</h1>
          <div className="header-status">
            <span className="status-indicator"></span>
            <span>Online and ready to help</span>
          </div>
        </div>
      </header>
      
      <div className="chat-main">
        <div className="sidebar-placeholder" />
        
        <div className="chat-center">
          <MessageList messages={messages} loading={loading} ref={messagesEndRef} />
          
          {showSuggestions && messages.length === 1 && (
            <div className="suggestions-container">
              <p className="suggestions-label">Try asking:</p>
              <div className="suggestions-grid">
                {SUGGESTED_QUESTIONS.map((question, index) => (
                  <button
                    key={index}
                    className="suggestion-button"
                    onClick={() => handleSendMessage(question)}
                    disabled={loading}
                  >
                    {question}
                  </button>
                ))}
              </div>
            </div>
          )}
          
          <MessageInput 
            onSendMessage={handleSendMessage} 
            disabled={loading} 
          />
        </div>
        
        <div className="sidebar-placeholder-right" />
      </div>
    </>
  )
}
