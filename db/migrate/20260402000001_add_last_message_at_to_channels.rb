class AddLastMessageAtToChannels < ActiveRecord::Migration[8.1]
  def up
    add_column :channels, :last_message_at, :datetime

    # Backfill from existing messages
    execute <<-SQL
      UPDATE channels
      SET last_message_at = (
        SELECT MAX(messages.created_at)
        FROM messages
        WHERE messages.channel_id = channels.id
          AND messages.deleted_at IS NULL
      )
    SQL
  end

  def down
    remove_column :channels, :last_message_at
  end
end
