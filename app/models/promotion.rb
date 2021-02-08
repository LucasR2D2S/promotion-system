class Promotion < ApplicationRecord

  has_many :coupons, dependent: :nullify_then_purge

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
end
