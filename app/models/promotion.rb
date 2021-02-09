class Promotion < ApplicationRecord

  has_many :coupons, dependent: :destroy
  has_one :promotion_approval
  belongs_to :user

  validates :name, :code, :discount_rate, :coupon_quantity, :expiration_date,  presence: {message: 'não pode ficar em branco'}
  validates :code, uniqueness: {message: 'deve ser único'}, presence: {message: 'não pode ficar em branco'}

  def generate_coupons!
    Coupon.transaction do
      (1..coupon_quantity).each do |number|
        coupons.create!(code: "#{code}-#{'%04d' % number}")
      end
    end
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
