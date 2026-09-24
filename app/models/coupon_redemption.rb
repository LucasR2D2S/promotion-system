class CouponRedemption < ApplicationRecord
  belongs_to :coupon

  scope :active, -> { where(cancelled_at: nil) }

  validates :order_reference, presence: true, length: { maximum: 64 }
  validates :original_total, :discount_amount, :final_total, :redeemed_at, presence: true

  def cancelled?
    cancelled_at.present?
  end
end
