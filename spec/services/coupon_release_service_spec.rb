require 'rails_helper'

RSpec.describe CouponReleaseService do
  let(:coupon) { create(:coupon, promotion: create(:promotion, :approved, discount_rate: 10)) }

  def redeem(order:, code: coupon.code)
    CouponRedemptionService.call(coupon_code: code, cart_total: '100.00', order_reference: order)
  end

  def release(order: 'PED-1', reason: 'cliente desistiu')
    described_class.call(order_reference: order, reason:)
  end

  it 'cancels the redemption, keeps it as a record and makes the coupon usable again' do
    redemption = redeem(order: 'PED-1').value.redemption

    travel_to Time.zone.local(2033, 11, 2, 9, 0) do
      result = release

      expect(result).to be_success
      expect(result.value.replayed).to be false
      expect(result.value.redemption).to eq redemption
    end
    expect(redemption.reload).to have_attributes(cancelled_at: Time.zone.local(2033, 11, 2, 9, 0),
                                                 cancellation_reason: 'cliente desistiu')
    expect(coupon.reload).to be_able
    expect(CouponRedemption.count).to eq 1
  end

  it 'lets another order redeem the released coupon' do
    redeem(order: 'PED-1')
    release(order: 'PED-1')

    result = redeem(order: 'PED-2')

    expect(result).to be_success
    expect(coupon.reload).to be_used
    expect(coupon.redemptions.pluck(:order_reference, :cancelled_at).map(&:first)).to contain_exactly('PED-1', 'PED-2')
    expect(coupon.active_redemption.order_reference).to eq 'PED-2'
  end

  it 'is idempotent: cancelling the same order again changes nothing' do
    redeem(order: 'PED-1')
    first = release(order: 'PED-1').value.redemption

    result = nil
    expect { result = release(order: 'PED-1') }.not_to(change { first.reload.cancelled_at })
    expect(result.value.replayed).to be true
  end

  it 'does not let a cancelled order use a coupon again' do
    redeem(order: 'PED-1')
    release(order: 'PED-1')

    expect(redeem(order: 'PED-1').error).to eq :order_cancelled
    expect(coupon.reload).to be_able
  end

  it 'answers :order_not_found for an order that used no coupon' do
    expect(release(order: 'PED-404').error).to eq :order_not_found
  end

  it 'requires an order reference of up to 64 characters' do
    expect(release(order: ' ').error).to eq :invalid_order_reference
    expect(release(order: 'P' * 65).error).to eq :invalid_order_reference
  end

  it 'answers :coupon_busy (retryable) when the coupon lock cannot be acquired in time' do
    redeem(order: 'PED-1')
    allow(Coupon).to receive(:lock).and_raise(ActiveRecord::LockWaitTimeout)

    expect(release(order: 'PED-1').error).to eq :coupon_busy
  end

  it 'enforces "one active redemption per coupon" in the database, not only in code' do
    redeem(order: 'PED-1')

    expect { coupon.redemptions.create!(order_reference: 'PED-X', original_total: 1, discount_amount: 0, final_total: 1, redeemed_at: Time.current) }
      .to raise_error(ActiveRecord::RecordNotUnique, /active_coupon_id/)

    release(order: 'PED-1')
    expect { coupon.redemptions.create!(order_reference: 'PED-Y', original_total: 1, discount_amount: 0, final_total: 1, redeemed_at: Time.current) }
      .not_to raise_error
  end
end
