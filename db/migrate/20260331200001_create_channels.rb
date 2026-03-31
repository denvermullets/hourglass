class CreateChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :channels do |t|
      t.string :name, null: false
      t.text :description
      t.references :category, null: true, foreign_key: true
      t.references :server, null: false, foreign_key: true
      t.integer :channel_type, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.string :topic
      t.boolean :is_private, null: false, default: false

      t.timestamps
    end

    add_index :channels, [ :server_id, :category_id, :position ]
    add_index :channels, [ :server_id, :name ], unique: true
  end
end
