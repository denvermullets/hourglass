class AddVerifyWebhookTimestampToServerIntegrations < ActiveRecord::Migration[8.1]
  def change
    add_column :server_integrations, :verify_webhook_timestamp, :boolean, default: true, null: false
  end
end
