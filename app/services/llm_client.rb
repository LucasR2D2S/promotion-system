require "net/http"

# Thin client for OpenAI-compatible Chat Completions APIs (Ollama, Groq, OpenAI).
# Returns the model's JSON answer as a Hash, constrained by a JSON Schema
# (structured outputs), or raises LlmClient::Error with a stable error code.
class LlmClient
  class Error < StandardError
    attr_reader :code

    def initialize(code, message = code.to_s)
      @code = code
      super(message)
    end
  end

  def initialize(config = Rails.configuration.x.ai)
    @base_url = config.base_url.to_s.chomp("/")
    @model = config.model
    @api_key = config.api_key
    @timeout = config.timeout
  end

  def chat_json(messages:, schema:, schema_name:, temperature: 0.7)
    response = post("/chat/completions", {
      model: @model,
      temperature:,
      messages:,
      response_format: { type: "json_schema", json_schema: { name: schema_name, strict: true, schema: } }
    })
    JSON.parse(response.dig("choices", 0, "message", "content").to_s)
  rescue JSON::ParserError
    raise Error.new(:invalid_response, "model did not return valid JSON")
  end

  private

  def post(path, payload)
    uri = URI("#{@base_url}#{path}")
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request["Authorization"] = "Bearer #{@api_key}" if @api_key.present?
    request.body = payload.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                                   open_timeout: 5, read_timeout: @timeout) do |http|
      http.request(request)
    end
    handle(response)
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise Error.new(:timeout, "LLM did not answer within #{@timeout}s")
  rescue SocketError, SystemCallError => e
    raise Error.new(:unreachable, "LLM unreachable at #{uri.host}:#{uri.port} (#{e.class})")
  end

  # Error messages carry the status only: provider bodies can echo request data.
  def handle(response)
    case response
    when Net::HTTPSuccess then JSON.parse(response.body)
    when Net::HTTPUnauthorized, Net::HTTPForbidden then raise Error.new(:unauthorized, "LLM rejected the API key")
    when Net::HTTPTooManyRequests then raise Error.new(:rate_limited, "LLM rate limit reached")
    else raise Error.new(:provider_error, "LLM answered HTTP #{response.code}")
    end
  rescue JSON::ParserError
    raise Error.new(:invalid_response, "LLM answered a non-JSON body")
  end
end
