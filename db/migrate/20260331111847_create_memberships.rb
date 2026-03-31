class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :server, null: false, foreign_key: true
      t.integer :role, default: 3, null: false
      t.datetime :joined_at, null: false
      t.string :nickname

      t.timestamps
    end

    add_index :memberships, [:user_id, :server_id], unique: true
  end
end
