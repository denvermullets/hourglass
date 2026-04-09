class CreateConversationMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.datetime :last_read_at
      t.boolean :muted, default: false, null: false

      t.timestamps
    end

    add_index :conversation_memberships, [:user_id, :conversation_id], unique: true
  end
end
