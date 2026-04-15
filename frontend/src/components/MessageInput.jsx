import { useState, useRef, useEffect } from 'react'

export default function MessageInput({ onSendMessage, disabled }) {
  const [input, setInput] = useState('')
  const textareaRef = useRef(null)

  // Auto-resize textarea
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto'
      textareaRef.current.style.height = Math.min(textareaRef.current.scrollHeight, 100) + 'px'
    }
  }, [input])

  const handleSubmit = (e) => {
    e.preventDefault()
    
    if (input.trim() && !disabled) {
      onSendMessage(input)
      setInput('')
      if (textareaRef.current) {
        textareaRef.current.style.height = 'auto'
      }
    }
  }

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSubmit(e)
    }
  }

  const charCount = input.length
  const charLimit = 500
  const charPercentage = (charCount / charLimit) * 100

  return (
    <form onSubmit={handleSubmit} className="input-container">
      <div className="input-form">
        <div className="textarea-wrapper">
          <textarea
            ref={textareaRef}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="Type your message..."
            className="input-field"
            disabled={disabled}
            autoFocus
            rows={1}
            maxLength={500}
          />
          <button
            type="submit"
            className="send-button"
            disabled={disabled || !input.trim()}
            title={disabled ? 'Waiting for response...' : input.trim() ? 'Send message (Enter)' : 'Type a message'}
            aria-label="Send message"
          >
            →
          </button>
        </div>
      </div>
    </form>
  )
}
