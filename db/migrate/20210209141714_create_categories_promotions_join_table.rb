class CreateCategoriesPromotionsJoinTable < ActiveRecord::Migration[6.1]
  def change
    create_join_table :categories, :promotions do |t|
      t.index :category_id
      t.index :promotions_id
    end
  end
end
