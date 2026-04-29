class AddWebhookSecretToServerIntegrations < ActiveRecord::Migration[8.1]
  def change
    add_column :server_integrations, :webhook_secret, :string
  end
end
