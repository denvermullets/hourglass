class AddDataToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :data, :jsonb, default: {}, null: false
    add_index :messages, "(data->>'source')", name: 'index_messages_on_data_source'
  end
end
