namespace :api do
  namespace :clients do
    desc "Issue a checkout API token: NAME='Loja virtual'. The token is shown only once."
    task create: :environment do
      name = ENV.fetch("NAME") { abort "Informe o nome do cliente: NAME='Loja virtual'" }
      client, token = ApiClient.issue!(name:)
      puts "Cliente ##{client.id} (#{client.name}) criado.",
           "Token (guarde agora, ele não pode ser recuperado depois):", token
    end

    desc "List checkout API clients"
    task list: :environment do
      ApiClient.order(:id).each do |client|
        status = client.revoked_at ? "revogado em #{client.revoked_at}" : "ativo"
        puts "##{client.id}  #{client.name.ljust(30)} #{status.ljust(35)} último uso: #{client.last_used_at || '-'}"
      end
    end

    desc "Revoke a checkout API client: ID=1"
    task revoke: :environment do
      client = ApiClient.find(ENV.fetch("ID") { abort "Informe o ID: ID=1" })
      client.revoke!
      puts "Cliente ##{client.id} (#{client.name}) revogado."
    end
  end
end
