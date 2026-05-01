class MtasksWebhookProcessorJob < ApplicationJob
  queue_as :default

  HANDLERS = {
    'link.created' => :handle_link_created,
    'link.removed' => :handle_link_removed,
    'issue.created' => :handle_issue_created,
    'issue.updated' => :handle_issue_updated,
    'issue.status_changed' => :handle_issue_status_changed,
    'issue.assigned' => :handle_issue_assigned
  }.freeze

  def perform(delivery_id)
    delivery = WebhookDelivery.find(delivery_id)
    return if delivery.processed?

    handler = HANDLERS[delivery.event_type]
    if handler
      send(handler, delivery)
    else
      Rails.logger.warn("[mtasks-webhook] unknown event: #{delivery.event_type}")
    end

    delivery.update!(processed_at: Time.current)
  end

  private

  HANDLERS.each_value do |method_name|
    define_method(method_name) do |delivery|
      Rails.logger.info("[mtasks-webhook] TODO #{method_name}: #{delivery.payload['data'].inspect}")
    end
  end
end
