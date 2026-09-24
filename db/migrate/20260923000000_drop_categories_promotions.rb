# Leftover from an abandoned has_and_belongs_to_many design; the app uses
# product_category_promotions (has_many :through) instead.
class DropCategoriesPromotions < ActiveRecord::Migration[6.1]
  def change
    drop_join_table :categories, :promotions do |t|
      t.index :category_id
      t.index :promotion_id
    end
  end
end
