import { useState } from 'react'

export default function MessageInput({ onSendMessage, disabled }) {
  const [input, setInput] = useState('')

  const handleSubmit = (e) => {
    e.preventDefault()
    
    if (input.trim()) {
      onSendMessage(input)
      setInput('')
    }
  }

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSubmit(e)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="input-container">
      <div className="input-form">
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyPress={handleKeyPress}
          placeholder="Type your message..."
          className="input-field"
          disabled={disabled}
          autoFocus
        />
        <button
          type="submit"
          className="send-button"
          disabled={disabled || !input.trim()}
        >
          {disabled ? 'Sending...' : 'Send'}
        </button>
      </div>
      <p className="text-xs text-gray-500 mt-2">
        Press Enter to send or Shift+Enter for new line
      </p>
    </form>
  )
}
