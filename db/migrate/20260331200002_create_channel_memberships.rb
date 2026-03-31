class CreateChannelMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :channel_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :channel, null: false, foreign_key: true
      t.boolean :muted, null: false, default: false
      t.datetime :last_read_at

      t.timestamps
    end

    add_index :channel_memberships, [ :user_id, :channel_id ], unique: true
  end
end
