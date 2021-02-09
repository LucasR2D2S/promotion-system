class CouponsController < ApplicationController
  def disable
    @coupon = Coupon.find(params[:id])
    # raise Error if @coupon
    @coupon.disable!
    redirect_to @coupon.promotion
  end

  def able
    @coupon = Coupon.find(params[:id])
    # raise Error if @coupon
    @coupon.able!
    redirect_to @coupon.promotion
  end
end