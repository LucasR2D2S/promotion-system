require 'rails_helper'

RSpec.describe CouponRedemptionService do
  let(:coupon) { create(:coupon, promotion: create(:promotion, :approved, discount_rate: 10)) }

  def redeem(code: coupon.code, total: '250.00', order: 'PED-1001', **)
    described_class.call(coupon_code: code, cart_total: total, order_reference: order, **)
  end

  it 'records the redemption with the quoted amounts and marks the coupon as used' do
    travel_to Time.zone.local(2033, 11, 1, 10, 30) do
      result = redeem

      expect(result).to be_success
      expect(result.value.replayed).to be false
      expect(result.value.redemption).to have_attributes(
        coupon:, order_reference: 'PED-1001', original_total: BigDecimal('250.00'),
        discount_amount: BigDecimal('25.00'), final_total: BigDecimal('225.00'),
        redeemed_at: Time.zone.local(2033, 11, 1, 10, 30)
      )
      expect(coupon.reload).to be_used
    end
  end

  it 'refuses the same coupon for another order' do
    redeem(order: 'PED-1001')

    result = nil
    expect { result = redeem(order: 'PED-2002') }.not_to change(CouponRedemption, :count)
    expect(result.error).to eq :coupon_used
  end

  it 'is idempotent: a checkout retry for the same order returns the original redemption' do
    first = redeem(order: 'PED-1001', total: '250.00').value.redemption

    result = nil
    expect { result = redeem(order: 'PED-1001', total: '999.00') }.not_to change(CouponRedemption, :count)
    expect(result).to be_success
    expect(result.value.replayed).to be true
    expect(result.value.redemption).to eq first
    expect(result.value.redemption.final_total).to eq BigDecimal('225.00') # original amounts, not the retry's
  end

  it 'allows only one coupon per order' do
    other = create(:coupon, promotion: coupon.promotion)
    redeem(code: coupon.code, order: 'PED-1001')

    result = redeem(code: other.code, order: 'PED-1001')

    expect(result.error).to eq :order_already_has_coupon
    expect(other.reload).to be_able
  end

  it 'finds the coupon ignoring case and surrounding whitespace, like the quote' do
    expect(redeem(code: "  #{coupon.code.downcase} ")).to be_success
  end

  describe 'reuses every quote rule and writes nothing when one fails' do
    {
      'an expired promotion' => [-> { create(:coupon, promotion: create(:promotion, :approved, :expired)) },
                                 :promotion_expired],
      'a disabled coupon' => [-> { create(:coupon, :disabled) }, :coupon_disabled],
      'a used coupon (legacy, without redemption record)' => [-> { create(:coupon, :used) }, :coupon_used],
      'an unapproved promotion' => [-> { create(:coupon, promotion: create(:promotion)) }, :promotion_not_approved]
    }.each do |situation, (build, error)|
      it "rejects #{situation}" do
        target = instance_exec(&build)
        status_before = target.status

        result = nil
        expect { result = redeem(code: target.code) }.not_to change(CouponRedemption, :count)
        expect(result.error).to eq error
        expect(target.reload.status).to eq status_before
      end
    end

    it 'rejects an invalid cart total' do
      expect(redeem(total: 'abc').error).to eq :invalid_cart_total
      expect(coupon.reload).to be_able
    end

    it 'rejects an unknown coupon' do
      expect(redeem(code: 'NAO-EXISTE').error).to eq :coupon_not_found
    end
  end

  it 'requires an order reference of up to 64 characters' do
    expect(redeem(order: '  ').error).to eq :invalid_order_reference
    expect(redeem(order: 'P' * 65).error).to eq :invalid_order_reference
    expect(redeem(order: 'P' * 64)).to be_success
  end

  it 'answers :coupon_busy (retryable) when the coupon lock cannot be acquired in time' do
    allow(Coupon).to receive(:lock).and_raise(ActiveRecord::LockWaitTimeout)

    expect(redeem.error).to eq :coupon_busy
  end

  it 'locks only the coupon row, never the promotion (campaign-wide redemptions stay parallel)' do
    code = coupon.code
    locking = []
    collect = ->(*, payload) { locking << payload[:sql] if payload[:sql].include?('FOR UPDATE') }

    ActiveSupport::Notifications.subscribed(collect, 'sql.active_record') { redeem(code:) }

    expect(locking.size).to eq 1
    expect(locking.first).to match(/FROM `coupons`/).and(match(/FOR UPDATE/))
    expect(locking.first).not_to include('promotions')
  end
end
