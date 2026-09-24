# A storefront or app authorized to call the checkout API with a bearer token.
#
# Tokens are random (40 base58 chars), so a plain SHA-256 digest is enough — and,
# unlike bcrypt's salted hashes, it can be looked up directly. The raw token only
# exists in the return value of .issue!: show it once, store it in the client's
# secret manager.
class ApiClient < ApplicationRecord
  TOKEN_PREFIX = "psk_".freeze

  scope :active, -> { where(revoked_at: nil) }

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true

  # Returns [client, raw_token].
  def self.issue!(name:, token: generate_token)
    [create!(name:, token_digest: digest(token)), token]
  end

  def self.authenticate(token)
    active.find_by(token_digest: digest(token)) if token.present?
  end

  def self.digest(token) = OpenSSL::Digest::SHA256.hexdigest(token)
  def self.generate_token = "#{TOKEN_PREFIX}#{SecureRandom.base58(40)}"

  def revoke! = update!(revoked_at: Time.current)

  # At most one write every few minutes per client, not one per request.
  def track_usage!
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 5.minutes.ago
  end
end
