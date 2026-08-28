class CreatePalettes < ActiveRecord::Migration[8.1]
  def change
    create_table :palettes do |t|
      t.string :name, null: false
      t.json :tags, null: false, default: []

      t.timestamps
    end

    # Names are addressable in the API, so uniqueness is enforced here and not
    # only in the model.
    add_index :palettes, "LOWER(name)", unique: true, name: "index_palettes_on_lower_name"
  end
end
