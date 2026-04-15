import { forwardRef } from 'react'

const MessageList = forwardRef(({ messages, loading }, ref) => {
  return (
    <div className="messages-container">
      {messages.map((message) => (
        <div key={message.id} className={`message ${message.role}`}>
          <div className="message-avatar">
            {message.role === 'user' ? '👤' : '🤖'}
          </div>
          <div className="message-wrapper">
            <div className="message-content">
              <p>{message.content}</p>
            </div>
            <span className="message-timestamp">
              {new Date(message.timestamp).toLocaleTimeString([], { 
                hour: '2-digit', 
                minute: '2-digit' 
              })}
            </span>
          </div>
        </div>
      ))}
      
      {loading && (
        <div className="message assistant">
          <div className="message-avatar">🤖</div>
          <div className="message-wrapper">
            <div className="message-content">
              <div className="loading-spinner">
                <span className="loading-dot"></span>
                <span className="loading-dot"></span>
                <span className="loading-dot"></span>
              </div>
            </div>
          </div>
        </div>
      )}
      
      <div ref={ref} />
    </div>
  )
})

MessageList.displayName = 'MessageList'

export default MessageList
