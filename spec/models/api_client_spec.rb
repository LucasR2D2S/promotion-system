require 'rails_helper'

RSpec.describe ApiClient do
  it 'stores only the digest of the token and shows the raw token once' do
    client, token = described_class.issue!(name: 'Loja virtual')

    expect(token).to start_with('psk_')
    expect(client.token_digest).to eq OpenSSL::Digest::SHA256.hexdigest(token)
    expect(described_class.pluck(:token_digest).join).not_to include(token)
  end

  it 'authenticates active clients by token' do
    client, token = described_class.issue!(name: 'Loja virtual')

    expect(described_class.authenticate(token)).to eq client
    expect(described_class.authenticate('psk_wrong')).to be_nil
    expect(described_class.authenticate(nil)).to be_nil
  end

  it 'rejects revoked clients' do
    client, token = described_class.issue!(name: 'Loja virtual')
    client.revoke!

    expect(described_class.authenticate(token)).to be_nil
  end

  it 'tracks usage with at most one write every 5 minutes' do
    client, = described_class.issue!(name: 'Loja virtual')

    travel_to Time.zone.local(2033, 1, 1, 10, 0) do
      client.track_usage!
      expect(client.reload.last_used_at).to eq Time.zone.local(2033, 1, 1, 10, 0)
    end
    travel_to Time.zone.local(2033, 1, 1, 10, 3) do
      expect { client.track_usage! }.not_to(change { client.reload.last_used_at })
    end
  end
end
