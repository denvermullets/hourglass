class CreateWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_deliveries do |t|
      t.string :source, null: false
      t.string :delivery_id, null: false
      t.string :event_type, null: false
      t.datetime :received_at, null: false
      t.datetime :processed_at
      t.jsonb :payload, default: {}, null: false

      t.timestamps
    end

    add_index :webhook_deliveries, %i[source delivery_id], unique: true
    add_index :webhook_deliveries, :event_type
    add_index :webhook_deliveries, :processed_at
  end
end
