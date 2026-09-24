class Category < ApplicationRecord
  has_many :product_category_promotions, dependent: :destroy
  has_many :promotions, through: :product_category_promotions

  validates :name, :code, presence: {message: 'não pode ficar em branco'}
  validates :code, uniqueness: {case_sensitive: false, message: 'já está em uso'}
end

