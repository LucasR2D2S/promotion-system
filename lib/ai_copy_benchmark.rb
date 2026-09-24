# Compares LLMs on the marketing copy task, so switching models is a measured
# decision instead of a hunch. Run with `bin/rails ai:benchmark`.
#
# Per model it reports how much copy passes the service's validation, how many
# model calls that takes, latency, which rules fail most, and "review flags":
# claims the validation can't judge (scope, shipping, installments, relative dates)
# printed with the snippet so a human decides whether they are hallucinations.
class AiCopyBenchmark
  # Fixed campaigns (no DB) so every model and every machine gets the same input.
  CAMPAIGNS = [
    { name: "Black Friday", discount_rate: 30, categories: ["Eletrônicos", "Games", "Casa e Decoração"] },
    { name: "Cyber Monday", discount_rate: 25, categories: ["Eletrônicos", "Games"] },
    { name: "Natal Premiado", discount_rate: 15, categories: ["Moda", "Beleza", "Livros"] },
    { name: "Volta às Aulas", discount_rate: 12.5, categories: ["Livros", "Eletrônicos"] }
  ].freeze

  REVIEW_FLAGS = {
    "escopo amplo (loja toda?)" => /toda a loja|todos os (nossos )?produtos|todo o (nosso )?(site|catálogo|estoque)|em tudo/i,
    "frete" => /frete/i,
    "parcelamento" => /parcel|sem juros/i,
    "data relativa" => /esta semana|neste fim de semana|amanhã|hoje/i
  }.freeze

  Report = Data.define(:model, :runs, :approved, :errors, :calls, :latencies, :rejections, :flags, :samples)

  def initialize(models:, runs: 12, samples: 1, io: $stdout, client_factory: nil)
    @models = models
    @runs = runs
    @samples = samples
    @io = io
    @client_factory = client_factory || ->(model) { LlmClient.new(Rails.configuration.x.ai.dup.merge!(model:)) }
  end

  def run
    reports = @models.map { benchmark(it) }
    reports.each { print_report(it) }
    reports
  end

  private

  def benchmark(model)
    client = @client_factory.call(model)
    warm_up(client)

    approved = 0
    errors = Hash.new(0)
    calls = 0
    latencies = []
    rejections = Hash.new(0)
    flags = Hash.new { |hash, key| hash[key] = [] }
    samples = []

    subscriber = ->(*, payload) do
      calls += 1
      payload[:problems].each { rejections[it] += 1 }
    end

    ActiveSupport::Notifications.subscribed(subscriber, AiMarketingCopyGeneratorService::ATTEMPT_EVENT) do
      CAMPAIGNS.cycle.first(@runs).each do |campaign|
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = AiMarketingCopyGeneratorService.call(**campaign, expiration_date: 30.days.from_now.to_date, client:)
        latencies << Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

        next errors[result.error] += 1 if result.failure?

        approved += 1
        text = result.value.to_h.values.join("\n")
        REVIEW_FLAGS.each do |label, pattern|
          text.scan(/.{0,40}#{pattern}.{0,40}/) { flags[label] << "#{campaign[:name]}: …#{$&.tr("\n", ' ').strip}…" }
        end
        samples << [campaign, result.value] if samples.size < @samples
      end
    end

    Report.new(model:, runs: @runs, approved:, errors:, calls:, latencies:, rejections:, flags:, samples:)
  end

  # The first call loads the model into memory; keep it out of the latency numbers.
  def warm_up(client)
    client.chat_json(messages: [{ role: "user", content: 'Responda {"ok": true}' }], schema_name: "ping",
                     schema: { type: "object", properties: { ok: { type: "boolean" } }, required: ["ok"],
                               additionalProperties: false })
  rescue LlmClient::Error => e
    raise e if e.code.in?(%i[unreachable model_not_found unauthorized])
  end

  def print_report(report)
    avg = report.latencies.sum / report.latencies.size
    @io.puts "== #{report.model} ==",
             "aprovados:            #{report.approved}/#{report.runs}" \
             "#{"  falhas: #{report.errors.to_h}" if report.errors.any?}",
             "chamadas ao modelo:   #{report.calls} (#{(report.calls.to_f / report.runs).round(2)} por e-mail)",
             "tempo:                médio #{avg.round(1)}s, máximo #{report.latencies.max.round(1)}s"
    print_counts("regras que mais falharam", report.rejections)
    if report.flags.empty?
      @io.puts "para revisão humana:  nada sinalizado"
    else
      @io.puts "para revisão humana (a validação não julga estes trechos):"
      report.flags.each { |label, snippets| snippets.each { @io.puts "  [#{label}] #{it}" } }
    end
    report.samples.each do |campaign, copy|
      @io.puts "--- exemplo: #{campaign[:name]} (#{campaign[:discount_rate]}% em #{campaign[:categories].join(', ')})",
               "Assunto: #{copy.subject}", "Pré-cabeçalho: #{copy.preheader}", "Botão: #{copy.call_to_action}",
               copy.body
    end
    @io.puts
  end

  def print_counts(title, counts)
    return @io.puts("#{"#{title}:".ljust(22)}nenhuma") if counts.empty?

    @io.puts "#{title}:"
    counts.sort_by { -it[1] }.each { |problem, count| @io.puts "  #{count}x #{problem}" }
  end
end
