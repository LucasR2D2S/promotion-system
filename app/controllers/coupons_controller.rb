class CouponsController < ApplicationController
  def inactivate
    @coupon = Coupon.find(params[:id])
    @coupon.inactivate!
    redirect_to @coupon.promotion
  end
end