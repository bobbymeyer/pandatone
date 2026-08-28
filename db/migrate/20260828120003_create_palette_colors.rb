class CreatePaletteColors < ActiveRecord::Migration[8.1]
  def change
    create_table :palette_colors do |t|
      t.references :palette, null: false, foreign_key: true
      t.references :color, null: false, foreign_key: true
      t.integer :position, null: false

      t.timestamps
    end

    add_index :palette_colors, [ :palette_id, :color_id ], unique: true
    add_index :palette_colors, [ :palette_id, :position ]
  end
end
