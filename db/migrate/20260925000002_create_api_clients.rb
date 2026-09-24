# Storefronts/apps allowed to call the checkout API. Only a SHA-256 digest of each
# token is stored, so a database leak doesn't leak working credentials.
class CreateApiClients < ActiveRecord::Migration[8.1]
  def change
    create_table :api_clients do |t|
      t.string :name, null: false
      t.string :token_digest, null: false, index: { unique: true }
      t.datetime :last_used_at
      t.datetime :revoked_at

      t.timestamps
    end
  end
end
