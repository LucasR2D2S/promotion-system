class CouponsController < ApplicationController
  before_action :set_coupon

  # A used coupon is final: toggling it back to "able" would allow a second redemption.
  def disable
    @coupon.disable! unless @coupon.used?
    redirect_to @coupon.promotion
  end

  def able
    @coupon.able! unless @coupon.used?
    redirect_to @coupon.promotion
  end

  private

  def set_coupon
    @coupon = Coupon.find(params[:id])
  end
end
