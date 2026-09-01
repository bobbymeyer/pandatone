class AddApiReadOnlyToUsers < ActiveRecord::Migration[8.1]
  def change
    # A token that may read the library and not rewrite it. The API is one
    # credential per user, so the scope belongs on the user rather than on a
    # token row that does not exist.
    #
    # Default false, so every account that already has a token keeps exactly
    # the reach it had: this adds a way to be less privileged, it does not
    # quietly demote anyone.
    add_column :users, :api_read_only, :boolean, null: false, default: false
  end
end
