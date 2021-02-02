class Promotion < ApplicationRecord

  has_many :coupons

  validates :name, presence: {message: 'não pode ficar em branco'}
  validates :code, uniqueness: {message: 'deve ser único'}, presence: {message: 'não pode ficar em branco'}
  validates :discount_rate, presence: {message: 'não pode ficar em branco'}
  validates :coupon_quantity, presence: {message: 'não pode ficar em branco'}
  validates :expiration_date, presence: {message: 'não pode ficar em branco'}
end
