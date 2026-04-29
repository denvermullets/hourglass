class CreateMtasksUserMaps < ActiveRecord::Migration[8.1]
  def change
    create_table :mtasks_user_maps do |t|
      t.references :hourglass_user, null: false, foreign_key: { to_table: :users }
      t.bigint :mtasks_user_id, null: false
      t.string :email, null: false
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :mtasks_user_maps, :email, unique: true
    add_index :mtasks_user_maps, :hourglass_user_id, unique: true, name: 'index_mtasks_user_maps_on_hourglass_user_id_unique'
    add_index :mtasks_user_maps, :mtasks_user_id, unique: true
  end
end
