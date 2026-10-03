class AddServerIntegrationToWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_reference :webhook_deliveries, :server_integration, foreign_key: { on_delete: :nullify }, null: true
  end
end
