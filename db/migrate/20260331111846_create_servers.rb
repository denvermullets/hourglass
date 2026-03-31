class CreateServers < ActiveRecord::Migration[8.1]
  def change
    create_table :servers do |t|
      t.string :name, null: false
      t.text :description
      t.string :invite_code, null: false
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.jsonb :settings, default: {}, null: false

      t.timestamps
    end

    add_index :servers, :invite_code, unique: true
  end
end
