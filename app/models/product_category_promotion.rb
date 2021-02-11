class ProductCategoryPromotion < ApplicationRecord
  belongs_to :category
  belongs_to :promotion
end
