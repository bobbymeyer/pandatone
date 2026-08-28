class CreateColors < ActiveRecord::Migration[8.1]
  def change
    create_table :colors do |t|
      t.string :name, null: false
      t.string :source_space, null: false

      # Every colour carries both spaces. source_space records which one the
      # author typed; the other is derived at write time and approximate.
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

    # Exact-RGB lookup is how both "which palettes contain this hex" and the
    # colour search reach a row, so it gets the index.
    add_index :colors, [ :r, :g, :b ]
    add_index :colors, :name
  end
end
