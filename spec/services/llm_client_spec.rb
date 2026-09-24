require 'rails_helper'

RSpec.describe LlmClient do
  let(:api_key) { nil }
  let(:config) do
    ActiveSupport::OrderedOptions.new.merge!(base_url: 'http://llm.test/v1/', model: 'test-model',
                                             api_key:, timeout: 5)
  end
  let(:endpoint) { 'http://llm.test/v1/chat/completions' }

  def completion(content)
    { choices: [{ message: { role: 'assistant', content: } }] }.to_json
  end

  def chat
    described_class.new(config).chat_json(messages: [{ role: 'user', content: 'oi' }],
                                          schema: { type: 'object' }, schema_name: 'test')
  end

  it 'posts an OpenAI-compatible request with a strict JSON Schema and returns the parsed answer' do
    stub_request(:post, endpoint).to_return(status: 200, body: completion('{"subject":"Olá"}'))

    expect(chat).to eq('subject' => 'Olá')
    expect(WebMock).to(have_requested(:post, endpoint).with do |request|
      body = JSON.parse(request.body)
      body['model'] == 'test-model' &&
        body['messages'] == [{ 'role' => 'user', 'content' => 'oi' }] &&
        body.dig('response_format', 'type') == 'json_schema' &&
        body.dig('response_format', 'json_schema', 'strict') == true
    end)
  end

  it 'sends no Authorization header when no key is configured (local Ollama)' do
    stub_request(:post, endpoint).to_return(status: 200, body: completion('{}'))

    chat

    expect(WebMock).to(have_requested(:post, endpoint).with { |request| !request.headers.key?('Authorization') })
  end

  context 'with an API key' do
    let(:api_key) { 'sk-super-secret' }

    it 'sends it as a Bearer token' do
      stub_request(:post, endpoint).with(headers: { 'Authorization' => 'Bearer sk-super-secret' })
                                   .to_return(status: 200, body: completion('{}'))

      expect(chat).to eq({})
    end

    it 'never leaks the key in error messages' do
      stub_request(:post, endpoint).to_return(status: 401, body: '{"error":"invalid key sk-super-secret"}')

      expect { chat }.to raise_error(LlmClient::Error) { |error| expect(error.message).not_to include('sk-super-secret') }
    end
  end

  {
    'HTTP 401' => [->(stub) { stub.to_return(status: 401) }, :unauthorized],
    'HTTP 403' => [->(stub) { stub.to_return(status: 403) }, :unauthorized],
    'HTTP 429' => [->(stub) { stub.to_return(status: 429) }, :rate_limited],
    'HTTP 500' => [->(stub) { stub.to_return(status: 500) }, :provider_error],
    'a timeout' => [->(stub) { stub.to_timeout }, :timeout],
    'a refused connection' => [->(stub) { stub.to_raise(Errno::ECONNREFUSED) }, :unreachable],
    'a non-JSON body' => [->(stub) { stub.to_return(status: 200, body: '<html>proxy error</html>') }, :invalid_response],
    'non-JSON model content' => [->(stub) { stub.to_return(status: 200, body: completion('Claro! Aqui está')) },
                                 :invalid_response]
  }.each do |situation, (respond, code)|
    it "raises LlmClient::Error(:#{code}) on #{situation}" do
      instance_exec(stub_request(:post, endpoint), &respond)

      expect { chat }.to raise_error(LlmClient::Error) { |error| expect(error.code).to eq code }
    end
  end
end
