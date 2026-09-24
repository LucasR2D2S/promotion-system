require 'rails_helper'

RSpec.describe 'Checkout API v1', type: :request do
  let(:token) { ApiClient.issue!(name: 'Loja virtual').last }
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }
  let(:coupon) { create(:coupon, promotion: create(:promotion, :approved, discount_rate: 25)) }

  def api(method, path, body = nil, with_headers: headers)
    public_send(method, "/api/v1#{path}", params: body&.to_json, headers: with_headers)
    response.parsed_body
  end

  def redeem(order:, total: '399.90', code: coupon.code)
    api(:post, '/redemptions', { coupon_code: code, cart_total: total, order_reference: order })
  end

  describe 'authentication' do
    it 'rejects requests without a token' do
      body = api(:post, '/quotes', {}, with_headers: { 'Content-Type' => 'application/json' })

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['WWW-Authenticate']).to eq 'Bearer realm="checkout"'
      expect(body.dig('error', 'code')).to eq 'unauthorized'
    end

    it 'rejects an unknown token and a revoked client' do
      api(:post, '/quotes', {}, with_headers: headers.merge('Authorization' => 'Bearer psk_nope'))
      expect(response).to have_http_status(:unauthorized)

      client, revoked_token = ApiClient.issue!(name: 'Antiga')
      client.revoke!
      api(:post, '/quotes', {}, with_headers: headers.merge('Authorization' => "Bearer #{revoked_token}"))
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /quotes' do
    it 'returns the discount with money as locale-independent strings' do
      body = api(:post, '/quotes', { coupon_code: coupon.code, cart_total: '1599.90' })

      expect(response).to have_http_status(:ok)
      expect(body).to eq('coupon_code' => coupon.code, 'discount_rate' => '25.00', 'original_total' => '1599.90',
                         'discount_amount' => '399.98', 'final_total' => '1199.92', 'currency' => 'BRL')
    end

    it 'does not consume the coupon' do
      api(:post, '/quotes', { coupon_code: coupon.code, cart_total: '100' })

      expect(coupon.reload).to be_able
    end

    {
      'unknown coupon' => [{ coupon_code: 'NAO-EXISTE', cart_total: '100' }, :not_found, 'coupon_not_found'],
      'invalid cart total' => [{ cart_total: 'abc' }, :unprocessable_content, 'invalid_cart_total']
    }.each do |situation, (body, status, code)|
      it "answers #{status} for #{situation}" do
        result = api(:post, '/quotes', { coupon_code: coupon.code }.merge(body))

        expect(response).to have_http_status(status)
        expect(result['error']).to include('code' => code, 'message' => be_present)
      end
    end

    it 'answers 422 with a business error code for an expired campaign' do
      expired = create(:coupon, promotion: create(:promotion, :approved, :expired))

      body = api(:post, '/quotes', { coupon_code: expired.code, cart_total: '100' })

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('code' => 'promotion_expired', 'message' => 'A promoção deste cupom expirou')
    end

    it 'answers 400 for malformed JSON' do
      post '/api/v1/quotes', params: '{"coupon_code":', headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.dig('error', 'code')).to eq 'invalid_json'
    end
  end

  describe 'POST /redemptions' do
    it 'redeems the coupon (201) and a retry of the same order replays it (200)' do
      first = redeem(order: 'PED-1')
      expect(response).to have_http_status(:created)
      expect(first).to include('order_reference' => 'PED-1', 'status' => 'active', 'final_total' => '299.92')

      again = redeem(order: 'PED-1')
      expect(response).to have_http_status(:ok)
      expect(response.headers['Idempotent-Replayed']).to eq 'true'
      expect(again).to eq first
      expect(CouponRedemption.count).to eq 1
    end

    it 'refuses the same coupon for another order (422 coupon_used)' do
      redeem(order: 'PED-1')

      body = redeem(order: 'PED-2')

      expect(response).to have_http_status(:unprocessable_content)
      expect(body.dig('error', 'code')).to eq 'coupon_used'
    end

    it 'answers 409 when the order already used another coupon' do
      redeem(order: 'PED-1')

      body = redeem(order: 'PED-1', code: create(:coupon, promotion: coupon.promotion).code)

      expect(response).to have_http_status(:conflict)
      expect(body.dig('error', 'code')).to eq 'order_already_has_coupon'
    end

    it 'answers 409 with Retry-After when the coupon is busy in another checkout' do
      allow(CouponRedemptionService).to receive(:call).and_return(ServiceResult.failure(:coupon_busy))

      body = redeem(order: 'PED-1')

      expect(response).to have_http_status(:conflict)
      expect(response.headers['Retry-After']).to eq '1'
      expect(body.dig('error', 'code')).to eq 'coupon_busy'
    end
  end

  describe 'GET /redemptions/:order_reference' do
    it 'returns the redemption of an order (references may contain dots)' do
      redeem(order: 'PED.2033.1')

      body = api(:get, '/redemptions/PED.2033.1')

      expect(response).to have_http_status(:ok)
      expect(body).to include('order_reference' => 'PED.2033.1', 'coupon_code' => coupon.code)
    end

    it 'answers 404 for an order without coupon' do
      body = api(:get, '/redemptions/PED-404')

      expect(response).to have_http_status(:not_found)
      expect(body.dig('error', 'code')).to eq 'order_not_found'
    end
  end

  describe 'DELETE /redemptions/:order_reference (order cancelled)' do
    it 'releases the coupon for another order, idempotently' do
      redeem(order: 'PED-1')

      cancelled = api(:delete, '/redemptions/PED-1', { reason: 'cliente desistiu' })
      expect(response).to have_http_status(:ok)
      expect(cancelled).to include('status' => 'cancelled', 'cancellation_reason' => 'cliente desistiu',
                                   'cancelled_at' => be_present)

      api(:delete, '/redemptions/PED-1')
      expect(response).to have_http_status(:ok)
      expect(response.headers['Idempotent-Replayed']).to eq 'true'

      redeem(order: 'PED-2')
      expect(response).to have_http_status(:created)
    end

    it 'does not let the cancelled order use a coupon again (409 order_cancelled)' do
      redeem(order: 'PED-1')
      api(:delete, '/redemptions/PED-1')

      body = redeem(order: 'PED-1')

      expect(response).to have_http_status(:conflict)
      expect(body.dig('error', 'code')).to eq 'order_cancelled'
    end
  end

  it 'rate-limits each client (429) so quotes cannot be used to enumerate coupon codes' do
    statuses = Array.new(Api::V1::BaseController::RATE_LIMIT_PER_MINUTE + 1) do
      api(:post, '/quotes', { coupon_code: 'X', cart_total: '1' })
      response.status
    end

    expect(statuses.last).to eq 429
    expect(statuses.count(429)).to eq 1
    expect(response.parsed_body.dig('error', 'code')).to eq 'rate_limited'
  end
end
