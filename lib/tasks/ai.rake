namespace :ai do
  desc "Compare LLMs on marketing copy quality. " \
       "MODELS=llama3.2,qwen2.5:7b N=12 SAMPLES=1 (defaults: configured model, 12 runs, 1 sample)"
  task benchmark: :environment do
    models = ENV.fetch("MODELS", Rails.configuration.x.ai.model).split(",").map(&:strip)
    puts "Endpoint: #{Rails.configuration.x.ai.base_url} — #{models.size} modelo(s), " \
         "#{ENV.fetch('N', 12)} e-mails cada\n\n"

    AiCopyBenchmark.new(models:, runs: Integer(ENV.fetch("N", 12)), samples: Integer(ENV.fetch("SAMPLES", 1))).run
  rescue LlmClient::Error => e
    abort "Não foi possível rodar o benchmark: #{e.message}"
  end
end
