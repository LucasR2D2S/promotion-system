# Quotes the final price of a cart for a coupon code. Read-only: it validates and
# calculates, it does not redeem the coupon.
#
#   result = DiscountApplicationService.call(cart_total: "250.00", coupon_code: "NATAL10-7KQ2-M9XA")
#   result.value.final_total # => 225.0 (BigDecimal)
#   result.error             # => :promotion_expired, :coupon_used, ... when it fails
#
# Money is handled as BigDecimal end to end (never Float); the discount is
# rounded half-up to cents and can never make the total negative.
class DiscountApplicationService < ApplicationService
  Quote = Data.define(:original_total, :discount_amount, :final_total, :coupon)

  def initialize(cart_total:, coupon_code:, on: Date.current)
    @cart_total = cart_total
    @coupon_code = coupon_code.to_s.strip
    @on = on
  end

  def call
    total = parse_amount(@cart_total)
    return failure(:invalid_cart_total) unless total

    # Checkout hot path: coupon, promotion and approval in a single JOIN query.
    coupon = Coupon.eager_load(promotion: :promotion_approval).find_by(code: @coupon_code)
    return failure(:coupon_not_found) unless coupon

    error = ineligibility_reason(coupon)
    return failure(error) if error

    discount = discount_for(total, coupon.promotion.discount_rate)
    success(Quote.new(original_total: total, discount_amount: discount,
                      final_total: total - discount, coupon:))
  end

  private

  def parse_amount(value)
    amount = BigDecimal(value.to_s)
    amount if amount.finite? && !amount.negative?
  rescue ArgumentError
    nil
  end

  def ineligibility_reason(coupon)
    promotion = coupon.promotion

    if coupon.used? then :coupon_used
    elsif coupon.disable? then :coupon_disabled
    elsif promotion.expired?(on: @on) then :promotion_expired
    elsif !promotion.approved? then :promotion_not_approved
    end
  end

  def discount_for(total, rate)
    (total * rate / 100).round(2, :half_up).clamp(..total)
  end
end
