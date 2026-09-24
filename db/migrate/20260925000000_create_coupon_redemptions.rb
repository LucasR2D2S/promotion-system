# Financial record of each coupon use. The unique indexes are the database-level
# guarantees behind the business rules, independent of application code:
#   coupon_id       -> a coupon is redeemed at most once
#   order_reference -> at most one coupon per order (no stacking)
class CreateCouponRedemptions < ActiveRecord::Migration[8.1]
  def change
    create_table :coupon_redemptions do |t|
      t.references :coupon, null: false, foreign_key: true, index: { unique: true }
      t.string :order_reference, null: false, limit: 64, index: { unique: true }
      t.decimal :original_total, precision: 12, scale: 2, null: false
      t.decimal :discount_amount, precision: 12, scale: 2, null: false
      t.decimal :final_total, precision: 12, scale: 2, null: false
      t.datetime :redeemed_at, null: false

      t.timestamps
    end
  end
end
