class Promotion < ApplicationRecord

  has_many :coupons, dependent: :destroy
  has_one :promotion_approval, dependent: :destroy

  has_many :product_category_promotions, dependent: :destroy
  has_many :categories, through: :product_category_promotions

  belongs_to :user

  validates :name, :code, :discount_rate, :coupon_quantity, :expiration_date,  presence: {message: 'não pode ficar em branco'}
  validates :code, uniqueness: {case_sensitive: false, message: 'deve ser único'}, presence: {message: 'não pode ficar em branco'}
  validates :discount_rate, numericality: { greater_than: 0, less_than_or_equal_to: 100, allow_nil: true }
  validates :coupon_quantity, numericality: { only_integer: true, greater_than: 0,
                                              less_than_or_equal_to: 100_000, allow_nil: true }

  # Valid through the whole expiration day.
  def expired?(on: Date.current)
    expiration_date < on
  end

  def coupons_fully_generated?
    coupons.size >= coupon_quantity
  end

  def approved?
    promotion_approval
  end

  def approver
    promotion_approval&.user
  end

  def approve!(approval_user)
    PromotionApproval.create(promotion: self, user: approval_user)
  end

  def approved_at
    promotion_approval&.created_at
  end
end
