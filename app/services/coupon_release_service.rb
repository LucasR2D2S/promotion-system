# Cancels the redemption of an order and releases its coupon for a new order.
# The redemption row is kept (marked cancelled): it is a financial record.
#
#   result = CouponReleaseService.call(order_reference: "PED-1042", reason: "customer cancelled")
#   result.value.redemption.cancelled_at # => 2026-11-27 10:31:04
#   result.value.replayed                # => true when the order was already cancelled
#
# Takes the same lock as CouponRedemptionService (the coupon row, first), so a
# release and a redemption of the same coupon are serialized and can't deadlock
# by locking rows in opposite orders. Idempotent: cancelling twice is a no-op.
class CouponReleaseService < ApplicationService
  Receipt = Data.define(:redemption, :replayed)

  def initialize(order_reference:, reason: nil)
    @order_reference = order_reference.to_s.strip
    @reason = reason.to_s.strip.presence&.truncate(255)
  end

  def call
    return failure(:invalid_order_reference) unless @order_reference.length.between?(1, 64)

    CouponRedemption.transaction do
      coupon_id = CouponRedemption.where(order_reference: @order_reference).pick(:coupon_id)
      next failure(:order_not_found) unless coupon_id

      coupon = Coupon.lock.find(coupon_id)
      # Read the redemption only after the lock: a concurrent release may have won.
      redemption = CouponRedemption.find_by!(order_reference: @order_reference)
      next success(Receipt.new(redemption, true)) if redemption.cancelled?

      redemption.update!(cancelled_at: Time.current, cancellation_reason: @reason)
      coupon.update!(status: :able)
      success(Receipt.new(redemption, false))
    end
  rescue ActiveRecord::LockWaitTimeout, ActiveRecord::Deadlocked
    failure(:coupon_busy)
  end
end
