class CreatePandatonePaletteColors < ActiveRecord::Migration[8.1]
  def change
    create_table :pandatone_palette_colors do |t|
      t.references :palette, null: false, foreign_key: { to_table: :pandatone_palettes }
      t.references :color, null: false, foreign_key: { to_table: :pandatone_colors }
      t.integer :position, null: false

      t.timestamps
    end

    add_index :pandatone_palette_colors, %i[ palette_id color_id ], unique: true
    add_index :pandatone_palette_colors, %i[ palette_id position ]
  end
end
