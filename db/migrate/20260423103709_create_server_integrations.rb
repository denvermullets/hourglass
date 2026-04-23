class CreateServerIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :server_integrations do |t|
      t.references :server, null: false, foreign_key: true
      t.string :kind, null: false
      t.boolean :enabled, default: false, null: false
      t.string :api_token
      t.string :base_url, default: 'https://justanotherissuetracker.com', null: false
      t.jsonb :discovered_teams, default: [], null: false
      t.datetime :last_verified_at

      t.timestamps
    end

    add_index :server_integrations, %i[server_id kind], unique: true
  end
end
