class AddPinToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :pinned_at, :datetime
    add_reference :messages, :pinned_by, foreign_key: { to_table: :users }, null: true

    add_index :messages, :pinned_at,
              where: 'pinned_at IS NOT NULL',
              name: 'index_messages_on_pinned_at_partial'
  end
end
