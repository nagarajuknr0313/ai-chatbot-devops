import { forwardRef } from 'react'

const MessageList = forwardRef(({ messages, messagesEndRef }, ref) => {
  return (
    <div className="messages-container">
      {messages.map((message) => (
        <div key={message.id} className={`message ${message.role}`}>
          <div className="message-content">
            <p className="whitespace-pre-wrap">{message.content}</p>
            <span className={`text-xs ${
              message.role === 'user' 
                ? 'text-blue-100' 
                : 'text-gray-500'
            } mt-1 block`}>
              {new Date(message.timestamp).toLocaleTimeString([], { 
                hour: '2-digit', 
                minute: '2-digit' 
              })}
            </span>
          </div>
        </div>
      ))}
      <div ref={messagesEndRef} />
    </div>
  )
})

MessageList.displayName = 'MessageList'

export default MessageList
