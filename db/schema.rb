ActiveRecord::Schema[7.1].define(version: 2024_12_15_000006) do
  enable_extension "plpgsql"

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "name", null: false
    t.string "role", default: "attendee"
    t.string "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.string "venue"
    t.string "city"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.string "status", default: "draft"
    t.bigint "user_id"
    t.string "category"
    t.integer "max_capacity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ticket_tiers", force: :cascade do |t|
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2
    t.integer "quantity", default: 0
    t.integer "sold_count", default: 0
    t.bigint "event_id"
    t.datetime "sales_start"
    t.datetime "sales_end"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "event_id"
    t.string "status", default: "pending"
    t.decimal "total_amount", precision: 10, scale: 2
    t.string "confirmation_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id"
    t.bigint "ticket_tier_id"
    t.integer "quantity", default: 1
    t.decimal "unit_price", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "order_id"
    t.decimal "amount", precision: 10, scale: 2
    t.string "status", default: "pending"
    t.string "provider", default: "stripe"
    t.string "provider_reference"
    t.text "failure_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
