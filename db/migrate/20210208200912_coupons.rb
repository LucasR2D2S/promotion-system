class RemoveNullKeyConstraint < ActiveRecord::Migration[6.1]
  def change
    change_column_null(:children, :parent_id, true)
  end
end