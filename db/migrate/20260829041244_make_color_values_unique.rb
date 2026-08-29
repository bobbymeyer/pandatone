# One value, one swatch. The index that answered "which colour is #E30613"
# now also guarantees the question has a single answer.
class MakeColorValuesUnique < ActiveRecord::Migration[8.1]
  def change
    remove_index :colors, [ :r, :g, :b ]
    add_index :colors, [ :r, :g, :b ], unique: true
  end
end
