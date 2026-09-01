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

ActiveRecord::Schema[8.1].define(version: 2026_08_31_180000) do
  create_table "colors", force: :cascade do |t|
    t.integer "b", null: false
    t.decimal "c", precision: 5, scale: 1, null: false
    t.datetime "created_at", null: false
    t.integer "g", null: false
    t.decimal "k", precision: 5, scale: 1, null: false
    t.decimal "m", precision: 5, scale: 1, null: false
    t.string "name", null: false
    t.integer "r", null: false
    t.string "source_space", null: false
    t.json "tags", default: [], null: false
    t.datetime "updated_at", null: false
    t.decimal "y", precision: 5, scale: 1, null: false
    t.index ["name"], name: "index_colors_on_name"
    t.index ["r", "g", "b"], name: "index_colors_on_r_and_g_and_b", unique: true
  end

  create_table "invitations", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.integer "invited_by_id", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_invitations_on_email_address", unique: true
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
  end

  create_table "palette_colors", force: :cascade do |t|
    t.integer "color_id", null: false
    t.datetime "created_at", null: false
    t.integer "palette_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["color_id"], name: "index_palette_colors_on_color_id"
    t.index ["palette_id", "color_id"], name: "index_palette_colors_on_palette_id_and_color_id", unique: true
    t.index ["palette_id", "position"], name: "index_palette_colors_on_palette_id_and_position"
    t.index ["palette_id"], name: "index_palette_colors_on_palette_id"
  end

  create_table "palettes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.json "tags", default: [], null: false
    t.datetime "updated_at", null: false
    t.index "LOWER(name)", name: "index_palettes_on_lower_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.boolean "api_read_only", default: false, null: false
    t.string "api_token", null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "palette_colors", "colors"
  add_foreign_key "palette_colors", "palettes"
  add_foreign_key "sessions", "users"
end
