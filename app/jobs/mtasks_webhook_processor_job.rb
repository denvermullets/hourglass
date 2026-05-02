class MtasksWebhookProcessorJob < ApplicationJob
  queue_as :default

  HANDLERS = {
    'link.created' => :handle_link,
    'link.removed' => :handle_link,
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

  def handle_link(delivery)
    result = Webhooks::Mtasks::ProcessLink.call(delivery: delivery)
    return if result.ok

    Rails.logger.warn("[mtasks-webhook] link processing rejected: #{result.error}")
  end

  # Auto-define stubs for the still-stubbed events only (skip :handle_link, which is real).
  HANDLERS.each_value.uniq.reject { |m| m == :handle_link }.each do |method_name|
    define_method(method_name) do |delivery|
      Rails.logger.info("[mtasks-webhook] TODO #{method_name}: #{delivery.payload['data'].inspect}")
    end
  end
end
