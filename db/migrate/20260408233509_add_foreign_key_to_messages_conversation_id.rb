class AddForeignKeyToMessagesConversationId < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :messages, :conversations
  end
end
