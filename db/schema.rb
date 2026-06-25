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

ActiveRecord::Schema[8.1].define(version: 2026_06_25_143000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.string "phone_number"
    t.datetime "updated_at", null: false
  end

  create_table "employee_positions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "employee_id", null: false
    t.bigint "position_id", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "position_id"], name: "index_employee_positions_on_employee_id_and_position_id", unique: true
    t.index ["employee_id"], name: "index_employee_positions_on_employee_id"
    t.index ["position_id"], name: "index_employee_positions_on_position_id"
  end

  create_table "employees", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.bigint "location_id", null: false
    t.text "notes"
    t.string "phone_number"
    t.datetime "updated_at", null: false
    t.index ["location_id", "last_name", "first_name"], name: "index_employees_on_location_id_and_last_name_and_first_name"
    t.index ["location_id"], name: "index_employees_on_location_id"
  end

  create_table "locations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "active", default: true, null: false
    t.string "address_line_1"
    t.string "city"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "postal_code"
    t.string "state"
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_locations_on_account_id_and_name"
    t.index ["account_id"], name: "index_locations_on_account_id"
  end

  create_table "positions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "color", default: "#8A4F2A", null: false
    t.datetime "created_at", null: false
    t.bigint "location_id", null: false
    t.string "name", null: false
    t.integer "position_order", default: 0, null: false
    t.string "section", default: "foh", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id", "name"], name: "index_positions_on_location_id_and_name"
    t.index ["location_id"], name: "index_positions_on_location_id"
  end

  create_table "schedules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "location_id", null: false
    t.text "notes"
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.date "week_start_date", null: false
    t.index ["location_id", "week_start_date"], name: "index_schedules_on_location_id_and_week_start_date", unique: true
    t.index ["location_id"], name: "index_schedules_on_location_id"
  end

  create_table "shifts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "employee_id", null: false
    t.time "ends_at", null: false
    t.text "notes"
    t.bigint "position_id", null: false
    t.bigint "schedule_id", null: false
    t.date "shift_date", null: false
    t.time "starts_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "shift_date"], name: "index_shifts_on_employee_id_and_shift_date"
    t.index ["employee_id"], name: "index_shifts_on_employee_id"
    t.index ["position_id", "shift_date"], name: "index_shifts_on_position_id_and_shift_date"
    t.index ["position_id"], name: "index_shifts_on_position_id"
    t.index ["schedule_id", "shift_date"], name: "index_shifts_on_schedule_id_and_shift_date"
    t.index ["schedule_id"], name: "index_shifts_on_schedule_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "account_id"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "employee_positions", "employees"
  add_foreign_key "employee_positions", "positions"
  add_foreign_key "employees", "locations"
  add_foreign_key "locations", "accounts"
  add_foreign_key "positions", "locations"
  add_foreign_key "schedules", "locations"
  add_foreign_key "shifts", "employees"
  add_foreign_key "shifts", "positions"
  add_foreign_key "shifts", "schedules"
  add_foreign_key "users", "accounts"
end
