class Coupon < ApplicationRecord
  belongs_to :promotion
  # Financial history: a redeemed coupon can't be deleted with its promotion.
  has_one :redemption, class_name: 'CouponRedemption', dependent: :restrict_with_exception

  enum :status, { able: 0, disable: 5, used: 10 }
end
