# Consumes a coupon for an order: validates it, records the redemption and marks
# the coupon as used — atomically, so the same coupon can't pay for two orders.
#
#   result = CouponRedemptionService.call(coupon_code: "NATAL10-7KQ2-M9XA",
#                                         cart_total: "250.00", order_reference: "PED-1042")
#   result.value.redemption.final_total # => 225.0
#   result.value.replayed               # => true when the same order retries
#
# Concurrency (two checkouts with the same coupon at the same moment):
# - The coupon row is locked (SELECT ... FOR UPDATE) and every rule is checked
#   *after* the lock is held; checking before locking would leave a window where
#   both requests see "able" and both redeem.
# - Only the coupon row is locked, never the promotion: redemptions of different
#   coupons of the same Black Friday campaign run in parallel.
# - Unique indexes (one *active* redemption per coupon, one redemption per order)
#   are a second, database-level guarantee in case a code path ever skips the lock.
#
# Idempotency: checkouts retry on timeouts. Redeeming again with the same coupon
# and order returns the original redemption (replayed: true) instead of failing
# with :coupon_used for an order that actually succeeded.
class CouponRedemptionService < ApplicationService
  Receipt = Data.define(:redemption, :replayed)

  def initialize(coupon_code:, cart_total:, order_reference:, on: Date.current)
    @coupon_code = coupon_code.to_s.strip
    @cart_total = cart_total
    @order_reference = order_reference.to_s.strip
    @on = on
  end

  def call
    return failure(:invalid_order_reference) unless @order_reference.length.between?(1, 64)

    Coupon.transaction do
      coupon = Coupon.lock.find_by(code: @coupon_code)
      next failure(:coupon_not_found) unless coupon

      if (current = coupon.active_redemption)
        next current.order_reference == @order_reference ? success(Receipt.new(current, true)) : failure(:coupon_used)
      end
      # Order references are never reused: a cancelled order stays cancelled.
      if (existing = CouponRedemption.find_by(order_reference: @order_reference))
        next failure(existing.cancelled? ? :order_cancelled : :order_already_has_coupon)
      end

      quote = DiscountApplicationService.call(cart_total: @cart_total, coupon:, on: @on)
      next quote if quote.failure?

      success(Receipt.new(redeem!(coupon, quote.value), false))
    end
  rescue ActiveRecord::LockWaitTimeout, ActiveRecord::Deadlocked
    failure(:coupon_busy) # another checkout holds this coupon; safe to retry
  rescue ActiveRecord::RecordNotUnique => e
    failure(e.message.include?("order_reference") ? :order_already_has_coupon : :coupon_used)
  end

  private

  def redeem!(coupon, quote)
    coupon.update!(status: :used)
    coupon.redemptions.create!(order_reference: @order_reference, original_total: quote.original_total,
                              discount_amount: quote.discount_amount, final_total: quote.final_total,
                              redeemed_at: Time.current)
  end
end
