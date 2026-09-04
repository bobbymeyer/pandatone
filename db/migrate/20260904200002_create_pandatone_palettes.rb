class CreatePandatonePalettes < ActiveRecord::Migration[8.1]
  def change
    create_table :pandatone_palettes do |t|
      t.string :name, null: false
      t.json :tags, null: false, default: []

      t.timestamps
    end

    add_index :pandatone_palettes, "LOWER(name)", unique: true, name: "index_pandatone_palettes_on_lower_name"
  end
end
