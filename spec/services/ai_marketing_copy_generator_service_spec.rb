require 'rails_helper'

RSpec.describe AiMarketingCopyGeneratorService do
  let(:client) { instance_double(LlmClient) }
  let(:valid_answer) do
    {
      'subject' => 'Black Friday: 30% OFF para você',
      'preheader' => 'Válido até 29/11/2033 em Eletrônicos e Games',
      'body' => "Olá, {{NOME}}!\n\nA Black Friday chegou com 30% de desconto em Eletrônicos e Games.\n\n" \
                "Use o cupom {{CUPOM}} no carrinho. Válido até 29/11/2033.\n\nEquipe Promotion Store",
      'call_to_action' => 'Aproveitar agora'
    }
  end

  def generate(**overrides)
    described_class.call(name: 'Black Friday', discount_rate: 30, expiration_date: Date.new(2033, 11, 29),
                         categories: %w[Eletrônicos Games], store_name: 'Promotion Store', client:, **overrides)
  end

  it 'returns the copy when the model answer follows every rule' do
    allow(client).to receive(:chat_json).and_return(valid_answer)

    result = generate

    expect(result).to be_success
    expect(result.value).to have_attributes(subject: 'Black Friday: 30% OFF para você',
                                            call_to_action: 'Aproveitar agora')
    expect(result.value.body).to include('{{CUPOM}}')
  end

  it 'sends the campaign data and the business rules to the model' do
    sent = nil
    allow(client).to receive(:chat_json) { |messages:, **| sent = messages; valid_answer }

    generate

    system, user = sent.map { it[:content] }
    expect(system).to include('português do Brasil', '"30%"', '{{CUPOM}} exatamente uma vez', 'Equipe Promotion Store')
    expect(user).to include('"campanha": "Black Friday"', '"desconto": "30%"', '"valido_ate": "29/11/2033"',
                            '"Eletrônicos"', '"loja": "Promotion Store"')
  end

  it 'formats fractional discounts the Brazilian way (12,5%)' do
    sent = nil
    answer = valid_answer.merge('subject' => 'Volta às Aulas: 12,5% OFF',
                                'body' => valid_answer['body'].gsub('30%', '12,5%'))
    allow(client).to receive(:chat_json) { |messages:, **| sent = messages; answer }

    expect(generate(discount_rate: 12.5)).to be_success
    expect(sent.last[:content]).to include('"desconto": "12,5%"')
  end

  describe 'validation of the model output (LLM output is untrusted)' do
    {
      'without the coupon merge tag' => [{ 'body' => 'Aproveite 30% de desconto!' }, '{{CUPOM}} exatamente uma vez'],
      'with the coupon merge tag twice' => [{ 'body' => '30% OFF: {{CUPOM}} {{CUPOM}}' }, '{{CUPOM}} exatamente uma vez'],
      'with a different discount' => [{ 'subject' => '25% OFF', 'body' => 'Só 25%! Use {{CUPOM}}.' },
                                      'exatamente como 30%'],
      'saying "até 30%" for a fixed discount' => [{ 'body' => 'Descontos de até 30%! Use {{CUPOM}}.' }, "'até'"],
      'with an unknown {{tag}}' => [{ 'body' => '30% OFF até {{valido_ate}}. Use {{CUPOM}}.' }, '{{valido_ate}}'],
      'with an unknown {tag}' => [{ 'body' => '30% OFF até {valido_ate}. Use {{CUPOM}}.' }, '{valido_ate}'],
      'with a [placeholder] to fill in' => [{ 'body' => '30% OFF na [Nome da Loja]. Use {{CUPOM}}.' }, 'colchetes'],
      'with HTML' => [{ 'body' => '<p>30% OFF. Use {{CUPOM}}.</p>' }, 'sem HTML'],
      'with invented urgency' => [{ 'body' => '30% OFF por tempo limitado! Use {{CUPOM}}.' }, 'não invente urgência'],
      'with invented scarcity' => [{ 'body' => '30% OFF antes que acabem! Use {{CUPOM}}.' }, 'não invente urgência'],
      'with sentences in English' => [{ 'body' => '30% OFF. Shop now with {{CUPOM}}!' }, 'português do Brasil'],
      'with an empty field' => [{ 'preheader' => '  ' }, 'preheader está vazio'],
      'with a subject over 80 characters' => [{ 'subject' => "30% OFF #{'a' * 80}" }, 'assunto passa de 80']
    }.each do |situation, (changes, expected_problem)|
      it "rejects copy #{situation} and gives up after #{described_class::MAX_ATTEMPTS} attempts" do
        feedback = []
        allow(client).to receive(:chat_json) do |messages:, **|
          feedback << messages.last[:content] if messages.size > 2
          valid_answer.merge(changes)
        end

        result = generate

        expect(result.error).to eq :invalid_copy
        expect(client).to have_received(:chat_json).exactly(described_class::MAX_ATTEMPTS).times
        expect(feedback.last).to include(expected_problem)
      end
    end

    it 'does not mistake the expiration date ("válido até 29/11") for a discount claim' do
      allow(client).to receive(:chat_json).and_return(valid_answer)

      expect(generate).to be_success
    end

    it 'sends the problems back to the model and accepts the corrected copy' do
      calls = []
      allow(client).to receive(:chat_json) do |messages:, **|
        calls << messages
        calls.size == 1 ? valid_answer.merge('body' => 'Aproveite 30% OFF!') : valid_answer
      end

      expect(generate).to be_success
      correction = calls.last
      expect(correction[-2]).to include(role: 'assistant')
      expect(correction[-1][:content]).to include('Corrija', '{{CUPOM}} exatamente uma vez')
    end

    it 'cleans escaped and dangling line breaks from small models' do
      body = "Olá!\\n\\nA Black Friday tem 30% OFF.\\\n\nUse o cupom {{CUPOM}}.\\"
      allow(client).to receive(:chat_json).and_return(valid_answer.merge('body' => body))

      expect(generate.value.body).to eq "Olá!\n\nA Black Friday tem 30% OFF.\n\nUse o cupom {{CUPOM}}."
    end

    it 'rejects text with invalid UTF-8 bytes instead of crashing' do
      broken = "Ol\xE1 \xFFm, 30% OFF. Use {{CUPOM}}.".b
      allow(client).to receive(:chat_json).and_return(valid_answer.merge('body' => broken))

      expect(generate.error).to eq :invalid_copy
    end
  end

  describe 'campaigns that must not reach the model' do
    it 'refuses an expired campaign' do
      allow(client).to receive(:chat_json)

      travel_to Date.new(2033, 11, 30) do
        expect(generate.error).to eq :campaign_expired
      end
      expect(client).not_to have_received(:chat_json)
    end

    [{ name: '  ' }, { discount_rate: 0 }, { discount_rate: 100.01 }, { discount_rate: 'abc' }].each do |invalid|
      it "refuses #{invalid.inspect}" do
        allow(client).to receive(:chat_json)

        expect(generate(**invalid).error).to eq :invalid_campaign
        expect(client).not_to have_received(:chat_json)
      end
    end
  end

  it 'turns client failures into error codes' do
    allow(client).to receive(:chat_json).and_raise(LlmClient::Error.new(:timeout))

    expect(generate.error).to eq :timeout
  end

  it 'builds the request from a promotion' do
    promotion = create(:promotion, name: 'Natal', discount_rate: 15, expiration_date: Date.new(2033, 12, 24),
                                   categories: [Category.create!(name: 'Livros', code: 'BOOK')])
    sent = nil
    allow(client).to receive(:chat_json) { |messages:, **| sent ||= messages.dup; valid_answer }

    described_class.for_promotion(promotion, client:)

    expect(sent.last[:content]).to include('"campanha": "Natal"', '"desconto": "15%"', '"Livros"', '24/12/2033')
  end
end
