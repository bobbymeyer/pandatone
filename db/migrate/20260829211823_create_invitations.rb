class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    # An address that is allowed to make an account. Signing up consumes the
    # row, so what is left is exactly the list of people who have not yet
    # arrived.
    create_table :invitations do |t|
      t.string :email_address, null: false
      t.references :invited_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :invitations, :email_address, unique: true
  end
end
