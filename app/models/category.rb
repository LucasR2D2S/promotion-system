class Category < ApplicationRecord
  has_many :product_category_promotion
  has_many :promotions, through: :product_category_promotion


  validates :name, :code, presence: {message: 'não pode ficar em branco'}
  validates :code, uniqueness: {message: 'já está em uso'}
end

