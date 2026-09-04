class CreatePandatoneColors < ActiveRecord::Migration[8.1]
  def change
    create_table :pandatone_colors do |t|
      t.string :name, null: false
      t.string :source_space, null: false
      t.integer :r, null: false
      t.integer :g, null: false
      t.integer :b, null: false
      t.decimal :c, precision: 5, scale: 1, null: false
      t.decimal :m, precision: 5, scale: 1, null: false
      t.decimal :y, precision: 5, scale: 1, null: false
      t.decimal :k, precision: 5, scale: 1, null: false
      t.json :tags, null: false, default: []

      t.timestamps
    end

    add_index :pandatone_colors, :name
    # A color is its value: no two rows may render the same hex.
    add_index :pandatone_colors, %i[ r g b ], unique: true
  end
end
