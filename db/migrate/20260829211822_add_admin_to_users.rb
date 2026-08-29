class AddAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    # The first account to exist is an admin; every account invited after it
    # is not, until someone says otherwise.
    add_column :users, :admin, :boolean, null: false, default: false
  end
end
