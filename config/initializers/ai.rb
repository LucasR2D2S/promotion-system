# LLM used by the AI features. Any OpenAI-compatible Chat Completions API works,
# so switching providers is configuration, not code:
#
#   Ollama (default: local, free, data never leaves the machine — no key needed)
#     AI_BASE_URL=http://localhost:11434/v1  AI_MODEL=llama3.2
#   Groq
#     AI_BASE_URL=https://api.groq.com/openai/v1  AI_MODEL=<model>  AI_API_KEY=gsk_...
#   OpenAI
#     AI_BASE_URL=https://api.openai.com/v1  AI_MODEL=<model>  AI_API_KEY=sk-...
#
# The API key is a secret: it comes from the environment (.env locally — git- and
# docker-ignored — or the platform's secret manager in production) or from Rails
# encrypted credentials (`bin/rails credentials:edit` → ai: { api_key: ... }).
# It is only read server-side and never logged or sent to the browser.
Rails.application.config.x.ai.tap do |ai|
  ai.base_url = ENV.fetch("AI_BASE_URL", "http://localhost:11434/v1")
  ai.model = ENV.fetch("AI_MODEL", "llama3.2")
  ai.api_key = ENV["AI_API_KEY"].presence || Rails.application.credentials.dig(:ai, :api_key)
  # Local models can take a while on the first call (loading into memory).
  ai.timeout = ENV.fetch("AI_TIMEOUT", 60).to_i
end

# Brand used in generated copy (signature, subject lines).
Rails.application.config.x.store_name = ENV.fetch("STORE_NAME", "Promotion Store")
