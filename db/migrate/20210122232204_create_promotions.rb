class CreatePromotions < ActiveRecord::Migration[6.1]
  def change
    create_table :promotions do |t|
      t.string :name
      t.string :description
      t.string :code
      t.decimal :discount_rate
      t.integer :coupon_quantity
      t.date :expiration_date

      t.timestamps
    end
  end
end
