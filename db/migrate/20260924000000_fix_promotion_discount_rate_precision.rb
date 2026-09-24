# discount_rate was DECIMAL(10,0): MySQL silently stored 12.5% as 12%.
# DECIMAL(5,2) holds 0.00..100.00 exactly.
class FixPromotionDiscountRatePrecision < ActiveRecord::Migration[8.1]
  def up
    change_column :promotions, :discount_rate, :decimal, precision: 5, scale: 2
  end

  def down
    change_column :promotions, :discount_rate, :decimal, precision: 10
  end
end
