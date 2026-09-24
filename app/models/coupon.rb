class Coupon < ApplicationRecord
  belongs_to :promotion
  # Financial history (active and cancelled orders): never deleted with the promotion.
  has_many :redemptions, class_name: 'CouponRedemption', dependent: :restrict_with_exception
  has_one :active_redemption, -> { active }, class_name: 'CouponRedemption', inverse_of: :coupon

  enum :status, { able: 0, disable: 5, used: 10 }
end
