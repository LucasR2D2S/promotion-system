# A cancelled order releases its coupon, but the redemption row stays: it is a
# financial record. The rule becomes "at most one *active* redemption per coupon".
#
# MySQL has no partial indexes (UNIQUE ... WHERE cancelled_at IS NULL), so a stored
# generated column holds coupon_id while the redemption is active and NULL once it
# is cancelled; a UNIQUE index on it allows any number of NULLs. The guarantee
# stays in the database, not only in application code.
class AddCancellationToCouponRedemptions < ActiveRecord::Migration[8.1]
  def change
    add_column :coupon_redemptions, :cancelled_at, :datetime
    add_column :coupon_redemptions, :cancellation_reason, :string
    add_column :coupon_redemptions, :active_coupon_id, :virtual, type: :bigint,
                                                                  as: "IF(cancelled_at IS NULL, coupon_id, NULL)",
                                                                  stored: true
    add_index :coupon_redemptions, :active_coupon_id, unique: true

    # The foreign key needs an index on coupon_id: add the plain one (history)
    # before dropping the unique one.
    add_index :coupon_redemptions, :coupon_id, name: "index_coupon_redemptions_on_coupon_id_history"
    remove_index :coupon_redemptions, :coupon_id, unique: true, name: "index_coupon_redemptions_on_coupon_id"
  end
end
