class Category < ApplicationRecord
  has_and_belongs_to_many :promotions

  validates :name, :code, presence: {message: 'não pode ficar em branco'}
  validates :code, uniqueness: {message: 'já está em uso'}
end

