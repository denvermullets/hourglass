class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.boolean :is_group, default: false, null: false
      t.string :name
      t.datetime :last_message_at

      t.timestamps
    end
  end
end
