class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.integer    :notification_type, null: false, default: 0
      t.references :notifiable, polymorphic: true, null: false
      t.datetime   :read_at
      t.jsonb      :data, default: {}, null: false
      t.timestamps
    end

    add_index :notifications, [:user_id, :read_at]
    add_index :notifications, [:user_id, :created_at]
    add_index :notifications, [:user_id, :notification_type, :notifiable_type, :notifiable_id],
              name: "idx_notifications_dedup"
  end
end
