class Coupon < ApplicationRecord
  belongs_to :promotion

  enum status: { able: 0, disable: 5 }
end
