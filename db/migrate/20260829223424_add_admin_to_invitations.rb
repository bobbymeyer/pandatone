class AddAdminToInvitations < ActiveRecord::Migration[8.1]
  def change
    # An invitation can carry the rank it will arrive as, so there is a way to
    # make a second admin that is not the console.
    add_column :invitations, :admin, :boolean, null: false, default: false
  end
end
