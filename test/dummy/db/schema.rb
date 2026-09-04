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

ActiveRecord::Schema[8.1].define(version: 2026_09_04_200003) do
  create_table "pandatone_colors", force: :cascade do |t|
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
    t.index ["name"], name: "index_pandatone_colors_on_name"
    t.index ["r", "g", "b"], name: "index_pandatone_colors_on_r_and_g_and_b", unique: true
  end

  create_table "pandatone_palette_colors", force: :cascade do |t|
    t.integer "color_id", null: false
    t.datetime "created_at", null: false
    t.integer "palette_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["color_id"], name: "index_pandatone_palette_colors_on_color_id"
    t.index ["palette_id", "color_id"], name: "index_pandatone_palette_colors_on_palette_id_and_color_id", unique: true
    t.index ["palette_id", "position"], name: "index_pandatone_palette_colors_on_palette_id_and_position"
    t.index ["palette_id"], name: "index_pandatone_palette_colors_on_palette_id"
  end

  create_table "pandatone_palettes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.json "tags", default: [], null: false
    t.datetime "updated_at", null: false
    t.index "LOWER(name)", name: "index_pandatone_palettes_on_lower_name", unique: true
  end

  add_foreign_key "pandatone_palette_colors", "pandatone_colors", column: "color_id"
  add_foreign_key "pandatone_palette_colors", "pandatone_palettes", column: "palette_id"
end
