class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.text :body, null: false
      t.references :user, null: false, foreign_key: true
      t.references :channel, foreign_key: true
      t.bigint :conversation_id
      t.references :parent_message, foreign_key: { to_table: :messages }
      t.datetime :edited_at
      t.datetime :deleted_at
      t.integer :message_type, default: 0, null: false

      t.timestamps
    end

    add_index :messages, [:channel_id, :created_at]
    add_index :messages, :conversation_id
  end
end
