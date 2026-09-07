# A consumer of the dresser, in the least form that still is one: something
# with ranked slots, wearing a palette through a colorway, a snapshot and a
# rule per slot. The engine's own tables know nothing of these; they are the
# host's, the way Stripeclub's and Badger's are.
class CreateWearers < ActiveRecord::Migration[8.0]
  def change
    create_table :wearers do |t|
      t.string :name, null: false
      t.integer :slot_count, null: false, default: 2
      t.timestamps
    end

    create_table :wearer_colorways do |t|
      t.references :wearer, null: false, foreign_key: true
      t.integer :palette_id, null: false
      t.timestamps
    end

    create_table :wearer_palette_snapshots do |t|
      t.references :colorway, null: false, foreign_key: { to_table: :wearer_colorways }, index: { unique: true }
      t.string :palette_name
      t.json :colors, null: false, default: []
      t.datetime :taken_at, null: false
      t.timestamps
    end

    create_table :wearer_rules do |t|
      t.references :colorway, null: false, foreign_key: { to_table: :wearer_colorways }
      t.integer :rank, null: false
      t.string :kind, null: false, default: "auto_value_match"
      t.json :settings, null: false, default: {}
      t.timestamps
    end
    add_index :wearer_rules, %i[ colorway_id rank ], unique: true
  end
end
