# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_24_000000) do
  create_table "categories", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "coupons", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.bigint "promotion_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_coupons_on_code", unique: true
    t.index ["promotion_id"], name: "index_coupons_on_promotion_id"
  end

  create_table "product_category_promotions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.bigint "promotion_id", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_product_category_promotions_on_category_id"
    t.index ["promotion_id"], name: "index_product_category_promotions_on_promotion_id"
  end

  create_table "promotion_approvals", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "promotion_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["promotion_id"], name: "index_promotion_approvals_on_promotion_id"
    t.index ["user_id"], name: "index_promotion_approvals_on_user_id"
  end

  create_table "promotions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "code"
    t.integer "coupon_quantity"
    t.datetime "created_at", null: false
    t.string "description"
    t.decimal "discount_rate", precision: 5, scale: 2
    t.date "expiration_date"
    t.string "name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_promotions_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "coupons", "promotions"
  add_foreign_key "product_category_promotions", "categories"
  add_foreign_key "product_category_promotions", "promotions"
  add_foreign_key "promotion_approvals", "promotions"
  add_foreign_key "promotion_approvals", "users"
  add_foreign_key "promotions", "users"
end
