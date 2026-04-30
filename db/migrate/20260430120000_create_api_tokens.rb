class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.references :server, null: true, foreign_key: true
      t.string :token_digest, null: false
      t.string :name, null: false
      t.jsonb :scopes, default: %w[read write], null: false
      t.datetime :revoked_at
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :api_tokens, :token_digest, unique: true
    add_index :api_tokens, %i[user_id revoked_at]
  end
end
