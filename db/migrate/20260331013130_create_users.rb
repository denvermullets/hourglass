class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :username, null: false
      t.string :display_name
      t.text :bio
      t.jsonb :favorite_artists, default: []

      t.timestamps
    end
    add_index :users, :email_address, unique: true
    add_index :users, :username, unique: true
  end
end
