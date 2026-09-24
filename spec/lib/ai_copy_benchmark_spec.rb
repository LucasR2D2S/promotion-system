require 'rails_helper'

RSpec.describe AiCopyBenchmark do
  # Fake LLM: answers with the discount it was asked for; the very first e-mail
  # comes without the coupon tag so one correction round is exercised.
  let(:fake_client) do
    Class.new do
      attr_reader :calls

      def initialize = @calls = 0

      def chat_json(messages:, schema_name:, **)
        return { 'ok' => true } if schema_name == 'ping'

        @calls += 1
        discount = messages.second[:content][/"desconto": "([^"]+)"/, 1]
        coupon = @calls == 1 ? '' : ' Use o cupom {{CUPOM}} no carrinho.'
        { 'subject' => "#{discount} OFF", 'preheader' => 'Ofertas da semana', 'call_to_action' => 'Comprar',
          'body' => "Ganhe #{discount} com frete grátis.#{coupon}\n\nEquipe Promotion Store" }
      end
    end.new
  end

  let(:io) { StringIO.new }

  def run_benchmark(runs: 4)
    described_class.new(models: ['fake-model'], runs:, samples: 1, io:, client_factory: ->(_) { fake_client }).run.first
  end

  it 'counts approvals, model calls including correction rounds, and rejected rules' do
    report = run_benchmark

    expect(report.approved).to eq 4
    expect(report.calls).to eq 5 # 4 e-mails + 1 correction
    expect(report.rejections).to eq('o corpo deve conter {{CUPOM}} exatamente uma vez' => 1)
    expect(report.latencies.size).to eq 4
  end

  it 'flags claims the validation cannot judge, with the snippet for human review' do
    report = run_benchmark

    expect(report.flags['frete'].size).to eq 4
    expect(report.flags['frete'].first).to include('Black Friday', 'frete grátis')
  end

  it 'prints a readable report with a sample e-mail' do
    run_benchmark

    expect(io.string).to include('== fake-model ==', 'aprovados:            4/4', '1.25 por e-mail',
                                 '[frete]', '--- exemplo: Black Friday')
  end

  it 'feeds every campaign with a future expiration date (expired ones would be refused)' do
    report = run_benchmark(runs: 8)

    expect(report.errors).to be_empty
  end
end
