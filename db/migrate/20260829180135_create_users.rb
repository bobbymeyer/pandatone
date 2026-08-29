class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      # The credential a script carries. A second one rather than the password
      # so that a tool holding it can be revoked on its own, and so the
      # password is never written into a cron line or a CI secret.
      t.string :api_token, null: false

      t.timestamps
    end
    add_index :users, :email_address, unique: true
    add_index :users, :api_token, unique: true
  end
end
